# RISC-V support matrix

The one copy of what each OS target needs. The plan, the course and the CPU README link
here; nothing is copied out of it.

## Legend

| Mark | Meaning |
|---|---|
| R | Required |
| O | Used if present |
| – | Not needed |
| ✔ | Checked against the guest's own source or build (2026-10-26 to 2026-10-28) |
| (no ✔) | From knowledge of the project or from a plan decision. Checked when that phase starts. |

The **RetroCore** column says what the emulator has today. It changes only when a test proves it.

## Extensions × OS

| Extension | Bare-metal tests | FreeRTOS | NuttX | xv6 | Linux (our soft-float build) | Stock distro Linux (lp64d) | RISC PC desktop | RetroCore today |
|---|---|---|---|---|---|---|---|---|
| I (base) | R | R | R | R | R | R | R | RV32, RV64 (official `ui` tests) |
| M (mul/div) | per test | R (as built) | R (as built) | R | R | R | R | RV32, RV64 (`um`) |
| A (atomics) | per test | O ✔ (the demo binary has none) | R ✔ (as built) | R ✔ | R | R | R | RV32, RV64 (`ua`) |
| C (compressed) | per test | O ✔ (built `rv32imac`) | R ✔ (as built) | R ✔ (as built) | O | R | R | RV32, RV64 (`uc`) |
| F / D (float) | per test | – | R ✔ (FPU on by default, `lp64d`) | R ✔ (upstream builds `rv64gc`) | – (plan decision) | R | R | RV32, RV64 (`uf`, `ud`, bare and paged; `CpuRiscVFloatTests`) |
| Zicsr | R | R | R | R | R | R | R | yes |
| Zifencei | R | O | O | O | R | R | R | yes (no-op) |
| Zicntr (counters) | R (`mi` tests) | O | O | O | R | R | R | yes; `time` on the virt machines (CLINT) |
| Zihpm (performance counters) | – | – | – | – | O | O | O | the `hpmcounter` shadows; 0 to 29 writable `mhpmcounter`s that never count (`CpuRiscVExtensionTests`); 16 on the virt machines |
| Zba / Zbb / Zbs | per test | – | O | – | O | O | O | RV32, RV64 (`uzba`, `uzbb`, `uzbs`) |
| Zicond, Zicbom / Zicboz | per test | – | – | – | O | O | O | – |
| V (vector) | per test | – | O | – | O | O | O | – |
| H (hypervisor) | per test | – | – | – | – | – | – | – |
| Privilege modes | M | M | M ✔ (flat build) | M + S + U | M + S + U | M + S + U | M + S + U | M + U; S with `IsaExtensions.S` (`si`) |
| Paging | – | – | – | Sv39 | Sv39 | Sv39 | Sv39 | Sv32 (RV32), Sv39 (RV64); the "v" tests run under it |
| PMP | – | – | O | – | R (OpenSBI) | R | R | 0, 16 or 64 entries (`rv32mi-p-pmpaddr`, `CpuRiscVPmpTests`); 16 on the virt machines |
| Sdtrig (debug triggers) | – | – | – | – | O | O | O | 1 to 8 `mcontrol` address triggers (`CpuRiscVTriggerTests`); 2 on the virt machines |
| Sstc (S-mode timer) | – | – | – | R ✔ (upstream `e93dabe` uses `stimecmp`) | O | O | O | RV32, RV64 (`CpuRiscVSstcTests`); on `riscv64-xv6` |

Linux notes (✔, Buildroot 2026.02.3, Linux 6.19.14, built `rv64imac` / `lp64`): it boots on
the `riscv64-linux` machine under OpenSBI v1.7 to a BusyBox root shell, and `ls /proc`, 200
fork and exec, a page-faulting `dd` and `cat /proc/cpuinfo` answer as on QEMU
(`RiscVLinuxTests`). `/proc/cpuinfo` shows `rv64imac_zicntr_zicsr_zifencei_zihpm_zaamo_zalrsc_zca`:
the kernel adds `zaamo`, `zalrsc` (from A) and `zca` (from C) itself.

