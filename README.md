# Digital Logic Testbench Generator

An automated hardware verification suite I built to test standard digital logic components.  this project implements the modern Design Verification (DV) process, combining hand-coded SystemVerilog with AI-generated testbenches.

## System Features
* **4-bit ALU:** A digital calculator that adds, subtracts, and performs logic operations, testing for math errors like overflows and carry bits.
* **4-to-16 Decoder:** Routes a 4-bit input signal to one of 16 output lines, tested automatically across every possible combination.
* **8-to-3 Priority Encoder:** Takes multiple input signals and outputs the one with the highest priority, testing how the system handles simultaneous button presses or signals.
* **4-bit Johnson Counter:** A clock-driven sequence generator, testing how the hardware shifts data step-by-step and handles system resets.
* **AI Test Automation:** Uses Claude AI to write the testing code, which automatically feeds edge-case numbers into the hardware and prints out a clear "PASS" or "FAIL".

## Verification Methodology
The hardware architecture and testbenches were simulated in the cloud using **EDA Playground** with the **Icarus Verilog** compiler:
* **RTL Design:** Built the core hardware modules manually in SystemVerilog.
* **Simulation Environment:** Copied the hardware and testbench pairs into EDA Playground and ran them through the Icarus Verilog compiler to instantly verify the logic via terminal outputs.

## Repository Structure
* `/src`: The SystemVerilog hardware source files (`.sv`).
* `/tb`: The testbench configuration files (`_tb.sv`).
* `/Images`: System documentation containing screenshots of the EDA Playground execution terminal proving all tests pass.