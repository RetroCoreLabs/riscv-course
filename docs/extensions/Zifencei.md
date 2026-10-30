# Zifencei — instruction-fetch fence

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "Zifencei".

## What it adds

One instruction, `fence.i`. After it, the hart's instruction fetches see every store this
same hart made before it.

## Why it exists

A real hart may keep instructions in a cache or a pipeline that does not watch ordinary
stores. Code that writes instructions and then runs them has to tell the hart.

## What it is used for

Loaders and debuggers that write code into memory, just-in-time compilers, and kernels that
patch their own code.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `fence.i` | `sw t0, 0(a0)` then `fence.i` then `jalr a0` | the new instruction at a0 runs, not an old copy |

## Who needs it

See the `Zifencei` row in [`../support-matrix.md`](../support-matrix.md).

## In RetroCore

Flag `IsaExtensions.Zifencei`. The handler does nothing, and that is correct here: RetroCore
keeps no copy of instructions, so every fetch reads memory and always sees the latest store.
