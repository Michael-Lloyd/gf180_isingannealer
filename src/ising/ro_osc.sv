/*
 * ro_osc.sv
 *
 * Free-running ring oscillator for the TRNG (hand-instantiated cells).
 * C model: none: the model takes ro_bit as an input pin
*/

// ro_osc.sv
//
// ring oscillator (don't touch)

`default_nettype none

module ro_osc (
    input logic en, // low to stop oscillator 
    output logic ro_out
);

`ifdef SIMULATION
    // the loop has no meaningful simulation
    logic unused_en;
    assign unused_en = en;
    assign ro_out = 1'b0;
`else
    // (* keep *) is essential to prevent synthesizer from simplifying
    (* keep *) wire n0, n1, n2;
    (* keep *) gf180mcu_fd_sc_mcu7t5v0__nand2_1 u_nand (.A1(en), .A2(n2), .ZN(n0));
    (* keep *) gf180mcu_fd_sc_mcu7t5v0__inv_1   u_inv0 (.I(n0), .ZN(n1));
    (* keep *) gf180mcu_fd_sc_mcu7t5v0__inv_1   u_inv1 (.I(n1), .ZN(n2));
    // output buffer, ring node n2 only sees u_nand and this one small input,
    // so the wiring to the sampler cannot load or couple into the ring
    (* keep *) gf180mcu_fd_sc_mcu7t5v0__buf_1   u_obuf (.I(n2), .Z(ro_out));
`endif

endmodule

`default_nettype wire
