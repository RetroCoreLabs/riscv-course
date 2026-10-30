# Zicsr — control and status registers

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "Zicsr", and
Volume II for the registers themselves.

## What it adds

Six instructions that read and change the control and status registers (CSRs), a separate
space of up to 4096 registers that hold the hart's settings and state: `csrrw`, `csrrs`,
`csrrc`, and the same three with a 5-bit immediate in place of a register (`csrrwi`, `csrrsi`,
`csrrci`).

Each one reads the old value into `rd` and writes a new one in the same step:

- `csrrw` writes the register value;
- `csrrs` sets the bits that are 1 in the source;
- `csrrc` clears them.

The address of a CSR says who may use it: bits 9:8 give the lowest privilege that can reach
it, and bits 11:10 = 11 mean read-only. A CSR that does not exist, or one used from too low a
privilege, raises an illegal instruction exception.

## Why it exists

Traps, interrupts, the counters, paging and floating-point rounding all need settings that are
not ordinary registers. One small set of instructions reaches all of them.

## What it is used for

Every trap handler (`mepc`, `mcause`, `mtval`, `mstatus`), every kernel (`satp`, `stvec`),
timing code (`cycle`, `time`), and anything that reads the hart's ID (`mhartid`).

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `csrr` (`csrrs rd, csr, x0`) | `csrr t0, mcause` | t0 = mcause, nothing written |
| `csrw` (`csrrw x0, csr, rs`) | `csrw mtvec, t0` | mtvec = t0 |
| `csrs` (`csrrs x0, csr, rs`) | `csrs mstatus, t0` | set the bits of t0 in mstatus |
| `csrci` | `csrci mstatus, 8` | clear MIE: machine interrupts off |
| `csrrw` | `csrrw t0, mscratch, t0` | swap t0 and mscratch |

## Who needs it

Everything: see the `Zicsr` row in [`../support-matrix.md`](../support-matrix.md).

## In RetroCore

Always present; it has no flag, because machine mode cannot work without CSRs. The registers
live in `CSRFile`.
