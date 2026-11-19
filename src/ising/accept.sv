// accept.sv
//
// Metropolis decision with dynamic offset
//

`default_nettype none
module accept
    import ising_params::*;
( 
    input logic signed [DEW-1:0] de,
    input logic [OFFW-1:0] offset,
    input logic [TW-1:0] t_level,
    input logic [K-1:0] u,
    output logic acc
);

    logic [K-1:0] thr;
    // one extra bit, de - offset reaches -(DE_MAX + OFF_MAX)
    logic signed [DEW:0] de_eff;

    // needs to be signed, widens offset 
    assign de_eff = (DEW + 1)'(de) - $signed((DEW + 1)'(offset));  

    // threshold lookup at {t_level, de_eff} when de_eff > 0
    thr_rom u_rom (
        .addr ({t_level, de_eff[THR_DW-1:0]}),
        .thr (thr)
    ); 

    assign acc = (d_eff <= 0) || (u < thr);

endmodule

`default_nettype wire
