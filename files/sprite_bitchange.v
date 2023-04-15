`timescale 1ns / 1ps

module vga_bitchange#(parameter CIDXW=1)(
	input clk,
	input bright,
	input button,
	input [9:0] hCount, vCount,
	input spr_drawing,
	input [CIDXW-1:0] spr_indx,
	output reg [11:0] rgb,
	output reg [15:0] score
   );
	
	parameter BLACK = 12'b0000_0000_0000;
	parameter WHITE = 12'b1111_1111_1111;
	parameter RED   = 12'b1111_0000_0000;
	parameter GREEN = 12'b0000_1111_0000;
	parameter ORANGE = 12'b1110_1011_0011;
	//parameter BLUE = 12'b0000_0000_1111;
	parameter TEST_COLOR = 12'b0101_0111_0000;

	wire whiteZone;
	wire greenMiddleSquare;
	reg reset;
	reg[9:0] greenMiddleSquareY;
	reg[49:0] greenMiddleSquareSpeed; 

	initial begin
		greenMiddleSquareY = 10'd320;
		score = 15'd0;
		reset = 1'b0;
	end
	
	
	always@ (*) // paint a white box on a red background
    	if (~bright)
		rgb = BLACK; // force black if not bright
	 else if(spr_drawing && (spr_indx == 1'b1))
	 	rgb = BLACK;
	 else if(spr_drawing && (spr_indx == 2'b10))
	 	rgb = ORANGE;
	 else if (testArt)
	 	rgb = TEST_COLOR;
	 // else if (greenMiddleSquare == 1)
		// rgb = GREEN;
	 else if (whiteZone == 1)
		rgb = WHITE; // white box
	 else
		rgb = 12'b1110_1110_1110; // background color

	
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

	assign whiteZone = ((hCount >= 10'd144) && (hCount <= 10'd784)) && ((vCount >= 10'd400) && (vCount <= 10'd475)) ? 1 : 0;

	assign greenMiddleSquare = ((hCount >= 10'd340) && (hCount < 10'd380)) &&
				   ((vCount >= greenMiddleSquareY) && (vCount <= greenMiddleSquareY + 10'd40)) ? 1 : 0;

	assign testArt = ((((hCount >= 10'd200) && (hCount <= 10'd220)) && ((vCount >= 10'd400) && (vCount <= 10'd475)))|| 
						(((hCount >= 10'd280) && (hCount <= 10'd300)) && ((vCount >= 10'd400) && (vCount <= 10'd475)))) ? 1:0;
	
endmodule
