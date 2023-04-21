
module core #(parameter CIDXW=3, parameter CORDW=10) (Clk, Reset, BtnR_Pulse, BtnU_Pulse, BtnD, 
        clk25, line, hc, vc, state, pix, score_pix, drawing);


	/*  INPUTS */
	input	Clk, BtnR_Pulse, BtnU_Pulse, BtnD, Reset; //, Start, Ack;
    input clk25, line;
    input [CORDW-1:0] hc, vc;
    
    output reg [CIDXW:0] pix;
    output reg [CIDXW:0] score_pix;
    output reg drawing;
	// store current state
	output reg [3:0] state;	
    reg [29:0] i_count;	// 2^30 = 1 073 741 824
    reg [21:0] x_count; // to deal with modulus operation. 2^22 = 4194304
    reg [1:0] jump_count; // to time character jump
    reg [9:0] score; // for now, +1 per second, displayed in binary, caps at 1023
                     // consider displaying in decimal?
                     // in decimal : 
    reg [3:0] score_th, score_hun, score_ten, score_one; // increment and cap at 9999
    reg [29:0] s_count; // for counting score
    reg score_en, score_count_en; // score_en for display, count_en to count score

		
	localparam 	
	TITLE = 4'b0000, TITLE1 = 4'b0001, TITLE2 = 4'b0010, TITLE3 = 4'b0011, TITLE4 = 4'b0100, 
        RUN1 = 4'b0101, RUN2 = 4'b0110, JUMP1 = 4'b0111, JUMP2 = 4'b1000, DUCK1 = 4'b1001, DUCK2 = 4'b1010, IDLE = 4'b1011, UNK = 4'bXXXX;
	
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
		else				
            case(state)	// TITLE SCREEN SEQUENCE
                TITLE: begin
                    if (BtnR_Pulse) state <= TITLE1;
                    duck_x <= 250;
                    duck_y <= 150;
                    title_x <= 160;
                    title_y <= 60;
                    i_count <= 0;
                    jump_count <= 0;
                    x_count <= 0;
                    percent_shown <= 3;
                    duck_en <= 1;
                    title_en <= 1;
                    idle_en <= 0; run1_en <= 0; run2_en <= 0; jump1_en <= 0; jump2_en <= 0; duck1_en <= 0; duck2_en <= 0;
                    varchar_y <= CHARY;
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
                        state <= IDLE;
                    end
                end
                // BELOW SECTION FOR CHAR STATES
                IDLE: begin
                    score_en <= 1;
                    idle_en <= 1;
                    if(BtnU_Pulse) begin
                        idle_en <= 0;
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
                    end
                    else if(i_count == 50'd25000000) begin
                        i_count <= 0; jump1_en <= 0;
                        jump_count <= jump_count+1;
                        state <= JUMP2;
                    end

                    x_count <= x_count+1;
                    if(x_count == 2500000) begin 
                        x_count <= 0;
                        if(jump_count == 2'd0) begin // GOING UP (decrement y)
                            varchar_y <= varchar_y-5;
                        end
                        else begin // GOING DOWN (increment y)
                            varchar_y <= varchar_y+5;
                        end
                    end
                end
                JUMP2: begin 
                    jump2_en <= 1;
                    i_count <= i_count+1;
                    if(BtnD) begin
                        i_count <= 0; jump2_en <= 0;
                        state <= DUCK1;
                        varchar_y <= CHARY;
                        jump_count <= 0;
                    end
                    else if(i_count == 50'd25000000) begin
                        i_count <= 0; jump2_en <= 0;
                        if(jump_count == 3) begin 
                            jump_count <= 0;
                            state <= RUN1;
                            varchar_y <= CHARY;
                        end
                        else begin 
                            jump_count <= jump_count+1;
                            state <= JUMP1;
                        end
                    end
                    
                    x_count <= x_count+1;
                    if(x_count == 2500000) begin 
                        x_count <= 0;
                        if(jump_count == 2'd1) begin // GOING UP (decrement y)
                            varchar_y <= varchar_y-5;
                        end
                        else begin // GOING DOWN (increment y)
                            varchar_y <= varchar_y+5;
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
            if(score_count_en) begin // TO INCREMENT SCORE (WITH 4 DECIMAL DIGITS FOR DISPLAY)
                s_count <= s_count+1;
                if(s_count == 100000000) begin // 1 SECOND
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
    localparam SCORE1X = 550;   // upper left corner, each digit is 
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
        // NOTE: will need a seperate output reg to store the score_pix because although score and char should not 
        //          intersect, need to check intersection of char and bg in another module. score and char pix can 
        //          be bitwise or'd before sending to vga_bitchange. drawing <= char || score is fine i think.
        IDLE, RUN1, RUN2, JUMP1, JUMP2, DUCK1, DUCK2: begin
            // this could cause all pix to be one clock delayed..
            pix <= char_pix;
            if (score1_pix || score10_pix || score100_pix || score1000_pix)
                score_pix <= 4'b1000;
            else
                score_pix <= 4'b0000;
            drawing <= char_drawing || score1_pix || score10_pix || score100_pix || score1000_pix; // all character drawing can go here bc only one active at a time.

        end
    endcase
    // assign spr_pix_indx = my_pix | duck_pix; // my_pix ? my_pix : (smallf_pix ? smallf_pix : 0);	// // nvm also need for color. or else evals to boolean. unless bitwise or? need this if pixels overlap
	// assign drawing = my_drawing || duck_drawing;
	

    // later, char_x will be constant for all 4 states. and char_y will be variable, in jump only
    localparam CHARX = 250;
    localparam CHARY = 175;
    reg [8:0] varchar_y;

    // JUMP1
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
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

    reg idle_en, run1_en, run2_en, jump1_en, jump2_en, duck1_en, duck2_en; 
	wire [CIDXW-1:0] char_pix, idle_pix, run1_pix, run2_pix, jump1_pix, jump2_pix, duck1_pix, duck2_pix;
    assign char_pix = idle_pix | run1_pix | run2_pix | jump1_pix | jump2_pix | duck1_pix | duck2_pix;
	wire char_drawing, idle_drawing, run1_drawing, run2_drawing, jump1_drawing, jump2_drawing, duck1_drawing, duck2_drawing;
    assign char_drawing = idle_drawing || run1_drawing || run2_drawing || jump1_drawing || jump2_drawing || duck1_drawing || duck2_drawing;

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
        .sprx(CHARX),
        .spry(CHARY),
        .pix(idle_pix),
        .drawing(idle_drawing),
        .en(idle_en)
    );

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
    localparam NAME_WIDTH  =  92;  // bitmap width in pixels
    localparam NAME_HEIGHT =  18;  // bitmap height in pixels
    localparam NAME_FILE   = "name.mem";  // bitmap file
	localparam NAME_SCALE  =  0;  // 2^2 = 4x scale
    // localparam SPR_DRAWW  = SPR_WIDTH * 2**SPR_SCALE;

	wire signed [CORDW-1:0] name_x, name_y;
    assign name_x = 300, name_y = 250; 
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
endmodule
