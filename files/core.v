
module core #(parameter CIDXW=3, parameter CORDW=10) (Clk, Reset, BtnR_Pulse, BtnU_Pulse, BtnD, 
        clk25, line, hc, vc, state, pix, drawing);


	/*  INPUTS */
	input	Clk, BtnR_Pulse, BtnU_Pulse, BtnD, Reset; //, Start, Ack;
    input clk25, line;
    input [CORDW-1:0] hc, vc;
    
	// input [7:0] Ain;
	// input [7:0] Bin;
	
	
    output reg [CIDXW:0] pix;
    output reg drawing;
	// store current state
	output reg [3:0] state;	
    reg [49:0] i_count;	
    reg [1:0] jump_count; // to time character jump
		
	localparam 	
	TITLE = 4'b0000, TITLE1 = 4'b0001, TITLE2 = 4'b0010, TITLE3 = 4'b0011, TITLE4 = 4'b0100, 
        RUN1 = 4'b0101, RUN2 = 4'b0110, JUMP1 = 4'b0111, JUMP2 = 4'b1000, DUCK1 = 4'b1001, DUCK2 = 4'b1010, UNK = 4'bXXXX;
	
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
		  end
		else				
            case(state)	// TITLE SCREEN SEQUENCE
                TITLE: begin
                    if (BtnR_Pulse) state <= TITLE1;
                    duck_x <= 250;
                    duck_y <= 150;
                    title_x <= 160;
                    title_y <= 50;
                    i_count <= 0;
                    jump_count <= 0;
                    percent_shown <= 3;
                    duck_en <= 1;
                    title_en <= 1;
                    run1_en <= 0; run2_en <= 0; jump1_en <= 0; jump2_en <= 0; duck1_en <= 0; duck2_en <= 0;
                    varchar_y <= CHARY;
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
                        state <= RUN1;
                    end
                end
                // STARTSCREEN: begin 
                    // idle_en <= 1;
                // end 

                // BELOW SECTION FOR CHAR STATES
                RUN1: begin
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

                    if(i_count%2500000 == 0) begin 
                        if(jump_count < 2) begin // GOING UP (decrement y)
                            varchar_y <= varchar_y-3;
                        end
                        else begin // GOING DOWN (increment y)
                            varchar_y <= varchar_y+3;
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

                    if(i_count%2500000 == 0) begin 
                        if(jump_count < 2) begin // GOING UP (decrement y)
                            varchar_y <= varchar_y-3;
                        end
                        else begin // GOING DOWN (increment y)
                            varchar_y <= varchar_y+3;
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
		
    // rand num every 4 Clk = 1 every clk25
    wire [12:0] rand_13;
    LFSR rand13 (.clock(Clk), .reset(Reset), .rnd(rand_13));

	// OFL
    always @ (posedge Clk)
    case(state)
        TITLE, TITLE1: begin 
            pix <= duck_pix ? duck_pix : title_pix; // title_pix | duck_pix;
            // if(rand_13 < percent_shown*2731)
                drawing <= title_drawing || duck_drawing;
            // else 
            //     drawing <= 0;
        end
        TITLE2, TITLE3, TITLE4: begin // NAME
            if(name_pix)
                pix <= 4'b1000;
            else
                pix <= 0;
            drawing <= name_drawing;
        end
        RUN1, RUN2, JUMP1, JUMP2, DUCK1, DUCK2: begin
            pix <= char_pix;
            drawing <= char_drawing; // all character drawing can go here bc only one active at a time.
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

    reg run1_en, run2_en, jump1_en, jump2_en, duck1_en, duck2_en; 
	wire [CIDXW-1:0] char_pix, run1_pix, run2_pix, jump1_pix, jump2_pix, duck1_pix, duck2_pix;
    assign char_pix = run1_pix | run2_pix | jump1_pix | jump2_pix | duck1_pix | duck2_pix;
	wire char_drawing, run1_drawing, run2_drawing, jump1_drawing, jump2_drawing, duck1_drawing, duck2_drawing;
    assign char_drawing = run1_drawing || run2_drawing || jump1_drawing || jump2_drawing || duck1_drawing || duck2_drawing;

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
