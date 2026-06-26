# Sigma-Delta ADC Digital Back-End (Verilog)

A high-performance digital decimation filter and serial transmission engine designed in Verilog to process a 1-bit PDM stream from a Sigma-Delta modulator, convert it to 16-bit parallel data, and stream it to a PC over UART.

##  Key Features
* **CIC Decimation Filter:** 1st-order Sinc filter with an OverSampling Ratio (OSR) of 32. Converts high-speed 1-bit PDM into 16-bit PCM.
* **16-to-8-Bit Splitter FSM:** An internal hardware manager that automatically captures the 16-bit filter data and sequences it into consecutive High and Low bytes for serial transmission.
* **Parameterized UART Transmitter:** Fully synchronous serial transmission engine configured for **115,200 Baud** at a 10 MHz system clock.

### Target Hardware Environment Constraints
Target FPGA Part Number: xc7a100tcsg324-1   
Product Family: Xilinx Artix-7  
Package Type: csg324  
Fabric Speed Grade: -1 

### PDM Sampling and Decimation Rate Conversion
The front-end delta-sigma modulator delivers a high-speed, 1-bit Pulse-Density Modulated (PDM) bitstream that represents the continuous profile of the target analog input signal (such as a baseline analog sine wave)
Master Input Sampling Frequency (f_clk): 10   
OverSampling Ratio (OSR): 32

The Cascaded Integrator-Comb (CIC) decimation stage smooths out the 1-bit quantization noise and downsamples the stream by a fixed factor equal to the OSR. The multi-bit output data frequency is calculated exactly as:

$$\text{Output PCM Sampling Rate} = \frac{\text{Input Clock Frequency}}{\text{OSR}} = \frac{10\text{ MHz}}{32} = 312.5\text{ kHz}$$


---

## 📐 System Architecture

```text
[1-bit PDM Stream] ──► [CIC Filter (OSR 32)] ──► [16-bit Parallel Data + Valid Strobe]
                                                               │
                                                               ▼
[PC / Serial Monitor] ◄── [UART TX (115.2k)] ◄── [Splitter FSM (High/Low Byte)]

