// entropy.sv
//
// Contains lfsr shift, advance, and entropy computations
//

`default_nettype none

module entropy
    import ising_params::*;
(
    input logic             clk,
    input logic             rst_n,
    input logic             ro_bit, // from ro_osc
    input logic             ro_en, ent_sel, whiten_bypass, // options
    input logic             consume,
    input logic             seed_lo_we, seed_hi_we,
    input logic [7:0]       seed_data,
    output logic [K-1:0]    u,
    output logic            u_valid,
    output logic [7:0]      raw_hist,
    output logic [LFSR_W-1:0] lfsr,
    output logic            trng_raw
);

    localparam int CW = $clog2(K + 1); // acc_cnt counts 0 .. K

    // registers for entropy state
    logic ro_s1, ro_s2; // sampler registers with ro_s2 as raw bit
    logic vn_have, vn_first; // whitener pair state 
    logic [K-1:0] acc; // the trng word being built 
    logic [CW-1:0] acc_cnt; 

    // one shift, bit shifted out of biut 0 is XORed into the taps
    function automatic logic [LFSR_W-1:0] lfsr_shift(input logic [LFSR_W-1:0] x);
        logic [LFSR_W-1:0] y;
        y = x >> 1;
        if (x[0]) begin
            y = y ^ LFSR_W'(LFSR_MASK);
        end
        return y;
    endfunction

    // one random word shifted K times
    function automatic logic [LFSR_W-1:0] lfsr_advance(input logic [LFSR_W-1:0] x);
        logic [LFSR_W-1:0] y;
        y = x;
        for (int k = 0; k < K; k++) begin
            y = lfsr_shift(y);
        end
        return y;
    endfunction

    function automatic logic [LFSR_W-1:0] seed_load(input logic [15:0] v);
        logic [LFSR_W-1:0] s;
        s = LFSR_W'(v);
        if (s == '0) begin
            s = LFSR_W'(1);
        end
        return s;
    endfunction
       
    // combinational outputs for the entropy mux
    assign u = ent_sel ? acc : lfsr[K-1:0];
    assign u_valid = ent_sel ? (acc_cnt == CW'(K)) : 1'b1;
    assign trng_raw = ro_s2;

    // whitener ouput (10 -> 1, 01 -> 0, else -> nothing)
    logic bit_valid, wbit;
    always_comb begin
        bit_valid = 1'b0;
        wbit = 1'b0;
        if (ro_en) begin
            if (whiten_bypass) begin
                bit_valid = 1'b1;
                wbit = ro_s2;
            end else if (vn_have && (vn_first != ro_s2)) begin
                bit_valid = 1'b1;
                wbit = vn_first;
            end
        end
    end

    // seed writes replace one byte of LFSR
    logic [15:0] lfsr16, seed_lo_val, seed_hi_val;
    assign lfsr16 = 16'(lfsr);
    assign seed_lo_val = (lfsr16 & 16'hFF00) | {8'h00, seed_data};
    assign seed_hi_val = (lfsr16 & 16'h00FF) | {seed_data, 8'h00};

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ro_s1    <= 1'b0;
            ro_s2    <= 1'b0;
            raw_hist <= '0;
            vn_have  <= 1'b0;
            vn_first <= 1'b0;
            acc      <= '0;
            acc_cnt  <= '0;
            lfsr     <= LFSR_W'(LFSR_RESET);
        end else begin
            // sampler, raw hist
            ro_s1 <= ro_en ? ro_bit : 1'b0;
            ro_s2 <= ro_s1;
            raw_hist <= {raw_hist[6:0], ro_s2};

            //whitener pair state 
            if (ro_en && !whiten_bypass) begin
                if (!vn_have) begin
                    vn_have <= 1'b1; // set first bit
                    vn_first <= ro_s2;
                end else begin
                    vn_have <= 1'b0; // pair complete
                end
            end

            // accumulator, word used -> start new one
            if (consume && ent_sel) begin
                acc_cnt <= '0;
            end else if (bit_valid && (acc_cnt < CW'(K))) begin
                acc <= {acc[K-2:0], wbit};
                acc_cnt <= acc_cnt + CW'(1);
            end

            // LFSR, seed writes else advance when datapath used
            if (seed_lo_we) begin
                lfsr <= seed_load(seed_lo_val);
            end else if (seed_hi_we) begin
                lfsr <= seed_load(seed_hi_val);
            end else if (consume && !ent_sel) begin
                lfsr <= lfsr_advance(lfsr);
            end
        end
    end

endmodule

`default_nettype wire
