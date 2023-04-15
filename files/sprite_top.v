`timescale 1ns / 1ps

module sprite_top(
	input ClkPort,
	input BtnC,
	input BtnU,
	input BtnD,
	
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

	wire line;
	wire drawing;  // drawing at (sx,sy)
	wire [CIDXW-1:0] spr_pix_indx;

	assign spr_pix_indx = my_pix | duck_pix; // my_pix ? my_pix : (smallf_pix ? smallf_pix : 0);	// // nvm also need for color. or else evals to boolean. unless bitwise or? need this if pixels overlap
	assign drawing = my_drawing || duck_drawing;

	wire bright;
	wire[9:0] hc, vc;
	wire[15:0] score;
	wire [6:0] ssdOut;
	wire [3:0] anode;
	wire [11:0] rgb;
	wire clk25;
	display_controller dc(.clk(ClkPort), .hSync(hSync), .vSync(vSync), .bright(bright), .hCount(hc), .vCount(vc), .line(line), .clk25(clk25));
	vga_bitchange #(.CIDXW(CIDXW)) vbc (.clk(ClkPort), .bright(bright), .button(BtnU), .spr_drawing(drawing) ,.spr_indx(spr_pix_indx), .hCount(hc), .vCount(vc), .rgb(rgb), .score(score));
	// counter cnt(.clk(ClkPort), .displayNumber(score), .anode(anode), .ssdOut(ssdOut));

	assign Dp = 1;
	assign {Ca, Cb, Cc, Cd, Ce, Cf, Cg} = ssdOut[6 : 0];
    assign {An7, An6, An5, An4, An3, An2, An1, An0} = {4'b1111, anode};

	
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



	// constant parameters
    localparam SX_OFFS=2;  // horizontal screen offset (pixels): +1 for CLUT
	localparam H_RES=784;
	localparam CORDW=10;
	localparam CIDXW=3; // maybe not constant if need space

	
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





	// sprite parameters
    localparam MY_WIDTH  =  70;  // bitmap width in pixels
    localparam MY_HEIGHT =  32;  // bitmap height in pixels
    localparam MY_FILE   = "title.mem";  // bitmap file
	localparam MY_SCALE  =  3;  // 2^2 = 4x scale
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

	//wire [CIDXW-1:0] spr_pix_indx;  // pixel colour index	
	wire signed [CORDW-1:0] my_x, my_y;
		assign my_x = 160;
		assign my_y = 50;
	wire [CIDXW-1:0] my_pix;
	wire my_drawing;

    sprite #(
        .CORDW(CORDW),
        .H_RES(H_RES),
        .SX_OFFS(SX_OFFS),
        .SPR_FILE(MY_FILE),
        .SPR_WIDTH(MY_WIDTH),
        .SPR_HEIGHT(MY_HEIGHT),
		.SPR_SCALE(MY_SCALE),
		.SPR_DATAW(CIDXW)
		) my (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(my_x),
        .spry(my_y),
        .pix(my_pix),
        .drawing(my_drawing)
    );

	// sprite parameters
	localparam BIGMY_SCALE  =  2;  // 2^2 = 4x scale
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

	//wire [CIDXW-1:0] spr_pix_indx;  // pixel colour index	
	wire signed [CORDW-1:0] bigmy_x, bigmy_y;
		assign bigmy_x = 350;
		assign bigmy_y = 250;
	wire [CIDXW-1:0] bigmy_pix;
	wire bigmy_drawing;

    sprite #(
        .CORDW(CORDW),
        .H_RES(H_RES),
        .SX_OFFS(SX_OFFS),
        .SPR_FILE(MY_FILE),
        .SPR_WIDTH(MY_WIDTH),
        .SPR_HEIGHT(MY_HEIGHT),
		.SPR_SCALE(BIGMY_SCALE),
		.SPR_DATAW(CIDXW)
		) bigmy (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(bigmy_x),
        .spry(bigmy_y),
        .pix(bigmy_pix),
        .drawing(bigmy_drawing)
    );

	

endmodule
