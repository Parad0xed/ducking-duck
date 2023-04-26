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
    wire [$clog2(30)-1:0] bmap_x;
    wire[CAT_SCALE:0] cnt_x;

    display_controller dc(.clk(Clk), .hSync(hSync), .vSync(vSync), .bright(bright), .hCount(hc), .vCount(vc), .line(line), .clk25(clk25));


    // screen dimensions (must match display_inst)
    localparam H_RES = 784;
    localparam CIDXW = 3;


    /* ========================================================================== */

    // ONE TIME IN 'LEVEL' MODULE

    assign output_pix = low2_data | high1_data;

    // CACTUS "LOWOBS2"
    localparam LOW2_WIDTH  =  30;  // bitmap width in pixels
    localparam LOW2_HEIGHT =  32;  // bitmap height in pixels
    localparam LOW2_SCALE  =  1;  // 2^2 = 4x scale
	localparam LOW2_FILE = "lowobs2.mem";
    localparam LOW2ROMDEPTH = LOW2_WIDTH * LOW2_HEIGHT;
    wire [$clog2(LOW2ROMDEPTH)-1:0] low2_addr1, low2_addr2, low2_addr3;
    wire [$clog2(LOW2ROMDEPTH)-1:0] low2_addr;  // pixel position
    wire [CIDXW-1:0] low2_data;  // pixel color
	assign low2_addr = low2_addr1 | low2_addr2 | low2_addr3;
    rom #(
        .WIDTH(3), // SPR_DATAW),
        .DEPTH(LOW2ROMDEPTH),
        .INIT_F(LOW2_FILE)
	) test (
        .clk(clk25),
        .addr(low2_addr),
        .data(low2_data)
    );

    // HELICOPTER "HIGHOBS1"
    localparam HIGH1_WIDTH  =  40;  // bitmap width in pixels
    localparam HIGH1_HEIGHT =  32;  // bitmap height in pixels
    localparam HIGH1_SCALE  =  1;  // 2^2 = 4x scale
	localparam HIGH1_FILE = "highobs1.mem";
    localparam HIGH1ROMDEPTH = HIGH1_WIDTH * HIGH1_HEIGHT;
    wire [$clog2(HIGH1ROMDEPTH)-1:0] high1_addr1, high1_addr2, high1_addr3;
    wire [$clog2(HIGH1ROMDEPTH)-1:0] high1_addr;  // pixel position
    wire [CIDXW-1:0] high1_data;  // pixel color
	assign high1_addr = high1_addr1 | high1_addr2 | high1_addr3;
    rom #(
        .WIDTH(3), // SPR_DATAW),
        .DEPTH(HIGH1ROMDEPTH),
        .INIT_F(HIGH1_FILE)
	) test (
        .clk(clk25),
        .addr(high1_addr),
        .data(high1_data)
    );


    /* =========================================================================== */

    // DUPLICATED CODE IN EACH OBSTACLE INSTANCE, FOR n UNIQUE OBSTACLES
    //      Note: each obstacle instance will need to have n output reg containing address from each sprite module
    reg [9:0] sprx, spry;
    reg low2_en, high1_en; // add more when adding more obstacles


    localparam LOW2_WIDTH  =  30;  // bitmap width in pixels
    localparam LOW2_HEIGHT =  32;  // bitmap height in pixels
    localparam LOW2_SCALE  =  1;  // 2^2 = 4x scale
    sprite2 #(
        .SPR_WIDTH(LOW2_WIDTH),
        .SPR_HEIGHT(LOW2_HEIGHT),
		.SPR_SCALE(LOW2_SCALE)
    ) low2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(sprx),
        .spry(spry),
		.spr_rom_addr(low2_addr1),
        .en(low2_en)
    );

    localparam HIGH1_WIDTH  =  40;  // bitmap width in pixels
    localparam HIGH1_HEIGHT =  32;  // bitmap height in pixels
    localparam HIGH1_SCALE  =  1;  // 2^2 = 4x scale
    sprite2 #(
        .SPR_WIDTH(HIGH1_WIDTH),
        .SPR_HEIGHT(HIGH1_HEIGHT),
		.SPR_SCALE(HIGH1_SCALE)
    ) high1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(sprx),
        .spry(spry),
		.spr_rom_addr(high1_addr1),
        .en(high1_en)
    );


    /* =========================================================================== */














    // sprite parameters
    localparam CAT_WIDTH  =  30;  // bitmap width in pixels
    localparam CAT_HEIGHT =  32;  // bitmap height in pixels
    localparam CAT_SCALE  =  0;  // 2^2 = 4x scale
	localparam CAT_IDLE_FILE = "idle1.mem";

	sprite2 #(
        .SPR_FILE(CAT_IDLE_FILE),
        .SPR_WIDTH(CAT_WIDTH),
        .SPR_HEIGHT(CAT_HEIGHT),
		.SPR_SCALE(CAT_SCALE)
    ) catidle1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(200),
        .spry(150),
		.spr_rom_addr(cataddr1),
        .cnt_x(cnt_x), .bmap_x(bmap_x), .state(state),
        .en(1)
    );

	sprite2 #(
        .SPR_FILE(CAT_IDLE_FILE),
        .SPR_WIDTH(CAT_WIDTH),
        .SPR_HEIGHT(CAT_HEIGHT),
		.SPR_SCALE(CAT_SCALE)
    ) catidle2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(400),
        .spry(150),
		.spr_rom_addr(cataddr2),
        .en(1)
    );

	wire [$clog2(CATROMDEPTH)-1:0] cataddr1, cataddr2;

	localparam CATROMDEPTH = CAT_WIDTH * CAT_HEIGHT;
    wire [$clog2(CATROMDEPTH)-1:0] spr_rom_addr;  // pixel position
    wire [CIDXW-1:0] spr_rom_data;  // pixel color
	assign spr_rom_addr = cataddr1 | cataddr2;
    rom #(
        .WIDTH(3), // SPR_DATAW),
        .DEPTH(CATROMDEPTH),
        .INIT_F(CAT_IDLE_FILE)
	) test (
        .clk(clk25),
        .addr(spr_rom_addr),
        .data(spr_rom_data)
    );
	
    /*
    draw sprite at position (sprx,spry)
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

    sprite #(
        .CORDW(CORDW),
        .H_RES(H_RES),
        .SX_OFFS(SX_OFFS),
        .SPR_FILE(SPR_FILE),
        .SPR_WIDTH(SPR_WIDTH),
        .SPR_HEIGHT(SPR_HEIGHT),
        .SPR_DATAW(SPR_DATAW)
		) test_sprite2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(300),
        .spry(0),
        .pix(pix2),
        .drawing(drawing2),
        .state(state),
        .bmap_x(bmap_x2),
        .spr_rom_addr(sp),
        .addr_return(ra)
    );
    */

    initial 
		  begin
			Clk = 0; // Initialize clock
		  end
		
    always  begin #20; Clk = ~ Clk; end


    initial begin
        Reset = 1;
        Clk = 0;
        
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