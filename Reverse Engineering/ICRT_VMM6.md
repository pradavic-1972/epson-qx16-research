# Epson QX-16 APX-ICRT VM6 640×400 Graphics Mode

## Overview

This document describes the reverse engineering, validation, and practical use of the Epson QX-16 APX-ICRT **VM6** graphics mode.

The QX-16 BIOS exposes IBM-compatible video modes, including BIOS mode 6 (`INT 10h`, `AH=00h`, `AL=06h`), which is conventionally treated as a 640×200 monochrome CGA mode. The APX-ICRT hardware, however, supports a separate 32 KB graphics-memory organization called **VM6** that allows all 400 physical scanlines of the QX-16 display to be addressed independently.

By combining the BIOS graphics timing with the APX-ICRT VM6 control setting, we obtained a working:

```text
640 × 400
1 bit per pixel
32 KB framebuffer
```

We then created a custom Sierra SCI0 video driver that converts the SCI 320×200 framebuffer into a dithered 640×400 monochrome image on the QX-16.

This work was verified on real QX-16 hardware.

---

## 1. Hardware Background

The QX-16 APX-ICRT video subsystem includes:

- a 46505-compatible CRT controller;
- 32 KB of graphics VRAM;
- IBM-compatible video I/O ports;
- Epson-specific graphics control and memory-mapping registers.

The important ports are:

| Port | Function |
|---|---|
| `03D4h` | CRTC register index, color-compatible interface |
| `03D5h` | CRTC register data |
| `03D8h` | mode control |
| `03D9h` | color/palette control |
| `03CEh` | APX-ICRT video-memory mode control |
| `03CFh` | APX-ICRT CPU VRAM mapping control |

The QX-16 also supports the monochrome-compatible CRTC ports at `03B4h` and `03B5h`, but the BIOS modes used during this work were configured through the color-compatible ports.

---

## 2. What the Technical Manual Says About VM6

The QX-16 technical manual describes several APX-ICRT VRAM modes.

VM6 uses:

```text
VRAM range: 0000h–7FFFh
VRAM size:  32 KB
R6:         64h
R9:         03h
Display:    400 lines without line repetition
```

The 32 KB address space is divided into **four 8 KB blocks**.

The display fetches successive scanlines from successive blocks:

```text
Block 0: 0000h–1FFFh
Block 1: 2000h–3FFFh
Block 2: 4000h–5FFFh
Block 3: 6000h–7FFFh
```

The resulting scanline distribution is:

```text
0000h block: Y = 0, 4, 8, 12, ...
2000h block: Y = 1, 5, 9, 13, ...
4000h block: Y = 2, 6, 10, 14, ...
6000h block: Y = 3, 7, 11, 15, ...
```

This organization is very similar to Hercules graphics memory.

The critical APX-ICRT mode value is:

```text
03CEh = C0h
```

Binary:

```text
1100 0000b
```

The upper three bits select VM6.

---

## 3. BIOS Analysis

### 3.1 MODE.COM does not program the video hardware directly

The QX-16 `MODE.COM` program was disassembled and inspected.

For commands such as:

```text
MODE 80
MODE 40
MODE BW80
MODE CO80
MODE MONO
```

the program ultimately delegates video setup to the BIOS through:

```asm
mov ah,00h
int 10h
```

It may first:

- query the current mode with `INT 10h, AH=0Fh`;
- update the BIOS equipment word;
- probe `B000h` or `B800h`;
- choose an IBM-compatible BIOS mode number.

It does not directly write the APX-ICRT CRTC or VM6 registers.

Therefore, the actual hardware programming is performed inside the BIOS `INT 10h`, `AH=00h` handler.

---

### 3.2 BIOS `INT 10h`, `AH=00h`

The BIOS mode-setting routine:

1. validates modes `0` through `7`;
2. disables the display;
3. selects one of four 16-byte CRTC tables;
4. writes CRTC registers `R0` through `R15`;
5. clears video memory;
6. writes an APX-ICRT mode value to `03CEh`;
7. writes the final mode-control value to `03D8h`;
8. writes the palette/control value to `03D9h`;
9. updates BIOS video state variables.

The BIOS groups the modes as follows:

