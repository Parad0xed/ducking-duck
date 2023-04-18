`timescale 1ns / 1ps

module core_tb;

    parameter CLK_PERIOD = 10;  // 40 ns == 25 MHz

    // display sync signals and coordinates
    localparam CORDW = 10;  // screen coordinate width in bits
    localparam CIDXW = 3;
    wire signed [CORDW-1:0] sx, sy;
    wire hSync, vSync;

    reg Clk;
	reg		Reset; // , ClkPort;
    reg BtnR;

	wire line;
	

	wire bright;
	wire[9:0] hc, vc;
	wire clk25;
    wire[3:0] state;
    wire[5:0] deb_state;
    wire drawing;
    wire [CIDXW-1:0] pix;
    wire BtnR_Pulse;
    wire MCEN_singal, CCEN_singal;

    // display_controller dc(.clk(Clk), .hSync(hSync), .vSync(vSync), .bright(bright), .hCount(hc), .vCount(vc), .line(line), .clk25(clk25));
    // core #(.CIDXW(CIDXW)) a (.Clk(Clk), .BtnR(BtnR_Pulse), .Reset(Reset), .clk25(clk25), .line(line), .hc(hc), .vc(vc), .state(state), .pix(pix), .drawing(drawing));
    debouncer #(.N_dc(23)) debounce1
        (.CLK(Clk), .RESET(Reset), .PB(BtnR), .DPB( ), 
		.SCEN(BtnR_Pulse), .MCEN(MCEN_singal ), .CCEN(CCEN_singal ), .state(deb_state));

   

    initial 
		  begin
			Clk = 0; // Initialize clock
		  end
		
    always  begin #5; Clk = ~ Clk; end

    initial begin
        Reset = 1;
        Clk = 0;
        BtnR = 0;
        #120 Reset = 0;

        #120 BtnR = 1; #84000010 BtnR = 0;

        #43000
        #43000
        #43000

        #50000 $finish;
    end
endmodule