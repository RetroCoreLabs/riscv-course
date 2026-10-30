# Lab 4: timers, interrupts, the UART

Source for the interrupt registers and cause codes: The RISC-V Instruction Set Manual,
Volume II (CC BY 4.0), chapter "Machine-Level ISA". Nothing is quoted from it; every value
below comes from the lab program.

You will set a timer, go to sleep, and let the timer wake the hart three times. Each time,
the program prints a digit on the serial console.

The program is
[`timer.S`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/04-timer/timer.S):

```asm
_start:
    la      t0, handler
    csrw    mtvec, t0               # traps and interrupts go to handler
    li      s0, 0                   # s0 counts the ticks
    li      s1, MTIMECMP
    ...                             # mtimecmp = mtime + 10000
    li      t0, MIE_MTIE
    csrs    mie, t0                 # let the timer interrupt in
    csrsi   mstatus, MSTATUS_MIE    # interrupts on
wait:
    wfi                             # sleep until an interrupt
    li      t0, TICKS
    blt     s0, t0, wait            # not three yet: sleep again
    ...                             # print a newline, switch the machine off

handler:
    addi    s0, s0, 1               # one more tick
    ...                             # print '0' + s0 on the UART
    ...                             # mtimecmp = mtimecmp + 10000
    mret                            # back to the instruction after the wfi
```

## 1. Concept

An **exception** (chapter 2) comes from the instruction the hart is running. An **interrupt**
comes from outside, at any moment: here, from a timer.

The timer lives in the **CLINT**, a small chip at `0x0200_0000`. It has two 64-bit
registers:

| Register | Address | Holds |
|---|---|---|
| `mtime` | `0x0200BFF8` | counts up all the time, 10,000,000 times a second on this machine |
| `mtimecmp` | `0x02004000` | the deadline: while `mtime` >= `mtimecmp`, the timer interrupt is pending |

Three switches must all be on before the hart takes the interrupt:

| Bit | Where | Name | Means |
|---|---|---|---|
| 7 | `mip` | MTIP | the timer is pending (the CLINT sets and clears it) |
| 7 | `mie` | MTIE | the timer is allowed in |
| 3 | `mstatus` | MIE | interrupts are on in machine mode |

When the hart takes it, the trap works as in chapter 2, but `mcause` has its top bit set:

```text
  wait: wfi                      the hart sleeps
          |
          |  mtime reaches mtimecmp: MTIP = 1, the hart wakes
          v
  mepc    = 0x80000044           the instruction after the wfi
  mcause  = 0x80000007           top bit: interrupt; 7: machine timer
  mstatus = 0x1880               MIE off, its old value in MPIE, MPP = 3 (machine mode)
  pc      = mtvec = 0x80000070
          |
          v
  handler: print a digit, mtimecmp = mtimecmp + 10000   (MTIP goes back to 0)
          |
          v
  mret: pc = 0x80000044, MIE on again
```

Writing a later deadline to `mtimecmp` is how the program says "done with this tick". Until
it does, MTIP stays 1, and the hart would take the same interrupt again the moment it returns.

`mtimecmp` is 64 bits, but RV32 stores 32 bits at a time. The program writes the high word,
which is 0, then the low word.

The serial console is an NS16550A **UART** at `0x1000_0000`. A byte stored at that address is
sent. The handler stores the digit with `sb`.

A real handler saves every register it uses before it touches them. This one does not need
to, because the main loop only waits and loads `t0` again after each `wfi`.

## 2. Run

From the course folder, with either program:

```text
retrocore --machine riscv32-bare --script labs/04-timer/run.txt
retrocore-cli --machine riscv32-bare --script labs/04-timer/run.txt
```

The console shows `123`, and the program switches the machine off.

(screenshot: the console showing 123)

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv32-bare --script labs/04-timer/run.txt --dap
retrocore-cli --machine riscv32-bare --script labs/04-timer/run.txt --dap
```

The steps use the debugger commands at the program's command line. A DAP client on the debugger
port sees the same session. RetroCore has no VS Code extension for RISC-V yet.

1. Stop at the first instruction of the handler:

   ```text
   break.set 0x80000070
   cpu.continue
   ```

2. Read what the interrupt wrote:

   ```text
   cpu.reg mcause
   cpu.reg mepc
   cpu.reg mip
   cpu.reg mie
   cpu.reg mstatus
   ```

   You see:

   ```text
   mcause = 0x80000007   (32-bit)
   mepc = 0x80000044   (32-bit)
   mip = 0x80   (32-bit)
   mie = 0x80   (32-bit)
   mstatus = 0x1880   (32-bit)
   ```

   (screenshot: the CSRs stopped in the handler)

3. Read the timer itself:

   ```text
   mem.dump 0x02004000 --count 8
   mem.dump 0x0200BFF8 --count 8
   ```

   `mtimecmp` is `1C 27 00 00 00 00 00 00`, which is `0x271C` = 10012: the program read
   `mtime` when it was 12 and added 10000. `mtime` is `1D 27 00 00 00 00 00 00` = 10013: one
   tick past the deadline.

4. Stop again at the `mret`, at the end of the handler:

   ```text
   break.set 0x80000094
   cpu.continue
   cpu.reg mip
   mem.dump 0x02004000 --count 8
   ```

   The console now shows `1`. `mip = 0x0`: the new deadline, `2C 4E 00 00 ...` = 20012,
   cleared MTIP.

5. Step the `mret`:

   ```text
   cpu.step
   cpu.pc
   cpu.reg mstatus
   ```

   `PC = 0x80000044`, the instruction after the `wfi`. `mstatus = 0x88`: MIE is on again,
   MPIE is 1, and MPP is now 0, user mode, the lowest mode this hart has.

6. `cpu.continue` stops in the handler again for the second tick: `cpu.reg s0` shows `0x1`,
   and `mem.dump 0x0200BFF8` starts `2D 4E`, 20013.

## 4. Try

Change one line in `timer.S`:

```asm
    .equ TICKS, 5                   # was: 3
```

**Predict:** the console shows `12345`.

Only one instruction changes: `li t0, 3` after the `wfi`, at `0x80000044`, becomes
`li t0, 5`, the word `0x00500293`. Check it in the debugger: start the program with `--dap` as
in step 3, then before `cpu.continue` type:

```text
mem.write 0x80000044 93025000
cpu.continue
```

The console shows `12345`.

If you have the RISC-V GCC toolchain, rebuild the ELF instead. Run this inside the lab
folder:

```text
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -static -T link.ld timer.S -o timer-rv32.elf
```

RetroCore's unit test `RiscVLabTests.Lab04_Try_FiveTicks_Prints12345` writes the same word and checks
the console. `Lab04_TimerFires_HandlerSeesTheInterrupt_AndPrints123` checks every value in
this chapter.

## 5. Under the hood

The hart picks a pending, enabled interrupt and enters the trap in `TryServiceInterrupt`, in
`TrapHandling.cs`.
