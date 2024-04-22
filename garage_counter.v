`timescale 1ns / 1ps
module garage_counter(
    input clk,           
    input btnC,          
    input btnU,          
    input btnD,          
    input btnL,          
    input [3:0] sw, 
    output reg [6:0] seg, 
    output reg [3:0] an  
);

parameter CLK_FREQ = 100000000; 
parameter REFRESH_RATE = 1000; // Refresh rate for the displays in Hz
parameter MAX_COUNT = CLK_FREQ / REFRESH_RATE; // Counts required per display update
parameter CORRECT_COMBO = 4'b1011; // Correct combination for unlocking

// Timing and counting
reg [31:0] refresh_counter = 0;
reg [6:0] seconds = 0;
reg [2:0] display_mux = 0;  // mux for 3 displays

// Debounce logic parameters
reg last_btnU_state = 0;
reg last_btnL_state = 0;
reg last_btnD_state = 0;
reg btnU_active = 0; // Flag to display "L"
reg gate_locked = 1; // Gate initially locked

// 7-segment decoder dispaly
function [6:0] decode_7seg(input [3:0] digit);
    begin
        case (digit)
            4'd0: decode_7seg = 7'b1000000; // "0"
            4'd1: decode_7seg = 7'b1111001; // "1"
            4'd2: decode_7seg = 7'b0100100; // "2"
            4'd3: decode_7seg = 7'b0110000; // "3"
            4'd4: decode_7seg = 7'b0011001; // "4"
            4'd5: decode_7seg = 7'b0010010; // "5"
            4'd6: decode_7seg = 7'b0000010; // "6"
            4'd7: decode_7seg = 7'b1111000; // "7"
            4'd8: decode_7seg = 7'b0000000; // "8"
            4'd9: decode_7seg = 7'b0010000; // "9"
            4'd10: decode_7seg = 7'b1000111; // "L"
            4'd11: decode_7seg = 7'b0000110; // "E"
            4'd12: decode_7seg = 7'b1000001; // "U"
            default: decode_7seg = 7'b1111111; // Blank
        endcase
    end
endfunction

always @(posedge clk) begin
    // Reset 
    if (btnC) begin
        seconds <= 0;
        refresh_counter <= 0;
        last_btnU_state <= 0;
        last_btnD_state <= 0;
        last_btnL_state <= 0;
        btnU_active <= 0;
        gate_locked <= 1; // Lock the gate
    end else begin
        if (!last_btnU_state && btnU) begin
            if (gate_locked) begin
                btnU_active <= 1;  // Indicate entry mode, show "E" for enter code
            end else if (seconds < 99) begin
                seconds <= seconds + 1;  // Increment counter if gate is unlocked
            end
        end

        if (!last_btnL_state && btnL) begin
            gate_locked <= 1;  // Lock the gate, show "L"
            btnU_active <= 0;
        end

        if (!last_btnD_state && btnD) begin
            if (seconds > 0) begin
                seconds <= seconds - 1;  // Decrement counter
            end
        end

        // Check combination if in entry mode
        if (btnU_active && sw == CORRECT_COMBO) begin
            gate_locked <= 0;  // Unlock the gate
            btnU_active <= 0;
        end
	
        last_btnU_state <= btnU;
        last_btnD_state <= btnD;
        last_btnL_state <= btnL;

        // Display refresh logic using mux 
        if (refresh_counter >= MAX_COUNT - 1) begin
            refresh_counter <= 0;
            display_mux <= display_mux + 1;
            case (display_mux)
                3'b000: begin
                    seg <= decode_7seg(seconds % 10); // Ones
                    an <= 4'b1011; // Ones counter digit display enable
                end
                3'b001: begin
                    seg <= decode_7seg(seconds / 10); // Tens
                    an <= 4'b0111; //  Tens counter digit display enable
                end
                3'b010: begin
                    seg <= btnU_active ? decode_7seg(4'd11) : (gate_locked ? decode_7seg(4'd10) : decode_7seg(4'd12));
                    an <= 4'b1110; // Rightmost  display for lock status
                end
                default: begin
                    display_mux <= 3'b000; // Reset to first display if out of range
                end
            endcase
        end else
            refresh_counter <= refresh_counter + 1;
    end
end

endmodule
