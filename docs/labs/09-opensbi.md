# Lab 9: OpenSBI, the device tree and the Linux entry

Sources: the RISC-V Supervisor Binary Interface Specification (CC BY 4.0) for what OpenSBI
offers the kernel; the Devicetree Specification for the tree's format; the Linux kernel's
RISC-V boot documents, `Documentation/arch/riscv/boot.rst` and `boot-image-header.rst`, for
what the kernel expects at entry. Nothing is quoted from any of them; every value below comes from the machine.

You will follow a real boot from the hart's first instruction to the Linux kernel's first
instruction: the boot ROM, then the OpenSBI firmware in M-mode, then the kernel in S-mode. At
each hand-over you will check the two values that travel with it: the hart's number in `a0`
and the address of the **device tree** in `a1`.

**This lab runs on `riscv64-linux`.** It has no program of its own: the machine loads OpenSBI
and the kernel from the media root.

## 1. Concept

A kernel does not know what machine it runs on: how much RAM, where the UART is, which
interrupt the disk uses. The machine tells it with a **device tree**: a block of memory that
lists every device, its addresses and its interrupt. It starts with the magic number
`0xD00DFEED`, and, unlike everything else on RISC-V, all its numbers are big-endian.

Linux on RISC-V does not run in M-mode. It runs in S-mode, on top of a small firmware that
stays in M-mode: the **SBI** (Supervisor Binary Interface). The kernel calls it with `ecall`
for the things only M-mode can do, such as setting the timer or switching the machine off.
**OpenSBI** is the usual SBI firmware. Its `fw_jump` build jumps to a fixed address when it
is done: `0x80200000`.

Three hand-overs, each with the same two registers:

```text
  reset
    |
    v
  boot ROM  0x1000  (M)      a0 = mhartid, a1 = the device tree, jump to 0x80000000
    |
    v
  OpenSBI   0x80000000  (M)  sets up PMP, delegation, the timer; prints its banner;
    |                         copies the tree to 0x82200000 and adds its own memory to it
    |  mret, with mstatus.MPP = S and mepc = 0x80200000
    v
  Linux     0x80200000  (S)  a0 = hart, a1 = the tree; paging still off
```

The kernel file, `Image`, starts with a 64-byte **header**. Its first instruction jumps over
the header to the real start, `_start_kernel`. The header holds, among other things, the
offset the kernel wants from the start of RAM (`0x200000`) and two magic values, `RISCV` at
byte `0x30` and `RSC` and 5 at byte `0x38`.

## 2. Run

This chapter has no program of its own. The `riscv64-linux` machine loads OpenSBI and a
Linux kernel from RetroCore's media folder, `RiscV/opensbi/` and `RiscV/linux/`. They come
with RetroCore, not with this course; [Getting RetroCore](../getting-retrocore.md) will say
how to get them. Then, with either program:

```text
retrocore --machine riscv64-linux
retrocore-cli --machine riscv64-linux
```

The console shows the OpenSBI banner and its report. These lines are the hand-over to the
kernel:

```text
Domain0 Next Address        : 0x0000000080200000
Domain0 Next Arg1           : 0x0000000082200000
Domain0 Next Mode           : S-mode
```

Next Address is where `mret` goes, Next Arg1 what `a1` holds there, and Next Mode the
privilege. The kernel then boots; `RiscVLinuxTests` (run by name, a few minutes each) checks
that it reaches the login prompt.

