# Lab 4: timers, interrupts, the UART.
# The program sets the CLINT timer to fire 10,000 mtime ticks from now (1 ms at 10 MHz),
# turns the machine timer interrupt on, and waits in WFI. Each time the timer fires, the
# handler prints the tick number on the UART and sets the next deadline. After three ticks
# the program prints a newline and switches the machine off. The console shows "123".
# Build: see the lab chapter, docs/labs/04-timer.md.

    .equ TEST, 0x00100000           # SiFive test device: 0x5555 = power off, pass
    .equ PASS, 0x5555
    .equ MTIMECMP, 0x02004000       # CLINT: hart 0's compare register, 64 bits
    .equ MTIME, 0x0200BFF8          # CLINT: the timer itself, 64 bits
    .equ UART, 0x10000000           # NS16550A: a byte written here is sent
    .equ INTERVAL, 10000            # mtime ticks between interrupts
    .equ TICKS, 3                   # how many interrupts to wait for
    .equ MIE_MTIE, 0x80             # mie bit 7: machine timer interrupt enable
    .equ MSTATUS_MIE, 0x8           # mstatus bit 3: interrupts on in machine mode

    .section .text.init
    .globl _start
_start:
    la      t0, handler
    csrw    mtvec, t0               # traps and interrupts go to handler
    li      s0, 0                   # s0 counts the ticks
    li      s1, MTIMECMP
    li      t0, MTIME
    lw      t1, 0(t0)               # mtime, low word (the high word is still 0)
    li      t2, INTERVAL
    add     t1, t1, t2
    sw      zero, 4(s1)             # mtimecmp, high word
    sw      t1, 0(s1)               # mtimecmp, low word: the first deadline
    li      t0, MIE_MTIE
    csrs    mie, t0                 # let the timer interrupt in
    csrsi   mstatus, MSTATUS_MIE    # interrupts on
wait:
    wfi                             # sleep until an interrupt
    li      t0, TICKS
    blt     s0, t0, wait            # not three yet: sleep again
done:
    li      t0, UART
    li      t1, '\n'
    sb      t1, 0(t0)
    li      t0, TEST
    li      t1, PASS
    sw      t1, 0(t0)
halt:
    wfi
    j       halt

    .align  2
handler:
    addi    s0, s0, 1               # one more tick
    li      t0, UART
    addi    t1, s0, '0'
    sb      t1, 0(t0)               # print the tick number
    lw      t1, 0(s1)
    li      t2, INTERVAL
    add     t1, t1, t2
    sw      t1, 0(s1)               # the next deadline; this also clears MTIP
    mret                            # back to the instruction after the wfi
