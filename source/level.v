module level #(
    parameter CIDXW=3,
    parameter CORDW=10
    )(
    input CLK,
    input RESET,
    input line,
    input clk25,
    input [3:0] state,
    input [9:0] hc,
    input [9:0] vc,

    output [CIDXW:0] output_level_pix, //4 bit pixel output for level
    output [CIDXW:0] obstacle_pix //4 bit pixel output for obstacle
    );

    //Register list
    reg [26:0] DIVCLK;
    reg [15:0] obstacleCooldown; // For tracking when the next obstacle should be generated. Generates when register is full
    reg [2:0] BGMod;
    reg [19:0] BGCounter;
    reg [7:0] speed; // Register to determine the speed at which the screen scrolls (lower is faster)
    reg [7:0] speedIncrement; // Register to determine when speed should be incremented
    
    //Parameters
    localparam 	
	    TITLE = 4'b0000, TITLE1 = 4'b0001, TITLE2 = 4'b0010, TITLE3 = 4'b0011, TITLE4 = 4'b0100, 
        RUN1 = 4'b0101, RUN2 = 4'b0110, JUMP1 = 4'b0111, JUMP2 = 4'b1000, DUCK1 = 4'b1001, DUCK2 = 4'b1010, IDLE = 4'b1011, 
        CHARSEL0 = 4'b1100, CHARSEL1 = 4'b1101, FAIL1 = 4'b1110, FAIL2 = 4'b1111, UNK = 4'bXXXX;
    wire gameRunning, gameStill;
    assign gameRunning = ((state == RUN1) || (state == RUN2) || (state == JUMP1) || (state == JUMP2) || (state == DUCK1) || (state == DUCK2));
    assign gameStill = ((state == IDLE) || (state == FAIL1) || (state == FAIL2));
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
    reg [CIDXW:0] obspix1, obspix2, obspix3, level_pix;
    //obstacle #() ob1(.CLK(CLK), .DIVCLK(DIVCLK), .RESET(RESET), .line(line), .state(state), .hc(hc), .vc(vc), .speed(speed), .location(loc1), .busy(busy1), .done(done1), .pix(obspix1));
    //obstacle #() ob2(.CLK(CLK), .DIVCLK(DIVCLK), .RESET(RESET), .line(line), .state(state), .hc(hc), .vc(vc), .speed(speed), .location(loc2), .busy(busy2), .done(done2), .pix(obspix2));
    //obstacle #() ob3(.CLK(CLK), .DIVCLK(DIVCLK), .RESET(RESET), .line(line), .state(state), .hc(hc), .vc(vc), .speed(speed), .location(loc3), .busy(busy3), .done(done3), .pix(obspix3));
    assign obstacle_pix = (hc >= 170 && hc <= 750) ? (low2_data | high1_data | low3_data) : 0; // to avoid side margins.
    assign output_level_pix = level_pix | cloud1_pix | cloud2_pix | cloud3_pix;
    reg [9:0] x1, x2, x3;
    reg [9:0] y1, y2, y3;
    localparam highY = 160, midY = 200, lowY = 247;
    localparam obsMod = 6;

    //Background Generation
    //hc 143 to 784
    //vc 34 to 516
    always @ (posedge CLK, posedge RESET) begin
        if(RESET) begin
            level_pix <= 4'b0000;
            BGMod <= 3'b000; //Setting this to not 0 causes color inversion
        end
        else if((gameRunning || gameStill) && (hc >= 170 && hc <= 750)) begin
            cloud1_en <= 1; cloud2_en <= 1; cloud3_en <= 1;
            if(vc == 308) begin
                if({hc[2], hc[1], hc[0]} == BGMod) level_pix <= 4'b0111;
                else level_pix <= 4'b0000;
            end
            else if(vc == 309) begin
                if({hc[2], hc[1], hc[0]} == BGMod) level_pix <= 4'b0000;
                else level_pix <= 4'b0111;
            end
            else level_pix <= 4'b0000;

            if(!gameStill) BGCounter <= BGCounter + 1;
            if(BGCounter == 4'hFFFFF) BGMod <= BGMod - 1;
        end
        else begin level_pix <= 4'b0000; cloud1_en <= 0; cloud2_en <= 0; cloud3_en <= 0; end
    end

    //Track when the next obstacle is generated
    always @ (posedge DIVCLK[19], posedge RESET) begin
        if(RESET || (state==IDLE)) begin //Will need to add initialization for game reset instead of global reset
            obstacleCooldown <= 0;
            busy1 <= 0; busy2 <= 0; busy3 <= 0;
        end
        else if(gameRunning) begin
            if (obstacleCooldown >= speed) begin //Next obstacle ready to generate (6 divclk23s per second)
                obstacleCooldown <= 0;
                if(!busy1) begin
                    if(((random_reg % obsMod) + 1) <= 6) busy1 = 1;
                    case((random_reg % obsMod) + 1)
                        1: begin y1 <= highY; high1_en1 <= 1; low2_en1 <= 0; low3_en1 <= 0; end
                        2: begin y1 <= midY; high1_en1 <= 1; low2_en1 <= 0; low3_en1 <= 0; end
                        3: begin y1 <= lowY; high1_en1 <= 0; low2_en1 <= 1; low3_en1 <= 0; end
                        4: begin y1 <= lowY; high1_en1 <= 0; low2_en1 <= 1; low3_en1 <= 0; end
                        5: begin y1 <= lowY; high1_en1 <= 0; low2_en1 <= 0; low3_en1 <= 1; end
                        6: begin y1 <= lowY; high1_en1 <= 0; low2_en1 <= 0; low3_en1 <= 1; end
                        default: obstacleCooldown <= obstacleCooldown;
                    endcase
                end
                else if(!busy2) begin
                    if(((random_reg % obsMod) + 1) <= 6) busy2 = 1;
                    case((random_reg % obsMod) + 1)
                        1: begin y2 <= highY; high1_en2 <= 1; low2_en2 <= 0; low3_en2 <= 0; end
                        2: begin y2 <= midY; high1_en2 <= 1; low2_en2 <= 0; low3_en2 <= 0; end
                        3: begin y2 <= lowY; high1_en2 <= 0; low2_en2 <= 1; low3_en2 <= 0; end
                        4: begin y2 <= lowY; high1_en2 <= 0; low2_en2 <= 1; low3_en2 <= 0; end
                        5: begin y2 <= lowY; high1_en2 <= 0; low2_en2 <= 0; low3_en2 <= 1; end
                        6: begin y2 <= lowY; high1_en2 <= 0; low2_en2 <= 0; low3_en2 <= 1; end
                        default: obstacleCooldown <= obstacleCooldown;
                    endcase
                end
                else if(!busy3) begin
                    if(((random_reg % obsMod) + 1) <= 6) busy3 = 1;
                    case((random_reg % obsMod) + 1)
                        1: begin y3 <= highY; high1_en3 <= 1; low2_en3 <= 0; low3_en3 <= 0; end
                        2: begin y3 <= midY; high1_en3 <= 1; low2_en3 <= 0; low3_en3 <= 0; end
                        3: begin y3 <= lowY; high1_en3 <= 0; low2_en3 <= 1; low3_en3 <= 0; end
                        4: begin y3 <= lowY; high1_en3 <= 0; low2_en3 <= 1; low3_en3 <= 0; end
                        5: begin y3 <= lowY; high1_en3 <= 0; low2_en3 <= 0; low3_en3 <= 1; end
                        6: begin y3 <= lowY; high1_en3 <= 0; low2_en3 <= 0; low3_en3 <= 1; end
                        default: obstacleCooldown <= obstacleCooldown;
                    endcase
                end
            end
            else obstacleCooldown <= obstacleCooldown + 1;

             //Check end conditions
            if(x1 <= 80) begin busy1 <= 0; low2_en1 <= 0; high1_en1 <= 0; low3_en1 <= 0; end
            if(x2 <= 80) begin busy2 <= 0; low2_en2 <= 0; high1_en2 <= 0; low3_en2 <= 0; end
            if(x3 <= 80) begin busy3 <= 0; low2_en3 <= 0; high1_en3 <= 0; low3_en3 <= 0; end
        end

    end

    reg [12:0] random_reg;
    always @ (posedge CLK) begin
        random_reg <= randVal;
    end

    //Display obstacles
    always @ (posedge CLK) begin
        if(busy1 && hc == x1) begin
            if(vc == y1) obspix1 <= 4'b1000;
            else obspix1 <= 4'b0000;
        end
        else obspix1 <= 4'b0000;

        if(busy2 && hc == x2) begin
           if(vc == y2) obspix2 <= 4'b1000;
           else obspix2 <= 4'b0000;
        end
        else obspix2 <= 4'b0000;

        if(busy3 && hc == x3) begin
           if(vc == y3) obspix3 <= 4'b1000;
            else obspix3 <= 4'b0000;
        end
        else obspix3 <= 4'b0000;
    end

    //Move obstacles
    reg [7:0] moveCount;
    always @ (posedge DIVCLK[10]) begin
        if(gameRunning) begin
            if(moveCount >= speed) begin
                if(busy1) x1 <= x1 - 1; //Running
                else x1 <= 780; //Not Running
                
                if(busy2) x2 <= x2 - 1;
                else x2 <= 780;

                if(busy3) x3 <= x3 - 1;
                else x3 <= 780;

                moveCount <= 0;
            end
            else moveCount <= moveCount + 1;
        end
        else if(state == IDLE || state == CHARSEL0 || state == CHARSEL1) begin
            x1 <= 780;
            x2 <= 780;
            x3 <= 780;
        end
    end

    //Update speed
    always @ (posedge DIVCLK[22], posedge RESET) begin
        if(RESET || gameStill) begin
            speed <= 200;
            speedIncrement <= 0;
        end
        else if(speedIncrement >= 180) begin
            speed <= speed - 20;
            speedIncrement <= 0;
        end
        else speedIncrement <= speedIncrement + 1; 
    end


//SPRITES
    reg low2_en1, low2_en2, low2_en3, low3_en1, low3_en2, low3_en3, high1_en1, high1_en2, high1_en3;
    sprite2 #(
        .SPR_WIDTH(LOW2_WIDTH),
        .SPR_HEIGHT(LOW2_HEIGHT),
		.SPR_SCALE(LOW2_SCALE)
    ) low2p1 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x1),
        .spry(y1),
		.spr_rom_addr(low2_addr1),
        .en(low2_en1)
    );

    sprite2 #(
        .SPR_WIDTH(LOW2_WIDTH),
        .SPR_HEIGHT(LOW2_HEIGHT),
		.SPR_SCALE(LOW2_SCALE)
    ) low2p2 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x2),
        .spry(y2),
		.spr_rom_addr(low2_addr2),
        .en(low2_en2)
    );

    sprite2 #(
        .SPR_WIDTH(LOW2_WIDTH),
        .SPR_HEIGHT(LOW2_HEIGHT),
		.SPR_SCALE(LOW2_SCALE)
    ) low2p3 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x3),
        .spry(y3),
		.spr_rom_addr(low2_addr3),
        .en(low2_en3)
    );

    sprite2 #(
        .SPR_WIDTH(LOW3_WIDTH),
        .SPR_HEIGHT(LOW3_HEIGHT),
		.SPR_SCALE(LOW3_SCALE)
    ) low3p1 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x1),
        .spry(y1),
		.spr_rom_addr(low3_addr1),
        .en(low3_en1)
    );

    sprite2 #(
        .SPR_WIDTH(LOW3_WIDTH),
        .SPR_HEIGHT(LOW3_HEIGHT),
		.SPR_SCALE(LOW3_SCALE)
    ) low3p2 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x2),
        .spry(y2),
		.spr_rom_addr(low3_addr2),
        .en(low3_en2)
    );

    sprite2 #(
        .SPR_WIDTH(LOW3_WIDTH),
        .SPR_HEIGHT(LOW3_HEIGHT),
		.SPR_SCALE(LOW3_SCALE)
    ) low3p3 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x3),
        .spry(y3),
		.spr_rom_addr(low3_addr3),
        .en(low3_en3)
    );

    sprite2 #(
        .SPR_WIDTH(HIGH1_WIDTH),
        .SPR_HEIGHT(HIGH1_HEIGHT),
		.SPR_SCALE(HIGH1_SCALE)
    ) high1p1 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x1),
        .spry(y1),
		.spr_rom_addr(high1_addr1),
        .en(high1_en1)
    );

    sprite2 #(
        .SPR_WIDTH(HIGH1_WIDTH),
        .SPR_HEIGHT(HIGH1_HEIGHT),
		.SPR_SCALE(HIGH1_SCALE)
    ) high1p2 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x2),
        .spry(y2),
		.spr_rom_addr(high1_addr2),
        .en(high1_en2)
    );

    sprite2 #(
        .SPR_WIDTH(HIGH1_WIDTH),
        .SPR_HEIGHT(HIGH1_HEIGHT),
		.SPR_SCALE(HIGH1_SCALE)
    ) high1p3 (
        .clk(clk25),
        .rst(RESET),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(x3),
        .spry(y3),
		.spr_rom_addr(high1_addr3),
        .en(high1_en3)
    );

    // CACTUS "LOWOBS2"
    localparam LOW2_WIDTH  =  30;  // bitmap width in pixels
    localparam LOW2_HEIGHT =  32;  // bitmap height in pixels
    localparam LOW2_SCALE  =  1;  // 2^2 = 4x scale
	localparam LOW2_FILE = "lowobs2.mem";
    localparam LOW2ROMDEPTH = LOW2_WIDTH * LOW2_HEIGHT;
    wire [$clog2(LOW2ROMDEPTH)-1:0] low2_addr1, low2_addr2, low2_addr3;
    wire [$clog2(LOW2ROMDEPTH)-1:0] low2_addr;  // pixel position
    wire [CIDXW-1:0] low2_data;  // pixel color
	assign low2_addr = low2_addr1 | low2_addr2 | low2_addr3;
    rom #(
        .WIDTH(3), // SPR_DATAW),
        .DEPTH(LOW2ROMDEPTH),
        .INIT_F(LOW2_FILE)
	) low2 (
        .clk(clk25),
        .addr(low2_addr),
        .data(low2_data)
    );

    // ROCK "LOWOBS3"
    localparam LOW3_WIDTH  =  39;  // bitmap width in pixels
    localparam LOW3_HEIGHT =  32;  // bitmap height in pixels
    localparam LOW3_SCALE  =  1;  // 2^2 = 4x scale
	localparam LOW3_FILE = "lowobs3.mem";
    localparam LOW3ROMDEPTH = LOW3_WIDTH * LOW3_HEIGHT;
    wire [$clog2(LOW3ROMDEPTH)-1:0] low3_addr1, low3_addr2, low3_addr3;
    wire [$clog2(LOW3ROMDEPTH)-1:0] low3_addr;  // pixel position
    wire [CIDXW-1:0] low3_data;  // pixel color
	assign low3_addr = low3_addr1 | low3_addr2 | low3_addr3;
    rom #(
        .WIDTH(3), // SPR_DATAW),
        .DEPTH(LOW3ROMDEPTH),
        .INIT_F(LOW3_FILE)
	) low3 (
        .clk(clk25),
        .addr(low3_addr),
        .data(low3_data)
    );

    // HELICOPTER "HIGHOBS1"
    localparam HIGH1_WIDTH  =  40;  // bitmap width in pixels
    localparam HIGH1_HEIGHT =  32;  // bitmap height in pixels
    localparam HIGH1_SCALE  =  1;  // 2^2 = 4x scale
	localparam HIGH1_FILE = "highobs1.mem";
    localparam HIGH1ROMDEPTH = HIGH1_WIDTH * HIGH1_HEIGHT;
    wire [$clog2(HIGH1ROMDEPTH)-1:0] high1_addr1, high1_addr2, high1_addr3;
    wire [$clog2(HIGH1ROMDEPTH)-1:0] high1_addr;  // pixel position
    wire [CIDXW-1:0] high1_data;  // pixel color
	assign high1_addr = high1_addr1 | high1_addr2 | high1_addr3;
    rom #(
        .WIDTH(3), // SPR_DATAW),
        .DEPTH(HIGH1ROMDEPTH),
        .INIT_F(HIGH1_FILE)
    ) high1 (
        .clk(clk25),
        .addr(high1_addr),
        .data(high1_data)
    );



    // AMBIENT BACKGROUND (CLOUDS)
    reg cloud1_en, cloud2_en, cloud3_en;
	wire [CIDXW-1:0] cloud1_pix, cloud2_pix, cloud3_pix;

    sprite #(
        .SPR_FILE("cloud1.mem"),
        .SPR_WIDTH(42),
        .SPR_HEIGHT(16),
		.SPR_SCALE(1)
    ) cloud1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(230),
        .spry(195),
        .pix(cloud1_pix),
        .en(cloud1_en)
    );

    sprite #(
        .SPR_FILE("cloud2.mem"),
        .SPR_WIDTH(54),
        .SPR_HEIGHT(22),
		.SPR_SCALE(1)
    ) cloud2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(365),
        .spry(150),
        .pix(cloud2_pix),
        .en(cloud2_en)
    );

    sprite #(
        .SPR_FILE("cloud3.mem"),
        .SPR_WIDTH(55),
        .SPR_HEIGHT(23),
		.SPR_SCALE(1)
    ) cloud3 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(590),
        .spry(205),
        .pix(cloud3_pix),
        .en(cloud3_en)
    );

endmodule