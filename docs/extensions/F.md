# F — single-precision floating point

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "F Extension for
Single-Precision Floating-Point"; Volume II, "Extension Context Status in mstatus Register".

## What it adds

- **32 floating-point registers** `f0` to `f31`, separate from the integer registers.
- **`fcsr`**, the floating-point control and status register: the rounding mode `frm`
  (bits 7:5) and the accrued exception flags `fflags` (bits 4:0: NV invalid, DZ divide by
  zero, OF overflow, UF underflow, NX inexact). Both can also be reached as CSRs of their own.
- **IEEE 754-2008 binary32 arithmetic**: add, subtract, multiply, divide, square root,
  minimum and maximum, and the four fused multiply-add forms (`fmadd`, `fmsub`, `fnmsub`,
  `fnmadd`) that round only once.
- **Compares** into an integer register (`feq` quiet, `flt` and `fle` signaling),
  **classify** (`fclass`, a one-hot mask of ten classes), **conversions** to and from 32-bit
  integers (and 64-bit ones on RV64), **sign injection** (`fsgnj`, `fsgnjn`, `fsgnjx`, which
  is how `fmv.s`, `fneg.s` and `fabs.s` are spelled) and **moves** of raw bits (`fmv.x.w`,
  `fmv.w.x`).
- **Loads and stores** `flw` and `fsw`, and on RV32 with C the compressed `c.flw`, `c.fsw`,
  `c.flwsp` and `c.fswsp`.

Every rounding instruction has a 3-bit `rm` field: 0 to 4 name a mode (to nearest ties to
even, toward zero, down, up, to nearest ties away from zero), 7 means "use `frm`", and 5 and
6 are reserved. A reserved `rm`, or 7 while `frm` holds 5 to 7, makes the instruction illegal,
even for an instruction whose result is always exact.

A NaN result is always the **canonical NaN**, `0x7FC00000`; the payload of an input NaN is
not passed on.

## Why it exists

Software floating point costs tens of integer instructions per operation. Code that does
graphics, audio, physics or numerics wants the hardware to do it in one.

## What it is used for

C's `float` under the `ilp32f`/`lp64f` and `lp64d` ABIs, the `rv64gc` distribution kernels'
user space, and anything that links a maths library built for hardware float.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `fadd.s` | `fadd.s fa0, fa1, fa2` | fa0 = fa1 + fa2, rounded by `frm` |
| `fmadd.s` | `fmadd.s fa0, fa1, fa2, fa3` | fa0 = fa1 × fa2 + fa3, rounded once |
| `fcvt.w.s` | `fcvt.w.s a0, fa0, rtz` | a0 = fa0 rounded toward zero to a 32-bit integer |
| `flt.s` | `flt.s a0, fa0, fa1` | a0 = 1 if fa0 < fa1, else 0 |
| `fmv.x.w` | `fmv.x.w a0, fa0` | a0 = the raw bits of fa0, sign-extended |

## mstatus.FS

Two bits in mstatus (14:13) say what the floating-point state holds: Off, Initial, Clean or
Dirty. While FS is Off every F instruction, and every access to `fflags`, `frm` and `fcsr`,
is illegal: an operating system leaves it Off for a process that has not used float yet, and
turns it on at the first trap. Any change to an f register or to `fcsr` sets FS to Dirty, so
the operating system knows which processes' f registers to save at a task switch. SD, the top
bit of mstatus, reads 1 whenever FS is Dirty.

## Who needs it

See the `F / D (float)` row in [`../support-matrix.md`](../support-matrix.md). Stock
distribution kernels and user spaces (`rv64gc`, `lp64d`) need F and D; our own Linux build
and xv6 are soft-float and do not.

## In RetroCore

Flag `IsaExtensions.F`. The arithmetic is `Common.SoftFloat`, a translation of Berkeley
SoftFloat-3e with the RISC-V specialization, on raw bit patterns: no host `float` or
`double` is used, so every result and every flag is the IEEE one, whatever machine RetroCore
runs on. `Common.SoftFloat` is checked against 67 million Berkeley TestFloat vectors.

The CPU is tested with the official `rv32uf` and `rv64uf` tests, both the bare (`-p-`) and
the paged (`-v-`) builds, and by `CpuRiscVFloatTests` for the reserved rounding modes,
mstatus.FS, NaN-boxing on input and FMIN/FMAX on zeros and NaNs.
