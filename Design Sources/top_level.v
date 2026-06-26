`timescale 1ns / 1ps

module top_level (
    input wire clk,         // 10 MHz Master Clock
    input wire rst,         // Reset button
    input wire bitstream,   // Incoming 1-bit PDM from the analog circuit
    output wire tx_out      // Outgoing Serial Data to the PC
);

    // --- Internal Wires ---
    wire [15:0] cic_data;
    wire cic_valid;
    
    reg tx_start;
    reg [7:0] tx_data;
    wire tx_active;

    // --- Instantiate the CIC Filter ---
    cic_filter my_filter (
        .clk(clk),
        .rst(rst),
        .bitstream(bitstream),
        .data_out(cic_data),
        .data_valid(cic_valid)
    );

    // --- Instantiate the UART Transmitter ---
    uart_tx my_uart (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_line(tx_out),
        .tx_active(tx_active)
    );

    // --- The 16-bit to 8-bit Splitter State Machine ---
    localparam IDLE       = 3'd0;
    localparam SEND_HIGH  = 3'd1;
    localparam WAIT_HIGH  = 3'd2;
    localparam SEND_LOW   = 3'd3;
    localparam WAIT_LOW   = 3'd4;

    reg [2:0] state = IDLE;
    reg [15:0] saved_cic_data = 0;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            tx_start <= 0;
            tx_data <= 0;
            saved_cic_data <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_start <= 0;
                    // Wait for the CIC filter to pulse data_valid
                    if (cic_valid) begin
                        saved_cic_data <= cic_data; // Lock in the 16-bit number
                        state <= SEND_HIGH;
                    end
                end
                
                SEND_HIGH: begin
                    tx_data <= saved_cic_data[15:8]; // Grab the top 8 bits
                    tx_start <= 1; // Pull the trigger
                    state <= WAIT_HIGH;
                end
                
                WAIT_HIGH: begin
                    tx_start <= 0; // Release the trigger
                    // Wait for UART to finish sending the byte
                    if (!tx_active) begin
                        state <= SEND_LOW;
                    end
                end
                
                SEND_LOW: begin
                    tx_data <= saved_cic_data[7:0]; // Grab the bottom 8 bits
                    tx_start <= 1; // Pull the trigger
                    state <= WAIT_LOW;
                end
                
                WAIT_LOW: begin
                    tx_start <= 0; // Release the trigger
                    if (!tx_active) begin
                        state <= IDLE; // Done! Go wait for the next CIC sample
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule