`timescale 1ns / 1ps

module tb_uart_tx();

    reg clk;
    reg rst;
    reg tx_start;
    reg [7:0] tx_data;
    
    wire tx_line;
    wire tx_active;

    // Instantiate the UART Transmitter
    uart_tx uut (
        .clk(clk),
        .rst(rst),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_line(tx_line),
        .tx_active(tx_active)
    );

    // 10 MHz Clock (100ns period)
    always begin
        #50 clk = ~clk;
    end

    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 1;
        tx_start = 0;
        tx_data = 8'h00;

        // Reset for 200ns
        #200;
        rst = 0;
        #100;

        // Load data (8'h5A = 01011010 binary) and trigger start
        tx_data = 8'h5A;
        tx_start = 1;
        #100; // Hold start high for 1 clock cycle
        tx_start = 0;

        // Wait for transmission to finish. 
        // 1 bit = 87 clocks = 8700 ns. 10 bits total (Start + 8 Data + Stop) = 87,000 ns
        // So we wait about 90 microseconds
        #90000;
        
        $display("UART Simulation Complete!");
        $stop; // Clean pause for Vivado GUI
    end

endmodule