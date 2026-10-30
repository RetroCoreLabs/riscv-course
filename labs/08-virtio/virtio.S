# Lab 8: the PLIC and a virtio disk read, from request to interrupt.
# The program reads one 512-byte sector from the virtio disk. It sets the disk up, writes a
# request into memory (a header saying "read sector 1", a buffer for the data, and a byte for
# the answer), and tells the disk to go. The disk copies the sector into the buffer and raises
# its interrupt line. The PLIC passes the interrupt to the hart, which traps to m_trap. The
# handler asks the PLIC which device it was (claim), acknowledges the disk, tells the PLIC it
# is done (complete) and sets a flag. The main program then prints the sector's text and
# switches the machine off. Everything runs in machine mode, so the PLIC's machine-mode
# context, 0, is the one used.
# Build: see the lab chapter, docs/labs/08-virtio.md.

    .equ TEST, 0x00100000           # SiFive test device: 0x5555 = power off, pass
    .equ PASS, 0x5555
    .equ UART, 0x10000000           # NS16550A: a byte written here is sent

    .equ PLIC, 0x0C000000           # priority of source n at PLIC + 4 * n
    .equ PLIC_ENABLE0, 0x0C002000   # context 0 (the hart's M-mode): one enable bit per source
    .equ PLIC_THRESHOLD0, 0x0C200000 # context 0: priorities at or below this are held back
    .equ PLIC_CLAIM0, 0x0C200004    # context 0: read = claim, write = complete
    .equ DISK_IRQ, 1                # the disk in virtio slot 0 is PLIC source 1

    .equ VIRTIO, 0x10001000         # virtio-mmio slot 0: the disk
    .equ V_MAGIC, 0x000             # 0x74726976, the letters v i r t
    .equ V_DEVICE_ID, 0x008         # 2 = block device
    .equ V_DRIVER_FEATURES, 0x020
    .equ V_DRIVER_FEATURES_SEL, 0x024
    .equ V_QUEUE_SEL, 0x030
    .equ V_QUEUE_NUM, 0x038
    .equ V_QUEUE_READY, 0x044
    .equ V_QUEUE_NOTIFY, 0x050
    .equ V_INTERRUPT_STATUS, 0x060
    .equ V_INTERRUPT_ACK, 0x064
    .equ V_STATUS, 0x070
    .equ V_QUEUE_DESC, 0x080        # low 32 bits; the high half at + 4
    .equ V_QUEUE_DRIVER, 0x090      # the available ring
    .equ V_QUEUE_DEVICE, 0x0A0      # the used ring

    .equ S_ACKNOWLEDGE, 1           # device status bits
    .equ S_DRIVER, 2
    .equ S_DRIVER_OK, 4
    .equ S_FEATURES_OK, 8
    .equ D_NEXT, 1                  # descriptor flags: another descriptor follows
    .equ D_WRITE, 2                 # the device writes this buffer
    .equ QUEUE_SIZE, 8              # descriptors in the queue
    .equ SECTOR, 1                  # the sector to read

    .equ MIE_MEIE, 0x800            # mie bit 11: machine external interrupts
    .equ MSTATUS_MIE, 0x8           # mstatus bit 3: interrupts on in M-mode

    .section .text.init
    .globl _start
_start:
    la      t0, m_trap
    csrw    mtvec, t0               # traps go to m_trap
    li      s0, 0                   # s0: set to 1 by the handler

    # The PLIC: give the disk priority 1, enable it for context 0, let every priority through.
    li      t0, PLIC
    li      t1, 1
    sw      t1, 4 * DISK_IRQ(t0)
    li      t0, PLIC_ENABLE0
    li      t1, 1 << DISK_IRQ
    sw      t1, 0(t0)
    li      t0, PLIC_THRESHOLD0
    sw      zero, 0(t0)

    # The disk: check it is there, then the start-up steps in the order the virtio spec gives.
    li      s1, VIRTIO
    lw      s2, V_MAGIC(s1)         # 0x74726976
    lw      s3, V_DEVICE_ID(s1)     # 2: a block device
    sw      zero, V_STATUS(s1)      # reset
    li      t0, S_ACKNOWLEDGE | S_DRIVER
    sw      t0, V_STATUS(s1)        # "I have seen you, and I have a driver for you"
    li      t0, 1
    sw      t0, V_DRIVER_FEATURES_SEL(s1) # feature bits 63:32
    sw      t0, V_DRIVER_FEATURES(s1)     # bit 32, VERSION_1: the only feature asked for
    li      t0, S_ACKNOWLEDGE | S_DRIVER | S_FEATURES_OK
    sw      t0, V_STATUS(s1)

    # Queue 0: eight descriptors, the available ring and the used ring.
    sw      zero, V_QUEUE_SEL(s1)
    li      t0, QUEUE_SIZE
    sw      t0, V_QUEUE_NUM(s1)
    la      t0, desc
    sw      t0, V_QUEUE_DESC(s1)
    sw      zero, V_QUEUE_DESC + 4(s1)
    la      t0, avail
    sw      t0, V_QUEUE_DRIVER(s1)
    sw      zero, V_QUEUE_DRIVER + 4(s1)
    la      t0, used
    sw      t0, V_QUEUE_DEVICE(s1)
    sw      zero, V_QUEUE_DEVICE + 4(s1)
    li      t0, 1
    sw      t0, V_QUEUE_READY(s1)
    li      t0, S_ACKNOWLEDGE | S_DRIVER | S_FEATURES_OK | S_DRIVER_OK
    sw      t0, V_STATUS(s1)        # the disk takes requests from now on

    # The request header: type 0 (read), a reserved word, then the 64-bit sector number.
    la      t0, header
    sw      zero, 0(t0)
    sw      zero, 4(t0)
