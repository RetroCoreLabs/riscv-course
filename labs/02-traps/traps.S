# Lab 2: CSRs, machine mode, traps.
# The program points mtvec at its handler, then tries to write mhartid, which is read-only,
# so the instruction is illegal. The hart traps: it saves the address in mepc, the reason
# in mcause, and jumps to mtvec. The handler adds 4 to mepc and returns with mret, so the
# program goes on after the bad instruction.
# Build: see the lab chapter, docs/labs/02-traps.md.

    .equ TEST, 0x00100000
    .equ PASS, 0x5555

    .section .text.init
    .globl _start
_start:
    la      t0, handler
    csrw    mtvec, t0           # traps now go to handler
    li      a0, 0               # a0 counts the traps
bad:
    csrw    mhartid, zero       # mhartid is read-only: writing it is illegal
after:
    li      t0, TEST            # back here after the handler
    li      t1, PASS
    sw      t1, 0(t0)
halt:
    wfi
    j       halt

    .align  2
handler:
    addi    a0, a0, 1           # one more trap
    csrr    t1, mepc            # the address of the instruction that trapped
    addi    t1, t1, 4           # skip it: every instruction here is 4 bytes
    csrw    mepc, t1
    mret                        # jump to mepc, back in the old privilege mode
