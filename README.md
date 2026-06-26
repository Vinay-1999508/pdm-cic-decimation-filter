# Sigma-Delta ADC Digital Back-End (Verilog)

A high-performance digital decimation filter and serial transmission engine designed in Verilog to process a 1-bit PDM stream from a Sigma-Delta modulator, convert it to 16-bit parallel data, and stream it to a PC over UART.

##  Key Features
* **CIC Decimation Filter:** 1st-order Sinc filter with an OverSampling Ratio (OSR) of 32. Converts high-speed 1-bit PDM into 16-bit PCM.
* **16-to-8-Bit Splitter FSM:** An internal hardware manager that automatically captures the 16-bit filter data and sequences it into consecutive High and Low bytes for serial transmission.
* **Parameterized UART Transmitter:** Fully synchronous serial transmission engine configured for **115,200 Baud** at a 10 MHz system clock.

---

## 📐 System Architecture

```text
[1-bit PDM Stream] ──► [CIC Filter (OSR 32)] ──► [16-bit Parallel Data + Valid Strobe]
                                                               │
                                                               ▼
[PC / Serial Monitor] ◄── [UART TX (115.2k)] ◄── [Splitter FSM (High/Low Byte)]
