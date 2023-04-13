//////////////////////////////////////////////////////////////////////////////////
// Author:			Shideh Shahidi, Bilal Zafar, Gandhi Puvvada
// Create Date:   02/25/08, 10/13/08
// File Name:		ee354_GCD.v 
// Description: 
//
//
// Revision: 		2.1
// Additional Comments:  
// 10/13/2008 SCEN has been added by Gandhi
//  3/1/2010  Signal names are changed in line with the divider_verilog design
//           `define is replaced by localparam construct
//  02/24/2020 Nexys-3 to Nexys-4 conversion done by Yue (Julien) Niu and reviewed by Gandhi
//////////////////////////////////////////////////////////////////////////////////


module ee354_GCD(Clk, SCEN, Reset, Start, Ack, Ain, Bin, A, B, AB_GCD, i_count, q_I, q_Sub, q_Mult, q_Done);


	/*  INPUTS */
	input	Clk, SCEN, Reset, Start, Ack;
	input [7:0] Ain;
	input [7:0] Bin;
	
	// i_count is a count of number of factors of 2	. We do not need an 8-bit counter. 
	// However, in-line with other variables, this has been made an 8-bit item.
	/*  OUTPUTS */
	// store the two inputs Ain and Bin in A and B . These (A, B) are also continuously output to the higher module. along with the AB_GCD
	output reg [7:0] A, B, AB_GCD, i_count;		// the result of the operation: GCD of the two numbers
	// store current state
	output q_I, q_Sub, q_Mult, q_Done;
	reg [3:0] state;	
	assign {q_Done, q_Mult, q_Sub, q_I} = state;
		
	localparam 	
	I = 4'b0001, SUB = 4'b0010, MULT = 4'b0100, DONE = 4'b1000, UNK = 4'bXXXX;
	
	// NSL AND SM
	always @ (posedge Clk, posedge Reset)
	begin 
		if(Reset) 
		  begin : GCD
			state <= I;
			i_count <= 8'bx;  	// ****** TODO ******
			A <= 8'bx;		  	// complete the 3 lines
			B <=8'bx;
			AB_GCD <= 8'bx;			
		  end
		else				// ****** TODO ****** complete several parts
				case(state)	
					I:
					begin
						// state transfers
						if (Start) state <= SUB;
						// data transfers
						i_count <= 0;
						A <= Ain;
						B <= Bin;
						AB_GCD <= 0;
					end		
					SUB: 
		               if (SCEN) //  This causes single-stepping the SUB state
						begin		
							// state transfers
							if (A == B) state <= (i_count == 0) ? DONE : MULT;
							// data transfers
							if (A == B) AB_GCD <= A;		
							if (A < B)
							  begin
								// swap A and B
                                A <= B;
                                B <= A;
							  end
							else						// if (A > B)
							  begin	
                                    if(A[0] && B[0]) A <= (A-B);//Both A and B odd
                                    else if(~A[0] && ~B[0]) //Both A and B even
                                        begin
                                            A <= (A >> 1);
                                            B <= (B >> 1);
                                            i_count <= (i_count+1);
                                        end
                                    else if(~A[0]) A <= (A >> 1); //Just A even
                                    else if(~B[0]) B <= (B >> 1); //Just B even
							  end
						end
					MULT:
					  if (SCEN) // This causes single-stepping the MULT state
						begin
							// state transfers
							if(i_count == 1) state <= DONE;
							// data transfers
                            AB_GCD <= (AB_GCD << 1);
                            i_count <= (i_count-1);
						end
					
					DONE:
						if (Ack)	state <= I;
						
					default:		
						state <= UNK;
				endcase
	end
		
	// OFL
	// no combinational output signals
	
endmodule
