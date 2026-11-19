// ising_macro.sv
//
// Annealer block for the shared die
//

`default_nettype none

module ising_macro (
    `ifdef USE_POWER_PINS
    inout  wire  VDD,
    inout  wire  VSS,
    `endif
    input  logic clk,
    input  logic rst_n,
    input  logic sclk, cs_n, sdi, start,
    output logic sdo,
    output logic done,
    output logic trng_raw
);

    logic rst_s1, rst_sync_n;
    logic ro_en, ro_bit;

    always_ff @(posedge clk) begin
        rst_s1     <= rst_n;
        rst_sync_n <= rst_s1;
    end

    ro_osc u_ro (
        .en     (ro_en),
        .ro_out (ro_bit)
    );

    ising_core u_core (
        .clk,
        .rst_n (rst_sync_n),
        .start,
        .sclk,
        .cs_n,
        .sdi,
        .ro_bit,
        .sdo,
        .done,
        .trng_raw,
        .ro_en
    );

endmodule

`default_nettype wire
