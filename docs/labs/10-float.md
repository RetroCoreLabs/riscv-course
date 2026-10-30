# Lab 10: floating point, `fcsr` flags and rounding modes

Source for the F and D extensions, `fcsr` and the rounding modes: The RISC-V Instruction Set
Manual, Volume I (CC BY 4.0), chapters "F" and "D"; `mstatus.FS` is in Volume II, "Machine-Level
ISA". The number formats are IEEE 754-2008. Nothing is quoted from either; every value below
comes from the lab program.

You will switch the floating-point unit on, do four sums that each go wrong in a different
way, and read the flag each one leaves behind. Then you will round 2.5 to a whole number five
ways.

**This lab runs on `riscv64-xv6`.** Its hart has F (single precision, 32 bits) and D (double
precision, 64 bits); none of the RV32 machines has either. As in chapters 6 and 7, the xv6
kernel is not needed: the lab program is loaded in its place.

The program is
[`float.S`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/10-float/float.S):

```asm
_start:
    li      t0, MSTATUS_FS_INITIAL
    csrs    mstatus, t0             # FPU on: until now every F or D instruction was illegal
    fsrmi   0                       # frm = 0: round to nearest, ties to even
    ...                             # ft0 = 1.0, ft1 = 3.0
third:
    fdiv.s  fa0, ft0, ft1           # 1/3 does not fit in 24 bits: rounded, NX set
    frflags a0                      # a0 = fflags
    fsflags zero                    # clear the flags
by_zero:
    ...                             # fa1 = 1/0, a1 = the flags
invalid:
    ...                             # fa2 = the square root of -1, a2 = the flags
double:
    ...                             # fa3 = 1/3 in double precision, a3 = the flags
ties:
    ...                             # fa4 = 2.5
    fcvt.w.s a4, fa4                # rounding mode from frm (nearest, ties to even): 2
    fcvt.w.s a5, fa4, rup           # round up: 3
    fcvt.w.s a6, fa4, rmm           # nearest, ties away from zero: 3
    fcvt.w.s a7, fa4, rtz           # towards zero: 2
    fcvt.w.s s2, fa4, rdn           # round down: 2
    frcsr   s1                      # s1 = fcsr
```

## 1. Concept

F and D add 32 more registers, `f0` to `f31`. Like the x registers they have ABI names:
`ft0`-`ft11` are temporaries, `fs0`-`fs11` saved, `fa0`-`fa7` arguments and results. On this
hart each is 64 bits wide. A single-precision value uses the low 32 bits, and the high 32 bits
are all ones (this is called NaN-boxing: seen as a double, the register holds a NaN).

The FPU starts **off**. `mstatus.FS` (bits 14:13) says whether the floating-point state is in
use: 0 Off, 1 Initial, 2 Clean, 3 Dirty. While it is Off, every F or D instruction is an
illegal instruction. A kernel uses this to save the f registers only for programs that use
them. The program writes 1, Initial; the first instruction that changes an f register or a
flag makes it 3, Dirty, and the top bit of `mstatus`, SD, then reads 1.

Most floating-point results do not fit exactly, so they are rounded. Nothing traps when that
happens, or when something worse happens. The hart sets a flag in **`fflags`** instead, and the
flags stay set until the program clears them:

| Bit | Flag | Set when |
|---|---|---|
| 4 | NV | invalid: there is no answer, such as the square root of -1; the result is the canonical NaN |
| 3 | DZ | divide by zero: the result is infinity |
| 2 | OF | overflow: too big for the format |
| 1 | UF | underflow: too small to keep its precision |
| 0 | NX | inexact: the result was rounded |

**`frm`** holds the rounding mode, and each F or D instruction that rounds has a 3-bit `rm`
field: a mode of its own, or 7, "use `frm`". The assembler writes 7 when you name no mode.

| `rm` | Name | 2.5 becomes | In the program |
|---|---|---|---|
| 0 | RNE: nearest, ties to even | 2 | `a4`, through `frm` |
| 1 | RTZ: towards zero | 2 | `a7` |
| 2 | RDN: down | 2 | `s2` |
| 3 | RUP: up | 3 | `a5` |
| 4 | RMM: nearest, ties away from zero | 3 | `a6` |

**`fcsr`** is the two together: `frm` in bits 7:5, `fflags` in bits 4:0. `frflags`, `fsflags`,
`frcsr` and `fsrmi` are the usual CSR instructions on these three CSRs.

```text
  1.0 / 3.0 = 0.0101 0101 0101 ... in binary, without end
          |
          |  single precision keeps 24 bits: the rest is cut at bit 24
          v
  0x3EAAAAAA + 0.66 of the last bit  ->  RNE rounds up  ->  0x3EAAAAAB, NX = 1
```

## 2. Run

From the course folder, with either program:

```text
retrocore --machine riscv64-xv6 --script labs/10-float/run.txt
retrocore-cli --machine riscv64-xv6 --script labs/10-float/run.txt
```

