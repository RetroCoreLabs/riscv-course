# Lab 2: CSRs, machine mode, traps, `ecall` and `mret`

Source for the trap registers and cause codes: The RISC-V Instruction Set Manual, Volume II
(CC BY 4.0), chapter "Machine-Level ISA". Nothing is quoted from it; every value below comes
from the lab program.

You will make the hart run an instruction it refuses, and watch where it goes and what it
writes down.

The program is
[`traps.S`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/02-traps/traps.S):

```asm
_start:
    la      t0, handler
    csrw    mtvec, t0           # traps now go to handler
    li      a0, 0               # a0 counts the traps
bad:
    csrw    mhartid, zero       # mhartid is read-only: writing it is illegal
after:
    ...                         # switch the machine off

handler:
    addi    a0, a0, 1           # one more trap
    csrr    t1, mepc            # the address of the instruction that trapped
    addi    t1, t1, 4           # skip it: every instruction here is 4 bytes
    csrw    mepc, t1
    mret                        # jump to mepc, back in the old privilege mode
```

## 1. Concept

CSRs (control and status registers) hold the hart's settings and state. They are not
ordinary registers. The `csrr` and `csrw` instructions read and write them (see
[Zicsr](../extensions/Zicsr.md)).

The hart starts in **machine mode** (M-mode), the most trusted level. When something goes
wrong, the hart takes a **trap**:

```text
  bad: csrw mhartid, zero      mhartid is read-only
          |
          |  the hart refuses; the instruction does nothing
          v
  mepc   = 0x80000010          where it happened
  mcause = 2                   why: illegal instruction
  mtval  = 0xF1401073          the instruction's own bits
  pc     = mtvec = 0x8000002C  go to the handler
          |
          v
  handler: mepc = mepc + 4, then mret
          |
          v
  after: 0x80000014            the program goes on
```

| CSR | Address | Holds |
|---|---|---|
| `mtvec` | `0x305` | where traps go |
| `mepc` | `0x341` | the address of the instruction that trapped |
| `mcause` | `0x342` | why: 2 = illegal instruction, 11 = `ecall` from M-mode |
| `mtval` | `0x343` | extra detail; for an illegal instruction, its bits |
| `mhartid` | `0xF14` | the hart's number; read-only |

`mret` is the way back. It jumps to `mepc`, and puts the hart back in the mode it was in
before the trap.

`ecall` makes a trap on purpose. It is how a program asks a more trusted level for help.
Its cause is 11 when it runs in M-mode.

Why `csrw mhartid` and not some made-up word? A CSR whose address has bits 11:10 = `11` is
read-only, and `0xF14` has them. So the CSR address alone makes the write illegal. An
all-zero word is illegal too, but this machine has the C extension, so it reads as two
16-bit compressed instructions (`c.unimp`). Compressed instructions are chapter 3.

## 2. Run

From the course folder, with either program:

```text
retrocore --machine riscv32-bare --script labs/02-traps/run.txt
retrocore-cli --machine riscv32-bare --script labs/02-traps/run.txt
```

The program traps once, comes back, and switches the machine off. At the command line, type
`cpu.reg a0`. You see `a0 = 0x1`: one trap.

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv32-bare --script labs/02-traps/run.txt --dap
retrocore-cli --machine riscv32-bare --script labs/02-traps/run.txt --dap
```

The steps use the debugger commands at the program's command line. A DAP client on the debugger
port sees the same session, where the CSRs are in the Registers scope after the integer
registers. RetroCore has no VS Code extension for RISC-V yet.

1. Stop at the first instruction of the handler:

   ```text
   break.set 0x8000002C
   cpu.continue
   ```

2. Read what the trap wrote:

   ```text
   cpu.reg mepc
   cpu.reg mcause
   cpu.reg mtval
   cpu.reg mtvec
   ```

   You see:

   ```text
   mepc = 0x80000010   (32-bit)
   mcause = 0x2   (32-bit)
   mtval = 0xF1401073   (32-bit)
   mtvec = 0x8000002C   (32-bit)
   ```

   `cpu.reg mhartid` is still `0x0`: the write did not happen.

   (screenshot: the CSRs stopped at the handler)

3. Look at the handler:

   ```text
   cpu.disasm --addr 0x8000002C --count 5
   ```

4. Step through it:

   ```text
   cpu.step
   cpu.step
   cpu.step
   cpu.step
   cpu.reg mepc
   ```

   After four steps `mepc = 0x80000014`. One more `cpu.step` runs `mret`, and `cpu.pc`
   shows `PC = 0x80000014`: the instruction after the bad one.

This lab does not use the UART.

## 4. Try

Change one line in `traps.S`:

```asm
bad:
    ecall                       # was: csrw mhartid, zero
```

**Predict:** the hart still traps to the handler with `mepc = 0x80000010`, but now
`mcause = 11` (`0xB`, `ecall` from M-mode) and `mtval = 0`.

`ecall` is the word `0x00000073`. Check it in the debugger: start the program with `--dap` as in
step 3, then before `cpu.continue` type:

```text
mem.write 0x80000010 73000000
break.set 0x8000002C
cpu.continue
cpu.reg mcause
cpu.reg mtval
```

You see `mcause = 0xB` and `mtval = 0x0`.

If you have the RISC-V GCC toolchain, rebuild the ELF instead. Run this inside the lab
folder:

```text
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -static -T link.ld traps.S -o traps-rv32.elf
```

RetroCore's unit test `RiscVLabTests.Lab02_Try_Ecall_GivesMcause11` writes the same word and checks
the three values. `Lab02_IllegalInstruction_SetsMepcMcauseMtval_AndJumpsToMtvec` checks every
value in this chapter.

## 5. Under the hood

The trap is recorded in `RaiseException` and taken in `EnterPendingTrap`; `mret` runs in
`Mret`. All three are in
`TrapHandling.cs`.
