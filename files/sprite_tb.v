`timescale 1ns / 1ps

module sprite_tb;

    parameter CLK_PERIOD = 40;  // 40 ns == 25 MHz

    // display sync signals and coordinates
    localparam CORDW = 10;  // screen coordinate width in bits
    wire signed [CORDW-1:0] sx, sy;
    wire hSync, vSync;

    reg Clk;
	reg		Reset; // , ClkPort;

	wire line;
	

	wire bright;
	wire[9:0] hc, vc;
	wire clk25;
    wire[3:0] state;
    wire[$clog2(SPR_WIDTH)-1:0] bmap_x1, bmap_x2;
    wire [$clog2(SPR_ROM_DEPTH)-1:0] ra;
    wire [$clog2(SPR_ROM_DEPTH)-1:0] sp;

    display_controller dc(.clk(Clk), .hSync(hSync), .vSync(vSync), .bright(bright), .hCount(hc), .vCount(vc), .line(line), .clk25(clk25));


    // screen dimensions (must match display_inst)
    localparam H_RES = 784;

    // sprite parameters
    localparam SX_OFFS    = 2;  // horizontal screen offset (pixels)
    localparam SPR_FILE   = "letter_f.mem";
    localparam SPR_WIDTH  = 8;  // width in pixels
    localparam SPR_HEIGHT = 8;  // height in pixels
    localparam SPR_SCALE  = 1;  // 2^1 = 2x scale
    localparam SPR_DATAW  = 2;  // bits per pixel

    wire drawing;  // drawing at (sx,sy)
    wire drawing1, drawing2;
	wire [SPR_DATAW-1:0] spr_pix_indx;
    

    localparam SPR_ROM_DEPTH = SPR_WIDTH * SPR_HEIGHT;

    // draw sprite at position (sprx,spry)
    reg signed [CORDW-1:0] sprx, spry;
    wire [SPR_SCALE:0] cnt_x;
    wire [SPR_DATAW-1:0] pix1, pix2;

    wire [SPR_DATAW-1:0] spr_pix_indx;
    // assign spr_pix_indx = pix1 ? pix1 : (pix2 ? pix2 : 0);
	// assign drawing = drawing1 || drawing2;

    sprite #(
        .CORDW(CORDW),
        .H_RES(H_RES),
        .SX_OFFS(SX_OFFS),
        .SPR_FILE(SPR_FILE),
        .SPR_WIDTH(SPR_WIDTH),
        .SPR_HEIGHT(SPR_HEIGHT),
        .SPR_DATAW(SPR_DATAW),
        .SPR_SCALE(SPR_SCALE)
		) test_sprite1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(sprx),
        .spry(spry),
        .pix(pix1),
        .drawing(drawing1),
        .state(state),
        .bmap_x(bmap_x1),
        .spr_rom_addr(sp),
        .addr_return(ra),
        .cnt_x(cnt_x)
    );

    // sprite #(
    //     .CORDW(CORDW),
    //     .H_RES(H_RES),
    //     .SX_OFFS(SX_OFFS),
    //     .SPR_FILE(SPR_FILE),
    //     .SPR_WIDTH(SPR_WIDTH),
    //     .SPR_HEIGHT(SPR_HEIGHT),
    //     .SPR_DATAW(SPR_DATAW)
	// 	) test_sprite2 (
    //     .clk(clk25),
    //     .rst(Reset),
    //     .line(line),
    //     .sx(hc),
    //     .sy(vc),
    //     .sprx(300),
    //     .spry(0),
    //     .pix(pix2),
    //     .drawing(drawing2),
    //     .state(state),
    //     .bmap_x(bmap_x2),
    //     .spr_rom_addr(sp),
    //     .addr_return(ra)
    // );

    initial 
		  begin
			Clk = 0; // Initialize clock
		  end
		
    always  begin #20; Clk = ~ Clk; end

    initial begin
        Reset = 1;
        Clk = 0;
        sprx = 143;
        spry = 0;
        #120 Reset = 0;

        #43000
        #43000
        #43000
        // sprx = -7;
        // spry = -7;

        // #43000
        // sprx = 20;
        // spry = 4;

        // #43000
        // sprx = 20;
        // spry = 16;

        // #43000
        // sprx = 0;
        // spry = 0;

        #50000 $finish;
    end
endmodule