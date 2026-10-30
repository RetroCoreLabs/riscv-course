# Sstc — a timer the supervisor sets itself

Source: The RISC-V Instruction Set Manual, Volume II (CC BY 4.0), chapter "Sstc", and the
`menvcfg` and `mcounteren` registers in the machine-level chapter.

## What it adds

One CSR, `stimecmp` (`0x14D`), that supervisor mode writes to set its own timer. While
`time` is at or past `stimecmp`, the supervisor timer interrupt (`STIP` in `mip`) is pending.
Writing a later value to `stimecmp` clears it again. The compare is unsigned. On RV32 the
high half is a separate CSR, `stimecmph` (`0x15D`).

Machine mode turns it on with `menvcfg.STCE` (bit 63; on RV32 bit 31 of `menvcfgh`). While
`STCE` is set, `STIP` follows the compare and is read-only to software. Supervisor mode may
reach `stimecmp` only when `STCE` is set and `mcounteren.TM` (bit 1) is set; otherwise the
access is an illegal instruction.

## Why it exists

Without Sstc, a supervisor kernel cannot set a timer itself. It asks machine mode, through
an SBI call to the firmware, and machine mode programs the CLINT's `mtimecmp` and passes the
interrupt down. That is a trap into machine mode for every timer tick. With Sstc the kernel
writes one CSR.

## What it is used for

Kernels that program their own timer tick. The upstream xv6-riscv kernel writes
`stimecmp` directly and does not run without it.

## Key instructions

Sstc adds no instructions; it is used through the Zicsr CSR instructions.

| Instruction | Example | Result |
|---|---|---|
| `csrw stimecmp, rs` | `csrw stimecmp, t0` | timer interrupt pending once `time` reaches t0 |
| `csrr rd, stimecmp` | `csrr t1, stimecmp` | t1 = the compare value |
| `csrs menvcfg, rs` (M-mode) | `csrs menvcfg, t2` with bit 63 set | Sstc on |

To set the next tick, a kernel reads `time`, adds the interval and writes the sum to
`stimecmp`. That write also clears the pending interrupt.

## Who needs it

See the `Sstc (S-mode timer)` row in [`../support-matrix.md`](../support-matrix.md).

## In RetroCore

Flag `IsaExtensions.Sstc`. It needs `IsaExtensions.S`: a hart built with Sstc and without S
is refused. `stimecmp` resets to 0. `riscv64-xv6` is the machine that turns it on, and the
device tree lists `sstc` in the hart's extensions. The machine wakes the hart when `time`
reaches `stimecmp`, so an idle hart in `wfi` skips straight to that deadline. Tests:
`CpuRiscVSstcTests`.
