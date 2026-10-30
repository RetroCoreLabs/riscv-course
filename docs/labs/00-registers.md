# Lab 0: registers, formats, encoding

Source for the instruction formats: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0),
chapter "RV32I Base Integer Instruction Set". Nothing is quoted from it; the bit layouts
below are read from the lab program's own instruction words.

You will run three instructions, watch them fill three registers, and take each
instruction word apart by hand.

The program is
[`registers.S`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/00-registers/registers.S):

```asm
_start:
    addi    a0, zero, 5         # a0 = 0 + 5
    addi    a1, zero, -3        # a1 = 0 + (-3)
    add     a2, a0, a1          # a2 = a0 + a1
```

After that it switches the machine off through the test device at `0x0010_0000`.

## 1. Concept

A RISC-V hart (one hardware thread) has 32 integer registers, `x0` to `x31`. `x0` always
reads 0, and anything written to it is lost. Each register also has an ABI name, the name the
calling convention gives it: `x0` is `zero`, `x10` is `a0`, `x11` is `a1`, `x12` is `a2`.
The debugger shows the ABI names.

Every instruction in this lab is 32 bits wide. The low 7 bits, the **opcode**, say which
layout the other 25 bits use. This lab has two layouts:

- **I-type** (`addi`): one source register and a 12-bit number inside the instruction.
- **R-type** (`add`): two source registers.

Here is `addi a0, zero, 5`, the word `0x00500513`, cut into its fields:

```text
 31            20 19   15 14  12 11    7 6       0
+----------------+-------+------+-------+---------+
|  000000000101  | 00000 | 000  | 01010 | 0010011 |
+----------------+-------+------+-------+---------+
   imm = 5         rs1=x0  addi   rd=x10   OP-IMM
                   (zero)         (a0)
```

The three words of the program, field by field:

| Address | Word | Instruction | Fields |
|---|---|---|---|
| `0x80000000` | `0x00500513` | `addi a0, zero, 5` | imm `000000000101` = 5, rs1 `00000` = x0, funct3 `000`, rd `01010` = x10, opcode `0010011` |
| `0x80000004` | `0xFFD00593` | `addi a1, zero, -3` | imm `111111111101` = -3, rs1 `00000` = x0, funct3 `000`, rd `01011` = x11, opcode `0010011` |
| `0x80000008` | `0x00B50633` | `add a2, a0, a1` | funct7 `0000000`, rs2 `01011` = x11, rs1 `01010` = x10, funct3 `000`, rd `01100` = x12, opcode `0110011` |

Two things to notice:

- The 12-bit number in an I-type word is signed. Its top bit, bit 31 of the word, is copied
  into every higher bit. `0xFFD` becomes `0xFFFFFFFD`, which is -3.
- `rd` sits in the same bits, 11 to 7, in both layouts. So do `rs1` and `funct3`. The
  hardware can find the registers before it knows which instruction it has.

## 2. Run

From the course folder, with either program:

```text
retrocore --machine riscv32-bare --script labs/00-registers/run.txt
retrocore-cli --machine riscv32-bare --script labs/00-registers/run.txt
```

The script loads the ready-built ELF file, `registers-rv32.elf`, and the machine runs it. The
program switches the machine off almost at once. Open the [command line](../getting-retrocore.md#the-command-line) and type:

```text
cpu.reg a2
```

You see:

```text
a2 = 0x2   (32-bit)
```

`cpu.regs` lists every register: `a0 = 0x5`, `a1 = 0xFFFFFFFD`, `a2 = 0x2`.

## 3. Debug

Start the program again with `--dap`. The machine now waits for the debugger before it runs a
single instruction:

```text
retrocore --machine riscv32-bare --script labs/00-registers/run.txt --dap
retrocore-cli --machine riscv32-bare --script labs/00-registers/run.txt --dap
```

The debugger listens for DAP clients on [the debugger port](../getting-retrocore.md#another-debugger). The steps below use the debugger commands
at the program's command line. They talk to the same debugger, so a DAP client on
the debugger port sees the same breakpoints and registers.

RetroCore has no VS Code extension for RISC-V yet, so this chapter does not show a
VS Code session.

1. Stop on the first instruction. The program starts at `0x80000000`; the boot ROM at
   `0x1000` runs five instructions first.

   ```text
   break.set 0x80000000
   cpu.continue
   ```

2. Read the code and the raw bytes:

   ```text
   cpu.disasm --addr 0x80000000 --count 3
   mem.dump 0x80000000
   ```

   The first bytes are `13 05 50 00`. That is `0x00500513` with the lowest byte first:
   RISC-V stores words little-endian.

   (screenshot: cpu.disasm and mem.dump at 0x80000000)

3. Step one instruction at a time and read the register each one writes:

   ```text
   cpu.step
   cpu.reg a0
   cpu.step
   cpu.reg a1
   cpu.step
   cpu.reg a2
   ```

   You see `a0 = 0x5`, then `a1 = 0xFFFFFFFD`, then `a2 = 0x2`.

4. `cpu.regs` shows all the registers by ABI name, then the machine CSRs. `priv = 0x3`
   says the hart runs in machine mode.

This lab does not use the UART.

## 4. Try

Change one line in `registers.S`:

```asm
    addi    a1, zero, 7         # was: addi a1, zero, -3
```

**Predict:** a1 = 7, so a2 = 5 + 7 = 12 (`0xC`).

The new line assembles to `0x00700593`. The only field that changes is imm, now
`000000000111`.

You can check it without a compiler. Write the new word over the old one in the debugger,
after step 3 and before the first `cpu.step`:

```text
mem.write 0x80000004 93057000
```

The bytes go lowest first, as in `mem.dump`. Step three times; `cpu.reg a2` shows `0xC`.

If you have the RISC-V GCC toolchain, rebuild the ELF instead. Run this inside the lab
folder:

```text
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -static -T link.ld registers.S -o registers-rv32.elf
```

RetroCore's unit test `RiscVLabTests.Lab00_Try_AddiA1Seven_MakesA2Twelve` makes the same change. It
writes `0x00700593` over the word at `0x80000004` and checks that a2 is 12.
`Lab00_StepAddiAndAdd_FillsA0A1A2` and `Lab00_InstructionWords_DecodeToTheFieldsInTheChapter`
check every value and field in this chapter.

## 5. Under the hood

`addi` runs in `OpADDI`, and `add` in `OpADD`, both in
`Integer.cs`.
