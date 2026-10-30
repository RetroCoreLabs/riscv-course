# Lab 1: loads, stores, branches, calls, the ABI

Source for the calling convention: the RISC-V ABIs Specification, "ILP32" (CC BY 4.0). Nothing
is quoted from it; every address and value below comes from the lab program.

You will follow a small C program as it calls one function from another, and read each
function's stack frame from memory.

The program is
[`calls.c`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/01-calls/calls.c):

```c
int add3(int a, int b, int c)
{
    return a + b + c;
}

int twice_sum(int x)
{
    int s = add3(x, x, 1);
    return s + s;
}

int main(void)
{
    return twice_sum(10);
}
```

A short start-up file,
[`start.S`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/01-calls/start.S),
sets the stack pointer, calls `main`, and then switches the machine off. `main` returns
(10 + 10 + 1) × 2 = 42.

It is built with `-O0`, no optimising, so each function keeps a full stack frame.

## 1. Concept

The calling convention is the agreement that lets separately compiled functions call each
other:

| Register | ABI name | Job |
|---|---|---|
| x1 | `ra` | return address: where to go back to |
| x2 | `sp` | stack pointer: the bottom of the stack; the stack grows down |
| x8 | `s0` | frame pointer at `-O0`: the top of the current frame |
| x10 to x17 | `a0` to `a7` | the first eight arguments; `a0` also carries the result |

A call is `jal ra, function`. It puts the address of the next instruction in `ra` and jumps.
A return is `jalr zero, 0(ra)`, written `ret`. A function that calls another must save its
own `ra` first, because the inner `jal` writes over it. It saves it on the stack, with `sw`.
It loads it back before returning, with `lw`.

The disassembly of `twice_sum`, from the ready-built ELF file:

```text
80000060:  fd010113   addi  sp,sp,-48      make a 48-byte frame
80000064:  02112623   sw    ra,44(sp)      save the return address
80000068:  02812423   sw    s0,40(sp)      save the caller's frame pointer
8000006c:  03010413   addi  s0,sp,48       s0 = top of this frame
80000070:  fca42e23   sw    a0,-36(s0)     store x
80000074:  00100613   addi  a2,zero,1      third argument: 1
80000078:  fdc42583   lw    a1,-36(s0)     second argument: x
8000007c:  fdc42503   lw    a0,-36(s0)     first argument: x
80000080:  fa5ff0ef   jal   ra,80000024    call add3
80000084:  fea42623   sw    a0,-20(s0)     s = the result
80000088:  fec42783   lw    a5,-20(s0)
8000008c:  00179793   slli  a5,a5,0x1      s + s, done as a shift left by one
80000090:  00078513   addi  a0,a5,0
80000094:  02c12083   lw    ra,44(sp)      get the return address back
80000098:  02812403   lw    s0,40(sp)
8000009c:  03010113   addi  sp,sp,48       give the frame back
800000a0:  00008067   jalr  zero,0(ra)     ret
```

The compiler turned `s + s` into a shift, even at `-O0`.

This program has no conditional branch (`beq`, `bne` and the rest); the C code has no `if`.
The only jumps are `jal` and `jalr`. The [I extension page](../extensions/I.md) shows `beq`.

The stack when the hart reaches `add3` (addresses grow upwards in the picture):

```text
0x800010E0  <- _stack_top: sp when main starts
            +-----------------------------+
0x800010DC  | 0x8000000C  main's saved ra |  back into _start
0x800010D8  | 0x00000000  main's saved s0 |  main frame (16 bytes)
0x800010D0  +-----------------------------+  <- s0 in twice_sum
0x800010CC  | 0x800000BC  saved ra        |  back into main
0x800010C8  | 0x800010E0  saved s0        |  main's frame pointer
            |   ...                       |  twice_sum frame (48 bytes)
0x800010AC  | 0x0000000A  x = 10          |  at s0 - 36
0x800010A0  +-----------------------------+  <- sp when add3 starts
```

## 2. Run

From the course folder, with either program:

