// delta_e.sv
//
// Energy change if spin i is flipped
//

`default_nettype none

module delta_e
    import ising_params::*;
(
    input  logic                  s_i, // 1 = +1, 0 = -1
    input  logic signed [LW-1:0]  lf,
    output logic signed [DEW-1:0] de
);

    logic signed [DEW-1:0] lf_double;

    assign lf_double = DEW'(lf) <<< 1; // sign extend then double
    assign de = s_i ? lf_double : -lf_double;

endmodule

`default_nettype wire
