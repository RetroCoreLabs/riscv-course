# Zbs — single-bit instructions

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "B Extension for Bit
Manipulation", section Zbs.

## What it adds

Work on one bit chosen by a register or an immediate:

- `bset` / `bseti`: set it;
- `bclr` / `bclri`: clear it;
- `binv` / `binvi`: flip it;
- `bext` / `bexti`: copy it to bit 0 of the destination, all other bits 0.

The bit number is taken modulo the register width.

## Why it exists

Setting or testing one bit in the base set takes a shift to make a mask and then a logic
instruction; with a bit above 11 the mask does not fit an immediate at all.

## What it is used for

Flag words, device registers and bitmaps.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `bseti` | `bseti a0, a0, 31` | set bit 31 of a0 |
| `bclr` | `bclr a0, a0, a1` | clear bit a1 of a0 |
| `binvi` | `binvi a0, a0, 0` | flip bit 0 of a0 |
| `bext` | `bext a0, a1, a2` | a0 = bit a2 of a1 |

## Who needs it

See the `Zba / Zbb / Zbs` row in [`../support-matrix.md`](../support-matrix.md). None of the
targets needs it; code built for it uses it when present.

## In RetroCore

Flag `IsaExtensions.Zbs`. Tested with the official `rv32uzbs` and `rv64uzbs` tests (the `p`
forms).
