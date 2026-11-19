// ising_core.sv
//
// top level of the annealer

`default_nettype none

module ising_core
    import ising_params::*;
(
    input  logic clk,
    input  logic rst_n, // synchronous, active low
    input  logic start, sclk, cs_n, sdi,
    input  logic ro_bit, // ring oscillator output
    output logic sdo,
    output logic done,
    output logic trng_raw,
    output logic ro_en // enables the ring oscillator
);
    // sync_in -> serial_if, anneal_ctrl
    logic sclk_rise, sclk_fall, cs_active, sdi_s, start_rise;

    // serial_if <-> regfile
    logic [6:0] rd_addr, wr_addr;
    logic [7:0] rd_data, wr_data;
    logic       wr_en;

    // regfile outputs
    logic cmd_start, cmd_stop, seed_lo_we, seed_hi_we;
    logic [7:0] seed_data;
    logic [NW-1:0][JW-1:0] weights;
    logic [N-1:0][HW-1:0] h;
    logic [N-1:0] spins, spin_mask;
    logic [TW-1:0] t_start, t_end;
    logic [15:0] level_sweeps;
    logic [OFFW-1:0] offset_step;
    logic continuous, ent_sel, whiten_bypass;

    // entropy outputs
    logic [K-1:0] u;
    logic u_valid;
    logic [7:0] raw_hist;
    logic [LFSR_W-1:0] lfsr;

    // anneal_ctrl outputs
    logic fire, flip, busy;
    logic [TW-1:0] t;
    logic [IW-1:0] i;
    logic [OFFW-1:0] offset;
    logic [15:0] flips, sweeps;

    // datapath
    logic signed [LW-1:0] lf;
    logic signed [DEW-1:0] de;
    logic acc;

    sync_in u_sync (
        .clk, 
        .rst_n, 
        .sclk, 
        .cs_n, 
        .sdi, 
        .start,
        .sclk_rise, 
        .sclk_fall, 
        .cs_active, 
        .sdi_s, 
        .start_rise
    );

    serial_if u_ser (
        .clk, 
        .rst_n, 
        .sclk_rise, 
        .sclk_fall, 
        .cs_active, 
        .sdi(sdi_s),
        .rd_data, 
        .rd_addr, 
        .wr_en, 
        .wr_addr, 
        .wr_data, 
        .sdo
    );

    regfile u_regs (
        .clk, 
        .rst_n,
        .wr_en, 
        .wr_addr, 
        .wr_data, 
        .rd_addr, 
        .rd_data,
        .busy, 
        .done, 
        .flip, 
        .flip_i(i), 
        .t, 
        .offset, 
        .raw_hist, 
        .u_valid,
        .lfsr, 
        .flips, 
        .sweeps,
        .start(cmd_start), 
        .stop(cmd_stop), 
        .seed_lo_we, 
        .seed_hi_we, 
        .seed_data,
        .weights, 
        .h, 
        .spins, 
        .spin_mask, 
        .t_start, 
        .t_end, 
        .level_sweeps,
        .offset_step, 
        .continuous, 
        .ent_sel, 
        .whiten_bypass, 
        .ro_en
    );

    entropy u_ent (
        .clk, 
        .rst_n, 
        .ro_bit, 
        .ro_en, 
        .ent_sel, 
        .whiten_bypass,
        .consume(fire), 
        .seed_lo_we, 
        .seed_hi_we, 
        .seed_data,
        .u, 
        .u_valid, 
        .raw_hist, 
        .lfsr, 
        .trng_raw
    );

    local_field u_lf (
        .weights, 
        .h, 
        .spins, 
        .i, 
        .lf
    );

    delta_e u_de (
        .s_i(spins[i]), 
        .lf, 
        .de
    );

    accept u_acc (
        .de, 
        .offset, 
        .t_level(t), 
        .u, 
        .acc
    );

    anneal_ctrl u_ctrl (
        .clk, 
        .rst_n,
        .start_pin(start_rise), 
        .start_reg(cmd_start), 
        .stop(cmd_stop),
        .u_valid, 
        .accept(acc), 
        .spin_mask, 
        .t_start, 
        .t_end, 
        .level_sweeps,
        .offset_step, 
        .continuous,
        .fire, 
        .flip, 
        .busy, 
        .done, 
        .t,
        .i, 
        .offset, 
        .flips, 
        .sweeps
    );

endmodule

`default_nettype wire
