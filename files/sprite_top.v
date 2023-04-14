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
	wire spr_pix_indx;
    

	wire bright;
	wire[9:0] hc, vc;
	wire[15:0] score;
	wire [6:0] ssdOut;
	wire [3:0] anode;
	wire [11:0] rgb;
	wire clk25;
	display_controller dc(.clk(ClkPort), .hSync(hSync), .vSync(vSync), .bright(bright), .hCount(hc), .vCount(vc), .line(line), .clk25(clk25));
	vga_bitchange vbc(.clk(ClkPort), .bright(bright), .button(BtnU), .spr_drawing(drawing) ,.spr_indx(spr_pix_indx), .hCount(hc), .vCount(vc), .rgb(rgb), .score(score));
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



	// sprite parameters
    localparam SX_OFFS    =  2;  // horizontal screen offset (pixels): +1 for CLUT
    localparam SPR_WIDTH  =  8;  // bitmap width in pixels
    localparam SPR_HEIGHT =  8;  // bitmap height in pixels
    // localparam SPR_SCALE  =  2;  // 2^2 = 4x scale
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;  // draw width
    // localparam SPR_SPX    =  2;  // horizontal speed (pixels/frame)
    localparam SPR_FILE   = "letter_f.mem";  // bitmap file
	localparam SPR_DATAW  =  1;
	localparam H_RES=784;
	localparam CORDW=10;
	localparam SPRX = 32;  // horizontal position
    localparam SPRY = 16;  // vertical position
	// localparam CIDXW = 1;

	//wire [CIDXW-1:0] spr_pix_indx;  // pixel colour index	
	wire signed [CORDW-1:0] sprx, spry;
	assign sprx = 150;
	assign spry = 50;

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

    sprite #(
        .CORDW(CORDW),
        .H_RES(H_RES),
        .SX_OFFS(SX_OFFS),
        .SPR_FILE(SPR_FILE),
        .SPR_WIDTH(SPR_WIDTH),
        .SPR_HEIGHT(SPR_HEIGHT)
		) test_sprite (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(sprx),
        .spry(spry),
        .pix(spr_pix_indx),
        .drawing(drawing)
    );

	

endmodule
