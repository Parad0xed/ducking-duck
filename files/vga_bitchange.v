`timescale 1ns / 1ps

module vga_bitchange#(parameter CIDXW=1)(
	input clk,
	input bright,
	input button,
	input [9:0] hCount, vCount,
	input drawing,
	input [CIDXW:0] pix,
	output reg [11:0] rgb,
	output reg [15:0] score
   );
	
	parameter BLACK = 12'b0000_0000_0000;
	parameter WHITE = 12'b1111_1111_1111;
	parameter RED   = 12'b1111_0000_0000;
	parameter GREEN = 12'b0000_1111_0000;
	parameter O  = 12'b111110100101;
	parameter P1 = 12'b111110111011;
	parameter P2 = 12'b111101101001;
	parameter P3 = 12'b101101001000;
	parameter B1 = 12'b100010111110;
	parameter B2 = 12'b010001011010;
	parameter B3 = 12'b010000110111;
	parameter TEXTCLR = 12'b000000000000;
	parameter BGCLR = 12'b1110_1110_1110;

	wire greenMiddleSquare;
	reg reset;
	reg[9:0] greenMiddleSquareY;
	reg[49:0] greenMiddleSquareSpeed; 

	initial begin
		greenMiddleSquareY = 10'd320;
		score = 15'd0;
		reset = 1'b0;
	end
	
	
	always@ (*) // BIT CHANGE
	begin
    	if (~bright)
			rgb = BLACK; // force black if not bright
		else if(drawing && (pix == 3'b001)) // FORCE BG
			rgb = BGCLR;
		else if(drawing && (pix == 3'b010))
			rgb = O;	
		else if(drawing && (pix == 3'b011))
			rgb = P2;
		else if(drawing && (pix == 3'b100))
			rgb = P3;
		else if(drawing && (pix == 3'b101))
			rgb = B1;
		else if(drawing && (pix == 3'b110))
			rgb = B2;
		else if(drawing && (pix == 3'b111))
			rgb = B3;
		else if(drawing && (pix == 4'b1000))
			rgb = TEXTCLR;
		else // DEFAULT BG
			rgb = BGCLR; 
	end
	
	always@ (posedge clk)
		begin
		greenMiddleSquareSpeed = greenMiddleSquareSpeed + 50'd1; 
		if (greenMiddleSquareSpeed >= 50'd500000) //500 thousand
			begin
			greenMiddleSquareY = greenMiddleSquareY + 10'd1;
			greenMiddleSquareSpeed = 50'd0;
			if (greenMiddleSquareY == 10'd779)
				begin
				greenMiddleSquareY = 10'd0;
				end
			end
		end

	always@ (posedge clk)
		if ((reset == 1'b0) && (button == 1'b1) && (hCount >= 10'd144) && (hCount <= 10'd784) && (greenMiddleSquareY >= 10'd400) && (greenMiddleSquareY <= 10'd475))
			begin
			score = score + 16'd1;
			reset = 1'b1;
			end
		else if (greenMiddleSquareY <= 10'd20)
			begin
			reset = 1'b0;
			end


	assign greenMiddleSquare = ((hCount >= 10'd340) && (hCount < 10'd380)) &&
				   ((vCount >= greenMiddleSquareY) && (vCount <= greenMiddleSquareY + 10'd40)) ? 1 : 0;

	/*
	// bg generation
	assign obst1_pix = rectangle of size depending on type, located at xpos1, ypos1
	10 registers for : xpos, ypos, type 
	every few clocks (26+), randomize in {0, obstacle 1, obstacle 2, ...}
	store to empty register (with invalid xpos. or size = 0?)
	in bitchange, decide rgb based on type. 

	// non obstacle bg
	can be hard coded maybe? and looped. 
	*/
	
endmodule
