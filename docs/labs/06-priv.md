# Lab 6: U, S and M privilege, delegation, `sret`

Source for the privilege modes, `medeleg`, `sret` and the cause codes: The RISC-V Instruction
Set Manual, Volume II (CC BY 4.0), chapters "Machine-Level ISA" and "Supervisor-Level ISA".
Nothing is quoted from it; every value below comes from the lab program.

You will start a tiny kernel in supervisor mode, start a user program below it, and watch the
user program's system call trap into the kernel instead of into machine mode.

**This lab runs on `riscv64-xv6`, an RV64 machine.** None of the RV32 machines has
supervisor mode: `riscv32-bare` has machine and user mode only. `riscv64-xv6` has all three,
so the lab uses its hart. The xv6 kernel is not needed: the lab program is loaded in its place.
On RV64 the registers are 64 bits wide; nothing else in this lab changes because of that.

The program is
[`priv.S`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/06-priv/priv.S):

```asm
_start:                             # machine mode
    la      t0, m_handler
    csrw    mtvec, t0               # traps that stay in M go here
    ...                             # PMP entry 0: S and U may use all memory
    li      t0, 1 << ECALL_FROM_U
    csrw    medeleg, t0             # an ecall from U goes to S
    la      t0, s_handler
    csrw    stvec, t0               # S-mode traps go here
    ...                             # mstatus.MPP = S, mepc = kernel
    mret

kernel:                             # supervisor mode
    ...                             # sepc = user, sstatus.SPP = U
    sret

user:                               # user mode
    li      a0, 'U'
    li      a7, SYS_PUTC
    ecall                           # ask the kernel to print a0
    li      a7, SYS_EXIT
    ecall                           # ask the kernel to stop

s_handler:                          # supervisor mode, entered from U
    ...                             # SYS_PUTC: print a0, sepc = sepc + 4, sret
    ...                             # SYS_EXIT: print a newline, switch the machine off

m_handler:                          # machine mode: a trap that was not delegated
    ...                             # print 'M', switch the machine off
```

## 1. Concept

A RISC-V hart runs in one of three privilege modes. The debugger shows the mode as `priv`:

| `priv` | Mode | Who runs there |
|---|---|---|
| 3 | M, machine | firmware: the most trusted code, it sees everything |
| 1 | S, supervisor | an operating system kernel |
| 0 | U, user | programs |

Chapter 2 showed a trap going to M-mode. A kernel in S-mode wants the traps of its own user
programs, such as their system calls, without asking the firmware each time. M-mode hands
them over with **delegation**: `medeleg` has one bit per exception cause, and a set bit sends
that exception to S-mode instead of M-mode, as long as it happens in S or U. An `ecall` made
in U-mode has cause 8, so `medeleg = 1 << 8 = 0x100` delegates system calls.

S-mode has its own copy of the trap registers: `stvec`, `sepc`, `scause`, `stval`, and
`sstatus` (a view of the S-mode bits of `mstatus`). `sret` is S-mode's `mret`.

Going down is always a return: `mret` goes to the mode in `mstatus.MPP`, `sret` to the mode
in `sstatus.SPP`. So the program writes the mode it wants there, and the address it wants in
`mepc` or `sepc`, and returns. Going up is always a trap.

```text
  M  _start: medeleg = 0x100, stvec = s_handler, MPP = S, mepc = kernel
          |
          |  mret
          v
  S  kernel: SPP = U, sepc = user
          |
          |  sret
          v
  U  user: a0 = 'U', a7 = SYS_PUTC, ecall     (0x80000078)
          |
          |  cause 8 and medeleg bit 8 is set: the trap goes to S, not M
          v
  S  s_handler   scause = 8, sepc = 0x80000078, SPP = 0 (it came from U)
          |       print 'U', sepc = 0x8000007C
          |  sret
          v
  U  0x8000007C: a7 = SYS_EXIT, ecall  ->  S  s_handler: switch the machine off
```

| CSR | Address | Holds |
|---|---|---|
| `sstatus` | `0x100` | SPP (bit 8): the mode `sret` goes to; SIE and SPIE as in `mstatus` |
| `stvec` | `0x105` | where S-mode traps go |
| `sepc` | `0x141` | the address of the instruction that trapped |
| `scause` | `0x142` | why: 8 = `ecall` from U-mode, 9 = from S-mode |
| `stval` | `0x143` | extra detail; 0 for an `ecall` |
| `medeleg` | `0x302` | exceptions M-mode hands to S-mode, one bit per cause |