```text
Modes 0–1  -> CRTC table 0
Modes 2–3  -> CRTC table 1
Modes 4–6  -> CRTC table 2
Mode 7     -> CRTC table 3
```

---

### 3.3 BIOS CRTC tables

The four tables are stored immediately before the `INT 10h`, `AH=00h` routine.

#### Modes 0–1: 40-column text

```text
34 28 2A A2 19 00 19 19
02 0F 0D 0E 00 00 00 00
```

Decoded:

| Register | Value |
|---|---:|
| R0 | `34h` |
| R1 | `28h` |
| R2 | `2Ah` |
| R3 | `A2h` |
| R4 | `19h` |
| R5 | `00h` |
| R6 | `19h` |
| R7 | `19h` |
| R8 | `02h` |
| R9 | `0Fh` |
| R10 | `0Dh` |
| R11 | `0Eh` |
| R12–R15 | `00h` |

This produces:

```text
40 columns × 8 pixels  = 320 horizontal pixels
25 rows × 16 rasters   = 400 physical scanlines
```

---

#### Modes 2–3: 80-column text

```text
69 50 54 A4 19 00 19 19
02 0F 0D 0E 00 00 00 00
```

This produces:

```text
80 columns × 8 pixels  = 640 horizontal pixels
25 rows × 16 rasters   = 400 physical scanlines
```

This confirms that the normal QX-16 80-column text display is physically 640×400.

---

#### Modes 4–6: graphics timing

```text
34 28 2A A2 67 00 64 64
02 03 0D 0E 00 00 00 00
```

Important values:

```text
R1 = 28h
R6 = 64h
R9 = 03h
```

The graphics timing is organized as:

```text
40 horizontal graphics units
100 vertical groups
4 raster positions per group
```

Therefore:

```text
100 × 4 = 400 physical scanlines
```

BIOS mode 6 is logically an IBM-compatible 640×200 mode, but the physical CRTC timing is already a 400-line timing. The APX-ICRT memory-mode setting determines whether the 400 physical scanlines are line-repeated or independently addressable.

---

#### Mode 7

```text
69 50 54 A4 19 00 19 19
02 0F 0D 0E 00 00 00 00
```

This is the same CRTC timing as modes 2–3, but it uses the monochrome-compatible register interface.

---

## 4. Enabling VM6

The simplest verified initialization sequence is:

```asm
mov ax,0006h
int 10h

mov dx,03CEh
mov al,0C0h
out dx,al

mov dx,03CFh
mov al,0E0h
out dx,al
```

The BIOS call establishes the correct QX-16 graphics CRTC timing.

The `03CEh` write changes the APX-ICRT from the normal BIOS mode-6 VRAM interpretation to VM6.

### `03CEh = C0h`

```text
Selects VM6
32 KB VRAM
four interleaved 8 KB blocks
400 independently addressable scanlines
```

### `03CFh = E0h`

This exposes the same 32 KB physical VRAM through both:

```text
B000:0000–7FFF
B800:0000–7FFF
```

The two CPU windows are aliases of the same physical memory.

For software written specifically for the QX-16, mapping only one aperture may be cleaner. During development, `E0h` was convenient because it allowed code using either `B000h` or `B800h` to access the same framebuffer.

---

## 5. VM6 Framebuffer Organization

VM6 is a one-bit-per-pixel framebuffer.

Resolution:

```text
640 × 400
```

Bytes per row:

```text
640 / 8 = 80 bytes = 50h
```

Total visible data:

```text
80 × 400 = 32000 bytes
```

The remaining bytes in the 32 KB aperture are unused by the visible 640×400 image.

---

### 5.1 Pixel address formula

For:

```text
X = 0..639
Y = 0..399
```

the byte offset is:

```text
offset =
    (Y & 3) * 2000h
  + (Y >> 2) * 50h
  + (X >> 3)
```

The pixel mask is:

```text
mask = 80h >> (X & 7)
```

Bit 7 is the leftmost pixel in each byte.

Equivalent C-like form:

```c
uint16_t vm6_offset(unsigned x, unsigned y)
{
    return ((y & 3) << 13)
         + ((y >> 2) * 80)
         + (x >> 3);
}
```

---

### 5.2 First scanlines

