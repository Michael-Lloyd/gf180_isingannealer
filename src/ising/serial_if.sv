// serial_if.sv
//
// Simple SPI interface (mode 0), msb first, 16-bit frames 
// as {rw, addr[6:0]}, data

`default_nettype none

module serial_if (
    input  logic clk,
    input  logic rst_n,
    input  logic sclk_rise, sclk_fall, cs_active, sdi, // from sync_in
    input  logic [7:0] rd_data, // from regfile 
    output logic [6:0] rd_addr,
    output logic wr_en,
    output logic [6:0] wr_addr,
    output logic [7:0] wr_data,
    output logic sdo
);

    // registers for serial state
    logic [4:0] bitcnt; // rising edges seen in this frame, 0..16
    /* verilator lint_off UNUSEDSIGNAL */
    logic [15:0] shreg; // bit 15 is never read 
    /* verilator lint_on UNUSEDSIGNAL */
    logic [7:0] tx; 

    // shift register with sdi shifted in at this edge
    logic [15:0] sh;
    logic shifting;
    assign sh = {shreg[14:0], sdi};
    assign shifting = cs_active && sclk_rise && (bitcnt < 5'd16);

    // combinational outputs, the read address at 8th edge and write pulse at the 16th
    assign rd_addr = sh[6:0];
    assign wr_en = shifting && (bitcnt == 5'd15) && !sh[15];
    assign wr_addr = sh[14:8];
    assign wr_data = sh[7:0];

    always_ff @(posedge clk) begin
        if (!rst_n || !cs_active) begin
            // reset, or cs_n high, clear the frame
            bitcnt <= '0;
            shreg <= '0;
            tx <= '0;
            sdo <= 1'b0;
        end else if (shifting) begin
            // rising edge. take in sdi
            shreg <= sh;
            bitcnt <= bitcnt + 5'd1;
            // at 8th edge of read frame capture the register value to echo
            if ((bitcnt == 5'd7) && sh[7]) begin
                tx <= rd_data;
            end
        end else if (sclk_fall && (bitcnt >= 5'd8) && (bitcnt < 5'd16)) begin
            // falling edge in the data byte means drive the next read bit 
            sdo <= tx[7];
            tx <= {tx[6:0], 1'b0};
        end
    end

endmodule

`default_nettype wire
