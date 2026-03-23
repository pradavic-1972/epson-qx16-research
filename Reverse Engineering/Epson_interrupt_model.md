# Epson QX Interrupt Model (QX-11 vs QX-16)

## Overview

Reverse engineering of both the **Epson QX-16** and **QX-11 (VENUS)** shows that Epson does **not** follow the IBM PC interrupt numbering scheme. Instead, Epson uses a **native interrupt block starting at INT 70h**, with hardware sources mapped sequentially.

While the two machines differ in hardware (8259-based vs gate-array), they follow the **same philosophy**:

> Hardware interrupt sources are numbered starting at **INT 70h**, and BIOS assigns meaning to each vector directly rather than following IBM IRQ→INT conventions.

---

## Key Findings

### 1. Native interrupt base at INT 70h

On both systems:

* **INT 70h** is the first hardware interrupt
* Subsequent interrupts increment sequentially
* This mapping is **independent of IBM PIC conventions**

---

### 2. Different hardware, same abstraction

| System | Interrupt Hardware                                   |
| ------ | ---------------------------------------------------- |
| QX-16  | Dual 8259-style controllers (custom ports 08h / 0Ch) |
| QX-11  | GAVNIT gate array (custom interrupt controller)      |

Despite this difference, both expose interrupts using the same **70h-based vector model**.

---

### 3. Timer interrupt

* QX-16: **INT 71h** is the native system timer
* QX-11: **INT 71h** is also the system timer

This is the **primary periodic interrupt** used by BIOS (not INT 08h).

---

### 4. Keyboard interrupt

* QX-16: **INT 74h** (Master IR4: Keyboard/RS-232)
* QX-11: **INT 75h** (GAVNIO-driven keyboard interrupt)

Both are real BIOS ISRs handling:

* scan/byte input
* modifier state
* translation tables
* Ctrl-Break / Print Screen

---

### 5. Floppy controller interrupt

* QX-16: **INT 76h**
* QX-11: **INT 74h**

On both systems:

* The vector points to a simple **IRET**
* No substantial ISR is implemented in BIOS

**Conclusion:**

> The floppy interrupt exists at the hardware level, but BIOS primarily uses **polling** for uPD765 operations.

---

### 6. INT 08h is not native

* QX-16: INT 08h is used only as a **compatibility hook** (called from INT 71h)
* QX-11: INT 08h points to a **halt / unused vector**

**Conclusion:**

> INT 08h is **not part of the native interrupt model** on either system.

---

## Interrupt Mapping Comparison

### Native Epson Interrupts

| Function          | QX-16      | QX-11      | Notes                    |
| ----------------- | ---------- | ---------- | ------------------------ |
| Power-down detect | INT 70h    | INT 70h    | First hardware interrupt |
| System timer      | INT 71h    | INT 71h    | Primary periodic ISR     |
| External / option | INT 72h    | INT 72h    | Varies                   |
| External / option | INT 73h    | INT 73h    | Varies                   |
| Keyboard / Serial | INT 74h    | INT 75h    | Hardware differs         |
| Floppy controller | INT 76h    | INT 74h    | Stub (IRET)              |
| Other sources     | INT 75–77h | INT 76–77h | Platform-specific        |

---

## Architectural Insight

### Epson interrupt philosophy

Epson’s design differs from IBM in two major ways:

1. **Vector-first design**

   * Interrupts are defined directly as INT 70h+N
   * No strict dependency on IRQ numbering

2. **Hardware abstraction in BIOS**

   * BIOS decides which interrupts are meaningful
   * Some hardware interrupts (e.g., floppy) are not fully serviced via ISR

---

### Practical consequences

For development and emulation:

* **Do not assume IBM IRQ→INT mapping**
* Treat **INT 70–77h as the native interrupt block**
* Expect:

  * Real ISRs for timer and keyboard
  * Stub handlers (IRET) for some hardware sources
* Use BIOS services (INT 1Ah, INT 16h, etc.) instead of raw interrupts when possible

---

## Summary

Both QX-16 and QX-11 implement a consistent Epson-specific interrupt model:

* Hardware interrupts are mapped starting at **INT 70h**
* The exact vector used for a device may differ between systems
* The underlying hardware (PIC vs gate array) is abstracted away
* BIOS selectively implements meaningful handlers

> This confirms that Epson systems share a common interrupt philosophy even when the hardware differs significantly.

---

**Author:** QX Reverse Engineering Notes
