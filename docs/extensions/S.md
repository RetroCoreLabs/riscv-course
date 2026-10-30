# S — supervisor mode and paging

Source: The RISC-V Instruction Set Manual, Volume II (CC BY 4.0), chapters "Supervisor-Level
ISA" and "Machine-Level ISA" (trap delegation).

## What it adds

A third privilege level between machine (M) and user (U), made for an operating-system
kernel:

- its own trap registers: `sstatus`, `stvec`, `sepc`, `scause`, `stval`, `sscratch`, `sie`
  and `sip` (the last two show the S-mode bits of `mie` and `mip`);
- `sret`, which returns from an S-mode trap;
- trap delegation: a bit set in `medeleg` (exceptions) or `mideleg` (interrupts) sends that
  trap from S- or U-mode straight to S-mode instead of to M-mode;
- virtual memory: `satp` picks the paging mode and the root page table, and `sfence.vma`
  tells the hart that page tables changed. Sv32 (two levels, 4 GiB of virtual space) is the
  RV32 mode; Sv39 (three levels, 512 GiB) the first RV64 mode.

Machine mode keeps the last word: M-mode code (the firmware, such as OpenSBI) decides what is
delegated and runs below the kernel.

## Why it exists

A kernel needs to protect itself and its programs from each other, and to give each program
its own address space. M-mode alone has no paging, and firmware wants a level below the
kernel for the things only it should touch.

## What it is used for

xv6 and Linux run their kernels in S-mode and their programs in U-mode. OpenSBI runs in
M-mode and starts the kernel in S-mode.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `sret` | `sret` | pc = sepc; the privilege goes back to what `sstatus.SPP` says |
| `sfence.vma` | `sfence.vma zero, zero` | forget every cached translation |
| `csrw` | `csrw satp, t0` | switch to the page table and mode in t0 |
| `csrw` (M-mode) | `csrw medeleg, t0` | delegate the exceptions in t0 to S-mode |

## Who needs it

See the `Privilege modes` and `Paging` rows in [`../support-matrix.md`](../support-matrix.md).
xv6 and Linux need it.

## In RetroCore

Flag `IsaExtensions.S`; without it the hart has M- and U-mode only. Paging is inside the CPU
(`PageTranslation`): Sv32 on RV32, Sv39 on RV64, with a small translation cache that
`sfence.vma` and every `satp` write empty. The hart sets a page's A and D bits itself. Tested
with the official `rv32si` and `rv64si` tests, and the `v` forms of the user tests, which run
in U-mode under a small S-mode kernel with paging on.
