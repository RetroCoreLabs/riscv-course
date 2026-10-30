# C — compressed instructions

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "C Extension for
Compressed Instructions" (Zca).

## What it adds

16-bit forms of the most common instructions. Each one does exactly what a 32-bit instruction
does; the hart expands it and runs that. A 16-bit instruction has its two lowest bits not
both 1, which is how the hart tells the two sizes apart.

To fit in 16 bits, many forms can only use registers `x8` to `x15` (`s0`, `s1`, `a0` to `a5`),
have short immediates, or use the same register as source and destination.

With C, instructions may start on any 2-byte boundary, so a jump to an address that is only
2-byte aligned no longer traps.

## Why it exists

Smaller code. The spec puts the saving at about 25 to 30 percent, which saves memory and, on
a real chip, instruction-cache space and fetch bandwidth.

## What it is used for

The stock RISC-V Linux distributions are built for RV64GC, where the C is this extension. The
FreeRTOS demo in RetroCore is built `rv32imac`.

## Key instructions

| Instruction | Expands to | Example |
|---|---|---|
| `c.addi` | `addi rd, rd, imm` | `c.addi a0, 1` |
| `c.li` | `addi rd, x0, imm` | `c.li a0, 5` |
| `c.mv` | `add rd, x0, rs2` | `c.mv a0, a1` |
| `c.lw` | `lw rd', off(rs1')` | `c.lw a0, 4(a1)` |
| `c.swsp` | `sw rs2, off(sp)` | `c.swsp ra, 12(sp)` |
| `c.j` | `jal x0, off` | `c.j loop` |
| `c.jr` | `jalr x0, 0(rs1)` | `c.jr ra` (a 2-byte `ret`) |

## Who needs it

See the `C (compressed)` row in [`../support-matrix.md`](../support-matrix.md). Stock Linux
distributions need it.

## In RetroCore

Flag `IsaExtensions.C`. Without F and D, the compressed floating-point loads and stores
(`c.flw`, `c.fld` and their kin) are illegal. Tested with the official `rv32uc` and `rv64uc`
tests.
