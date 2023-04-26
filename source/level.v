module level #(
    parameter CIDXW=3,
    parameter CORDW=10
    )(
    input CLK,
    input RESET,
    input line,
    input [3:0] state,
    input [9:0] hc,
    input [9:0] vc,

    output reg[CIDXW:0] level_pix, //4 bit pixel output for level
    output reg[CIDXW:0] obstacle_pix //4 bit pixel output for obstacle
    );

    //Register list
    reg [26:0] DIVCLK;
    reg [7:0] obstacleCooldown; // For tracking when the next obstacle should be generated. Generates when register is full
    reg generateNextObstacle; // Flag to indicate whether the next obstacle object should be generated
    reg [1:0] nextObstacleLocation; // Register to determine next obstacle position. (0 = no obstacle, 1 = low, 2 = mid, 3 = high)
    reg [2:0] BGMod;
    reg [19:0] BGCounter;
    reg [7:0] speedLevel; // Register to determine the speed at which the screen scrolls
    
    localparam 	
	    TITLE = 4'b0000, TITLE1 = 4'b0001, TITLE2 = 4'b0010, TITLE3 = 4'b0011, TITLE4 = 4'b0100, 
        RUN1 = 4'b0101, RUN2 = 4'b0110, JUMP1 = 4'b0111, JUMP2 = 4'b1000, DUCK1 = 4'b1001, DUCK2 = 4'b1010, IDLE = 4'b1011, 
        CHARSEL0 = 4'b1100, CHARSEL1 = 4'b1101, UNK = 4'bXXXX;

    wire gameRunning;
    assign gameRunning = ((state == RUN1) || (state == RUN2) || (state == JUMP1) || (state == JUMP2) || (state == DUCK1) || (state == DUCK2));

    //hc 143 to 784
    //vc 34 to 516

    //Initialize random LSFR module
    wire [12:0] randVal;
    LFSR #() random(.clock(CLK), .reset(RESET), .random(randVal));

    //Always block to handle DIVCLK
    always @ (posedge CLK, posedge RESET) begin
        if(RESET) DIVCLK <= 0;
        else DIVCLK <= DIVCLK + 1;
    end

    //Background Generation
    always @ (posedge CLK, posedge RESET) begin
        if(RESET) begin
            level_pix <= 4'b0000;
            BGMod <= 3'b000; //Setting this to not 0 causes color inversion
        end
        else if(gameRunning && (hc >= 170 && hc <= 750)) begin
            if(vc == 308) begin
                if({hc[2], hc[1], hc[0]} == BGMod) level_pix <= 4'b0111;
                else level_pix <= 4'b0000;
            end
            else if(vc == 309) begin
                if({hc[2], hc[1], hc[0]} == BGMod) level_pix <= 4'b0000;
                else level_pix <= 4'b0111;
            end
            else level_pix <= 4'b0000;

            BGCounter <= BGCounter + 1;
            if(BGCounter == 4'hFFFFF) BGMod <= BGMod - 1;

        end
        else level_pix <= 4'b0000;
    end
    
    //Always block to track when the next obstacle is generated
    always @ (posedge DIVCLK[24], posedge RESET) begin
        if(RESET) begin //Will need to add initialization for game reset instead of global reset
            generateNextObstacle <= 0;
            obstacleCooldown <= 0;
            nextObstacleLocation <= 0; 
        end
        else if(gameRunning) begin
            if (obstacleCooldown == 3) begin //Next obstacle ready to generate (3 divclk 24s per second)
                generateNextObstacle <= 1;
                obstacleCooldown <= 0;
                nextObstacleLocation <= (randVal % 3) + 1;
            end
            else obstacleCooldown <= obstacleCooldown + 1;
        end
    end

    //Always block to generate the next obstacle
    always @ (posedge CLK) begin
        if(generateNextObstacle && hc == 500) begin
            if((nextObstacleLocation == 1 && vc == 160) ||
               (nextObstacleLocation == 2 && vc == 200) ||
               (nextObstacleLocation == 3 && vc == 250)) begin   
                obstacle_pix <= 4'b1000;
            end
            else obstacle_pix <= 4'b0000;
        end 
        else obstacle_pix <= 4'b0000;
    end

endmodule