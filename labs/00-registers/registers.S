# Lab 0: registers, formats, encoding.
# Three instructions put numbers in a0, a1 and a2, then the program powers the machine off
# through the test device at 0x0010_0000 (0x5555 = pass).
# Build: see the lab chapter, docs/labs/00-registers.md.

    .equ TEST, 0x00100000
    .equ PASS, 0x5555

    .section .text.init
    .globl _start
_start:
    addi    a0, zero, 5         # a0 = 0 + 5
    addi    a1, zero, -3        # a1 = 0 + (-3)
    add     a2, a0, a1          # a2 = a0 + a1
done:
    li      t0, TEST
    li      t1, PASS
    sw      t1, 0(t0)
halt:
    wfi
    j       halt
