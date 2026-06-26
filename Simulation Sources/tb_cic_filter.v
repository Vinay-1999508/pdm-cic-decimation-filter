`timescale 1ns / 1ps

module tb_cic_filter();

    // Inputs to the UUT (Unit Under Test)
    reg clk;
    reg rst;
    reg bitstream;

    // Outputs from the UUT
    wire [15:0] data_out;
    wire data_valid;

    // Instantiate the Unit Under Test (UUT)
    cic_filter uut (
        .clk(clk),
        .rst(rst),
        .bitstream(bitstream),
        .data_out(data_out),
        .data_valid(data_valid)
    );

    // 1. Clock Generator (10 MHz clock -> Period = 100ns)
    // Toggles every 50ns
    always begin
        #50 clk = ~clk;
    end

    // 2. Stimulus Generation
    integer i;
    initial begin
        // Initialize inputs
        clk = 0;
        rst = 1;
        bitstream = 0;

        // Hold reset for 200ns (2 clock cycles)
        #200;
        rst = 0;
        #100;

        // --- TEST CASE 1: Mid-scale Signal (50% Density) ---
        // Alternating 1 and 0. Over 32 cycles, we expect sixteen 1s.
        // The filter output should read '16'
        for (i = 0; i < 64; i = i + 1) begin
            bitstream = (i % 2 == 0) ? 1'b1 : 1'b0;
            #100; // Wait 1 clock cycle
        end

        // --- TEST CASE 2: Low-scale Signal (25% Density) ---
        // One 1 followed by three 0s. Over 32 cycles, we expect eight 1s.
        // The filter output should drop to '8'
        for (i = 0; i < 64; i = i + 1) begin
            bitstream = (i % 4 == 0) ? 1'b1 : 1'b0;
            #100;
        end

        // --- TEST CASE 3: Maximum Signal (100% Density) ---
        // All 1s. Over 32 cycles, we expect thirty-two 1s.
        // The filter output should climb to '32'
        bitstream = 1'b1;
        #3200; // Run for exactly 32 clock cycles

        // End simulation
        $display("Simulation Complete!");
        $stop;
    end
      
endmodule
