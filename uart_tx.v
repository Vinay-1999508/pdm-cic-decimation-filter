`timescale 1ns / 1ps

module uart_tx #(
    parameter CLKS_PER_BIT = 87 // 10 MHz / 115200 baud = ~87
)(
    input wire clk,
    input wire rst,
    input wire tx_start,        // Trigger pulse to start sending
    input wire [7:0] tx_data,   // The 8-bit byte to send
    output reg tx_line,         // The actual serial output wire
    output reg tx_active        // High while sending, low when done
);
    
    // State Machine Definitions
    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;
    
    reg [2:0] state = IDLE;
    reg [7:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] saved_data = 0;
    
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            tx_line <= 1'b1; // UART idles high
            tx_active <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_line <= 1'b1;
                    tx_active <= 1'b0;
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if (tx_start) begin
                        saved_data <= tx_data; // Latch the data immediately
                        state <= START;
                        tx_active <= 1'b1;
                    end
                end
                
                START: begin
                    tx_line <= 1'b0; // Start bit is a logic LOW
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA;
                    end
                end
                
                DATA: begin
                    tx_line <= saved_data[bit_index]; // Send bit by bit (LSB first)
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP;
                        end
                    end
                end
                
                STOP: begin
                    tx_line <= 1'b1; // Stop bit is a logic HIGH
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= IDLE; // Ready for next byte
                        tx_active <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule