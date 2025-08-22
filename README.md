# Signed 32-bit Q22.10 Vectoring CORDIC atan2 in VHDL

This project implements a **signed fixed-point (Q22.10) 32-bit vectoring CORDIC algorithm** in VHDL to calculate `atan2(y, x)` for all quadrants.  
The design supports **signed inputs in two's complement format** and outputs a signed angle in the same fixed-point format.

---

## 🚀 Features
- **Data format**: Q22.10 fixed-point, signed
- **Algorithm**: Vectoring CORDIC for atan2 computation
- **Bit width**: 32-bit inputs and outputs
- **Latency**: ~470 ns at 160 MHz (including setup and result states)
- **Sign handling**: Two's complement support for all four quadrants
- **Technology**: VHDL-93, synthesizable for FPGA

---

## ⚙ Technical Description
The design uses a **finite state machine (FSM)** with the following stages:

1. **RS** – Reset internal registers and outputs.
2. **Sleep** – Wait for `start` signal.
3. **Pre** – Convert input operands to absolute values if negative.
4. **Pre1** – Shift inputs to match Q22.10 fixed-point scaling.
5. **Pro** – Initialize iteration variables (`x`, `y`, `z`) and set the first angle from the lookup table.
6. **Op1–Op4** – Perform CORDIC rotations iteratively, updating the vector and accumulating the angle.
7. **Res** – Scale the accumulated angle and adjust the result according to the quadrant.
8. **Res1** – Apply final sign correction and assert `done`.

The **lookup table (`alfat`)** stores precomputed arctangent values of `2^-i` in Q22.10 format.  
The iterative vectoring method rotates the input vector toward the x-axis, efficiently computing the arctangent without multipliers.

---

## 🖥 Simulation Waveform
Example simulation showing the atan2 calculation and output timing.

![Simulation waveform](img/cordic_atan2_simwave.png)

