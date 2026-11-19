// regfile.sv
//
// Host-visible registers: read mux, write decode and storage
//

`default_nettype none

module regfile
    import ising_params::*;
(
    input  logic                  clk,
    input  logic                  rst_n,
    // from serial_if
    input  logic                  wr_en,
    input  logic [6:0]            wr_addr,
    input  logic [7:0]            wr_data,
    input  logic [6:0]            rd_addr,
    output logic [7:0]            rd_data,
    // datapath flip and status for reads
    input  logic                  busy, done,
    input  logic                  flip,
    input  logic [IW-1:0]         flip_i,
    input  logic [TW-1:0]         t,
    input  logic [OFFW-1:0]       offset,
    input  logic [7:0]            raw_hist,
    input  logic                  u_valid,
    input  logic [LFSR_W-1:0]     lfsr,
    input  logic [15:0]           flips, sweeps,
    // command strobes
    output logic                  start, stop,
    output logic                  seed_lo_we, seed_hi_we,
    output logic [7:0]            seed_data,
    // registers
    output logic [NW-1:0][JW-1:0] weights,
    output logic [N-1:0][HW-1:0]  h,
    output logic [N-1:0]          spins,
    output logic [N-1:0]          spin_mask,
    output logic [TW-1:0]         t_start, t_end,
    output logic [15:0]           level_sweeps,
    output logic [OFFW-1:0]       offset_step,
    output logic                  continuous, ent_sel, whiten_bypass, ro_en
);

    // true for the bias field registers H_BASE .. H_BASE + N - 1
    function automatic logic is_h_addr(input logic [6:0] addr);
        logic r;
        r = (addr >= REG_H_BASE) && (addr < REG_H_BASE + 7'(N));
        return r;
    endfunction

    logic [IW-1:0] rd_h_idx, wr_h_idx; // index into h for an H address
    logic [7:0]    h_rd, wchain_out, ctrl_rd, status_rd;
    logic [7:0]    flips_lo, flips_hi, sweeps_lo, sweeps_hi;
    logic          ctrl_write, idle_write;

    assign rd_h_idx = IW'(rd_addr - REG_H_BASE);
    assign wr_h_idx = IW'(wr_addr - REG_H_BASE);

    // read fields as plain signals, outside the always_comb
    assign h_rd       = 8'(h[rd_h_idx]);
    assign wchain_out = 8'(weights[NW-1]);
    assign ctrl_rd    = {2'b00, ro_en, whiten_bypass, ent_sel, continuous, 2'b00};
    assign status_rd  = {5'b00000, u_valid, done, busy};

    // counter bytes, 0 unless counters are enabled
    assign flips_lo  = (COUNTERS != 0) ? flips[7:0]   : 8'd0;
    assign flips_hi  = (COUNTERS != 0) ? flips[15:8]  : 8'd0;
    assign sweeps_lo = (COUNTERS != 0) ? sweeps[7:0]  : 8'd0;
    assign sweeps_hi = (COUNTERS != 0) ? sweeps[15:8] : 8'd0;

    // read mux
    always_comb begin
        rd_data = '0;
        if (is_h_addr(rd_addr)) begin
            rd_data = h_rd;
        end else begin
            case (rd_addr)
                REG_ID:              rd_data = 8'(ID_VALUE);
                REG_CTRL:            rd_data = ctrl_rd;
                REG_STATUS:          rd_data = status_rd;
                REG_SPINS:           rd_data = spins;
                REG_SPIN_MASK:       rd_data = spin_mask;
                REG_T_START:         rd_data = 8'(t_start);
                REG_T_END:           rd_data = 8'(t_end);
                REG_LEVEL_SWEEPS_LO: rd_data = level_sweeps[7:0];
                REG_LEVEL_SWEEPS_HI: rd_data = level_sweeps[15:8];
                REG_OFFSET_STEP:     rd_data = 8'(offset_step);
                REG_SEED_LO:         rd_data = lfsr[7:0];
                REG_SEED_HI:         rd_data = lfsr[15:8];
                REG_RAW:             rd_data = raw_hist;
                REG_LEVEL:           rd_data = 8'(t);
                REG_OFFSET:          rd_data = 8'(offset);
                REG_WCHAIN_OUT:      rd_data = wchain_out;
                REG_FLIPS_LO:        rd_data = flips_lo;
                REG_FLIPS_HI:        rd_data = flips_hi;
                REG_SWEEPS_LO:       rd_data = sweeps_lo;
                REG_SWEEPS_HI:       rd_data = sweeps_hi;
                default:             rd_data = '0;
            endcase
        end
    end

    // command strobes from this clock's write
    assign ctrl_write = wr_en && (wr_addr == REG_CTRL);
    assign idle_write = wr_en && !busy; // seed writes only count while idle
    assign start      = ctrl_write && wr_data[0];
    assign stop       = ctrl_write && wr_data[1];
    assign seed_lo_we = idle_write && (wr_addr == REG_SEED_LO);
    assign seed_hi_we = idle_write && (wr_addr == REG_SEED_HI);
    assign seed_data  = wr_data;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            weights       <= '0;
            h             <= '0;
            spins         <= '0;
            spin_mask     <= REG_SPIN_MASK_RESET;
            t_start       <= TW'(REG_T_START_RESET);
            t_end         <= TW'(REG_T_END_RESET);
            level_sweeps  <= {REG_LEVEL_SWEEPS_HI_RESET, REG_LEVEL_SWEEPS_LO_RESET};
            offset_step   <= OFFW'(REG_OFFSET_STEP_RESET);
            continuous    <= 1'b0;
            ent_sel       <= 1'b0;
            whiten_bypass <= 1'b0;
            ro_en         <= 1'b0;
        end else begin
            // only the datapath writes spins while busy
            if (flip) begin
                spins[flip_i] <= ~spins[flip_i];
            end

            if (wr_en) begin
                if (wr_addr == REG_CTRL) begin
                    // always writable, bits 0 and 1 are strobes and not stored
                    continuous    <= wr_data[2];
                    ent_sel       <= wr_data[3];
                    whiten_bypass <= wr_data[4];
                    ro_en         <= wr_data[5];
                end else if (!busy) begin
                    // everything else is locked while an anneal runs
                    if (is_h_addr(wr_addr)) begin
                        h[wr_h_idx] <= wr_data[HW-1:0];
                    end else begin
                        case (wr_addr)
                            REG_SPINS:           spins              <= wr_data;
                            REG_SPIN_MASK:       spin_mask          <= wr_data;
                            REG_T_START:         t_start            <= wr_data[TW-1:0];
                            REG_T_END:           t_end              <= wr_data[TW-1:0];
                            REG_LEVEL_SWEEPS_LO: level_sweeps[7:0]  <= wr_data;
                            REG_LEVEL_SWEEPS_HI: level_sweeps[15:8] <= wr_data;
                            REG_OFFSET_STEP:     offset_step        <= wr_data[OFFW-1:0];
                            // shift every weight up one index, new weight into 0
                            REG_WCHAIN_IN:       weights <= {weights[NW-2:0], wr_data[JW-1:0]};
                            default: ;
                        endcase
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
