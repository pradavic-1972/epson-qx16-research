# Epson QX-16 Power Supply Replacement  
## Using a Modern Mean Well RPT-60B PSU

---

## Overview

The original Epson QX-16 power supply is now over forty years old. Like many early 1980s switch-mode power supplies, it relies heavily on electrolytic capacitors and aging components that can degrade over time. Common symptoms include unstable voltages, failure to start, excessive ripple, and in some cases damage to logic or video circuitry.

To improve long-term reliability while keeping the system electrically safe and reversible, the original power supply was replaced with a modern industrial unit: the **Mean Well RPT-60B**.

This document describes the reasoning, electrical considerations, connector pinout, and wiring strategy used for this replacement.

---

## Why Replace the Original Power Supply?

Typical issues seen in original QX-16 PSUs include:

- Dried or leaking electrolytic capacitors  
- Poor voltage regulation under load  
- Increased ripple and electrical noise  
- Excessive heat generation  
- Difficulty sourcing replacement components  

While recapping the original PSU is possible, a modern replacement provides:

- Tighter voltage regulation  
- Built-in over-current and over-voltage protection  
- Higher efficiency and lower heat  
- Readily available replacement hardware  

---

## Why the Mean Well RPT-60B?

The Mean Well RPT-60B is a compact, open-frame industrial power supply well suited for retro computer restorations.

### Electrical Specifications

| Rail | Voltage | Max Current |
|----|----|----|
| +5 V | 5.0 V | 6.0 A |
| +12 V | 12.0 V | 2.0 A |
| −12 V | −12.0 V | 0.5 A |

These rails match the QX-16 requirements closely:

- **+5 V** → logic, RAM, CPU, gate arrays  
- **+12 V** → floppy drives, video, analog circuits  
- **−12 V** → RS-232 and analog reference circuits  

The presence of a native −12 V rail is particularly important, as many modern PSUs omit it.

---

## Mechanical Considerations

The RPT-60B is significantly smaller than the original Epson PSU, allowing flexible mounting options inside the chassis. Because it is an open-frame PSU:

- All mains connections must be insulated  
- Strain relief must be used  
- Earth (FG) must be bonded to chassis ground  

---

## Motherboard Power Connector

The Epson QX-16 motherboard uses a **13-pin power input connector** with multiple pins per rail to reduce current density and improve stability.

### Official 13-Pin Connector Pinout

| Pin | Signal | Description |
|----:|:------|:------------|
| 1 | PWD | Power failure detection |
| 2 | GND | Ground of +5 V |
| 3 | GND | Ground of −12 V |
| 4 | GND | Ground of +12 V |
| 5 | GP | Ground of +12 V |
| 6 | GP | Ground of +12 V |
| 7 | +5V | +5 V for logic |
| 8 | +5V | +5 V for logic |
| 9 | +5V | +5 V for logic |
|10 | +12L | +12 V for logic |
|11 | +12L | +12 V for logic |
|12 | +12F | +12 V for floppy drives |
|13 | +12C | +12 V for CRT / video |

Although grounds are labeled separately in documentation, all grounds are electrically common on the motherboard. Likewise, all +12 V rails are derived from the same supply, despite serving different subsystems.

---

## Connector and Crimp Housing

To avoid modifying the motherboard, **BH3-96P crimp housings** were used. These match the original connector pitch and allow a fully reversible installation.

No soldering was performed on the motherboard.

[PSU Connector detail](/photos/ps-connector.jpg)
---

## Mean Well RPT-60B Outputs

The RPT-60B provides the following DC outputs:

- +5 V (two terminals, internally common)  
- +12 V  
- −12 V  
- COM (Ground)  

Although the PSU exposes fewer terminals than the motherboard has pins, this is handled by rail fan-out.

---

## Wiring Strategy

Because the QX-16 expects multiple pins per rail, the correct approach is **fan-out**, not one-to-one mapping.

### Rail Distribution

| QX-16 Pins | Voltage | Connected To |
|-----------|--------|--------------|
| Pins 7–9 | +5 V | Mean Well +5 V |
| Pins 10–13 | +12 V | Mean Well +12 V |
| Pin 3 | −12 V | Mean Well −12 V |
| Pins 2, 4–6 | GND | Mean Well COM |
| Pin 1 | PWD | Connected to GND |

### Power Failure Detect (PWD)

The **PWD (Power Failure Detect)** pin is tied to **ground**, matching the expected “power good / no failure” condition used by the original Epson PSU. Leaving this pin floating is not recommended.

---

## Implementation Notes

- Multiple wires are used to distribute +5 V and +12 V across their respective pins
- All ground pins are populated and tied together at the PSU
- A single dedicated wire is used for −12 V
- All crimps were mechanically verified and continuity-checked

The attached photo in the repository shows the completed BH3-96P connector installed on the motherboard.

---

## Electrical Verification

Before connecting the motherboard:

1. All rails verified with a multimeter  
2. Correct polarity confirmed pin-by-pin  
3. Ground continuity verified  
4. Voltages confirmed within tolerance  

After installation:

- Immediate and reliable power-on  
- Stable boot into CP/M and MS-DOS modes  
- No observable voltage sag under load  
- Stable video and floppy operation  

---

## Preservation Considerations

This modification:

- Does not alter the motherboard  
- Preserves the original connector format  
- Is fully reversible  
- Improves long-term reliability  

The original PSU can be restored separately while keeping the system usable and electrically safe.

---

## Final Notes

The Epson QX-16 contains rare custom gate arrays and video hardware that depend on stable power delivery. Replacing the aging PSU with a modern, regulated supply like the Mean Well RPT-60B significantly reduces risk while maintaining the system’s original electrical behavior.

For systems intended to be actively used rather than displayed, this upgrade is strongly recommended.

---