xv6 notes (✔, upstream commit `e93dabe`, `RiscVXv6Tests`): built as its Makefile builds it,
`-march=rv64gc`, and it programs its timer through Sstc. `kernel/spinlock.c` uses `amoswap`,
so it needs A. The 2022 commit `f5b93ef` never read the UART's IIR and ran only on a PLIC whose
complete ignores the line, as QEMU's does; upstream acknowledges the interrupt.

NuttX notes (✔, 13.1.0, `rv-virt:nsh64` unchanged, `RiscVNuttxTests`): one hart, flat M-mode,
console on the 16550, tick from the CLINT at 10 MHz. Semihosting HostFS is built in but only
`mount -t hostfs` uses it; the virt machines have no semihosting.

## Chips × OS

| Chip | Bare-metal tests | FreeRTOS | NuttX | xv6 | Linux | RISC PC desktop | RetroCore today |
|---|---|---|---|---|---|---|---|
| NS16550A UART | O | R ✔ | R ✔ (console, IRQ 10) | R ✔ (`0x1000_0000`, IRQ 10) | R | R | yes, with the receive character timeout (`Ns16550Tests`); no transmit or receive pacing (BUGS.md) |
| CLINT (`mtime`, `mtimecmp`, `msip`) | – | R ✔ | R ✔ (`sleep` on time) | R ✔ | R (OpenSBI timer + IPI) | R | yes, one hart |
| PLIC | – | – ✔ (the demo polls the UART) | R ✔ (interrupt-driven console) | R ✔ (UART IRQ 10, disk IRQ 1) | R | R | yes, 53 sources, M and S contexts |
| VirtIO-MMIO transport | – | – | – | R ✔ (`0x1000_1000`) | R | R | yes, 8 slots (`RiscVVirtVirtioTests`) |
| virtio-blk | – | – | – | R ✔ | R (root disk later) | R | yes, in the first slot (`Chips.VirtIO` tests) |
| virtio-net | – | – | – | – | R ✔ | R | yes, in the second slot, ping as on QEMU (`Chips.VirtIO` tests, `Linux_Network_PingsTheGateway_AsOnQemu`) |
| virtio-gpu (2D) | – | – | – | – | – | R | yes, in slot 3 of `riscv64-debian-desktop`, 1280x800; XFCE draws on it (`VirtioGpuTests`, `RiscVDebianDesktopTests`) |
| virtio-input | – | – | – | – | – | R | yes, a keyboard in slot 4 and a tablet in slot 5 of `riscv64-debian-desktop` (`VirtioInputTests`) |
| virtio-rng | – | – | – | – | O | R | yes, in the third slot (`VirtioRngTests`) |
| Goldfish RTC | – | – | – | – | O | R | yes, at `0x0010_1000`, PLIC source 11 (`GoldfishRtcTests`) |
| syscon "test" device (power off, reboot) | – | – | – | – | R, or shutdown hangs | R | yes |
| `tohost` watch (not a chip) | R | – | – | – | – | – | – |

## Not chips, but needed

- Boot ROM at `0x1000`: a plain memory region holding real RISC-V code (a0 = hart ID, a1 = device tree, jump to the entry).
- Sv32 / Sv39 MMU and PMP: inside the CPU (`PageTranslation`). Not an `IAddressTranslator`: that interface carries 32-bit addresses, and Sv39 virtual addresses are 39 bits.
- Device tree: built by the machine from its own parts at reset (`DeviceTreeWriter`, `RiscVDeviceTreeTests`), listing only what it has, and handed over in a1.
- ELF loader: `ElfReader` in `Common` (landed). Softfloat: `Common.SoftFloat` (Berkeley SoftFloat-3e, f32/f64, checked with 67 million TestFloat vectors).
