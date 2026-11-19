// anneal_ctrl.sv
//
// Run state, temperature schedule, dynamic offset, counters
//

`default_nettype none

module anneal_ctrl
    import ising_params::*;
(
    input logic clk,
    input logic rst_n,
    // control input
    input logic            start_pin, start_reg, stop,
    input logic            u_valid, accept,
    input logic [N-1:0]    spin_mask,
    input logic [TW-1:0]   t_start, t_end,
    input logic [15:0]     level_sweeps,
    input logic [OFFW-1:0] offset_step,
    input logic            continuous,
    // control output
    output logic fire, flip,
    // registers
    output logic            busy, done,
    output logic [TW-1:0]   t,
    output logic [IW-1:0]   i,
    output logic [OFFW-1:0] offset,
    output logic [15:0]     flips, sweeps
);

    logic sweep_acc; // true if flip accepted this sweep
    logic [15:0] sweep_cnt; // number of sweeps completed this level

    assign fire = busy && u_valid && !stop; // if high, update this cycle
    assign flip = fire && accept && spin_mask[i];

    logic [15:0] sweeps_done; // 16 bit wrap, 0 is 65536
    logic [OFFW:0] off_sum; // offset + offset_step can exceed OFF_MAX, extra bit
    logic [15:0] flips_inc, sweeps_inc;

    assign sweeps_done = sweep_cnt + 16'd1; 
    assign off_sum = offset + offset_step; // TODO: extend explicitly 
    assign flips_inc = (flips == 16'hFFFF) ? flips : (flips + 16'd1);
    assign sweeps_inc = (sweeps == 16'hFFFF) ? sweeps : (sweeps + 16'd1);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            busy        <= 1'b0;
            done        <= 1'b0;
            t           <= '0;
            i           <= '0;
            sweep_cnt   <= '0;
            offset      <= '0;
            sweep_acc   <= 1'b0;
            flips       <= '0;
            sweeps      <= '0;
        end else if (stop) begin
            // end the anneal, don't change done
            busy <= 1'b0;
        end else if ( (start_pin || start_reg) && !busy ) begin 
            // start, from the first level, spin 0
            busy        <= 1'b1;
            done        <= 1'b0;
            t           <= t_start;
            i           <= '0;
            sweep_cnt   <= '0;
            offset      <= '0;
            sweep_acc   <= 1'b0;
            flips       <= '0;
            sweeps      <= '0;
        end else if (fire) begin
            // an accepted flip clears the dynamic offset
            if (flip) begin
                offset  <= '0;
                sweep_acc <= 1'b1;
                // increment the flips counter
                if (COUNTERS != 0) begin
                    flips <= flips_inc;
                end
            end

            // check if this is not the last spin
            if (i != IW'(N - 1)) begin
                i <= i + IW'(1);
            end else begin
                // this is the end of the sweep,
                // go back to spin 0.
                i <= '0;
                sweep_acc <= 1'b0;

                // no accepted flip this sweep so raise offset
                // (saturates at OFF_MAX)
                if (!sweep_acc && !flip) begin
                    if (off_sum > (OFFW+1)'(OFF_MAX)) begin
                        offset <= OFFW'(OFF_MAX);
                    end else begin
                        offset <= off_sum[OFFW-1:0];
                    end
                end

                // increment the sweeps counter
                if (COUNTERS != 0) begin
                    sweeps <= sweeps_inc;
                end

                // check if we have not reached the sweeps for
                // current level.
                if (sweeps_done != level_sweeps) begin
                    sweep_cnt <= sweeps_done; 
                end else begin
                    // end of the level, next (cooler) level or finish
                    sweep_cnt <= '0;
                    if (t < t_end) begin
                        t <= t + TW'(1);
                    end else if (!continuous) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end
            end
        end
    end
endmodule

`default_nettype wire
