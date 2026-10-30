# RISC-V labs

One chapter per topic. Each has the same five steps: concept, run, debug, try, under the
hood. See [the front page](../index.md) for who the course is for, and
[Getting RetroCore](../getting-retrocore.md) for the two programs that run the labs.


| Ch | Chapter | Lab |
|---|---|---|
| 0 | [Registers, formats, encoding](00-registers.md) | step `addi` and `add`, read the decoded fields |
| 1 | [Loads, stores, branches, calls, the ABI](01-calls.md) | follow a C call frame by frame |
| 2 | [CSRs, machine mode, traps, `ecall` and `mret`](02-traps.md) | watch `mepc`, `mcause` and `mtvec` on an illegal instruction |
| 3 | [M and C, RV32 vs RV64](03-mc.md) | one C program built four ways: sizes, encodings, `mul` and `div` results |
| 4 | [Timers, interrupts, the UART](04-timer.md) | a CLINT timer tick wakes the hart and prints on the UART |
| 5 | [An RTOS context switch](05-rtos.md) | stop FreeRTOS as it saves one task and starts another |
| 6 | [U, S and M privilege, delegation, `sret`](06-priv.md) | a user `ecall` traps into a supervisor kernel, not into M |
| 7 | [Sv39 paging, page faults, the TLB](07-paging.md) | walk a three-level page table by hand, then ask `mmu.translate` |
| 8 | [The PLIC and a virtio disk read](08-virtio.md) | read one sector: the request in memory, the interrupt through the PLIC |
| 9 | [OpenSBI, the device tree, the Linux entry](09-opensbi.md) | follow `a0` and `a1` from the boot ROM through OpenSBI into the kernel |
| 10 | [Floating point, `fcsr` flags and rounding](10-float.md) | four sums, four flags; 2.5 rounded five ways |

The lab programs, their link scripts, the built ELF files and the start-up scripts are in
the course's [`labs/`](https://github.com/RetroCoreLabs/riscv-course/tree/main/labs) folder.
Every command line in the chapters is typed in the course folder, the one that holds `labs/`.

Chapters 0 to 4 and 8 run on the `riscv32-bare` machine; the RV64 builds of chapter 3 run on
`riscv64-nuttx`. Chapters 6, 7 and 10 need an RV64 hart with supervisor mode (and, for 10,
floating point), so they run on `riscv64-xv6` with the lab program loaded in place of the xv6
kernel. Chapter 8 also mounts a small disk image from its lab folder. Chapters 5 and 9 have
no program of their own: chapter 5 uses the FreeRTOS demo that the `riscv32-rtos` machine
loads from RetroCore's media folder, and chapter 9 the OpenSBI firmware and Linux kernel that
`riscv64-linux` loads from there.

RetroCore's own unit tests check every chapter (`RiscVLabTests`), and send the debugger steps
of each chapter as DAP requests (`RiscVLabDebuggerTests`).

The ELF files were built with the RISC-V GCC 10.2 bare-metal toolchain
(`riscv64-unknown-elf-gcc`). You do not need it to run the labs; each chapter gives its build
command for when you change a program.
