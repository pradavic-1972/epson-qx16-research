# Epson QX-16 Timer Interrupt (INT 71h)

## Overview

The Epson QX-16 does **not** follow the standard IBM PC timer interrupt model. Instead of using IRQ0 → INT 08h as the primary system timer, the QX-16 uses a **native timer interrupt at INT 71h**.

This document explains how INT 71h works, how it is connected to the hardware, and how it interacts with IBM-compatible interrupts.

---

## Interrupt Architecture

### Interrupt Controllers

The QX-16 uses a dual interrupt controller architecture similar to the IBM PC AT, but with different I/O mappings:

* **Master interrupt controller:** I/O port `0x08`
* **Slave interrupt controller:** I/O port `0x0C`

Unlike the IBM PC:

* End-of-interrupt (EOI) is issued using:

  ```asm
  OUT 08h, 20h
  ```
* There is no use of port `0x20` (standard IBM PIC command port)

---

## INT 71h Vector

The interrupt vector for INT 71h is located at:

```
0000:01C4
```

Typical vector contents:

```
31 09 70 00 → 0070:0931
```

---

## INT 71h Execution Flow

### Step 1: Hardware Timer Event

A hardware timer source (likely driven by the interrupt controller) generates a periodic interrupt mapped to **INT 71h**.

---

### Step 2: BIOS Stub (0070:0931)

The interrupt first enters a BIOS wrapper routine:

```asm
PUSHF
CALL F000:2902
INT 08
IRET
```

This stub performs two key actions:

1. Calls the native QX-16 timer handler
2. Invokes INT 08h for IBM compatibility

---

### Step 3: Main Timer Handler (F000:2902)

This is the actual timer ISR. Its responsibilities include:

* Enabling interrupts (`STI`)
* Setting DS to BIOS Data Area (0040h)
* Updating system tick counters:

  * `0040:006C` (low word)
  * `0040:006E` (high word)
* Handling rollover and time-of-day flags
* Calling INT 1Ch (user timer hook)

Example behavior:

* Increment tick count
* On overflow, increment high word
* When a threshold is reached, set a flag at `0040:0070`

---

### Step 4: INT 1Ch (User Timer Hook)

The BIOS calls:

```
INT 1Ch
```

This is the standard DOS-compatible hook for applications and TSRs.

---

### Step 5: IBM Compatibility (INT 08h)

After the native handler, the BIOS stub invokes:

```
INT 08h
```

This provides compatibility for software expecting IBM PC timer behavior.

---

### Step 6: End of Interrupt (EOI)

The timer ISR signals completion via:

```asm
MOV AL,20h
OUT 08h,AL
```

Note:

* This differs from IBM PC, which uses `OUT 20h,20h`

---

## Complete Flow

```
Hardware Timer
   ↓
INT 71h
   ↓
BIOS Stub (0070:0931)
   ↓
F000:2902 (Main ISR)
   ↓
INT 1Ch (user hook)
   ↓
INT 08h (IBM compatibility)
   ↓
EOI → OUT 08h,20h
```

---

## Key Differences from IBM PC

| Feature                    | IBM PC       | QX-16               |
| -------------------------- | ------------ | ------------------- |
| Primary timer interrupt    | INT 08h      | INT 71h             |
| Interrupt controller ports | 0x20 / 0xA0  | 0x08 / 0x0C         |
| EOI command port           | 0x20         | 0x08                |
| INT 08h role               | Native timer | Compatibility layer |

---

## Practical Implications

### For Software Development

* **INT 71h is the true hardware timer interrupt**
* INT 08h should be treated as a compatibility layer
* INT 1Ch is the safest hook for application-level timing

### For Emulation (MAME)

Accurate emulation requires:

* Correct delivery of INT 71h
* Proper BIOS tick updates
* EOI via port `0x08`
* Separation between native timer (INT 71h) and compatibility path (INT 08h)

### For DOS Compatibility

Epson MS-DOS bridges INT 71h to INT 08h to support:

* TSRs
* Games
* Software expecting IBM timer behavior

---

## Summary

The QX-16 uses a **native timer interrupt at INT 71h**, with BIOS providing a compatibility bridge to INT 08h. This design allows the system to maintain Epson-specific hardware behavior while supporting IBM PC-compatible software.

Understanding this distinction is critical when:

* Porting software between QX-16 and other systems
* Developing low-level applications
* Emulating the hardware accurately

---

## Notes

* INT 71h is the authoritative timing source
* INT 08h is optional and may be patched by DOS
* EOI must always be sent to port `0x08`

---

**Author:** QX-16 Reverse Engineering Notes
