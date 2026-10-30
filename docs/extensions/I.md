# I — the base integer instructions

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapters "RV32I" and "RV64I".

## What it adds

Everything a program needs to compute and move data: 32 integer registers (`x0` always reads
0), add and subtract, logic, shifts, compares, loads and stores of 1, 2 and 4 bytes (and 8 on
RV64), conditional branches, jumps with a link register, `fence`, `ecall` and `ebreak`. Every
instruction is 32 bits wide.

RV32I has 32-bit registers. RV64I widens them to 64 bits and adds the `w` forms (`addiw`,
`addw`, `sllw` and the rest), which work on the low 32 bits and sign-extend the result, plus
`ld`, `sd` and `lwu`.

## Why it exists

RISC-V keeps the base small and fixed, so that a simple chip can stop here and a bigger one
adds lettered extensions on top. Software built for the base runs on every RISC-V hart.

## What it is used for

All of it. A compiler can build any program from I alone; the extensions only make some
programs smaller or faster.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `addi` | `addi a0, zero, 5` | a0 = 5 |
| `add` | `add a0, a0, a1` | a0 = a0 + a1, no overflow trap |
| `lw` | `lw t0, 8(sp)` | t0 = the 4 bytes at sp + 8, sign-extended |
| `sw` | `sw t0, 0(a0)` | the low 4 bytes of t0 go to a0 |
| `beq` | `beq a0, zero, done` | jump to `done` when a0 is 0 |
| `jal` | `jal ra, func` | ra = the next instruction's address, jump to `func` |
| `jalr` | `jalr zero, 0(ra)` | jump to ra: the `ret` of a function |
| `lui` | `lui a0, 0x12345` | a0 = 0x12345000 |
| `ecall` | `ecall` | trap to the next privilege level up (a system call) |

## Who needs it

Everything: see the `I (base)` row in [`../support-matrix.md`](../support-matrix.md).

## In RetroCore

Always present; it has no flag. Choose RV32 or RV64 with `Xlen` when the CPU is built. The
official `rv32ui` and `rv64ui` tests from `riscv-tests` (BSD licence) run against it.
