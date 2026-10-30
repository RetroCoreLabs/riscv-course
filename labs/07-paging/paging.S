# Lab 7: Sv39 paging, page faults, the TLB.
# Machine mode builds a three-level Sv39 page table by hand. It maps:
#   - VA 0x0000_0000-0x3FFF_FFFF to the same physical addresses, one 1 GiB page, read and
#     write: the UART and the test device live there;
#   - VA 0x8000_0000-0xBFFF_FFFF to the same physical addresses, one 1 GiB page, read, write
#     and run: the program and its tables live there;
#   - VA 0x4020_1000 to the physical page data_page, one 4 KiB page, read only. The three
#     parts of its page number, VPN[2], VPN[1] and VPN[0], are all 1.
# It turns paging on (satp), hands page faults to S-mode (medeleg) and drops to S. The kernel
# reads the value at VA 0x4020_1000 through the walk, then stores to the page. The page is read
# only, so the store is a page fault. The handler makes the page writable, flushes the TLB
# (sfence.vma) and returns; the store runs again and works. The kernel reads the stored value
# back, prints it as one digit, and switches the machine off.
# Build: see the lab chapter, docs/labs/07-paging.md.

    .equ TEST, 0x00100000           # SiFive test device: 0x5555 = power off, pass
    .equ PASS, 0x5555
    .equ UART, 0x10000000           # NS16550A: a byte written here is sent
    .equ VA, 0x40201000             # the virtual page: VPN[2] = 1, VPN[1] = 1, VPN[0] = 1
    .equ PTE_V, 0x01                # PTE bits: valid
    .equ PTE_R, 0x02                # readable
    .equ PTE_W, 0x04                # writable
    .equ PTE_X, 0x08                # runnable
    .equ PTE_A, 0x40                # accessed
    .equ PTE_D, 0x80                # dirty
    .equ SATP_SV39, 8               # satp.MODE, bits 63:60
    .equ STORE_PAGE_FAULT, 15       # the cause code of a store page fault
    .equ MSTATUS_MPP, 0x1800        # mstatus bits 12:11: the mode mret goes to
    .equ MPP_S, 0x0800              # MPP = 01: supervisor
    .equ PMP_NAPOT_RWX, 0x1F        # pmpcfg: A = NAPOT, X, W, R

    .section .text.init
    .globl _start
_start:                             # machine mode
    li      t0, -1
    csrw    pmpaddr0, t0            # PMP entry 0: all of memory
    li      t0, PMP_NAPOT_RWX
    csrw    pmpcfg0, t0             # S may read, write and run it

    # root[0]: VA 0 to 1 GiB, a gigapage onto physical 0, read and write.
    la      s1, root
    li      t0, PTE_V | PTE_R | PTE_W | PTE_A | PTE_D
    sd      t0, 0(s1)
    # root[1]: a pointer to the level-1 table (no R, W or X: not a leaf).
    la      t0, level1
    srli    t0, t0, 12              # its physical page number
    slli    t0, t0, 10              # PPN goes in PTE bits 53:10
    ori     t0, t0, PTE_V
    sd      t0, 8(s1)
    # root[2]: VA 2 GiB to 3 GiB, a gigapage onto physical 0x8000_0000: this program.
    li      t0, (0x80000000 >> 12) << 10
    ori     t0, t0, PTE_V | PTE_R | PTE_W | PTE_X | PTE_A | PTE_D
    sd      t0, 16(s1)
    # level1[1]: a pointer to the level-0 table.
    la      t1, level1
    la      t0, level0
    srli    t0, t0, 12
    slli    t0, t0, 10
    ori     t0, t0, PTE_V
    sd      t0, 8(t1)
    # level0[1]: the leaf for VA 0x4020_1000, onto data_page, read only.
    la      t1, level0
    la      t0, data_page
    srli    t0, t0, 12
    slli    t0, t0, 10
leaf_flags:
    ori     t0, t0, PTE_V | PTE_R | PTE_A
    sd      t0, 8(t1)

    la      t0, s_handler
    csrw    stvec, t0               # S-mode traps go here
    li      t0, 1 << STORE_PAGE_FAULT
    csrw    medeleg, t0             # a store page fault in S goes to S
    li      t0, SATP_SV39
    slli    t0, t0, 60
    srli    t1, s1, 12
    or      t0, t0, t1
    csrw    satp, t0                # paging on, for S and U: MODE Sv39, root page number
    sfence.vma
    li      t0, MSTATUS_MPP
    csrc    mstatus, t0
    li      t0, MPP_S
    csrs    mstatus, t0             # mret will go to S
    la      t0, kernel
    csrw    mepc, t0
    mret

kernel:                             # supervisor mode: every address is now virtual
    li      s0, 0                   # s0 counts page faults
    li      s2, VA
load:
    ld      a0, 0(s2)               # through the three-level walk: data_page's first word
store:
    li      a1, 7
    sd      a1, 8(s2)               # the page is read only: a store page fault
after:
    ld      a2, 8(s2)               # the 7 just stored
    li      t0, UART
    addi    t1, a2, '0'
    sb      t1, 0(t0)               # print it
    li      t1, '\n'
    sb      t1, 0(t0)
    li      t0, TEST
    li      t1, PASS
    sw      t1, 0(t0)
halt:
    j       halt

    .align  2
s_handler:                          # supervisor mode
    addi    s0, s0, 1               # one more page fault
    la      t0, level0
    ld      t1, 8(t0)               # the leaf PTE
    ori     t1, t1, PTE_W
    sd      t1, 8(t0)               # now writable
    sfence.vma                      # forget the old translation
    sret                            # run the store again

    .section .data
    .align  12
data_page:                          # the page VA 0x4020_1000 maps to
    .quad   0x1122334455667788

    .section .bss
    .align  12
root:                               # 512 entries of 8 bytes each: one 4 KiB page per table
    .skip   4096
level1:
    .skip   4096
level0:
    .skip   4096