sector:
    li      t1, SECTOR
    sw      t1, 8(t0)
    sw      zero, 12(t0)

    # Three descriptors, 16 bytes each: address (64 bits), length, flags, next.
    la      t2, desc
    sw      t0, 0(t2)               # 0: the header, 16 bytes, the device reads it
    sw      zero, 4(t2)
    li      t1, 16
    sw      t1, 8(t2)
    li      t1, D_NEXT | (1 << 16)  # flags NEXT, next = 1
    sw      t1, 12(t2)
    la      t1, buffer
    sw      t1, 16(t2)              # 1: the data buffer, 512 bytes, the device writes it
    sw      zero, 20(t2)
    li      t1, 512
    sw      t1, 24(t2)
    li      t1, D_NEXT | D_WRITE | (2 << 16)
    sw      t1, 28(t2)
    la      t1, answer
    sw      t1, 32(t2)              # 2: the answer byte, the device writes it
    sw      zero, 36(t2)
    li      t1, 1
    sw      t1, 40(t2)
    li      t1, D_WRITE
    sw      t1, 44(t2)
    la      t1, answer
    li      t0, 0xFF
    sb      t0, 0(t1)               # 0xFF until the disk writes its answer

    # The available ring: flags 0, ring[0] = descriptor 0, then idx = 1 hands it over.
    la      t0, avail
    sh      zero, 0(t0)
    sh      zero, 4(t0)
    li      t1, 1
    sh      t1, 2(t0)

    li      t0, MIE_MEIE
    csrs    mie, t0                 # external interrupts on
    csrsi   mstatus, MSTATUS_MIE    # interrupts on in M-mode
notify:
    sw      zero, V_QUEUE_NOTIFY(s1) # "queue 0 has work": the disk starts
wait:
    beqz    s0, wait                # until the handler has run

done:
    la      t0, answer
    lbu     a0, 0(t0)               # 0 = the read worked
    la      t2, buffer
    li      t0, UART
print:
    lbu     t1, 0(t2)               # the sector's text, up to its first zero byte
    beqz    t1, off
    sb      t1, 0(t0)
    addi    t2, t2, 1
    j       print
off:
    li      t0, TEST
    li      t1, PASS
    sw      t1, 0(t0)
halt:
    j       halt

    .align  2
m_trap:                             # mcause 0x8000000B: a machine external interrupt
    li      t0, PLIC_CLAIM0
    lw      a1, 0(t0)               # claim: the source that interrupted, 1
    lw      a2, V_INTERRUPT_STATUS(s1) # bit 0: the used ring has a new entry
    sw      a2, V_INTERRUPT_ACK(s1) # the disk lowers its line
    sw      a1, 0(t0)               # complete: the PLIC may send source 1 again
    li      s0, 1
    mret

    .section .bss
    .align  12
desc:                               # QUEUE_SIZE descriptors of 16 bytes
    .skip   16 * QUEUE_SIZE
    .align  12
avail:                              # flags, idx, ring[QUEUE_SIZE], all 16 bits
    .skip   4 + 2 * QUEUE_SIZE
    .align  12
used:                               # flags, idx, then QUEUE_SIZE entries of id and length
    .skip   4 + 8 * QUEUE_SIZE
    .align  12
header:                             # the request header
    .skip   16
answer:                             # the disk's answer: 0 = OK
    .skip   1
    .align  12
buffer:                             # one sector
    .skip   512
