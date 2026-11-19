package ising_params;

    localparam int N          = 8;
    localparam int JW         = 3;
    localparam int BIAS       = 1;
    localparam int HW         = 3;
    localparam int K          = 12;
    localparam int LEVELS     = 16;
    localparam int OFFW       = 6;
    localparam int LFSR_W     = 16;
    localparam int LFSR_MASK  = 'hB400;
    localparam int LFSR_RESET = 'hACE1;
    localparam int COUNTERS   = 1;
    localparam int ID_VALUE   = 'h15;

    localparam int NW      = N * (N - 1) / 2;
    localparam int IW      = $clog2(N);
    localparam int TW      = $clog2(LEVELS);
    localparam int L_MAX   = (N - 1) * 2**(JW - 1) + BIAS * 2**(HW - 1);
    localparam int LW      = $clog2(L_MAX + 1) + 1;
    localparam int DE_MAX  = 2 * L_MAX;
    localparam int DEW     = $clog2(DE_MAX + 1) + 1;
    localparam int THR_DW  = $clog2(DE_MAX + 1);
    localparam int OFF_MAX = 2**OFFW - 1;

    localparam logic [6:0] REG_ID              = 7'h00;
    localparam logic [6:0] REG_CTRL            = 7'h01;
    localparam logic [6:0] REG_STATUS          = 7'h02;
    localparam logic [6:0] REG_SPINS           = 7'h03;
    localparam logic [6:0] REG_SPIN_MASK       = 7'h04;
    localparam logic [6:0] REG_T_START         = 7'h05;
    localparam logic [6:0] REG_T_END           = 7'h06;
    localparam logic [6:0] REG_LEVEL_SWEEPS_LO = 7'h07;
    localparam logic [6:0] REG_LEVEL_SWEEPS_HI = 7'h08;
    localparam logic [6:0] REG_OFFSET_STEP     = 7'h09;
    localparam logic [6:0] REG_SEED_LO         = 7'h0A;
    localparam logic [6:0] REG_SEED_HI         = 7'h0B;
    localparam logic [6:0] REG_RAW             = 7'h0C;
    localparam logic [6:0] REG_LEVEL           = 7'h0D;
    localparam logic [6:0] REG_OFFSET          = 7'h0E;
    localparam logic [6:0] REG_WCHAIN_IN       = 7'h10;
    localparam logic [6:0] REG_WCHAIN_OUT      = 7'h11;
    localparam logic [6:0] REG_H_BASE          = 7'h18;
    localparam logic [6:0] REG_FLIPS_LO        = 7'h20;
    localparam logic [6:0] REG_FLIPS_HI        = 7'h21;
    localparam logic [6:0] REG_SWEEPS_LO       = 7'h22;
    localparam logic [6:0] REG_SWEEPS_HI       = 7'h23;

    localparam logic [7:0] REG_SPIN_MASK_RESET       = 8'hFF;
    localparam logic [7:0] REG_T_START_RESET         = 8'd0;
    localparam logic [7:0] REG_T_END_RESET           = 8'(LEVELS - 1);
    localparam logic [7:0] REG_LEVEL_SWEEPS_LO_RESET = 8'd16;
    localparam logic [7:0] REG_LEVEL_SWEEPS_HI_RESET = 8'd0;
    localparam logic [7:0] REG_OFFSET_STEP_RESET     = 8'd0;

endpackage
