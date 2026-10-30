# M — multiply and divide

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "M Extension for
Integer Multiplication and Division".

## What it adds

Integer multiply, divide and remainder: `mul`, `mulh`, `mulhsu`, `mulhu`, `div`, `divu`,
`rem`, `remu`. RV64 adds the 32-bit forms `mulw`, `divw`, `divuw`, `remw` and `remuw`.

`mul` gives the low half of the product; the three `mulh` forms give the high half for signed,
signed-by-unsigned and unsigned operands.

Division never traps:

- dividing by zero gives all ones from `div` and `divu`, and the dividend from `rem` and `remu`;
- the most negative number divided by -1 gives that same number, with remainder 0.

## Why it exists

Multiply and divide take a lot of chip area. Keeping them out of the base lets the smallest
cores leave them out and do the work in software.

## What it is used for

Array indexing with a stride that is not a power of two, hashing, number formatting, any C
code with `*`, `/` or `%`. Without M the compiler calls library routines instead.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `mul` | `mul a0, a1, a2` | a0 = low half of a1 × a2 |
| `mulhu` | `mulhu a0, a1, a2` | a0 = high half of a1 × a2, both unsigned |
| `div` | `div a0, a1, a2` | a0 = a1 / a2, signed, rounded toward zero |
| `rem` | `rem a0, a1, a2` | a0 = what is left of a1 after that division |
| `divw` (RV64) | `divw a0, a1, a2` | divide the low 32 bits, sign-extend the result |

## Who needs it

See the `M (mul/div)` row in [`../support-matrix.md`](../support-matrix.md). xv6 and Linux
need it.

## In RetroCore

Flag `IsaExtensions.M`. Tested with the official `rv32um` and `rv64um` tests.
