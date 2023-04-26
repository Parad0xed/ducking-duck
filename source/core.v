
module core #(parameter CIDXW=3, parameter CORDW=10) (Clk, Reset, FAIL_signal, BtnR_Pulse, BtnL_Pulse, BtnU_Pulse, BtnD_Pulse, BtnD, 
        clk25, line, hc, vc, state, pix, score_pix, drawing);


	/*  INPUTS */
	input	Clk, BtnR_Pulse, BtnL_Pulse, BtnU_Pulse, BtnD_Pulse, BtnD, Reset; //, Start, Ack;
    input clk25, line;
    input [CORDW-1:0] hc, vc;
    input FAIL_signal;
    
    output reg [CIDXW:0] pix;
    output reg [CIDXW:0] score_pix;
    output reg drawing;
	// store current state
	output reg [3:0] state;	

    reg [29:0] i_count;	// 2^30 = 1 073 741 824
    reg [21:0] x_count; // to deal with modulus operation. 2^22 = 4194304
    reg [1:0] jump_count; // to time character jump
    reg [10:0] jump_time; // for varchar_y calculations
    reg [19:0] timesquare;
    reg [9:0] score; // for now, +1 per second, displayed in binary, caps at 1023
                     // consider displaying in decimal?
                     // in decimal : 
    reg [3:0] score_th, score_hun, score_ten, score_one; // increment and cap at 9999
    reg [3:0] hiscore_th, hiscore_hun, hiscore_ten, hiscore_one; // HIGH SCORE TRACKER
    reg [29:0] s_count; // for counting score
    reg score_en, score_count_en; // score_en for display, count_en to count score
    reg char0or1;
		
	localparam 	
	TITLE = 4'b0000, TITLE1 = 4'b0001, TITLE2 = 4'b0010, TITLE3 = 4'b0011, TITLE4 = 4'b0100, 
        RUN1 = 4'b0101, RUN2 = 4'b0110, JUMP1 = 4'b0111, JUMP2 = 4'b1000, DUCK1 = 4'b1001, DUCK2 = 4'b1010, IDLE = 4'b1011, 
        CHARSEL0 = 4'b1100, CHARSEL1 = 4'b1101, FAIL1 = 4'b1110, FAIL2 = 4'b1111, UNK = 4'bXXXX;
	
    // sprite parameters
    localparam DUCK_WIDTH  =  64;  // bitmap width in pixels
    localparam DUCK_HEIGHT =  64;  // bitmap height in pixels
    localparam DUCK_FILE   = "duck.mem";  // bitmap file
	localparam DUCK_SCALE  =  3;  // 2^2 = 4x scale
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

	//wire [CIDXW-1:0] spr_pix_indx;  // pixel colour index	
	reg signed [CORDW-1:0] duck_x, duck_y;
		// assign duck_x = 250;
		// assign duck_y = 150;
    reg duck_en;
	wire [CIDXW-1:0] duck_pix;
	wire duck_drawing;

    sprite #(
        .SPR_FILE(DUCK_FILE),
        .SPR_WIDTH(DUCK_WIDTH),
        .SPR_HEIGHT(DUCK_HEIGHT),
		.SPR_SCALE(DUCK_SCALE)
		) duck (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(duck_x),
        .spry(duck_y),
        .pix(duck_pix),
        .drawing(duck_drawing),
        .en(duck_en)
    );

	// sprite parameters
    localparam TITLE_WIDTH  =  70;  // bitmap width in pixels
    localparam TITLE_HEIGHT =  32;  // bitmap height in pixels
    localparam TITLE_FILE   = "title.mem";  // bitmap file
	localparam TITLE_SCALE  =  3;  // 2^2 = 4x scale
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

	reg signed [CORDW-1:0] title_x, title_y;
		// assign title_x = 160;
		// assign title_y = 50;
    reg title_en;
	wire [CIDXW-1:0] title_pix;
	wire title_drawing;

    sprite #(
        .SPR_FILE(TITLE_FILE),
        .SPR_WIDTH(TITLE_WIDTH),
        .SPR_HEIGHT(TITLE_HEIGHT),
		.SPR_SCALE(TITLE_SCALE)
		) title (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(title_x),
        .spry(title_y),
        .pix(title_pix),
        .drawing(title_drawing),
        .en(title_en)
    );

    reg [1:0] percent_shown;

	// NSL AND SM
	always @ (posedge Clk, posedge Reset)
	begin 
		if(Reset) 
		  begin : PROJ
			state <= TITLE;
			i_count <= 8'bx;  	// TITLE INCREMENTER
            score_count_en <= 0;
            score_en <= 0;
                    		
		  end
        else if (score_one == 0 && score_ten == 1 && score_hun == 0 && FAIL_signal != 1) begin // SCORE == 10
            FAIL_signal <= 1;
            score_count_en <= 0;
            state <= FAIL1;
            if ({score_th, score_hun, score_ten, score_one} > {hiscore_th, hiscore_hun, hiscore_ten, hiscore_one})begin 
                hiscore_th <= score_th;
                hiscore_hun <= score_hun;
                hiscore_ten <= score_ten;
                hiscore_one <= score_one;
            end
        end
		else				
            case(state)	// TITLE SCREEN SEQUENCE
                FAIL1: begin
                    failtext_en <= 1;
                    if(BtnD_Pulse) state <= FAIL2; 
                    if(BtnR_Pulse) begin
                        state <= IDLE;
                        i_count <= 0;
                        jump_count <= 0;
                        jump_time <= 25;
                        timesquare <= 902500;
                        x_count <= 0;
                        idle_en <= 0; idle1_en <= 0; run1_en <= 0; run2_en <= 0; jump1_en <= 0; jump2_en <= 0; duck1_en <= 0; duck2_en <= 0;
                        varchar_y <= CHARY;
                        varchar_x <= CHARX; varchar_x1 <= CHARX;
                        // char0or1 <= 0;
                        FAIL_signal <= 0;
                        score_count_en <= 0;
                        score_en <= 0;
                        failtext_en <= 0;
                    end
                end
                FAIL2: begin
                    failtext_en <= 1;
                    if(BtnU_Pulse) state <= FAIL1; 
                    if(BtnR_Pulse) begin
                        state <= CHARSEL0;
                        i_count <= 0;
                        jump_count <= 0;
                        jump_time <= 25;
                        timesquare <= 902500;
                        x_count <= 0;
                        idle_en <= 0; idle1_en <= 0; run1_en <= 0; run2_en <= 0; jump1_en <= 0; jump2_en <= 0; duck1_en <= 0; duck2_en <= 0;
                        varchar_y <= CHARY;
                        varchar_x <= CHARX; varchar_x1 <= CHARX;
                        // char0or1 <= 0;
                        FAIL_signal <= 0;
                        score_count_en <= 0;
                        score_en <= 0;
                        failtext_en <= 0;
                    end
                end
                TITLE: begin
                    if (BtnR_Pulse) state <= TITLE1;
                    duck_x <= 250;
                    duck_y <= 150;
                    title_x <= 160;
                    title_y <= 60;
                    i_count <= 0;
                    jump_count <= 0;
                    jump_time <= 25;
                    timesquare <= 902500;
                    x_count <= 0;
                    percent_shown <= 3;
                    duck_en <= 1;
                    title_en <= 1;
                    idle_en <= 0; idle1_en <= 0; run1_en <= 0; run2_en <= 0; jump1_en <= 0; jump2_en <= 0; duck1_en <= 0; duck2_en <= 0;
                    varchar_y <= CHARY;
                    varchar_x <= CHARX; varchar_x1 <= CHARX;
                    char0or1 <= 0;
                    FAIL_signal <= 0;
                    hiscore_one <= 0; hiscore_ten <= 0; hiscore_hun <= 0; hiscore_th <= 0;
                    // score vars: // need to do this in same block. figure this out on game lose + play again
                    // score_count_en <= 0;
                    // score_en <= 0;
                    // // s_count <= 0; 
                    // score_one <= 0; score_ten <= 0; score_hun <= 0; score_th <= 0;
                end		
                TITLE1: begin	// TITLE ONLY NO DUCK	
                    duck_en <= 0;
                    i_count <= i_count+1;
                    if(i_count == 50'd200000000) begin
                        i_count <= 0;
                        state <= TITLE2;
                    end
                end
                TITLE2: begin // BLANK
                    title_en <= 0;
                    i_count <= i_count+1;
                    if(i_count == 50'd100000000) begin
                        i_count <= 0;
                        state <= TITLE3;
                    end
                end
                TITLE3: begin // NAME
                    name_en <= 1;
                    i_count <= i_count+1;
                    if(i_count == 50'd200000000) begin
                        i_count <= 0;
                        state <= TITLE4;
                    end
                end
                TITLE4: begin // BLANK
                    name_en <= 0;
                    i_count <= i_count+1;
                    if(i_count == 50'd100000000) begin
                        i_count <= 0;
                        state <= CHARSEL0;
                    end
                end

                // CHAR SELECT STATES 
                //      display should have: two chars, box around selected one, text: "BtnU to Select"
                CHARSEL0: begin
                    seltext_en <= 1;
                    idle_en <= 1; idle1_en <= 1; varchar_x <= 350; varchar_x1 <= 470;
                    // draw box around char0
                    
                    if(BtnR_Pulse) 
                        state <= CHARSEL1;                        
                    if(BtnU_Pulse) begin
                        char0or1 <= 0;
                        idle1_en <= 0;
                        varchar_x <= CHARX;
                        varchar_x1 <= CHARX;
                        seltext_en <= 0;
                        state <= IDLE;
                    end
                end
                CHARSEL1: begin 
                    // seltext_en <= 1;
                    // draw box around char1
                    
                    if(BtnL_Pulse) 
                        state <= CHARSEL0;
                    if(BtnU_Pulse) begin
                        char0or1 <= 1;
                        idle_en <= 0;
                        varchar_x <= CHARX;
                        varchar_x1 <= CHARX;
                        seltext_en <= 0;
                        state <= IDLE;
                    end
                end
                // BELOW SECTION FOR CHAR STATES
                IDLE: begin
                    score_en <= 1;
                    idle_en <= 1;
                    idle1_en <= 1;
                    varchar_x <= CHARX;
                    if(BtnU_Pulse) begin
                        idle_en <= 0;
                        idle1_en <= 0;
                        state <= RUN1;
                    end
                end
                RUN1: begin
                    score_count_en <= 1;
                    run1_en <= 1;
                    i_count <= i_count+1;
                    if(BtnU_Pulse)begin
                        i_count <= 0; run1_en <= 0;
                        state <= JUMP1;
                    end
                    else if (BtnD)begin
                        run1_en <= 0; 
                        state <= DUCK1;
                    end
                    else if(i_count == 50'd25000000) begin
                        i_count <= 0; run1_en <= 0;
                        state <= RUN2;
                    end 
                end
                RUN2: begin
                    run2_en <= 1;
                    i_count <= i_count+1;
                    if(BtnU_Pulse) begin
                        i_count <= 0; run2_en <= 0;
                        state <= JUMP1;
                    end
                    else if (BtnD) begin
                        run2_en <= 0; 
                        state <= DUCK2;
                    end
                    else if(i_count == 50'd25000000) begin
                        i_count <= 0; run2_en <= 0;
                        state <= RUN1;
                    end
                end
                JUMP1: begin
                    jump1_en <= 1;
                    i_count <= i_count+1;
                    if(BtnD) begin
                        i_count <= 0; jump1_en <= 0;
                        state <= DUCK1;
                        varchar_y <= CHARY;
                        jump_count <= 0;
                        jump_time <= 25;
                        timesquare <= 902500;
                    end
                    else if(i_count == 50'd25000000) begin
                        i_count <= 0; jump1_en <= 0;
                        jump_count <= jump_count+1;
                        state <= JUMP2;
                    end

                    x_count <= x_count+1;
                    if(x_count == 2500000) begin 
                        x_count <= 0;
                        // Split division to meet timing constraints 
                        jump_time <= jump_time + 25;
                        timesquare <= (((jump_time+25)-500)**2) << 2;
                        varchar_y <= CHARY-100+(timesquare)/10000;
                        // varchar_y <= CHARY-100+(4*(jump_time-500)**2)/10000;

                    end
                end
                JUMP2: begin 
                    jump2_en <= 1;
                    i_count <= i_count+1;
                    
                    
                    x_count <= x_count+1;
                    if(x_count == 2500000) begin 
                        x_count <= 0;
                        // Split division to meet timing constraints 
                        jump_time <= jump_time + 25;
                        timesquare <= (((jump_time+25)-500)**2) << 2;
                        varchar_y <= CHARY-100+(timesquare)/10000;
                        // varchar_y <= CHARY-100+(4*(jump_time-500)**2)/10000;
                    end
                    if(BtnD) begin
                        i_count <= 0; jump2_en <= 0;
                        state <= DUCK1;
                        varchar_y <= CHARY;
                        jump_count <= 0;
                        jump_time <= 25;
                        timesquare <= 902500;
                    end
                    else if(i_count == 50'd25000000) begin
                        i_count <= 0; jump2_en <= 0;
                        if(jump_count == 3) begin 
                            jump_count <= 0;
                            jump_time <= 25;
                            timesquare <= 902500;
                            state <= RUN1;
                            varchar_y <= CHARY;
                        end
                        else begin 
                            jump_count <= jump_count+1;
                            state <= JUMP1;
                        end
                    end
                end
                DUCK1: begin
                    duck1_en <= 1;
                    i_count <= i_count+1;
                    if(!BtnD) begin
                        duck1_en <= 0;
                        state <= RUN1;
                    end
                    else if(i_count == 50'd25000000) begin 
                        i_count <= 0; duck1_en <= 0;
                        state <= DUCK2;
                    end
                end
                DUCK2: begin
                    duck2_en <= 1;
                    i_count <= i_count+1;
                    if(!BtnD) begin
                        duck2_en <= 0;
                        state <= RUN2;
                    end
                    else if(i_count == 50'd25000000) begin 
                        i_count <= 0; duck2_en <= 0;
                        state <= DUCK1;
                    end
                end
                default:		
                    state <= UNK;
            endcase
	end
	

    // scorekeeper / counter
    //      - check score to transition map states if there is time
    always @ (posedge Clk, posedge Reset) begin
        if(Reset) begin 
            s_count <= 0; score <= 0; // remove if not using binary display
            score_one <= 0; score_ten <= 0; score_hun <= 0; score_th <= 0;
        end
        else begin

            // temporary condition for artificial fail signal
            if((state == FAIL1 && BtnR_Pulse) || (state == FAIL2 && BtnR_Pulse)) begin
                score_one <= 0; score_ten <= 0; score_hun <= 0; score_th <= 0; s_count <= 0;
            end

            if(score_count_en) begin // TO INCREMENT SCORE (WITH 4 DECIMAL DIGITS FOR DISPLAY)
                s_count <= s_count+1;
                if(s_count == 50000000) begin // 1 SECOND
                    s_count <= 0; 
                    if(score_one != 9) begin
                        score_one <= score_one+1;
                    end
                    else begin // ONES = 9
                        score_one <= 0;
                        if(score_ten != 9) begin
                            score_ten <= score_ten+1;
                        end
                        else begin // TENS = 9
                            score_ten <= 0;
                            if(score_hun != 9) begin 
                                score_hun <= score_hun+1;
                            end
                            else begin // HUNDREDS = 9
                                score_hun <= 0;
                                if(score_th != 9)
                                    score_th <= score_th+1;
                                else begin // MAX SCORE
                                    // ... SCORE CAPPED BEHAVIOUR
                                    // FOR NOW, just reset to 0 and continue. later put a you win congrats state maybe
                                    score_one <= 0; score_ten <= 0; score_hun <= 0; score_th <= 0;
                                end
                            end
                        end
                    end
                end 
               
            end
        end
    end

    // SCORE DISPLAY LOGIC
    reg score1_pix, score10_pix, score100_pix, score1000_pix;
    // reg score1_drawing, score10_drawing, score100_drawing, score1000_drawing;
    localparam SCOREY = 120; // same for all 4 digits
    localparam SCORE_DIGIT_WIDTH = 12; 
    localparam SCORE_SPACE_WIDTH = 4;
    localparam SCORE_LINE_WIDTH = 2;
    localparam SCORE1X = 630;   // upper left corner, each digit is 
    localparam SCORE10X = SCORE1X-(SCORE_DIGIT_WIDTH+SCORE_SPACE_WIDTH);
    localparam SCORE100X = SCORE1X-2*(SCORE_DIGIT_WIDTH+SCORE_SPACE_WIDTH);
    localparam SCORE1000X = SCORE1X-3*(SCORE_DIGIT_WIDTH+SCORE_SPACE_WIDTH);
    always @ (posedge Clk) begin
        if(score_en) begin
            case (score_one)
                0:  if(
                        (((hc >= SCORE1X) && (hc < (SCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X) && (hc < (SCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score1_pix <= 1; else score1_pix <= 0;
                1: if(
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) score1_pix <= 1; else score1_pix <= 0;
                2: if(
                        ((hc >= SCORE1X) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X) && (hc < SCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score1_pix <= 1; else score1_pix <= 0;
                3: if(
                        ((hc >= SCORE1X) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE1X) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score1_pix <= 1; else score1_pix <= 0;
                4: if(
                        ((hc >= SCORE1X) && (hc < SCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                   
                    ) score1_pix <= 1; else score1_pix <= 0;
                5: if(
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X) && (hc < SCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE1X) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score1_pix <= 1; else score1_pix <= 0;
                6: if(
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X) && (hc < SCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||
                        ((hc >= SCORE1X) && (hc < SCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                                    
                    ) score1_pix <= 1; else score1_pix <= 0;
                7: if(
                        ((hc >= SCORE1X) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < SCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) score1_pix <= 1; else score1_pix <= 0;
                8: if(
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= SCORE1X) && (hc < (SCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X) && (hc < (SCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score1_pix <= 1; else score1_pix <= 0;
                9: if(
                        ((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= SCORE1X) && (hc < (SCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+2*SCORE_LINE_WIDTH) && (hc < SCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score1_pix <= 1; else score1_pix <= 0;
            endcase
            case (score_ten)
                0:  if(
                        (((hc >= SCORE10X) && (hc < (SCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < (SCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < (SCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X) && (hc < (SCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score10_pix <= 1; else score10_pix <= 0;
                1: if(
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) score10_pix <= 1; else score10_pix <= 0;
                2: if(
                        ((hc >= SCORE10X) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X) && (hc < SCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score10_pix <= 1; else score10_pix <= 0;
                3: if(
                        ((hc >= SCORE10X) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE10X) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score10_pix <= 1; else score10_pix <= 0;
                4: if(
                        ((hc >= SCORE10X) && (hc < SCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                   
                    ) score10_pix <= 1; else score10_pix <= 0;
                5: if(
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X) && (hc < SCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE10X) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score10_pix <= 1; else score10_pix <= 0;
                6: if(
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X) && (hc < SCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||
                        ((hc >= SCORE10X) && (hc < SCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                                    
                    ) score10_pix <= 1; else score10_pix <= 0;
                7: if(
                        ((hc >= SCORE10X) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < SCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) score10_pix <= 1; else score10_pix <= 0;
                8: if(
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= SCORE10X) && (hc < (SCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < (SCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < (SCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X) && (hc < (SCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score10_pix <= 1; else score10_pix <= 0;
                9: if(
                        ((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= SCORE10X) && (hc < (SCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+2*SCORE_LINE_WIDTH) && (hc < SCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < (SCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE10X+5*SCORE_LINE_WIDTH) && (hc < (SCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score10_pix <= 1; else score10_pix <= 0;
            endcase
            case (score_hun)
                0:  if(
                        (((hc >= SCORE100X) && (hc < (SCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < (SCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < (SCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X) && (hc < (SCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score100_pix <= 1; else score100_pix <= 0;
                1: if(
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) score100_pix <= 1; else score100_pix <= 0;
                2: if(
                        ((hc >= SCORE100X) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X) && (hc < SCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score100_pix <= 1; else score100_pix <= 0;
                3: if(
                        ((hc >= SCORE100X) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE100X) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score100_pix <= 1; else score100_pix <= 0;
                4: if(
                        ((hc >= SCORE100X) && (hc < SCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                   
                    ) score100_pix <= 1; else score100_pix <= 0;
                5: if(
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X) && (hc < SCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE100X) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score100_pix <= 1; else score100_pix <= 0;
                6: if(
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X) && (hc < SCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||
                        ((hc >= SCORE100X) && (hc < SCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                                    
                    ) score100_pix <= 1; else score100_pix <= 0;
                7: if(
                        ((hc >= SCORE100X) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < SCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) score100_pix <= 1; else score100_pix <= 0;
                8: if(
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= SCORE100X) && (hc < (SCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < (SCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < (SCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X) && (hc < (SCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score100_pix <= 1; else score100_pix <= 0;
                9: if(
                        ((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= SCORE100X) && (hc < (SCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+2*SCORE_LINE_WIDTH) && (hc < SCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < (SCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE100X+5*SCORE_LINE_WIDTH) && (hc < (SCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score100_pix <= 1; else score100_pix <= 0;
            endcase
            case (score_th)
                0:  if(
                        (((hc >= SCORE1000X) && (hc < (SCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X) && (hc < (SCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                1: if(
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                2: if(
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                3: if(
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                4: if(
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                   
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                5: if(
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                6: if(
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                                    
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                7: if(
                        ((hc >= SCORE1000X) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < SCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                8: if(
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= SCORE1000X) && (hc < (SCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X) && (hc < (SCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score1000_pix <= 1; else score1000_pix <= 0;
                9: if(
                        ((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= SCORE1000X) && (hc < (SCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+2*SCORE_LINE_WIDTH) && (hc < SCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= SCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (SCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) score1000_pix <= 1; else score1000_pix <= 0;
            endcase
        end
    end

    // HIGH SCORE LOGIC
    reg hiscore1_pix, hiscore10_pix, hiscore100_pix, hiscore1000_pix;
    // reg hiscore1_drawing, hiscore10_drawing, hiscore100_drawing, hiscore1000_drawing;
    localparam HISCORE1X = 555;   // upper left corner, each digit is 
    localparam HISCORE10X = HISCORE1X-(SCORE_DIGIT_WIDTH+SCORE_SPACE_WIDTH);
    localparam HISCORE100X = HISCORE1X-2*(SCORE_DIGIT_WIDTH+SCORE_SPACE_WIDTH);
    localparam HISCORE1000X = HISCORE1X-3*(SCORE_DIGIT_WIDTH+SCORE_SPACE_WIDTH);
    always @ (posedge Clk) begin
        if(score_en) begin
            case (hiscore_one)
                0:  if(
                        (((hc >= HISCORE1X) && (hc < (HISCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X) && (hc < (HISCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                1: if(
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                2: if(
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                3: if(
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                4: if(
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                   
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                5: if(
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                6: if(
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                                    
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                7: if(
                        ((hc >= HISCORE1X) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                8: if(
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= HISCORE1X) && (hc < (HISCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X) && (hc < (HISCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
                9: if(
                        ((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= HISCORE1X) && (hc < (HISCORE1X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore1_pix <= 1; else hiscore1_pix <= 0;
            endcase
            case (hiscore_ten)
                0:  if(
                        (((hc >= HISCORE10X) && (hc < (HISCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X) && (hc < (HISCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                1: if(
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                2: if(
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                3: if(
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                4: if(
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                   
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                5: if(
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                6: if(
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                                    
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                7: if(
                        ((hc >= HISCORE10X) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < HISCORE10X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                8: if(
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= HISCORE10X) && (hc < (HISCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X) && (hc < (HISCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
                9: if(
                        ((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= HISCORE10X) && (hc < (HISCORE10X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+2*SCORE_LINE_WIDTH) && (hc < HISCORE10X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE10X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE10X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore10_pix <= 1; else hiscore10_pix <= 0;
            endcase
            case (hiscore_hun)
                0:  if(
                        (((hc >= HISCORE100X) && (hc < (HISCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X) && (hc < (HISCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                1: if(
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                2: if(
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                3: if(
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                4: if(
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                   
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                5: if(
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                6: if(
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                                    
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                7: if(
                        ((hc >= HISCORE100X) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < HISCORE100X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                8: if(
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= HISCORE100X) && (hc < (HISCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X) && (hc < (HISCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
                9: if(
                        ((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= HISCORE100X) && (hc < (HISCORE100X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+2*SCORE_LINE_WIDTH) && (hc < HISCORE100X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE100X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE100X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore100_pix <= 1; else hiscore100_pix <= 0;
            endcase
            case (hiscore_th)
                0:  if(
                        (((hc >= HISCORE1000X) && (hc < (HISCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X) && (hc < (HISCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                1: if(
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                2: if(
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                3: if(
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                4: if(
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                   
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                5: if(
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                     
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                6: if(
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||                     
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH)) ||
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                                    
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                7: if(
                        ((hc >= HISCORE1000X) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH)) || 
                        ((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+6*SCORE_LINE_WIDTH) && (vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))                         
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                8: if(
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= HISCORE1000X) && (hc < (HISCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY+8*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X) && (hc < (HISCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
                9: if(
                        ((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH) && (vc >= SCOREY+4*SCORE_LINE_WIDTH) && (vc < SCOREY+5*SCORE_LINE_WIDTH)) || 
                        (((hc >= HISCORE1000X) && (hc < (HISCORE1000X+SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+5*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+2*SCORE_LINE_WIDTH) && (hc < HISCORE1000X+4*SCORE_LINE_WIDTH)) && ((vc >= SCOREY) && (vc < SCOREY+SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY) && (vc < SCOREY+4*SCORE_LINE_WIDTH))) ||
                        (((hc >= HISCORE1000X+5*SCORE_LINE_WIDTH) && (hc < (HISCORE1000X+6*SCORE_LINE_WIDTH))) && ((vc >= SCOREY+5*SCORE_LINE_WIDTH) && (vc < SCOREY+9*SCORE_LINE_WIDTH))) 
                    ) hiscore1000_pix <= 1; else hiscore1000_pix <= 0;
            endcase
        end
    end

	// OFL
    always @ (posedge Clk)
    case(state)
        TITLE, TITLE1: begin 
            pix <= duck_pix ? duck_pix : title_pix; // title_pix | duck_pix;
            drawing <= title_drawing || duck_drawing;
        end
        TITLE2, TITLE3, TITLE4: begin // NAME
            if(name_pix)
                pix <= 4'b1000;
            else
                pix <= 0;
            drawing <= name_drawing;
        end
        CHARSEL0: begin
            // pix <= char_pix | char1_pix;
            // if (seltext_pix) // use score_pix to specify 4 bit color
            //     score_pix <= 4'b1000; else score_pix <= 4'b0000;
            pix <= seltext_pix ? 4'b1000 : ((char_pix | char1_pix) ? (char_pix | char1_pix) : 
                ( (hc >= varchar_x-4) && (hc < varchar_x + CHAR_WIDTH*(2**CHAR_SCALE)+4) && (vc >= varchar_y-4) && (vc < varchar_y+CHAR_HEIGHT*(2**CHAR_SCALE)+4)) 
                ? 4'b1001 : 0);
            // if( (hc >= varchar_x-4) &&  )
            //     pix <= box color..;
            // drawing <= char_drawing || char1_drawing || seltext_drawing;
        end
        CHARSEL1: begin
            pix <= seltext_pix ? 4'b1000 : ((char_pix | char1_pix) ? (char_pix | char1_pix) : 
                ( (hc >= varchar_x1-4) && (hc < varchar_x1 + CHAR_WIDTH*(2**CHAR_SCALE)+4) && (vc >= varchar_y-4) && (vc < varchar_y+CHAR_HEIGHT*(2**CHAR_SCALE)+4)) 
                ? 4'b1001 : 0);
        end
        IDLE, RUN1, RUN2, JUMP1, JUMP2, DUCK1, DUCK2, FAIL1, FAIL2: begin
            if ((state == DUCK1 || state == DUCK2)) begin 
                if ((hc >= CHARX) && (hc < CHARX+CHAR_LONG_WIDTH*(2**CHAR_SCALE)) && (vc >= varchar_y) && (vc < varchar_y + CHAR_HEIGHT*(2**CHAR_SCALE))) // CHECK IF HC VC IN CHAR RANGE TO AVOID GLITCH
                begin
                    if(char0or1 == 0)
                        pix <= char_pix;
                    else
                        pix <= char1_pix;
                    // pix <= char_pix;
                end
                else 
                    pix <= 4'b0000;
            end
            else if (state == FAIL1) begin // if fail text, else if box around option 1, else if char location (if char 1, else char 0), else empty
                // when compared with background pix later, this pix should always take precedent
                pix <= failtext_pix ? failtext_pix : (((hc >= failtext_x) && (hc < failtext_x + 68*(2**failtext_scale)) && (vc >= failtext_y+17*(2**failtext_scale)) && (vc < failtext_y+26*(2**failtext_scale)) ) ? 4'b1001 : 
                    (((hc >= CHARX) && (hc < CHARX+CHAR_LONG_WIDTH*(2**CHAR_SCALE)) && (vc >= varchar_y) && (vc < varchar_y + CHAR_HEIGHT*(2**CHAR_SCALE))) ? 
                    (char0or1 ? char1_pix : char_pix) : 4'b0000));
            end
            else if(state == FAIL2) begin
                pix <= failtext_pix ? failtext_pix : (((hc >= failtext_x) && (hc < failtext_x + 68*(2**failtext_scale)) && (vc >= failtext_y+28*(2**failtext_scale)) && (vc < failtext_y+37*(2**failtext_scale)) ) ? 4'b1001 : 
                    (((hc >= CHARX) && (hc < CHARX+CHAR_LONG_WIDTH*(2**CHAR_SCALE)) && (vc >= varchar_y) && (vc < varchar_y + CHAR_HEIGHT*(2**CHAR_SCALE))) ? 
                    (char0or1 ? char1_pix : char_pix) : 4'b0000));
            end
            else begin
                if ((hc >= CHARX) && (hc < CHARX+CHAR_WIDTH*(2**CHAR_SCALE)) && (vc >= varchar_y) && (vc < varchar_y + CHAR_HEIGHT*(2**CHAR_SCALE))) // CHECK IF HC VC IN CHAR RANGE TO AVOID GLITCH
                begin
                    if(char0or1 == 0)
                        pix <= char_pix;
                    else
                        pix <= char1_pix;
                end
                else 
                    pix <= 4'b0000;
            end
            if (score1_pix || score10_pix || score100_pix || score1000_pix)
                score_pix <= 4'b1000;
            else if (hiscore1_pix || hiscore10_pix || hiscore100_pix || hiscore1000_pix)
                score_pix <= 4'b1010;
            else
                score_pix <= 4'b0000;
            // if (char0or1 == 0)
            //     drawing <= char_drawing || score1_pix || score10_pix || score100_pix || score1000_pix; // all character drawing can go here bc only one active at a time.
            // else 
            //     drawing <= char1_drawing || score1_pix || score10_pix || score100_pix || score1000_pix; // all character drawing can go here bc only one active at a time.

        end
    endcase
    // assign spr_pix_indx = my_pix | duck_pix; // my_pix ? my_pix : (smallf_pix ? smallf_pix : 0);	// // nvm also need for color. or else evals to boolean. unless bitwise or? need this if pixels overlap
	// assign drawing = my_drawing || duck_drawing;
	

    localparam CHARX = 250;
    localparam CHARY = 250;
    reg [8:0] varchar_y; // for jump
    reg [8:0] varchar_x; // for char sel, idle sprite only
    reg [8:0] varchar_x1; // for second sprite

    
    localparam CHAR_WIDTH  =  30;  // bitmap width in pixels
    localparam CHAR_LONG_WIDTH  =  43; // for duck duck
    localparam CHAR_HEIGHT =  32;  // bitmap height in pixels
    localparam CHAR_SCALE  =  1;  // 2^2 = 4x scale
    localparam DUCK_JUMP1_FILE   = "jump2.mem";  // bitmap file
    localparam DUCK_JUMP2_FILE   = "jump1.mem";  // bitmap file
    localparam DUCK_RUN1_FILE    = "run1.mem";  // bitmap file
    localparam DUCK_RUN2_FILE    = "run2.mem";  // bitmap file
    localparam DUCK_DUCK1_FILE   = "duck1.mem";  // bitmap file
    localparam DUCK_DUCK2_FILE   = "duck2.mem";  // bitmap file
    localparam DUCK_IDLE_FILE = "idle.mem";
    localparam CAT_IDLE_FILE = "idle1.mem";
    localparam CAT_JUMP1_FILE   = "jump2cat.mem";  // bitmap file
    localparam CAT_JUMP2_FILE   = "jump1cat.mem";  // bitmap file
    localparam CAT_RUN1_FILE    = "run1cat.mem";  // bitmap file
    localparam CAT_RUN2_FILE    = "run2cat.mem";  // bitmap file
    localparam CAT_DUCK1_FILE   = "duck1cat.mem";  // bitmap file
    localparam CAT_DUCK2_FILE   = "duck2cat.mem";  // bitmap file
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

    // CHAR 0
    reg idle_en, run1_en, run2_en, jump1_en, jump2_en, duck1_en, duck2_en; 
	wire [CIDXW-1:0] char_pix, idle_pix, run1_pix, run2_pix, jump1_pix, jump2_pix, duck1_pix, duck2_pix;
    assign char_pix = idle_pix | run1_pix | run2_pix | jump1_pix | jump2_pix | duck1_pix | duck2_pix;
	wire char_drawing, idle_drawing, run1_drawing, run2_drawing, jump1_drawing, jump2_drawing, duck1_drawing, duck2_drawing;
    assign char_drawing = idle_drawing || run1_drawing || run2_drawing || jump1_drawing || jump2_drawing || duck1_drawing || duck2_drawing;

    // CHAR 1
    reg idle1_en;  
	wire [CIDXW-1:0] char1_pix, idle1_pix, run1_1pix, run2_1pix, jump1_1pix, jump2_1pix, duck1_1pix, duck2_1pix;
    assign char1_pix = idle1_pix | run1_1pix | run2_1pix | jump1_1pix | jump2_1pix | duck1_1pix | duck2_1pix;
	// wire char1_drawing, idle1_drawing; // run1_drawing, run2_drawing, jump1_drawing, jump2_drawing, duck1_drawing, duck2_drawing;
    // assign char_drawing = idle_drawing || run1_drawing || run2_drawing || jump1_drawing || jump2_drawing || duck1_drawing || duck2_drawing;

    // DUCKIDLE
    sprite #(
        .SPR_FILE(DUCK_IDLE_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) duckidle (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(varchar_x),
        .spry(CHARY),
        .pix(idle_pix),
        .drawing(idle_drawing),
        .en(idle_en)
    );
    // CATIDLE
    sprite #(
        .SPR_FILE(CAT_IDLE_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) catidle (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(varchar_x1),
        .spry(CHARY),
        .pix(idle1_pix),
        .en(idle1_en)
    );

// CAT CONTROLS V
    sprite #(
        .SPR_FILE(CAT_JUMP1_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) catjump1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(varchar_y),
        .pix(jump1_1pix),
        .en(jump1_en)
    );

    sprite #(
        .SPR_FILE(CAT_JUMP2_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) catjump2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(varchar_y),
        .pix(jump2_1pix),
        .en(jump2_en)
    );

    sprite #(
        .SPR_FILE(CAT_RUN1_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) catrun1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(CHARY),
        .pix(run1_1pix),
        .en(run1_en)
    );

    sprite #(
        .SPR_FILE(CAT_RUN2_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) catrun2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(CHARY),
        .pix(run2_1pix),
        .en(run2_en)
    );

    sprite #(
        .SPR_FILE(CAT_DUCK1_FILE),
        .SPR_WIDTH(CHAR_LONG_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) catduck1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(CHARY),
        .pix(duck1_1pix),
        .en(duck1_en)
    );

    sprite #(
        .SPR_FILE(CAT_DUCK2_FILE),
        .SPR_WIDTH(CHAR_LONG_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) catduck2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(CHARY),
        .pix(duck2_1pix),
        .en(duck2_en)
    );

// DUCK CONTROLS V
    sprite #(
        .SPR_FILE(DUCK_JUMP1_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) duckjump1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(varchar_y),
        .pix(jump1_pix),
        .drawing(jump1_drawing),
        .en(jump1_en)
    );

    sprite #(
        .SPR_FILE(DUCK_JUMP2_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) duckjump2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(varchar_y),
        .pix(jump2_pix),
        .drawing(jump2_drawing),
        .en(jump2_en)
    );

    sprite #(
        .SPR_FILE(DUCK_RUN1_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) duckrun1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(CHARY),
        .pix(run1_pix),
        .drawing(run1_drawing),
        .en(run1_en)
    );

    sprite #(
        .SPR_FILE(DUCK_RUN2_FILE),
        .SPR_WIDTH(CHAR_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) duckrun2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(CHARY),
        .pix(run2_pix),
        .drawing(run2_drawing),
        .en(run2_en)
    );

    sprite #(
        .SPR_FILE(DUCK_DUCK1_FILE),
        .SPR_WIDTH(CHAR_LONG_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) duckduck1 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(CHARY),
        .pix(duck1_pix),
        .drawing(duck1_drawing),
        .en(duck1_en)
    );

    sprite #(
        .SPR_FILE(DUCK_DUCK2_FILE),
        .SPR_WIDTH(CHAR_LONG_WIDTH),
        .SPR_HEIGHT(CHAR_HEIGHT),
		.SPR_SCALE(CHAR_SCALE)
    ) duckduck2 (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(CHARX),
        .spry(CHARY),
        .pix(duck2_pix),
        .drawing(duck2_drawing),
        .en(duck2_en)
    );

    
    
    
    // NAME :D
    localparam NAME_WIDTH  =  78;  // bitmap width in pixels
    localparam NAME_HEIGHT =  15;  // bitmap height in pixels
    localparam NAME_FILE   = "name.mem";  // bitmap file
	localparam NAME_SCALE  =  1;  // 2^2 = 4x scale
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

	wire signed [CORDW-1:0] name_x, name_y;
    assign name_x = 325, name_y = 250; 
    reg name_en;
	wire [CIDXW-1:0] name_pix;
	wire name_drawing;

    sprite #(
        .SPR_FILE(NAME_FILE),
        .SPR_WIDTH(NAME_WIDTH),
        .SPR_HEIGHT(NAME_HEIGHT),
		.SPR_SCALE(NAME_SCALE)
    ) name (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(name_x),
        .spry(name_y),
        .pix(name_pix),
        .drawing(name_drawing),
        .en(name_en)
    );

   // SELTEXT SELECTION TEXT CHARACTER SELECT
    wire signed [CORDW-1:0] seltext_x, seltext_y;
    assign seltext_x = 335, seltext_y = 160; 
    reg seltext_en;
	wire [CIDXW-1:0] seltext_pix;
	wire seltext_drawing;

    sprite #(
        .SPR_FILE("seltext.mem"),
        .SPR_WIDTH(52),
        .SPR_HEIGHT(5),
		.SPR_SCALE(2)
    ) seltext (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(seltext_x),
        .spry(seltext_y),
        .pix(seltext_pix),
        .drawing(seltext_drawing),
        .en(seltext_en)
    );

    // FAILTEXT FAIL COLLISION TEXT
    wire signed [CORDW-1:0] failtext_x, failtext_y;
    assign failtext_x = 300, failtext_y = 205; 
    reg failtext_en;
	wire [CIDXW-1:0] failtext_pix;
    localparam failtext_scale = 2;

    sprite #(
        .SPR_FILE("failtext.mem"),
        .SPR_WIDTH(68),
        .SPR_HEIGHT(35),
		.SPR_SCALE(failtext_scale)
    ) failtext (
        .clk(clk25),
        .rst(Reset),
        .line(line),
        .sx(hc),
        .sy(vc),
        .sprx(failtext_x),
        .spry(failtext_y),
        .pix(failtext_pix),
        .en(failtext_en)
    );


endmodule
