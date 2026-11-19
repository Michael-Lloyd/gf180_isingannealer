create_clock -name clk -period $::env(CLOCK_PERIOD) [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]

set inputs [delete_from_list [all_inputs] [get_ports clk]]
set_false_path -from $inputs
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__buf_2 -pin Z $inputs
set_output_delay [expr {$::env(CLOCK_PERIOD) * 0.2}] -clock clk [all_outputs]
set_load 0.05 [all_outputs]

set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}

set ro_cells [get_cells -quiet -hierarchical *u_ro*]
if { [llength $ro_cells] > 0 } {
    set_disable_timing $ro_cells
}
