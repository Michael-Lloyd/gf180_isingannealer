// sync_in.sv
//
// 2-flip synchronizers and edge detection for async pins

`default_nettype none

module sync_in (
    input logic clk,
    input logic rst_n,
    input logic sclk, cs_n, sdi, start,
    output logic sclk_rise, sclk_fall,
    output logic cs_active,
    output logic sdi_s,
    output logic start_rise
);

    logic sclk_s1, sclk_s2, sclk_q;
    logic cs_s1, cs_s2;
    logic sdi_s1, sdi_s2;
    logic start_s1, start_s2, start_q;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sclk_s1 <= 1'b0;
            sclk_s2 <= 1'b0; 
            sclk_q  <= 1'b0;
            cs_s1 <= 1'b1;
            cs_s2 <= 1'b1; // cs_n idles high
            sdi_s1 <= 1'b0; 
            sdi_s2 <= 1'b0;
            start_s1 <= 1'b0;
            start_s2 <= 1'b0;
            start_q <= 1'b0;
        end else begin
            sclk_s1 <= sclk;
            sclk_s2 <= sclk_s1;
            sclk_q <= sclk_s2;
            cs_s1 <= cs_n; 
            cs_s2 <= cs_s1;
            sdi_s1 <= sdi;
            sdi_s2 <= sdi_s1;
            start_s1 <= start;
            start_s2 <= start_s1;
            start_q <= start_s2;
        end
    end

    assign sclk_rise = sclk_s2 & ~sclk_q;
    assign sclk_fall = ~sclk_s2 &  sclk_q;
    assign cs_active = ~cs_s2;
    assign sdi_s = sdi_s2;
    assign start_rise = start_s2 & ~start_q;

endmodule

`default_nettype wire
