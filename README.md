
# Epson QX-16 Research Archive

This repository documents the technical details, discoveries, ROM dumps, schematics, and experimental work related to the **Epson QX-16** computer.

The QX-16 is a CPM/MS-DOS-compatible system produced by Epson in the early 1980s, featuring a unique architecture, proprietary video and floppy systems.

---

## 🧠 Purpose of This Project

This archive aims to:

- Preserve knowledge about the QX-16, its hardware, and firmware
- Reverse-engineer undocumented components like the **GAFDDC** floppy gate array
- Share ROM dumps and tools for analysis or emulation
- Provide schematics and documentation for modern upgrades and repairs
- Assist other retrocomputing enthusiasts in understanding and working with this rare system

---

## 🛠️ Current Highlights

### ✅ ROM Dumps
- `system_rom_high.bin` and `system_rom_low.bin` – Original QX-11 MS-DOS 2.11 ROM

### ✅ Repairs
 - [**Keyboard power issues**](/troubleshooting/qx16_keyboard_power_repair_with_svg.md) 

### ✅ Reverse Engineering
- GAFDDC to uPD765 FDC signal mapping
- DRAM bank emulation and memory upgrades

### ✅ Experiments
- **RAM Expansion** up to 1MB using Raspberry Pi Pico
- [**PSU Replacement**](/Reverse%20Engineering/psu_replacement.md) using modern switching supplies
- **Custom VGA Output** interfaced via GPIO (Pico-based)

### ✅ Documentation
- [**QX16 Technical Documentation**](documentation/Epson%20QX-16%20Technical%20Manual.pdf)

---

## 📷 Gallery

See `/photos/` for high-res images of:
- QX-16 motherboard (front and back)
- GAFDDC chip and FDC region
- Power supply area with TL494s
- Expansion slots and video port

---

## 📚 Related Systems

This work relates to:
- Epson QC/X-10 and QC/X-11
- NEC µPD765 floppy controllers
---

## 📄 License

- 🧩 All **code** (scripts, tools, KiCad files) is licensed under the [MIT License](LICENSE).
- 📸 All **images**, **ROM dumps**, **text documentation**, and **diagrams** are licensed under the [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) license.

Please credit this repository when reusing content.

---

## 🙌 Contributions

Pull requests are welcome for:
- Additional photos or ROMs
- Hardware mods and writeups
- Documentation or translations

---

## 💾 Disclaimer

ROM dumps and photos are shared for **educational and preservation purposes only**. The copyright of any original software belongs to its respective owners.

---

## 🔗 External Links

- [Retrocomputing Wiki](https://wiki.retrocomputing.net/)
- [Datasheet: uPD765AC](https://archive.org/details/nec-upd765-datasheet)
- [GAFDDC Analysis (WIP)](LINK_TO_YOUR_WRITEUP_HERE)
