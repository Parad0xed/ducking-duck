
module rom_async #(parameter WIDTH=8,
    parameter DEPTH=256,
    parameter INIT_F="",
    localparam ADDRW=$clog2(DEPTH)
    )	(
		input wire clk,
		input wire [ADDRW-1:0] addr,
		output reg [ADDRW-1:0] addr_return, // to track delayed address
		output reg [WIDTH-1:0] data
	);

	(* rom_style = "block" *)

	//signal declaration
	// reg [2:0] address_reg;

	// always @(posedge clk)
	// 	address_reg <= address;

    reg [WIDTH-1:0] memory [DEPTH-1:0]; 

    initial begin
        if (INIT_F != 0) begin
            $display("Creating rom_async from init file '%s'.", INIT_F);
            $readmemh(INIT_F, memory);
        end
    end

    always @(posedge clk)
	begin
        data <= memory[addr];
		addr_return <= addr;
    end
    
    integer i;
    /*read and display the values from the text file on screen*/

    initial begin
        $display("rdata:");
        for (i=0; i < 55; i=i+1)
            $display("%d:%h",i,memory[i]);
    end
endmodule

	/*
    integer i;
    /*read and display the values from the text file on screen

    initial begin
        $display("rdata:");
        for (i=0; i < 56; i=i+1)
            if(i%8 == 7)
                $display("%h",memory[i]);
            else
                $write("%h",memory[i]);
    end
	*/


// module rom_async #(
//     parameter WIDTH=8,
//     parameter DEPTH=256,
//     parameter INIT_F="",
//     localparam ADDRW=$clog2(DEPTH)
//     ) (
//     input wire [ADDRW-1:0] addr,
//     output     data
//     );

//     logic [WIDTH-1:0] memory [DEPTH];

//     initial begin
//         if (INIT_F != 0) begin
//             $display("Creating rom_async from init file '%s'.", INIT_F);
//             $readmemh(INIT_F, memory);
//         end
//     end

//     assign data = memory[addr];
// endmodule

/* module rams_init_file (clk, addr, dout);
	input clk;
	// input we;
	input [5:0] addr;
	// input [31:0] din;
	input 
	output [31:0] dout;

	reg [31:0] ram [0:63];
	reg [31:0] dout;

	initial begin
		$readmemb("rams_init_file.data",ram);
	end

	always @(posedge clk)
	begin
		// if (we)
		// 	ram[addr] <= din;
		dout <= ram[addr];
	end 
endmodule */