```text
retrocore --machine riscv32-bare --script labs/01-calls/run.txt
retrocore-cli --machine riscv32-bare --script labs/01-calls/run.txt
```

The program runs and switches the machine off. At the command line, type `cpu.reg a0`. You see
`a0 = 0x2A`, which is 42.

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv32-bare --script labs/01-calls/run.txt --dap
retrocore-cli --machine riscv32-bare --script labs/01-calls/run.txt --dap
```

The steps use the debugger commands at the program's command line. A DAP client on the debugger
port sees the same session. RetroCore has no VS Code extension for RISC-V yet.

The debugger does not read the ELF file's symbols, so breakpoints go on addresses. The
addresses are `main` = `0x800000A4`, `twice_sum` = `0x80000060` and `add3` = `0x80000024`.
The call stack view shows only the current PC, so this lab reads the frames from `sp`, `ra`
and memory.

1. Stop at the start of `add3`:

   ```text
   break.set 0x80000024
   cpu.continue
   ```

2. Read the arguments and the links:

   ```text
   cpu.reg a0
   cpu.reg a1
   cpu.reg a2
   cpu.reg ra
   cpu.reg sp
   cpu.reg s0
   ```

   You see `a0 = 0xA`, `a1 = 0xA`, `a2 = 0x1`: add3(10, 10, 1). `ra = 0x80000084` is the
   instruction after the `jal` in `twice_sum`. `sp = 0x800010A0` and `s0 = 0x800010D0` are
   the bottom and top of the `twice_sum` frame.

3. Read the stack:

   ```text
   mem.dump 0x800010A0
   ```

   ```text
   0x800010A0  00 00 00 00 00 00 00 00  00 00 00 00 0A 00 00 00  ................
   0x800010B0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  ................
   0x800010C0  00 00 00 00 00 00 00 00  E0 10 00 80 BC 00 00 80  ................
   0x800010D0  00 00 00 00 00 00 00 00  00 00 00 00 0C 00 00 80  ................
   ```

   Find each word of the picture above: `0A` at `0x800010AC` is x, `E0 10 00 80` and
   `BC 00 00 80` are the saved `s0` and `ra` of `twice_sum`, and `0C 00 00 80` is the saved
   `ra` of `main`. Each word is stored lowest byte first.

   (screenshot: registers and mem.dump stopped at add3)

4. Continue. The breakpoint stays set, but `add3` is not called again:

   ```text
   cpu.continue
   ```

   The program runs to the end and `cpu.reg a0` shows `0x2A`.

To follow the frames one by one, set the next breakpoint before you continue. Stop at `main`
(`0x800000A4`): `sp = 0x800010E0` and `ra = 0x8000000C`. Then stop at `twice_sum`
(`0x80000060`): `a0 = 0xA`, `ra = 0x800000BC` and `sp = 0x800010D0`.

This lab does not use the UART.

## 4. Try

Change one line in `calls.c`:

```c
    int s = add3(x, x, 2);      /* was: add3(x, x, 1) */
```

**Predict:** `add3` returns 22, so `main` returns 44 (`0x2C`).

Only one instruction changes: `addi a2,zero,1` at `0x80000074` becomes `addi a2,zero,2`,
the word `0x00200613`. Check it in the debugger: start the program with `--dap` as in step 3,
then before `cpu.continue` type:

```text
mem.write 0x80000074 13062000
cpu.continue
cpu.reg a0
```

You see `a0 = 0x2C`.

If you have the RISC-V GCC toolchain, rebuild the ELF instead. Run this inside the lab
folder:

```text
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -static -O0 -ffreestanding -T link.ld start.S calls.c -o calls-rv32.elf
```

RetroCore's unit test `RiscVLabTests.Lab01_Try_Add3WithTwo_Returns44` writes the same word and checks
44. `Lab01_Main_Returns42` and `Lab01_CallFrames_AtAdd3Entry_HoldTheChapterValues` check every
register and stack value in this chapter.

## 5. Under the hood

The call is `OpJAL` and the return is `OpJALR`, both in
`Branch.cs`.
