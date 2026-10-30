# Lab 1 start-up: set the stack pointer, call main, then power off through the test
# device at 0x0010_0000 (0x5555 = pass). main's return value stays in a0.

    .equ TEST, 0x00100000
    .equ PASS, 0x5555

    .section .text.init
    .globl _start
_start:
    la      sp, _stack_top
    call    main
    li      t0, TEST
    li      t1, PASS
    sw      t1, 0(t0)
halt:
    wfi
    j       halt