```text
Y=0 -> 0000h
Y=1 -> 2000h
Y=2 -> 4000h
Y=3 -> 6000h
Y=4 -> 0050h
Y=5 -> 2050h
Y=6 -> 4050h
Y=7 -> 6050h
```

This pattern repeats every four scanlines.

---

## 6. Comparison With Hercules

The VM6 organization is structurally equivalent to Hercules interleaving.

### Hercules

```text
720 × 348
90 bytes per row = 5Ah
```

Address formula:

```text
offset =
    (Y & 3) * 2000h
  + (Y >> 2) * 5Ah
  + (X >> 3)
```

### QX-16 VM6

```text
640 × 400
80 bytes per row = 50h
```

Address formula:

```text
offset =
    (Y & 3) * 2000h
  + (Y >> 2) * 50h
  + (X >> 3)
```

The differences are:

| Feature | Hercules | QX-16 VM6 |
|---|---:|---:|
| Resolution | 720×348 | 640×400 |
| Bytes per row | `5Ah` | `50h` |
| Banks | four 8 KB | four 8 KB |
| Base segment | normally `B000h` | `B000h`, `B800h`, or aliases |
| Pixel packing | 1 bpp, MSB first | 1 bpp, MSB first |

This similarity made Hercules and CGA monochrome drivers useful references, but the QX-16 still requires its own initialization and exact 640×400 row handling.

---

## 7. Mapping Test Program

A small NASM `.COM` program was used to validate VM6.

Build:

```bash
nasm -f bin QX16VM6_NASM.ASM -o QX16VM6.COM
```

The test:

1. calls BIOS mode 6;
2. writes `C0h` to `03CEh`;
3. writes `E0h` to `03CFh`;
4. clears all 32 KB;
5. draws a diagonal using the VM6 formula;
6. waits for a key;
7. restores BIOS mode 3.

The initial diagonal used:

```text
X = Y
Y = 0..399
```

Therefore, it ran from approximately:

```text
(0,0) to (399,399)
```

It did not reach the right edge because the display is wider than it is tall.

This was not a framebuffer limitation. It was simply the geometry of the test.

---

### 7.1 Why this test was important

With the correct VM6 mapping, a single continuous diagonal appeared across the screen.

With the wrong mode value, the image appeared as multiple separated or compressed dot patterns.

The continuous diagonal confirmed:

- all four 8 KB banks were visible;
- the bank interleave was correct;
- the row stride was `50h`;
- lines through `Y=399` were accessible;
- the display was behaving as a 400-line framebuffer.

---

### 7.2 Additional verification patterns

Useful diagnostic patterns include:

#### Alternating scanlines

```text
even Y -> FFh across 80 bytes
odd Y  -> 00h across 80 bytes
```

A true 400-line mode displays one-pixel-high alternating horizontal lines.

#### Four distinct top rows

```text
Y=0 -> FFh pattern
Y=1 -> AAh pattern
Y=2 -> CCh pattern
Y=3 -> F0h pattern
```

These rows live in four different 8 KB blocks and should appear as four independent adjacent scanlines.

#### Bottom-row test

Write distinct patterns to:

```text
Y=396
Y=397
Y=398
Y=399
```

This verifies that the bottom of the 400-line framebuffer is reachable.

---

## 8. Why a Modified CGA Driver Showed Missing Scanlines

A standard CGA 640×200 monochrome driver normally uses two-bank interleaving:

```text
0000h -> one set of rows
2000h -> the alternating set
```

When that driver is placed into VM6 without changing its renderer, it continues writing only the first two VM6 banks.

VM6 expects four banks:

```text
0000h
2000h
4000h
6000h
```

As a result, the image appears to skip scanlines because two of the four physical scanline banks are not being filled.

A true VM6 driver must either:

- generate 400 independent rows; or
- duplicate each 200-line source row into two physical VM6 rows.

---

## 9. Sierra SCI0 Driver

### 9.1 Source framebuffer

The Sierra SCI0 framebuffer is:

```text
320 × 200
4 bits per pixel
two pixels per byte
160 bytes per row
```

The custom driver converts this into:

```text
640 × 400
1 bit per pixel
```

Each SCI source pixel becomes a 2×2 monochrome cell.

---

### 9.2 Exact 2×2 scaling

For each SCI source row:

