# D — double-precision floating point

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "D Extension for
Double-Precision Floating-Point".

## What it adds

The D extension depends on F. It widens `f0` to `f31` to 64 bits and adds the same
instructions as F for IEEE 754-2008 binary64: `fadd.d` to `fnmadd.d`, compares, classify,
sign injection, conversions to and from integers, and `fld` / `fsd` (with C: `c.fld`,
`c.fsd`, `c.fldsp`, `c.fsdsp`, on RV32 and RV64). It also adds the two conversions between
the widths: `fcvt.s.d` rounds a double to a single, `fcvt.d.s` widens a single exactly. On
RV64, `fmv.x.d` and `fmv.d.x` move the raw 64 bits to and from an integer register.

The canonical NaN of a double is `0x7FF8000000000000`.

## NaN-boxing

With D the f registers are 64 bits wide but F's instructions still work on 32-bit values. A
single is kept in the low 32 bits with the upper 32 bits all ones, which makes the 64-bit
pattern a NaN. An F instruction that reads a register whose upper half is not all ones reads
the canonical single NaN instead; the sign-injection instructions do too. `fsw` and
`fmv.x.w` are the exceptions: they copy the low 32 bits as they are.

## Why it exists

`double` is C's default floating type, and most numerical code needs its 53-bit precision.

## What it is used for

The `lp64d` ABI that Debian, Fedora and Ubuntu riscv64 are built for, which passes `double`
arguments in f registers.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `fadd.d` | `fadd.d fa0, fa1, fa2` | fa0 = fa1 + fa2 |
| `fcvt.s.d` | `fcvt.s.d fa0, fa1` | fa0 = fa1 rounded to single, NaN-boxed |
| `fcvt.d.w` | `fcvt.d.w fa0, a0` | fa0 = a0 as a double, always exact |
| `fld` | `fld fa0, 8(sp)` | fa0 = the 8 bytes at sp + 8 |

## Who needs it

See the `F / D (float)` row in [`../support-matrix.md`](../support-matrix.md).

## In RetroCore

Flag `IsaExtensions.D`. Asking for D without F throws when the CPU is built. The arithmetic
is `Common.SoftFloat`, as for [F](F.md). Tested with the official `rv32ud` and `rv64ud` tests,
bare and paged.
