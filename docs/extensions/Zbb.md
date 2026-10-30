# Zbb — basic bit manipulation

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "B Extension for Bit
Manipulation", section Zbb.

## What it adds

Single instructions for bit work the base set needs several for:

- logic with an inverted operand: `andn`, `orn`, `xnor`;
- counting: `clz` (leading zeros), `ctz` (trailing zeros), `cpop` (bits set);
- `min`, `max`, `minu`, `maxu`;
- sign and zero extension: `sext.b`, `sext.h`, `zext.h`;
- rotates: `rol`, `ror`, `rori`;
- `orc.b` (each byte becomes 0x00 if it was zero, else 0xFF) and `rev8` (reverse the bytes).

RV64 adds the 32-bit forms `clzw`, `ctzw`, `cpopw`, `rolw`, `rorw`, `roriw`.

## Why it exists

These come up in string handling, hashing, crypto and bit sets, and each one replaces a short
sequence or a loop.

## What it is used for

`orc.b` finds a zero byte in a word at once, which speeds up `strlen` and `strcmp`. `rev8`
swaps byte order for network data. `clz` and `ctz` find the first set bit in a bitmap.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `clz` | `clz a0, a1` | a0 = number of zero bits above the highest 1 in a1 |
| `cpop` | `cpop a0, a1` | a0 = number of 1 bits in a1 |
| `andn` | `andn a0, a1, a2` | a0 = a1 AND NOT a2 |
| `max` | `max a0, a1, a2` | a0 = the larger of a1 and a2, signed |
| `rev8` | `rev8 a0, a1` | a0 = a1 with its bytes in reverse order |
| `orc.b` | `orc.b a0, a1` | each byte of a0 = 0xFF where a1's byte is not 0, else 0 |

## Who needs it

See the `Zba / Zbb / Zbs` row in [`../support-matrix.md`](../support-matrix.md). None of the
targets needs it; code built for it uses it when present.

## In RetroCore

Flag `IsaExtensions.Zbb`. Tested with the official `rv32uzbb` and `rv64uzbb` tests (the `p`
forms).
