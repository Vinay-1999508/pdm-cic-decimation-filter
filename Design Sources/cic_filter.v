`timescale 1ns / 1ps

module cic_filter (
    input wire clk,         // 10 MHz Master Clock
    input wire rst,         // Synchronous Reset
    input wire bitstream,   // 1-bit input stream from Delta-Sigma Modulator
    output reg [15:0] data_out, // 16-bit filtered parallel data word
    output reg data_valid   // High for 1 clock cycle when a new sample is ready
);

    // --- 1. INTEGRATOR STAGE (Runs at 10 MHz) ---
    reg [15:0] integrator = 0;

    always @(posedge clk) begin
        if (rst) begin
            integrator <= 0;
        end else begin
            // Accumulate the input bitstream. If bitstream is 1, add 1. If 0, add 0.
            integrator <= integrator + bitstream;
        end
    end

    // --- 2. DECIMATION/DOWN-SAMPLING STAGE ---
    // Count up to our OverSampling Ratio (OSR = 32)
    reg [4:0] clk_count = 0;
    reg sample_pulse = 0;

    always @(posedge clk) begin
        if (rst) begin
            clk_count <= 0;
            sample_pulse <= 0;
        end else begin
            if (clk_count == 31) begin
                clk_count <= 0;
                sample_pulse <= 1; // Trigger a pulse every 32 clock cycles
            end else begin
                clk_count <= clk_count + 1;
                sample_pulse <= 0;
            end
        end
    end

    // --- 3. COMB STAGE (Runs at 312.5 kHz via the sample_pulse) ---
    reg [15:0] integrator_delayed = 0;

    always @(posedge clk) begin
        if (rst) begin
            integrator_delayed <= 0;
            data_out <= 0;
            data_valid <= 0;
        end else if (sample_pulse) begin
            // Comb equation: Y(n) = X(n) - X(n-1)
            data_out <= integrator - integrator_delayed;
            integrator_delayed <= integrator;
            data_valid <= 1;
        end else begin
            data_valid <= 0; // Turn off valid pulse after one clock cycle
        end
    end

endmodule