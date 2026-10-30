# Zba — address generation

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "B Extension for Bit
Manipulation", section Zba.

## What it adds

Shift-and-add in one step: `sh1add`, `sh2add`, `sh3add` compute `rs2 + (rs1 << 1, 2 or 3)`.

RV64 adds the `.uw` forms, which first take the low 32 bits of `rs1` as an unsigned number:
`add.uw`, `sh1add.uw`, `sh2add.uw`, `sh3add.uw`, and `slli.uw`.

## Why it exists

Indexing an array of 2-, 4- or 8-byte elements is "base + index × size". The base set needs a
shift and an add for that; Zba does it in one instruction. The `.uw` forms handle the common
C case of a 32-bit unsigned index on a 64-bit machine.

## What it is used for

Compiled code that walks arrays and tables. Compilers use it when told the target has it
(`-march=..._zba`).

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `sh2add` | `sh2add a0, a1, a2` | a0 = a2 + a1 × 4: the address of `int` element a1 at a2 |
| `sh3add` | `sh3add a0, a1, a2` | a0 = a2 + a1 × 8 |
| `add.uw` (RV64) | `add.uw a0, a1, a2` | a0 = a2 + the low 32 bits of a1, zero-extended |
| `slli.uw` (RV64) | `slli.uw a0, a1, 2` | a0 = (low 32 bits of a1, zero-extended) << 2 |

## Who needs it

See the `Zba / Zbb / Zbs` row in [`../support-matrix.md`](../support-matrix.md). None of the
targets needs it; code built for it uses it when present.

## In RetroCore

Flag `IsaExtensions.Zba`. Tested with the official `rv32uzba` and `rv64uzba` tests (the `p`
forms).
