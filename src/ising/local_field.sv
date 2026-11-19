// local_field.sv
//
// the local field combinational logic for the datapath
// ( L_i = sum_{j != i}{ J_{i,j} * s_j } + h_i )

`default_nettype none

module local_field
    import ising_params::*;
(
    input logic [NW-1:0][JW-1:0] weights, // raw 2-complement patterns
    input logic [N-1:0][HW-1:0] h,
    input logic [N-1:0] spins, 
    input logic [IW-1:0] i,
    output logic signed [LW-1:0] lf
);

    // same as weight_index, only called with constants 
    function automatic int widx(int a, int b);
        int lo = (a < b) ? a : b;
        int hi = (a < b) ? b : a;
        int r = (lo * N) - ( (lo * (lo + 1)) / 2 ) + (hi - lo - 1);
        return r;
    endfunction

    logic [JW-1:0] w_row [N][N-1];
    logic s_row [N][N-1];
   
    // unrolled
    for (genvar si = 0; si < N; si++) begin : g_row
        for (genvar k = 0; k < N - 1; k++) begin : g_slot
            localparam int J = (k < si) ? k : k + 1; // need to skip j == si
            assign w_row[si][k] = weights[widx(si, J)];
            assign s_row[si][k] = spins[J];
        end
    end
  
    // row select mux on i, conditional negate, adder chain
    always_comb begin
        logic signed [JW:0] jw;
        lf = '0;
        for (int k = 0; k < N - 1; k++) begin
            jw = (JW+1)'($signed(w_row[i][k])); // extend for sign
            lf = s_row[i][k] ? (lf + LW'(jw)) : (lf - LW'(jw));
        end
        lf = lf + LW'($signed(h[i]));
    end

endmodule

`default_nettype wire