The program prints nothing; it switches the machine off when it is done. At the command line, type
`cpu.reg a4`: you see `a4 = 0x2   (64-bit)`, 2.5 rounded to even.

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv64-xv6 --script labs/10-float/run.txt --dap
retrocore-cli --machine riscv64-xv6 --script labs/10-float/run.txt --dap
```

The steps use the debugger commands at the program's command line. A DAP client on the debugger
port sees the same session, with the f registers, `fflags`, `frm` and `fcsr` in their own
Float group. RetroCore has no VS Code extension for RISC-V yet.

1. Stop at the first division:

   ```text
   break.set 0x8000001C
   cpu.continue
   cpu.reg ft0
   cpu.reg ft1
   cpu.reg frm
   cpu.reg fflags
   ```

   You see `ft0 = 0xFFFFFFFF3F800000` (1.0, boxed), `ft1 = 0xFFFFFFFF40400000` (3.0),
   `frm = 0x0` and `fflags = 0x0`: making 1.0 and 3.0 from integers was exact.

2. Run the division:

   ```text
   cpu.step
   cpu.reg fa0
   cpu.reg fflags
   cpu.reg fcsr
   ```

   You see:

   ```text
   fa0 = 0xFFFFFFFF3EAAAAAB   (64-bit)
   fflags = 0x1   (8-bit)
   fcsr = 0x1   (32-bit)
   ```

   `0x3EAAAAAB` is 1/3 rounded to the nearest single-precision number, and NX says it was
   rounded.

   (screenshot: fa0, fflags and fcsr after the division)

3. Stop after each of the next three sums, just after its `frflags`:

   ```text
   break.set 0x80000034
   cpu.continue
   cpu.reg fa1
   cpu.reg fflags
   ```

   | Stop at | Sum | Result | `fflags` |
   |---|---|---|---|
   | `0x80000034` | 1.0 / 0.0 | `fa1 = 0xFFFFFFFF7F800000`, infinity | `0x8`, DZ |
   | `0x80000044` | square root of -1.0 | `fa2 = 0xFFFFFFFF7FC00000`, the canonical NaN | `0x10`, NV |
   | `0x80000060` | 1.0 / 3.0, double | `fa3 = 0x3FD5555555555555`, not boxed: it fills all 64 bits | `0x1`, NX |

   The flags are new each time because the program clears them with `fsflags zero` after
   reading them.

4. Stop at the end and read the five conversions of 2.5:

   ```text
   break.set 0x80000090
   cpu.continue
   cpu.reg fa4
   cpu.reg a4
   cpu.reg a5
   cpu.reg a6
   cpu.reg a7
   cpu.reg s2
   cpu.reg fcsr
   cpu.reg mstatus
   ```

   `fa4 = 0xFFFFFFFF40200000` is 2.5. `a4 = 0x2` (from `frm`, nearest with ties to even),
   `a5 = 0x3` (RUP), `a6 = 0x3` (RMM), `a7 = 0x2` (RTZ), `s2 = 0x2` (RDN). `fcsr = 0x1`: `frm` is still 0, and
   NX is set again, because 2.5 is not a whole number. `mstatus = 0x8000000A00006000`: FS is 3,
   Dirty, so SD (bit 63) is 1; the `A` is UXL and SXL, which always read 2 on this hart.

## 4. Try

Change one line in `float.S`:

```asm
    fsrmi   3                       # was: fsrmi 0
```

**Predict:** `frm` is now 3, round up. The single-precision 1/3 does not change, because
round-to-nearest already rounded it up. The double-precision 1/3 does: its lost part was a
third of the last bit, so nearest rounded it down, and up now gives one more,
`fa3 = 0x3FD5555555555556`. `a4` (from `frm`) becomes 3; `a5`, `a6`, `a7` and `s2` name their own
modes and stay 3, 3, 2 and 2. `fcsr = 0x61`: `frm` 3 in bits 7:5, and NX.

Only one instruction changes: `fsrmi 0` at `0x80000008` becomes `fsrmi 3`, the word
`0x0021D073`. Check it in the debugger: start the program with `--dap` as in step 3, then before
`cpu.continue` type:

```text
mem.write 0x80000008 73D02100
break.set 0x80000090
cpu.continue
cpu.reg fa3
cpu.reg a4
cpu.reg fcsr
```

You see `fa3 = 0x3FD5555555555556`, `a4 = 0x3` and `fcsr = 0x61`.

If you have the RISC-V GCC toolchain, rebuild the ELF instead. Run this inside the lab
folder:

```text
riscv64-unknown-elf-gcc -march=rv64ifd -mabi=lp64 -nostdlib -nostartfiles -static -T link.ld float.S -o float-rv64.elf
```

RetroCore's unit test `RiscVLabTests.Lab10_Try_RoundUp_ChangesTheDoubleAndTheTie` writes the same word
and checks the results. `Lab10_EachSumRaisesItsFlag_AndEachRoundingModeItsInteger` checks
every value in this chapter, and
`RiscVLabDebuggerTests.Lab10_WatchTheFlagsAndTheRounding_InTheFloatRegisters` runs every
debugger step.

## 5. Under the hood

`fdiv.s` runs in `OpFDIV_S`, and the rounding mode is chosen in `TryRounding`, both in
`FloatArith.cs`.
The arithmetic itself is Berkeley SoftFloat (BSD licence), ported to C#; no host floating
point is used.
