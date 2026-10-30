# Lab 10: floating point, the fcsr flags and the rounding modes.
# The program switches the FPU on (mstatus.FS), sets the rounding mode to "nearest, ties to
# even", and does four sums that each raise one exception flag: 1/3 in single precision
# (inexact), 1/0 (divide by zero), the square root of -1 (invalid), and 1/3 in double
# precision (inexact). After each one it copies fflags to an a register and clears it. Then it
# converts 2.5 to an integer five times, each with a different rounding mode, and reads fcsr.
# Build: see the lab chapter, docs/labs/10-float.md.

    .equ TEST, 0x00100000           # SiFive test device: 0x5555 = power off, pass
    .equ PASS, 0x5555
    .equ MSTATUS_FS_INITIAL, 0x2000 # mstatus bits 14:13 = 01: the FPU is on, its state clean

    .section .text.init
    .globl _start
_start:
    li      t0, MSTATUS_FS_INITIAL
    csrs    mstatus, t0             # FPU on: until now every F or D instruction was illegal
    fsrmi   0                       # frm = 0: round to nearest, ties to even
    li      t0, 1
    fcvt.s.w ft0, t0                # ft0 = 1.0
    li      t0, 3
    fcvt.s.w ft1, t0                # ft1 = 3.0
third:
    fdiv.s  fa0, ft0, ft1           # 1/3 does not fit in 24 bits: rounded, NX set
    frflags a0                      # a0 = fflags
    fsflags zero                    # clear the flags
by_zero:
    fcvt.s.w ft2, zero              # ft2 = 0.0
    fdiv.s  fa1, ft0, ft2           # 1/0 = infinity, DZ set
    frflags a1
    fsflags zero
invalid:
    fneg.s  ft3, ft0                # ft3 = -1.0
    fsqrt.s fa2, ft3                # no real answer: the canonical NaN, NV set
    frflags a2
    fsflags zero
double:
    li      t0, 1
    fcvt.d.w ft4, t0                # ft4 = 1.0, double
    li      t0, 3
    fcvt.d.w ft5, t0                # ft5 = 3.0, double
    fdiv.d  fa3, ft4, ft5           # 1/3 in 53 bits: rounded, NX set
    frflags a3
    fsflags zero
ties:
    li      t0, 5
    fcvt.s.w ft6, t0
    li      t0, 2
    fcvt.s.w ft7, t0
    fdiv.s  fa4, ft6, ft7           # fa4 = 2.5, exact: no flag
    fcvt.w.s a4, fa4                # rounding mode from frm (nearest, ties to even): 2
    fcvt.w.s a5, fa4, rup           # round up: 3
    fcvt.w.s a6, fa4, rmm           # nearest, ties away from zero: 3
    fcvt.w.s a7, fa4, rtz           # towards zero: 2
    fcvt.w.s s2, fa4, rdn           # round down: 2
    frcsr   s1                      # s1 = fcsr: frm in bits 7:5, the flags in bits 4:0
done:
    li      t0, TEST
    li      t1, PASS
    sw      t1, 0(t0)
halt:
    j       halt