```text
source Y -> destination rows 2Y and 2Y+1
```

For each SCI source pixel:

```text
source X -> destination pixels 2X and 2X+1
```

This provides an exact integer scale:

```text
320 × 2 = 640
200 × 2 = 400
```

There is no fractional vertical scaling.

This is cleaner than a Hercules SCI renderer, where 200 source rows must be distributed across 348 physical rows.

---

### 9.3 Monochrome dithering

The driver preserves the QX-11 driver's table-driven 2×2 ordered dithering.

Each packed SCI byte contains two source pixels.

Two packed SCI bytes contain four source pixels and become one 8-pixel VM6 destination byte.

The driver uses separate lookup tables for the two physical output rows:

```text
mono_top_hi
mono_top_lo
mono_bottom_hi
mono_bottom_lo
```

This allows the top and bottom halves of each 2×2 cell to use different patterns.

The result preserves more visual information than a simple threshold-to-black-or-white conversion.

---

### 9.4 Destination addressing for the SCI driver

For source row `Y`:

```text
physical row 0 = 2Y
physical row 1 = 2Y+1
```

The first row address can be simplified to:

```text
first_offset =
    (Y & 1) * 4000h
  + (Y >> 1) * 50h
  + X_byte
```

The second physical row is:

```text
second_offset = first_offset + 2000h
```

Examples:

```text
SCI Y=0 -> VM6 rows 0 and 1
           0000h and 2000h

SCI Y=1 -> VM6 rows 2 and 3
           4000h and 6000h

SCI Y=2 -> VM6 rows 4 and 5
           0050h and 2050h

SCI Y=3 -> VM6 rows 6 and 7
           4050h and 6050h
```

---

## 10. Changes From the QX-11 SCI Driver

The QX-11 universal SCI driver was used as the architectural base.

The following subsystems were retained:

- SCI dispatch table;
- framebuffer interface;
- dirty-rectangle updates;
- 320×200 source clipping;
- lookup-table conversion;
- 2×2 monochrome dithering;
- software cursor;
- cursor background save and restore;
- cursor overlap detection;
- cursor redraw after dirty updates;
- scroll delegation;
- previous-mode restoration.

The following QX-11-specific parts were replaced:

- QX-11 monitor detection;
- QX-11 color-plane selection;
- QX-11 planar VRAM writes;
- QX-11 split 640×400 monochrome banks;
- QX-11 GAVDP display-origin screen shake;
- QX-11 row formulas.

The QX-16 version uses:

```text
B000h framebuffer segment
VM6 four-bank row interleave
80-byte visible row width
32 KB contiguous CPU aperture
```

---

## 11. QX-16 Driver Initialization

The QX-16 SCI driver initialization performs:

```asm
mov ah,0Fh
int 10h
push ax

mov ax,0006h
int 10h

mov dx,03CEh
mov al,0C0h
out dx,al

mov dx,03CFh
mov al,0E0h
out dx,al
```

It then clears the VM6 framebuffer and begins rendering.

On shutdown, the saved BIOS mode is restored with:

```asm
xor ah,ah
int 10h
```

---

## 12. Clearing the Framebuffer

Unlike the QX-11 planar framebuffer, QX-16 VM6 can be cleared as one contiguous 32 KB aperture:

```asm
mov ax,0B000h
mov es,ax
xor di,di
xor ax,ax
mov cx,4000h
rep stosw
```

This clears:

```text
4000h words = 8000h bytes = 32 KB
```

---

## 13. Cursor Handling

The SCI software cursor is 16×16 in SCI coordinates.

After 2× scaling, it covers:

```text
32 × 32 physical VM6 pixels
```

The adapted driver:

- saves both physical rows for each SCI cursor row;
- restores both rows;
- applies the SCI AND/XOR cursor operation to both physical rows;
- uses the VM6 pair-address helper;
- redraws the cursor after overlapping dirty-rectangle updates.

Because VM6 is row-centric and 1 bpp, cursor handling is simpler than the QX-11 three-plane color path.

---

## 14. Dirty Rectangle Rendering

The driver does not need to redraw the full screen on every SCI update.

For each dirty rectangle:

1. the rectangle is aligned to groups of four SCI pixels;
2. source bytes are read from the SCI framebuffer;
3. lookup tables create the top and bottom monochrome rows;
4. each generated row is copied into the correct VM6 bank;
5. only the affected area is updated;
6. the software cursor is restored and redrawn when required.

Four SCI pixels become one VM6 byte:

```text
4 source pixels × 2 horizontal output pixels = 8 output pixels
```

Therefore:

```text
320 source pixels / 4 = 80 destination bytes
```

This exactly matches the 640-pixel VM6 row width.

---

## 15. Screen Shake

The QX-11 driver used GAVDP display-origin registers to implement screen shake.

Those registers are specific to the QX-11 and are not used by the QX-16 APX-ICRT driver.

The initial QX-16 driver disables the shake callback.

A future implementation could experiment with CRTC start-address manipulation, but that has not yet been validated and should not be treated as part of the confirmed VM6 implementation.

---

## 16. Build Instructions

### VM6 test program

```bash
nasm -f bin QX16VM6_NASM.ASM -o QX16VM6.COM
```

### SCI driver

```bash
nasm -f bin QX16VID.asm -o QX16VID.DRV
```

Use the resulting driver in place of the original Sierra SCI0 video driver.

The exact driver filename expected by a game may vary.

---

## 17. Confirmed Results

The following were confirmed on real QX-16 hardware:

- BIOS mode 6 establishes a stable 400-line graphics timing;
- `03CEh=C0h` activates VM6;
- `03CFh=E0h` exposes the VM6 framebuffer through `B000h` and `B800h`;
- the framebuffer is 32 KB;
- scanlines are interleaved across four 8 KB blocks;
- the visible stride is 80 bytes;
- the VM6 pixel formula is correct;
- a 400-line diagonal renders correctly;
- the custom SCI driver runs;
- Sierra SCI graphics render at 640×400 monochrome;
- dirty-rectangle updates work;
- software cursor support works.

---

## 18. Important Distinction: Physical Resolution vs. Source Resolution

The QX-16 output is physically 640×400.

The original SCI framebuffer is only 320×200.

Therefore, the driver scales the source image by exactly 2×2.

This means:

- all 400 physical scanlines are used;
- there are no missing VM6 banks;
- the display timing and framebuffer are genuinely 640×400;
- the game artwork still originates from a 320×200 logical image.

The 2×2 dithering can improve tonal representation, but it cannot create new source-image detail that was not present in SCI's original 320×200 framebuffer.

---

## 19. Minimal VM6 Setup Reference

```asm
; Establish QX-16 graphics timing.
mov ax,0006h
int 10h

; Select VM6.
mov dx,03CEh
mov al,0C0h
out dx,al

; Expose the 32 KB framebuffer through B000 and B800.
mov dx,03CFh
mov al,0E0h
out dx,al
```

Pixel address:

```text
offset =
    (Y & 3) * 2000h
  + (Y >> 2) * 50h
  + (X >> 3)

mask = 80h >> (X & 7)
```

---

## 20. Project Significance

This work demonstrates that the Epson QX-16 APX-ICRT supports a practical native 640×400 monochrome bitmap mode that is not directly exposed as a normal IBM-compatible BIOS graphics mode.

The project combined:

- technical-manual analysis;
- BIOS disassembly;
- CRTC-table extraction;
- APX-ICRT register analysis;
- real-hardware testing;
- framebuffer mapping experiments;
- SCI driver development.

The result is both a documented VM6 programming model and a functional Sierra SCI0 driver for the QX-16.

---

## Files

Suggested repository layout:

```text
QX16-VM6/
├── README.md
├── QX16VM6_NASM.ASM
├── QX16VM6.COM
├── QX16VID.asm
├── QX16VID.DRV
├── QX11VID.asm
├── BIOS_INT10_NOTES.md
└── screenshots/
```

Recommended screenshots:

- VM6 diagonal test;
- alternating scanline test;
- Sierra title screen;
- in-game SCI scene;
- close-up comparison with the original QX-11 driver.

---

## Credits

Reverse engineering and real-hardware validation performed as part of the Epson QX-11/QX-16 research project.

The QX-16 SCI driver was adapted from the previously developed universal QX-11 SCI0 driver and rewritten for the APX-ICRT VM6 framebuffer.