One more thing must be set before S and U can touch memory at all: **PMP**, physical memory
protection. When the hart has PMP entries and none of them matches an address, S and U may
not use it. The program sets entry 0 to cover all of memory with read, write and run allowed
(`pmpaddr0 = -1`, `pmpcfg0 = 0x1F`). Firmware such as OpenSBI does the same (chapter 9).

## 2. Run

From the course folder, with either program:

```text
retrocore --machine riscv64-xv6 --script labs/06-priv/run.txt
retrocore-cli --machine riscv64-xv6 --script labs/06-priv/run.txt
```

The console shows `U`, and the program switches the machine off.

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv64-xv6 --script labs/06-priv/run.txt --dap
retrocore-cli --machine riscv64-xv6 --script labs/06-priv/run.txt --dap
```

The steps use the debugger commands at the program's command line. A DAP client on the debugger
port sees the same session; the S-mode CSRs are in their own Supervisor group. RetroCore has
no VS Code extension for RISC-V yet.

1. Stop at the kernel, just after `mret`:

   ```text
   break.set 0x80000058
   cpu.continue
   cpu.reg priv
   cpu.reg medeleg
   cpu.reg stvec
   ```

   You see `priv = 0x1` (S), `medeleg = 0x100` and `stvec = 0x80000088`.

2. Stop at the user code, just after `sret`:

   ```text
   break.set 0x80000070
   cpu.continue
   cpu.reg priv
   ```

   `priv = 0x0`: user mode.

3. Stop where the system call lands:

   ```text
   break.set 0x80000088
   cpu.continue
   cpu.reg priv
   cpu.reg scause
   cpu.reg sepc
   cpu.reg sstatus
   cpu.reg mcause
   ```

   You see:

   ```text
   priv = 0x1   (8-bit)
   scause = 0x8   (64-bit)
   sepc = 0x80000078   (64-bit)
   sstatus = 0x200000000   (64-bit)
   mcause = 0x0   (64-bit)
   ```

   The kernel has the trap, and M-mode never saw it: `mcause` is still 0. In `sstatus`, SPP
   (bit 8) is 0, so the trap came from U-mode. The `2` in bits 33:32 is UXL: user mode is 64
   bits wide too, and it always reads 2 on this hart. `cpu.reg a0` shows `0x55`, the `'U'`
   the program asks to print, and `cpu.reg a7` shows `0x1`, `SYS_PUTC`.

   (screenshot: the S-mode CSRs stopped in s_handler)

4. Step through the handler. Seven steps reach the `sret` at `0x800000A4`; the console now
   shows `U`, and `cpu.reg sepc` shows `0x8000007C`. One more `cpu.step` runs the `sret`:
   `cpu.pc` shows `PC = 0x8000007C`, the instruction after the `ecall`, and `cpu.reg priv`
   shows `0x0` again.

5. `cpu.continue` stops in `s_handler` once more, for the second `ecall`: `sepc = 0x80000080`
   and `a7 = 0x2`, `SYS_EXIT`. One more `cpu.continue` and the program ends.

## 4. Try

Change one line in `priv.S`:

```asm
    li      t0, 0                   # was: li t0, 1 << ECALL_FROM_U
```

**Predict:** nothing is delegated, so the first `ecall` traps to M-mode: the hart stops in
`m_handler` at `0x800000C8` with `priv = 0x3`, `mcause = 0x8` and `mepc = 0x80000078`, and
the console shows `M` instead of `U`. `scause` stays 0.

Only one instruction changes: `li t0, 256` at `0x8000001C` becomes `li t0, 0`, the word
`0x00000293`. Check it in the debugger: start the program with `--dap` as in step 3, then before
`cpu.continue` type:

```text
mem.write 0x8000001C 93020000
break.set 0x800000C8
cpu.continue
cpu.reg priv
cpu.reg mcause
cpu.reg mepc
```

You see `priv = 0x3`, `mcause = 0x8` and `mepc = 0x80000078`. `cpu.continue` prints `M`.

If you have the RISC-V GCC toolchain, rebuild the ELF instead. Run this inside the lab
folder:

```text
riscv64-unknown-elf-gcc -march=rv64i -mabi=lp64 -nostdlib -nostartfiles -static -T link.ld priv.S -o priv-rv64.elf
```

RetroCore's unit test `RiscVLabTests.Lab06_Try_NoDelegation_EcallGoesToM` writes the same word and
checks the result. `Lab06_MretToS_SretToU_EcallTrapsIntoS` checks every value in this chapter,
and `RiscVLabDebuggerTests.Lab06_FollowTheModes_MToSToU_AndTheEcallBackIntoS` runs every
debugger step.

## 5. Under the hood

The choice between M and S is made in `EnterTrap`, and `sret` runs in `Sret`, both in
`TrapHandling.cs`.
