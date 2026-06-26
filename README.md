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

### Parameterized Baud Rate Clock Division
To step down the internal 10 MHz FPGA master clock frequency to a stable, standard serial PC transmission speed of 115,200 Baud, an explicit internal division count parameter is declared within the transmitter logic:

$$\text{Target Transmission Baud Rate} = 115,200\text{ bps}$$  $$\text{Master Cycles Per Serial Bit Window} = \frac{10,000,000\text{ Hz}}{115,200\text{ bps}} \approx 86.805 \implies \text{Declared Parameter } (\texttt{CLK PER BIT}) = 87$$  
  
  By assigning CLK PER BIT = 87, the hardware counter accurately controls the serial bit duration, preventing bit-cell timing drift and confirming compliance with external serial receivers.

## Module-by-Module Functional Deep Dive

### 1. Custom 1st-Order CIC Decimation Filter (cic_filter.v)
Core Function: This module accepts the raw 1-bit PDM stream running at the high-frequency 10 MHz sampling boundary. It filters the high-frequency noise and groups the data into multi-bit words. 

RTL Architecture Details: * Integrator Stage: Runs continuously at the 10 MHz clock edge, accumulating incoming pulses inside a local tracking register (integrator). 
* Decimation Strobe Generator: An internal window counter (clk count) increments up to 32 to monitor the OSR limit, firing a single-cycle sampling pulse (sample pulse) exactly on the boundary. * Comb Differentiation Stage: When sample_pulse asserts, the logic runs a backward-difference calculation between the current integrator value and its historical state from the prior decimation window (integrator delayed):
  
  $$\texttt{data\ out} = \texttt{integrator} - \texttt{integrator\ delayed}$$

* Data Handshake: A single-cycle hardware strobe (data valid) pulses high concurrently with the computed output word update, alerting downstream modules that a fresh 16-bit value is ready.

### 2. Parameterized Serial Transmitter Engine (uart_tx.v)
Core Function: A synchronous, hardware-bounded serial engine that frames and shifts parallel byte payloads onto a 1-wire asynchronous communication line (tx_line).  

* **State Machine & Protocol Framing:** * The engine is organized around a clean 4-state control manager containing the states IDLE (2'b00), START (2'b01), DATA (2'b10), and STOP (2'b11).
Protocol assembly complies with standard serial configurations: it drives the line low for 1 full bit-window to mark the Start Bit, shifts out exactly 8 bits sequentially, and pulls the line high to register the Stop Bit. 
Data serialization strictly enforces a Least Significant Bit (LSB) first protocol hierarchy.  

* **Flow Protection:** As soon as an external transmission trigger (tx_start) registers, the internal tx_active flag drives high. While tx_active is high, any accidental trigger inputs are ignored to keep the active frame protected from mid-stream corruption.  

### 3. Top-Level Integration Manager (top_level.v)
Core Function: Connects the mixed-signal components and coordinates bus widths. It bridges the wide 16-bit output space of the decimation filter with the narrow 8-bit pipeline of the UART transmitter.  

Control Coordination Logic: * The parent logic monitors the filter's execution line. The moment the single-cycle data_valid flag is caught, the full 16-bit parallel word is latched into a protected holding register (saved_cic_data). 

* To transmit the full word without dropping bits, a sequential control state machine splits the 16-bit word into two pieces.  
* It isolates the upper byte (saved_cic_data[15:8]), matches it to the UART transmitter bus, and drives the tx_start pulse high. It monitors tx_active, waiting for the upper payload frame to clear the line.  
* Once the transmitter is clear, the state machine loads the lower byte (saved_cic_data[7:0]), triggers the transmitter a second time, and returns to its idle monitoring loop once the lower byte is safely transmitted.

##  Behavioral Simulation Verification

The complete processing pipeline was verified in Xilinx Vivado using behavioral testbenches to validate timing alignment, protocol framing, and multi-module data-path synchronization.

### 1. CIC Filter Unit Test (`cic_waveform.png`)
* **Execution Window:** 16.30 µs simulation timeline.
* **Verification Metrics:** Evaluated filter accuracy across two distinct input stream pulse distributions:
  * **50% PDM Density (Half-scale signal):** Alternating `101010` bitstream accumulates exactly 16 ones per OSR window, outputting `16'h0010` (16 decimal).
  * **25% PDM Density (Low-scale signal):** Sparse `10001000` bitstream accumulates exactly 8 ones, updating the parallel output word cleanly to `16'h0008` (8 decimal).
* **Handshake Validation:** Output updates align perfectly with the single-cycle `data_valid` hardware strobe.



### 2. Isolated UART Transmitter Unit Test (`uart_waveform.png`)
* **Execution Window:** 90.40 µs simulation timeline.
* **Verification Metrics:** Verified standalone serial protocol framing accuracy by driving a test payload byte of `8'h5A` (`8'b01011010`).
* **Protocol Compliance:** The serial line drops low for exactly 1 bit-period (87 clock cycles) to frame the **Start Bit**, shifts data out sequentially **LSB-first** (`0 → 1 → 0 → 1 → 1 → 0 → 1 → 0`), and pulls high for the **Stop Bit**. 
* **Hardware Interlock:** The `tx_active` flag stays asserted for the exact duration of the 10-bit frame, protecting active serialization from external input disruptions.



### 3. Top-Level Master Pipeline Verification (`system_waveform.png`)
* **Execution Window:** 206.70 µs full data-path tracking timeline.
* **Verification Metrics:** Validated end-to-end data-width conversion from raw 1-bit PDM stream to physical serial package transmission.
* **FSM Coordination:** Fed a continuous 50% density bitstream to force a calculated word value of `0x0010`. On the `data_valid` edge, the 5-state coordinator FSM locks the data into a holding register and successfully drives the UART engine to execute two consecutive transmissions over the physical `tx_out` pin: transmitting the **High Byte (`0x00`)** burst first, followed immediately by the **Low Byte (`0x10`)**.


---

## 📐 System Architecture

```text
[1-bit PDM Stream] ──► [CIC Filter (OSR 32)] ──► [16-bit Parallel Data + Valid Strobe]
                                                               │
                                                               ▼
[PC / Serial Monitor] ◄── [UART TX (115.2k)] ◄── [Splitter FSM (High/Low Byte)]

