# Lab 6: U, S and M privilege, delegation, sret.
# The program starts in machine mode (M). It lets S and U use all memory through PMP entry 0,
# delegates "ecall from U-mode" to supervisor mode (medeleg bit 8), points stvec at the
# kernel's trap handler, and drops to S with mret. The kernel drops to user mode (U) with
# sret. The user code asks the kernel to print 'U' with an ecall, then asks it to stop with a
# second one. Both ecalls trap into S, not M, because of the delegation bit. The console
# shows "U". The M-mode handler runs only when a trap is not delegated: it prints 'M'.
# Build: see the lab chapter, docs/labs/06-priv.md.

    .equ TEST, 0x00100000           # SiFive test device: 0x5555 = power off, pass
    .equ PASS, 0x5555
    .equ UART, 0x10000000           # NS16550A: a byte written here is sent
    .equ SYS_PUTC, 1                # the kernel's two system calls, numbered in a7
    .equ SYS_EXIT, 2
    .equ ECALL_FROM_U, 8            # the cause code of an ecall made in U-mode
    .equ MSTATUS_MPP, 0x1800        # mstatus bits 12:11: the mode mret goes to
    .equ MPP_S, 0x0800              # MPP = 01: supervisor
    .equ SSTATUS_SPP, 0x100         # sstatus bit 8: the mode sret goes to, 0 = user
    .equ PMP_NAPOT_RWX, 0x1F        # pmpcfg: A = NAPOT, X, W, R

    .section .text.init
    .globl _start
_start:                             # machine mode
    la      t0, m_handler
    csrw    mtvec, t0               # traps that stay in M go here
    li      t0, -1
    csrw    pmpaddr0, t0            # PMP entry 0: all of memory
    li      t0, PMP_NAPOT_RWX
    csrw    pmpcfg0, t0             # S and U may read, write and run it
    li      t0, 1 << ECALL_FROM_U
    csrw    medeleg, t0             # an ecall from U goes to S
    la      t0, s_handler
    csrw    stvec, t0               # S-mode traps go here
    li      t0, MSTATUS_MPP
    csrc    mstatus, t0
    li      t0, MPP_S
    csrs    mstatus, t0             # mret will go to S
    la      t0, kernel
    csrw    mepc, t0                # ... at kernel
    mret

kernel:                             # supervisor mode
    la      t0, user
    csrw    sepc, t0                # sret will go to user
    li      t0, SSTATUS_SPP
    csrc    sstatus, t0             # ... in U-mode
    sret

user:                               # user mode
    li      a0, 'U'
    li      a7, SYS_PUTC
    ecall                           # ask the kernel to print a0
    li      a7, SYS_EXIT
    ecall                           # ask the kernel to stop
spin:
    j       spin

    .align  2
s_handler:                          # supervisor mode, entered from U
    li      t0, SYS_PUTC
    bne     a7, t0, exit
    li      t0, UART
    sb      a0, 0(t0)               # print the byte
    csrr    t0, sepc                # the address of the ecall
    addi    t0, t0, 4               # skip it
    csrw    sepc, t0
    sret                            # back to U, after the ecall
exit:
    li      t0, UART
    li      t1, '\n'
    sb      t1, 0(t0)
    li      t0, TEST
    li      t1, PASS
    sw      t1, 0(t0)               # S may reach the test device: PMP entry 0 allows it
halt:
    j       halt

    .align  2
m_handler:                          # machine mode: a trap that was not delegated
    li      t0, UART
    li      t1, 'M'
    sb      t1, 0(t0)
    li      t1, '\n'
    sb      t1, 0(t0)
    li      t0, TEST
    li      t1, PASS
    sw      t1, 0(t0)
mhalt:
    j       mhalt
