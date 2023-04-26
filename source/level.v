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
    reg [15:0] obstacleCooldown; // For tracking when the next obstacle should be generated. Generates when register is full
    reg [2:0] BGMod;
    reg [19:0] BGCounter;
    reg [7:0] speed; // Register to determine the speed at which the screen scrolls
    
    //Parameters
    localparam 	
	    TITLE = 4'b0000, TITLE1 = 4'b0001, TITLE2 = 4'b0010, TITLE3 = 4'b0011, TITLE4 = 4'b0100, 
        RUN1 = 4'b0101, RUN2 = 4'b0110, JUMP1 = 4'b0111, JUMP2 = 4'b1000, DUCK1 = 4'b1001, DUCK2 = 4'b1010, IDLE = 4'b1011, 
        CHARSEL0 = 4'b1100, CHARSEL1 = 4'b1101, UNK = 4'bXXXX;
    wire gameRunning;
    assign gameRunning = ((state == RUN1) || (state == RUN2) || (state == JUMP1) || (state == JUMP2) || (state == DUCK1) || (state == DUCK2));

    //Always block to handle DIVCLK
    always @ (posedge CLK, posedge RESET) begin
        if(RESET) DIVCLK <= 0;
        else DIVCLK <= DIVCLK + 1;
    end

    //Initialize random LSFR module
    wire [12:0] randVal;
    LFSR #() random(.clock(CLK), .reset(RESET), .random(randVal));

    //Initialize obstacle modules
    reg [1:0] loc1, loc2, loc3;
    reg busy1, busy2, busy3;
    reg [CIDXW:0] obspix1, obspix2, obspix3;
    //obstacle #() ob1(.CLK(CLK), .DIVCLK(DIVCLK), .RESET(RESET), .line(line), .state(state), .hc(hc), .vc(vc), .speed(speed), .location(loc1), .busy(busy1), .done(done1), .pix(obspix1));
    //obstacle #() ob2(.CLK(CLK), .DIVCLK(DIVCLK), .RESET(RESET), .line(line), .state(state), .hc(hc), .vc(vc), .speed(speed), .location(loc2), .busy(busy2), .done(done2), .pix(obspix2));
    //obstacle #() ob3(.CLK(CLK), .DIVCLK(DIVCLK), .RESET(RESET), .line(line), .state(state), .hc(hc), .vc(vc), .speed(speed), .location(loc3), .busy(busy3), .done(done3), .pix(obspix3));
    reg [9:0] x1, x2, x3;

    //Background Generation
    //hc 143 to 784
    //vc 34 to 516
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
    always @ (posedge DIVCLK[23], posedge RESET) begin
        if(RESET) begin //Will need to add initialization for game reset instead of global reset
            obstacleCooldown <= 0;
            busy1 <= 0; busy2 <= 0; busy3 <= 0;
            loc1 <= 0; loc2 <= 0; loc3 <= 0;
        end
        else if(gameRunning) begin
            if (obstacleCooldown >= 18) begin //Next obstacle ready to generate (6 divclk23s per second)
                if(!busy1 || !busy2 || !busy3) obstacleCooldown <= 0;
                if(!busy1) begin
                    busy1 <= 1;
                    loc1 <= (randVal % 3) + 1;
                end
                else if(!busy2) begin
                    busy2 <= 1;
                    loc2 <= (randVal % 3) + 1;
                end
                else if(!busy3) begin
                    busy3 <= 1;
                    loc3 <= (randVal % 3) + 1;
                end
            end
            else obstacleCooldown <= obstacleCooldown + 1;

             //Check end conditions
            if(x1 <= 80) busy1 <= 0;
            if(x2 <= 80) busy2 <= 0;
            if(x3 <= 80) busy3 <= 0;
        end

    end

    //Display obstacles
    always @ (posedge CLK) begin
        obstacle_pix <= (obspix1 | obspix2 | obspix3);
        
        if(busy1 && hc == x1) begin
           if((loc1 == 1 && vc == 160) ||
               (loc1 == 2 && vc == 200) ||
               (loc1 == 3 && vc == 250)) begin   
                obspix1 <= 4'b1000;
            end
            else obspix1 <= 4'b0000;
        end
        else obspix1 <= 4'b0000;

        if(busy2 && hc == x2) begin
           if((loc2 == 1 && vc == 160) ||
               (loc2 == 2 && vc == 200) ||
               (loc2 == 3 && vc == 250)) begin   
                obspix2 <= 4'b1000;
            end
            else obspix2 <= 4'b0000;
        end
        else obspix2 <= 4'b0000;

        if(busy3 && hc == x3) begin
           if((loc3 == 1 && vc == 160) ||
               (loc3 == 2 && vc == 200) ||
               (loc3 == 3 && vc == 250)) begin   
                obspix3 <= 4'b1000;
            end
            else obspix3 <= 4'b0000;
        end
        else obspix3 <= 4'b0000;

    end

    //Move obstacles
    always @ (posedge DIVCLK[19]) begin
        if(busy1) x1 <= x1 - 1; //Running
        else x1 <= 700; //Not Running
        
        if(busy2) x2 <= x2 - 1;
        else x2 <= 700;

        if(busy3) x3 <= x3 - 1;
        else x3 <= 700;
    end

endmodule