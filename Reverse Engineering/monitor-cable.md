# QX-16 → QX-10 / Q702A Monochrome Monitor  
## Correct Video Cable Wiring (Verified on Real Hardware)

While bringing up an Epson **QX-16** system using an original **Q702A monochrome monitor** (the same monitor shipped with the QX-10), I encountered a non-obvious but critical detail that is **not clearly documented** in available manuals.

This document records the **correct, verified wiring** required to obtain a visible image.

![Q702A using Intendity Pin as Video Signal](/photos/0202.jpg)

---

## Key Finding (Important)

Although the QX-16 provides **RGB + Intensity** video outputs, the **Q702A does NOT use the Green channel as luminance**.

**The correct video signal for the Q702A is the QX-16 *Intensity* output.**

Using the Green output results in:
- Stable horizontal and vertical sync
- A visible raster
- **No characters or graphics**

Using the Intensity output immediately produces a proper image.

This behavior was verified using:
- Oscilloscope measurements at the monitor input
- Direct observation on real hardware
- Multiple wiring permutations

---

## Final, Known-Good Cable Mapping

**QX-16 video DIN → Q702A monitor input**

| QX-16 DIN Pin | Signal (QX-16) | Q702A Pin | Signal (Monitor) |
|---------------|---------------|-----------|------------------|
| **1** | **Intensity** | **1** | **Video input (0–4 V full bright)** |
| **2** | Ground | **7** | Ground |
| **4** | Horizontal Sync | **3** | Horizontal Sync (TTL, positive) |
| **5** | Vertical Sync | **2** | Vertical Sync (TTL, positive) |

All other pins are **not connected**.

---

## Why This Works

- The Q702A expects a **0–4 V video signal**, not raw TTL RGB.
- The **Intensity** output on the QX-16 is already correctly biased and shaped for this input.
- RGB outputs (including Green) toggle correctly but **do not properly drive the Q702A video amplifier**.
- Sync wiring can be completely correct while still producing *no visible image* if the wrong video signal is used.

This explains a common failure mode:
> Stable raster and sync, but no text — only a green field with retrace lines.

---

## Symptoms When Wired Incorrectly

- ✔ Horizontal sync locks
- ✔ Vertical sync locks
- ✔ Full raster visible at high brightness
- ❌ No characters or graphics

Switching the video connection from **Green → Intensity** resolves the issue immediately.

---

## Notes

- Sync polarity for the Q702A is **TTL positive**, compatible with QX-16 outputs.
- No additional resistors or bias networks are required when using the Intensity line.
- Ground reference was verified using both connector ground and internal monitor ground points.

---

## Conclusion

For **QX-16 → QX-10 / Q702A monochrome monitor setups**:

> **Intensity is the luminance signal.**

This is an Epson-specific detail that is easy to miss and not consistently described in documentation, but it is essential for a working display.

Documenting this should help avoid unnecessary debugging when restoring or testing QX-series systems.
