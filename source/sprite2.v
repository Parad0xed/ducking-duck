module sprite2 #(
    parameter CORDW=12,      // signed coordinate width (bits)
    parameter H_RES=784,     // horizontal screen resolution (pixels)
    parameter SX_OFFS=2,     // horizontal screen offset (pixels)
    parameter SPR_FILE="",   // sprite bitmap file ($readmemh format)
    parameter SPR_WIDTH=8,   // sprite bitmap width in pixels
    parameter SPR_HEIGHT=8,  // sprite bitmap height in pixels
    parameter SPR_SCALE=0,
    parameter SPR_DATAW=3    // data width: bits per pixel
    ) (
    input  wire en,            // consider this to activate/deactivate a sprite? 
    input  wire clk,                            // clock
    input  wire rst,                            // reset
    input  wire line,                           // start of active screen line
    input  wire signed [CORDW-1:0] sx, sy,      // screen position
    input  wire signed [CORDW-1:0] sprx, spry,  // sprite position
    input wire [SPR_DATAW-1:0] spr_rom_data,
    output reg [3:0] state,     // for debugging
    output reg [$clog2(SPR_WIDTH)-1:0] bmap_x,
    output reg [$clog2(SPR_ROM_DEPTH)-1:0] spr_rom_addr,
    output reg [SPR_SCALE:0] cnt_x,
    output      reg [SPR_DATAW-1:0] pix,                        // use [SPR_DATAW-1:0] for >1 bit pix
    output      reg drawing                     // drawing at position (sx,sy)
    );

    localparam SPR_ROM_DEPTH = SPR_WIDTH * SPR_HEIGHT;
    // reg [$clog2(SPR_ROM_DEPTH)-1:0] spr_rom_addr;  // pixel position
    // wire [SPR_DATAW-1:0] spr_rom_data;  // pixel color
    
    // horizontal coordinate within sprite bitmap
    reg [$clog2(SPR_WIDTH)-1:0] bmap_x;

    // horizontal scale counter
    reg [SPR_SCALE:0] cnt_x;

    // for registering sprite position
    reg unsigned [CORDW-1:0] sprx_r, spry_r;

    // status flags: used to change state
    wire signed [CORDW:0]  spr_diff;  // diff vertical screen and sprite positions
    wire spr_active;  // sprite active on this line
    wire spr_begin;   // begin sprite drawing
    wire spr_end;     // end of sprite on this line
    wire line_end;    // end of screen line, corrected for sx offset
    
    assign spr_diff = (sy - spry_r) >>> SPR_SCALE;  // arithmetic right-shift
    assign spr_active = (spr_diff >= 0) && (spr_diff < SPR_HEIGHT);
    //assign spr_active = (sy - spry_r >= 0) && (sy - spry_r < SPR_HEIGHT);
    assign spr_begin  = (sx >= sprx_r - SX_OFFS);
    assign spr_end    = (bmap_x == SPR_WIDTH-1);
    assign line_end   = (sx == H_RES - SX_OFFS);
    
    // sprite state machine

    localparam 	
	IDLE = 4'b0000, REG_POS = 4'b0001, ACTIVE = 4'b0010, WAIT_POS = 4'b0011, SPR_LINE = 4'b0100, WAIT_DATA = 4'b0101, UNK = 4'bXXXX, TEST = 4'b0110;
    reg [3:0] state;	

    always @(posedge clk) begin
        if (line) begin  // prepare for new line
            state <= REG_POS;
            pix <= 0;
            drawing <= 0;
            spr_rom_addr <= 0;
        end else if(en) begin
            case (state)
                REG_POS: begin
                    state <= ACTIVE;
                    sprx_r <= sprx;
                    spry_r <= spry;
                end
                ACTIVE: state <= spr_active ? WAIT_POS : IDLE;
                WAIT_POS: begin
                    if (spr_begin) begin
                        $display(" ");
                        state <= SPR_LINE;
                        // spr_rom_addr <= (sy - spry_r) * SPR_WIDTH + (sx - sprx_r) + SX_OFFS;
                        spr_rom_addr <= spr_diff * SPR_WIDTH + (sx - sprx_r) + SX_OFFS;
                        bmap_x <= 0;
                        cnt_x <= 0;
                        if(sx < 20 && sy > 150)
                            $display("spr_diff: %d, sx: %d, sprx_r: %d, sx-sr: %d", spr_diff, sx, sprx_r,  (sx-sprx_r));
                    end
                end
                SPR_LINE: begin
                    // extra state to wait for data from synchronous rom
                    if(sx < 20 && sy > 150)
                            $display("sprite rom addr at hc=%d vc=%d : %d", sx, sy, spr_rom_addr);
                    state <= TEST;
                    // if (spr_end || line_end) state <= WAIT_DATA; // is this line necessary??
                    // spr_rom_addr <= spr_rom_addr + 1;
                    if (line_end) state <= WAIT_DATA;
                    cnt_x <= cnt_x + 1;
                    if (SPR_SCALE == 0) begin
                        spr_rom_addr <= spr_rom_addr + 1;
                        bmap_x <= bmap_x+1;
                    end
                    // $display("read a %h at addr = %h IN SPRL, state = %d, SP = %h", spr_rom_data, addr_return, state, spr_rom_addr);
                end
                // SPR_LINE2: begin
                //     // extra state for first bit with 1 less
                // end
                TEST: begin
                    // if (spr_end || line_end) state <= WAIT_DATA;
                    // spr_rom_addr <= spr_rom_addr + 1;
                    // bmap_x <= bmap_x + 1;
                    // pix <= spr_rom_data;
                    // drawing <= 1;
                    if (line_end) state <= WAIT_DATA;
                    pix <= spr_rom_data;
                    drawing <= 1;
                    if (SPR_SCALE == 0 || cnt_x == 2**SPR_SCALE-1) begin
                        spr_rom_addr <= spr_rom_addr + 1;
                        bmap_x <= bmap_x +1;
                    // end
                    // if (SPR_SCALE == 0 || cnt_x == 2**SPR_SCALE-1) begin
                        if (spr_end) begin 
                            state <= WAIT_DATA;
                            spr_rom_addr <= spr_rom_addr;
                        end
                        // bmap_x <= bmap_x + 1;
                        cnt_x <= 0;
                    end else cnt_x <= cnt_x + 1;
                    // $write("%h ",spr_rom_data);
                end
                WAIT_DATA: begin
                    state <= IDLE;  // 1 cycle between address set and data receipt
                    pix <= 0;  // default color
                    drawing <= 0;
                    spr_rom_addr <= 0;
                end
                default: state <= IDLE;
            endcase
        end

        if (rst) begin
            state <= IDLE;
            spr_rom_addr <= 0;
            bmap_x <= 0;
            cnt_x <= 0;
            pix <= 0;
            drawing <= 0;
        end
    end
endmodule