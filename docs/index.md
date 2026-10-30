# Learn RISC-V by running it

This course teaches the RISC-V instruction set by running real programs on an emulated
RISC-V machine and stopping them in a debugger: registers, instruction encodings, calls,
traps, timers, privilege levels, paging, a virtio disk, OpenSBI and floating point.

The machine is [RetroCore](getting-retrocore.md), an emulator. It is the lab bench: you start
a machine, it loads the chapter's program, and you step through it instruction by
instruction.

## Who it is for

Students and retro-computing people. You need to be able to read a little C or assembly. No
knowledge of RetroCore's own code is assumed; a chapter names the RetroCore file that runs an
instruction only as a pointer for the curious.

## Where to start

1. [Getting RetroCore](getting-retrocore.md): the two programs that run the labs, and the
   three command-line flags every lab uses.
2. [The labs](labs/README.md): eleven chapters, from registers to floating point.
3. [The extensions](extensions/I.md): one page per RISC-V extension, what it adds and who
   needs it.
4. [The support matrix](support-matrix.md): which extension and which chip each operating
   system needs, and what the emulator has today.

## How a chapter works

Every chapter has the same five steps:

1. **Concept**: plain words, one picture.
2. **Run**: a ready-built program, started with one command line.
3. **Debug**: a guided session. Breakpoint, step, registers by their ABI names, CSRs, memory,
   the UART.
4. **Try**: change one line, predict the result, check it.
5. **Under the hood**: where the emulator does it, by name. No code walk-through.

Every extension page answers the same questions: what it adds, why it exists, what it is
used for, its key instructions with one example each, who needs it, and how the emulator
handles it.

## Licences

The course text and the lab programs are under the MIT licence (see `LICENSE`). Text quoted
from the RISC-V specifications names its licence where it is quoted.
