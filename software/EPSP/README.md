# QX-16 EPSP Read-Only Block Driver (Beta)

This is a beta read-only DOS block device driver for the Epson QX-16.

It allows DOS on the QX-16 to access a disk image mounted through the EPSP/vfloppy server over the QX-16 serial port.

## Current status

Confirmed working on real QX-16 hardware:

- DOS installs an EPSP-backed block device.
- The mounted image appears as the next available DOS drive letter, usually `C:`.
- `DIR` works.
- Files can be read from the mounted image.
- Programs can be executed directly from the EPSP drive.
- The driver is currently **read-only**.
- Writes are intentionally rejected.

The working serial configuration is approximately **62,400 baud**.

## Files

Compile the driver source with NASM:

```bash
nasm -f bin QX16_EPSP_READONLY_BLOCK_DRIVER_V1_FIX4_QX11_NOTREADY.asm -o QXEPSP.SYS
```

Copy `QXEPSP.SYS` to the QX-16 boot disk.

## CONFIG.SYS

Add:

```text
DEVICE=QXEPSP.SYS
```

DOS will assign the next available drive letter to the EPSP block device.

On a normal QX-16 system with drives `A:` and `B:`, the EPSP drive will normally appear as:

```text
C:
```

## Starting vfloppy / epspd

Before accessing the EPSP drive, start the vfloppy/`epspd` server on the host computer and mount the disk image you want to use.

Configure the host serial port for:

```text
62400 baud
8 data bits
no parity
1 stop bit
```

Use the same serial adapter/port that is connected to the QX-16.

The QX-16 driver uses the native QX-16 serial hardware:

- uPD7201 data port `11h`
- uPD7201 command/status port `13h`
- 8253 channel 2 at port `06h`
- 8253 control port `07h`

## Important: do not change the serial speed after the driver loads

Do not run another startup utility that reprograms the QX-16 serial port after `QXEPSP.SYS` has initialized it.

During testing, an `AUTOEXEC` utility that changed the serial speed caused EPSP traffic to turn into invalid bytes and made the drive unusable.

If you have a serial configuration program in `AUTOEXEC.BAT`, remove it or make sure it does not alter the port used by QXEPSP.

## Using the drive

After DOS boots:

```text
C:
DIR
```

You should see the directory of the mounted image.

You can read files normally:

```text
TYPE C:\CONFIG.SYS
```

You can also run programs directly from the EPSP drive:

```text
C:
PROGRAM.COM
```

or:

```text
C:\PROGRAM
```

Programs that only read from the EPSP drive should work normally.

Programs that attempt to create, modify, or delete files on the EPSP drive will fail because this beta driver is read-only.

## What the driver does

For each DOS sector read, the driver translates the DOS logical sector request into the Epson EPSP protocol:

```text
READ 70h
GET_BLOCK 73h block 0
GET_BLOCK 73h block 1
GET_BLOCK 73h block 2
GET_BLOCK 73h block 3
```

Each `GET_BLOCK` returns 128 bytes, giving one complete 512-byte DOS sector.

The QX-16 implementation uses a polled receive path and temporarily disables interrupts during the timing-critical 128-byte serial bursts.

## If the EPSP server is unavailable

The latest beta is intended to behave similarly to the QX-11 external EPSP drive support:

- the DOS block device remains installed,
- if the server is unavailable, DOS should report the drive as not ready,
- when the server becomes available again, a later access/retry can reconnect.

This reconnect/not-ready behavior should still be considered **beta**. For the most reliable current setup, have vfloppy/`epspd` running before accessing the drive.

## Disk format

The current beta was developed and tested with the FAT12 geometry used by the QX disk image we tested:

- 512 bytes per sector
- 2 sectors per cluster
- 1 reserved sector
- 2 FATs
- 112 root directory entries
- 720 total sectors
- media descriptor `FDh`
- 2 sectors per FAT
- 9 sectors per track
- 2 heads

Other image geometries may need additional driver work.

## Background

The work started by modifying vfloppy/`epspd` to support the Epson QX-11 BIOS EPSP implementation and tracing the EPSP protocol used by the original external floppy support.

Once the QX-11 protocol behavior was understood, the same EPSP protocol was implemented directly on the QX-16 using its native uPD7201 serial controller and 8253 clock.

The QX-16 block driver was then developed and debugged with ChatGPT, using real QX-16 hardware tests and server-side EPSP logs to validate each stage.

## Current limitations

- Read-only.
- One EPSP block unit.
- FAT12 geometry currently fixed to the tested image format.
- Serial speed currently fixed to the proven ~62,400 baud configuration.
- Runtime disconnect/reconnect handling is still beta.