(screenshot: the OpenSBI banner and the Domain0 lines)

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv64-linux --dap
retrocore-cli --machine riscv64-linux --dap
```

The steps use the debugger commands at the program's command line. RetroCore has no VS Code
extension for RISC-V yet.

1. Look at the boot ROM before anything runs:

   ```text
   cpu.disasm --addr 0x1000 --count 5
   mem.dump 0x1000 32
   ```

   Five instructions and two data words:

   | Address | Word | Instruction |
   |---|---|---|
   | `0x1000` | `0x00000297` | `auipc t0, 0`: t0 = `0x1000` |
   | `0x1004` | `0xF1402573` | `csrr a0, mhartid`: a0 = 0 |
   | `0x1008` | `0x01C2E583` | `lwu a1, 28(t0)`: a1 = the word at `0x101C` |
   | `0x100C` | `0x0182E283` | `lwu t0, 24(t0)`: t0 = the word at `0x1018` |
   | `0x1010` | `0x00028067` | `jr t0` |
   | `0x1018` | `0x80000000` | the entry: OpenSBI |
   | `0x101C` | `0x8FE00000` | the device tree: the top 2 MiB of the 256 MiB of RAM |

2. Stop at OpenSBI's first instruction:

   ```text
   break.set 0x80000000
   cpu.continue
   cpu.reg priv
   cpu.reg a0
   cpu.reg a1
   mem.dump 0x8FE00000 8
   ```

   `priv = 0x3` (M), `a0 = 0x0`, `a1 = 0x8FE00000`. The tree starts `D0 0D FE ED 00 00 0B 5E`:
   the magic, then its total size, `0xB5E`, 2910 bytes, both big-endian.

3. Stop at the `mret` that leaves OpenSBI. `fw_jump-rv64.elf` (next to the `.bin` in the
   media root) is linked at 0 and runs at `0x80000000`; its `sbi_hart_switch_mode` ends with
   `mv a0, s5`, `mv a1, s4`, `mret` at `0x10FA0`, so at `0x80010FA0` in memory:

   ```text
   break.clear --addr 0x80000000
   break.set 0x80010FA0
   cpu.continue
   cpu.reg mepc
   cpu.reg mstatus
   cpu.reg a0
   cpu.reg a1
   cpu.reg medeleg
   cpu.reg mideleg
   ```

   `mepc = 0x80200000`: `mret` will jump to the kernel. `mstatus` bits 12:11, MPP, are 01: it
   will go to S. `a0 = 0x0` and `a1 = 0x82200000`: the tree's new place. `medeleg = 0xB109`
   (bits 0, 3, 8, 12, 13 and 15: misaligned fetch, breakpoint, `ecall` from U and the three
   page faults) and `mideleg = 0x222` (bits 1, 5 and 9: the supervisor software, timer and
   external interrupts) go to S, as chapter 6 did by hand for one cause. The banner is on the
   console by now.

   (screenshot: the registers at the mret)

4. One more stop, the kernel's first instruction:

   ```text
   break.set 0x80200000
   cpu.continue
   cpu.reg priv
   cpu.reg a0
   cpu.reg a1
   cpu.reg satp
   mem.dump 0x82200000 4
   mem.dump 0x80200000 64
   ```

   `priv = 0x1` (S), `a0 = 0x0`, `a1 = 0x82200000`, and `satp = 0x0`: paging is still off, the
   kernel turns it on itself (chapter 7). `D0 0D FE ED` at `0x82200000`: the tree is there.
   The first 64 bytes are the `Image` header:

   ```text
   80200000  4D 5A 6F 10 60 0D 01 00 00 00 20 00 00 00 00 00   li s4,-13 / j _start_kernel / nop, text offset 0x200000
   ...
   80200030  52 49 53 43 56 00 00 00 52 53 43 05 ...            "RISCV", "RSC" 5
   ```

   The first two bytes, `4D 5A`, are both the instruction `li s4, -13` and the letters `MZ`:
   the same header also lets a UEFI loader start the kernel.

5. Step twice: `li s4, -13`, then the jump. The PC is `0x802010D8`, `_start_kernel`, whose
   first instruction is `csrw sie, zero`: the kernel turns off every supervisor interrupt
   before it does anything else. In `vmlinux` the same instruction is at
   `0xFFFFFFFF800010D8`, the address it will have once paging is on.

## 4. Try

Compare the two trees: the one the boot ROM gave OpenSBI and the one OpenSBI gives the kernel.

**Predict:** the copy is bigger. OpenSBI keeps its own code and data in RAM at `0x80000000`,
and the kernel must not use that memory, so OpenSBI adds a `reserved-memory` node for each
part before it passes the tree on.

Stop at the kernel as in step 4, then read the size word of each tree:

```text
mem.dump 0x8FE00004 4
mem.dump 0x82200004 4
```

You see `00 00 0B 5E` (2910 bytes) and `00 00 0F 7E` (3966 bytes). The copy holds two new
nodes, `mmode_resv0@80040000` (OpenSBI's read-write data) and `mmode_resv1@80000000` (its
code); the boot ROM's tree has neither. These match the two M-only regions in the banner,
`Region04` and `Region05`.

RetroCore's unit test `RiscVLabTests.Lab09_Try_OpenSbiAddsItsOwnMemory_ToTheTreeItPassesOn` checks the
sizes and looks for both node names. `Lab09_BootRom_OpenSbi_Kernel_EachHandsOnTheHartAndTheTree`
checks every value in this chapter, and
`RiscVLabDebuggerTests.Lab09_FromTheBootRom_ThroughOpenSbi_ToTheKernelsFirstInstruction` runs
every debugger step. Without the images in the media root they fail with a message that names
the missing file and the build command.

## 5. Under the hood

The boot ROM is written by `WriteBootRom`, and the tree built from the machine's own parts by
`BuildDeviceTree` and placed by `PlaceDeviceTree`, all in
`RiscVVirt.cs`. The
boot ROM is ordinary RISC-V code that the hart runs. The tree lists only what the machine
has: the hart with its ISA string, RAM, the CLINT, the PLIC, the UART, the eight virtio slots
and the test device.

`RiscV64LinuxMachine.cs`
loads the kernel at `0x80200000` and OpenSBI at `0x80000000`, and points the boot ROM at
OpenSBI. Everything after that is OpenSBI's and the kernel's own code.
