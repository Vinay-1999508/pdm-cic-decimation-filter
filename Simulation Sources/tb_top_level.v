`timescale 1ns / 1ps

module tb_top_level();

    reg clk;
    reg rst;
    reg bitstream;
    wire tx_out;

    // Instantiate the Top Level Module
    top_level uut (
        .clk(clk),
        .rst(rst),
        .bitstream(bitstream),
        .tx_out(tx_out)
    );

    // 10 MHz Clock (100ns period)
    always begin
        #50 clk = ~clk;
    end

    integer i;

    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 1;
        bitstream = 0;

        // Reset the whole system for 200ns
        #200;
        rst = 0;
        #100;

        // Feed a 50% density signal into the bitstream for 64 clock cycles.
        // We expect the CIC filter to output '16' (Hex: 0010).
        // The Top-Level should then send '00' over UART, followed by '10'.
        for (i = 0; i < 64; i = i + 1) begin
            bitstream = (i % 2 == 0) ? 1'b1 : 1'b0;
            #100;
        end

        // Keep feeding a 0 signal while we wait for UART to finish sending.
        // Sending two bytes at 115200 baud takes roughly 180,000 ns.
        // We will wait 200,000 ns to safely capture everything.
        bitstream = 0;
        #200000;
        
        $display("Full System Simulation Complete!");
        $stop; // Clean pause
    end

endmodule
