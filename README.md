# Sigma-Delta ADC Digital Back-End (Verilog)

A high-performance digital decimation filter and serial transmission engine designed in Verilog to process a 1-bit PDM stream from a Sigma-Delta modulator, convert it to 16-bit parallel data, and stream it to a PC over UART.

##  Key Features
* **CIC Decimation Filter:** 1st-order Sinc filter with an OverSampling Ratio (OSR) of 32. Converts high-speed 1-bit PDM into 16-bit PCM.
* **16-to-8-Bit Splitter FSM:** An internal hardware manager that automatically captures the 16-bit filter data and sequences it into consecutive High and Low bytes for serial transmission.
* **Parameterized UART Transmitter:** Fully synchronous serial transmission engine configured for **115,200 Baud** at a 10 MHz system clock.

## 1. CIC Filter (cic_filter.v) — The Decimation Engine
* **The Engineering Challenge:**  The analog modulator sends data as a rapid, 1-bit stream where the density of the pulses represents the signal amplitude. Standard digital blocks cannot process a 1-bit PDM stream directly without massive quantization noise.

* **The Implementation:** This block implements a 1st-order Cascaded Integrator-Comb (Sinc) filter structure. It treats the incoming bitstream as an unsigned value (0 or 1) and continuously accumulates them into a 16-bit register over a fixed window defined by the OverSampling Ratio (OSR) of 32.

* **The Handshake:** Exactly on the 32nd clock cycle, the filter performs two simultaneous operations in a single clock edge: it asserts the data_valid flag to alert the rest of the system, and it clears the internal accumulator back to zero to prevent data leakage into the next sampling window.

* **Verification Proof:** 50% Density: An input string of alternating 101010 values results in exactly 16 ones collected per window, yielding a static output hex value of 0x0010.

* **25% Density:** An input string of 10001000 collects exactly 8 ones, yielding 0x0008.

* **Waveform Capture:** (See image_40f299.png) The single-cycle pulse behavior of data_valid perfectly aligns with the closing edge of the OSR counter.

## 2. UART Transmitter (uart_tx.v) — The Serial Interface
The Engineering Challenge: FPGAs process data on wide parallel buses (like our 16-bit filter output), but standard communication interfaces like PCs require data to arrive sequentially over a single wire. Furthermore, a 10 MHz hardware clock is far too fast for standard serial communication receivers.

* **The Implementation:** This engine utilizes a fixed clock-divider counter that counts up to 87 master clock cycles per serial bit, transforming our 10 MHz internal frequency into a standard 115,200 Baud rate. The core is driven by a 4-state machine: IDLE, START_BIT, DATA_BITS, and STOP_BIT.

* **The Safety Interlock:** When a transmission begins, the module asserts a hardware flag called tx_active. As long as tx_active is high (1), the module ignores any accidental external trigger pulses, ensuring the current 10-bit serial frame cannot be corrupted mid-transmission.

* **Verification Proof:** Control Byte Test: Injected a hardcoded value of 0x5A (01011010 binary).

* **Waveform Capture:** (See image_72f9ed.png) The simulation proves perfect compliance with the RS-232 serial standard. The line drops low for exactly 1 bit period (Start), sequences through the bits starting with the LSB (0, then 1, then 0...), and returns high for the Stop bit, with tx_active bounding the execution perfectly.

## 3. Top-Level Integration Manager (top_level.v) — The Bus-Width Converter FSM
The Engineering Challenge: A classic hardware bottleneck—we have a 16-bit data sample produced by the filter, but the UART engine can only transmit 8 bits at a time. Shoving 16 bits down an 8-bit pipe requires structured data pacing.

The Implementation: This module solves the bottleneck by implementing a 5-state Control Finite State Machine (FSM):

IDLE: Polls the filter. The moment data_valid fires, it snaps a copy of the 16-bit word into a holding register (saved_cic_data) to protect it from being overwritten by the next filter cycle.

SEND_HIGH: Isolates the upper half of the register (saved_cic_data[15:8]), drives it onto the UART data bus, and pulls the tx_start trigger high.

WAIT_HIGH: Drops the trigger and monitors tx_active. The moment the UART drops tx_active low, the FSM knows the upper byte is safely on its way to the PC.

SEND_LOW: Isolates the lower half of the register (saved_cic_data[7:0]), exposes it to the UART, and pulls the trigger again.

WAIT_LOW: Waits for the lower byte transmission to finish, then returns to IDLE.
---

## 📐 System Architecture

```text
[1-bit PDM Stream] ──► [CIC Filter (OSR 32)] ──► [16-bit Parallel Data + Valid Strobe]
                                                               │
                                                               ▼
[PC / Serial Monitor] ◄── [UART TX (115.2k)] ◄── [Splitter FSM (High/Low Byte)]

