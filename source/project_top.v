`timescale 1ns / 1ps

module project_top(
	input ClkPort,
	input BtnC,
	input BtnU,
	input BtnD,
	input BtnR,
	input BtnL, 
	
	//VGA signal
	output hSync, vSync,
	output [3:0] vgaR, vgaG, vgaB,
	
	//SSG signal 
	output An0, An1, An2, An3, An4, An5, An6, An7,
	output Ca, Cb, Cc, Cd, Ce, Cf, Cg, Dp,
	
	output MemOE, MemWR, RamCS, QuadSpiFlashCS,

	output ampPWM, ampSD
	);
	
	wire board_clk;
	wire		Reset; // , ClkPort;
	reg [26:0]	DIV_CLK;

	assign Dp = 1;
	assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg} = ssdOut[6 : 0];
    assign {An7, An6, An5, An4, An3, An2, An1, An0} = {4'b1111, anode};

	wire [3:0] state;
	
	assign vgaR = rgb[11 : 8];
	assign vgaG = rgb[7  : 4];
	assign vgaB = rgb[3  : 0];
	
	// disable mamory ports
	assign {MemOE, MemWR, RamCS, QuadSpiFlashCS} = 4'b1111;

	assign Reset = BtnC;
	BUFGP BUFGP1 (board_clk, ClkPort);
	always @(posedge board_clk, posedge Reset) 	
    begin							
        if (Reset)
		DIV_CLK <= 0;
        else
		DIV_CLK <= DIV_CLK + 1'b1;
    end

	reg FAIL_signal;
	wire BtnR_Pulse, BtnL_Pulse, BtnU_Pulse, BtnD_Pulse, BtnD_Signal;
	wire line;
	wire drawing;  // drawing at (sx,sy)
	wire [CIDXW:0] pix, char_pix, score_pix, level_pix, obstacle_pix;
	wire bright;
	wire[9:0] hc, vc;
	wire [6:0] ssdOut;
	wire [3:0] anode;
	wire [11:0] rgb;
	wire clk25;
	display_controller dc(.clk(ClkPort), .hSync(hSync), .vSync(vSync), .bright(bright), .hCount(hc), .vCount(vc), .line(line), .clk25(clk25));
	vga_bitchange #(.CIDXW(CIDXW)) vbc (.clk(ClkPort), .bright(bright), .button(BtnU), .drawing(drawing) ,.pix(pix), .hCount(hc), .vCount(vc), .rgb(rgb), .score(score));
	core #(.CIDXW(CIDXW)) a (.Clk(ClkPort), .FAIL_signal(FAIL_signal), .BtnR_Pulse(BtnR_Pulse), .BtnL_Pulse(BtnL_Pulse), .BtnU_Pulse(BtnU_Pulse), .BtnD_Pulse(BtnD_Pulse), .BtnD(BtnD_Signal), .Reset(Reset), .clk25(clk25), .line(line), .hc(hc), .vc(vc), .pix(char_pix), .score_pix(score_pix), .drawing(drawing), .state(state));
	// state output ommitted ^ (not anymore)
	level #() levelGen(.CLK(ClkPort), .RESET(Reset), .line(line), .clk25(clk25), .state(state), .hc(hc), .vc(vc), .level_pix(level_pix), .obstacle_pix(obstacle_pix));

	localparam CIDXW=3; // maybe not constant if need space	

	// why doesn't N_dc need to be listed at module declarationa as a parameter ???
	debouncer #(.N_dc(15)) debounce1
        (.CLK(ClkPort), .RESET(Reset), .PB(BtnR), .DPB( ), 
		.SCEN(BtnR_Pulse), .MCEN( ), .CCEN( ));

	debouncer #(.N_dc(15)) debounce2
        (.CLK(ClkPort), .RESET(Reset), .PB(BtnU), .DPB( ), 
		.SCEN(BtnU_Pulse), .MCEN( ), .CCEN( ));

	debouncer #(.N_dc(15)) debounce4
        (.CLK(ClkPort), .RESET(Reset), .PB(BtnL), .DPB( ), 
		.SCEN(BtnL_Pulse), .MCEN( ), .CCEN( ));
		
	debouncer #(.N_dc(15)) debounce3
        (.CLK(ClkPort), .RESET(Reset), .PB(BtnD), .DPB( ), 
		.SCEN(BtnD_Pulse), .MCEN( ), .CCEN(BtnD_Signal ));

	
	assign pix = (char_pix ? char_pix:level_pix) | score_pix | obstacle_pix; // for now. add background check when that part is done
	always @ (posedge Reset, posedge ClkPort) begin
		if (Reset) begin
			FAIL_signal <= 0;
		end
		else begin
			if (obstacle_pix != 0 && char_pix != 0) begin
				FAIL_signal <= 1;
			end
			else FAIL_signal <= 0;
		end
	end
	
	// TESTING
	// localparam CAT_WIDTH  =  30;  // bitmap width in pixels
    // localparam CAT_HEIGHT =  32;  // bitmap height in pixels
    // localparam CAT_SCALE  =  1;  // 2^2 = 4x scale
	// localparam CAT_IDLE_FILE = "idle1.mem";

	// sprite2 #(
    //     .SPR_FILE(CAT_IDLE_FILE),
    //     .SPR_WIDTH(CAT_WIDTH),
    //     .SPR_HEIGHT(CAT_HEIGHT),
	// 	.SPR_SCALE(CAT_SCALE)
    // ) catidle1 (
    //     .clk(clk25),
    //     .rst(Reset),
    //     .line(line),
    //     .sx(hc),
    //     .sy(vc),
    //     .sprx(200),
    //     .spry(150),
	// 	.spr_rom_addr(cataddr1),
    //     .en(1)
    // );

	// sprite2 #(
    //     .SPR_FILE(CAT_IDLE_FILE),
    //     .SPR_WIDTH(CAT_WIDTH),
    //     .SPR_HEIGHT(CAT_HEIGHT),
	// 	.SPR_SCALE(CAT_SCALE)
    // ) catidle2 (
    //     .clk(clk25),
    //     .rst(Reset),
    //     .line(line),
    //     .sx(hc),
    //     .sy(vc),
    //     .sprx(300),
    //     .spry(150),
	// 	.spr_rom_addr(cataddr2),
    //     .en(1)
    // );

	// sprite2 #(
    //     .SPR_FILE(CAT_IDLE_FILE),
    //     .SPR_WIDTH(CAT_WIDTH),
    //     .SPR_HEIGHT(CAT_HEIGHT),
	// 	.SPR_SCALE(0)
    // ) catidle3 (
    //     .clk(clk25),
    //     .rst(Reset),
    //     .line(line),
    //     .sx(hc),
    //     .sy(vc),
    //     .sprx(400),
    //     .spry(150),
	// 	.spr_rom_addr(cataddr3),
    //     .en(1)
    // );

	// sprite2 #(
    //     .SPR_FILE(CAT_IDLE_FILE),
    //     .SPR_WIDTH(CAT_WIDTH),
    //     .SPR_HEIGHT(CAT_HEIGHT),
	// 	.SPR_SCALE(2)
    // ) catidle4 (
    //     .clk(clk25),
    //     .rst(Reset),
    //     .line(line),
    //     .sx(hc),
    //     .sy(vc),
    //     .sprx(450),
    //     .spry(150),
	// 	.spr_rom_addr(cataddr4),
    //     .en(1)
    // );

	// wire [$clog2(CATROMDEPTH)-1:0] cataddr1, cataddr2, cataddr3, cataddr4;

	// localparam CATROMDEPTH = CAT_WIDTH * CAT_HEIGHT;
    // wire [$clog2(CATROMDEPTH)-1:0] spr_rom_addr;  // pixel position
    // wire [CIDXW-1:0] spr_rom_data;  // pixel color
	// assign spr_rom_addr = cataddr1 | cataddr2 | cataddr3 | cataddr4;
    // rom #(
    //     .WIDTH(3), // SPR_DATAW),
    //     .DEPTH(CATROMDEPTH),
    //     .INIT_F(CAT_IDLE_FILE)
	// ) test (
    //     .clk(clk25),
    //     .addr(spr_rom_addr),
    //     .data(spr_rom_data)
    // );

endmodule
 /*
 // always_ff @(posedge clk_pix) begin
    //     if (frame) begin
    //         if (sprx <= -SPR_DRAWW) sprx <= H_RES;  // move back to right of screen
    //         else sprx <= sprx - SPR_SPX;  // otherwise keep moving left
    //     end
    //     if (Reset) begin  // start off screen and level with grass
    //         sprx <= H_RES;
    //         spry <= 240;
    //     end
    // end
	
	// constant parameters (CAN JUST SET IN SPRITE module instead)
		localparam SX_OFFS=2;  // horizontal screen offset (pixels): +1 for CLUT
		localparam H_RES=784;
		localparam CORDW=10;
		localparam CIDXW=3; // maybe not constant if need space

	// sprite parameters
    localparam DUCK_WIDTH  =  64;  // bitmap width in pixels
    localparam DUCK_HEIGHT =  64;  // bitmap height in pixels
    localparam DUCK_FILE   = "duck.mem";  // bitmap file
	localparam DUCK_SCALE  =  3;  // 2^2 = 4x scale
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

	//wire [CIDXW-1:0] spr_pix_indx;  // pixel colour index	
	wire signed [CORDW-1:0] duck_x, duck_y;
		assign duck_x = 250;
		assign duck_y = 150;
	wire [CIDXW-1:0] duck_pix;
	wire duck_drawing;

    sprite #(
        .CORDW(CORDW),
        .H_RES(H_RES),
        .SX_OFFS(SX_OFFS),
        .SPR_FILE(DUCK_FILE),
        .SPR_WIDTH(DUCK_WIDTH),
        .SPR_HEIGHT(DUCK_HEIGHT),
		.SPR_SCALE(DUCK_SCALE),
		.SPR_DATAW(CIDXW)
		) duck (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(duck_x),
        .spry(duck_y),
        .pix(duck_pix),
        .drawing(duck_drawing)
    );
*/ 