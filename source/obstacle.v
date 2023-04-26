module obstacle #( //UNUSED
    parameter CIDXW=3,
    parameter CORDW=10
    ) (
        input CLK,
        input [26:0] DIVCLK,
        input RESET,
        input line,
        input [3:0] state,
        input [9:0] hc,
        input [9:0] vc,

        input [7:0] speed,
        input [2:0] location,
        input busy,
        
        output reg done,
        output reg [CIDXW:0] pix
    );
    
    //Local Declarations
    reg [9:0] x;
    reg [9:0] y;
    reg [7:0] count;

    //Block to move the obstacle position value
    always @ (posedge DIVCLK[19]) begin
        if(busy) begin //Running
            count <= count + 1;
            case(location)
                0: y <= 0;
                1: y <= 160;
                2: y <= 200;
                3: y <= 250;
            endcase

            // if(count == 5) begin
            //     count <= 0;
            //     x <= x - 1; 
            // end
            // if(x == 60) begin //End Condition
            //     done <= 1;
            // end
        end
        else begin // Not Running
            count <= 0;
            x <= 780;
        end
    end

    //Block to display the obstacle
    always @ (posedge CLK) begin
        if(busy) begin
            if((hc == x) && (vc == y)) pix <= 4'b1000;
            else pix <= 4'b0000;
        end
    end

endmodule