# Lab 8: the PLIC and a virtio disk read

Sources: for the PLIC, the RISC-V Platform-Level Interrupt Controller Specification (CC BY
4.0); for the disk, the OASIS Virtual I/O Device (VIRTIO) specification, version 1.x, sections
"Virtio Over MMIO", "Virtqueues" and "Block Device". Nothing is quoted from either; every value
below comes from the lab program.

You will read one sector from a disk the way a kernel does: write a request into memory, tell
the disk, and let the disk's interrupt tell you it is done. The interrupt goes through the
PLIC, the chip that collects every device's interrupt line and passes it on to the hart.

**This lab runs on `riscv32-bare`** with a small disk image in its virtio disk slot, `vda`. The
image, [`disk.img`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/08-virtio/disk.img),
is four sectors of 512 bytes. Sectors 0, 1 and 2 each hold one line of text:
`This is sector 0.`, `Hello from sector 1.` and `And this is sector 2.`.

The program is
[`virtio.S`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/08-virtio/virtio.S):

```asm
_start:
    ...                             # mtvec = m_trap
    ...                             # PLIC: source 1 priority 1, enabled on context 0, threshold 0
    ...                             # disk: reset, ACKNOWLEDGE, DRIVER, features, FEATURES_OK
    ...                             # queue 0: 8 descriptors, desc / avail / used addresses, ready
    ...                             # DRIVER_OK
sector:
    li      t1, SECTOR              # the header: read, sector 1
    ...                             # three descriptors: header, buffer, answer
    ...                             # avail.ring[0] = 0, avail.idx = 1
    ...                             # mie.MEIE, mstatus.MIE: interrupts on
notify:
    sw      zero, V_QUEUE_NOTIFY(s1) # "queue 0 has work"
wait:
    beqz    s0, wait                # until the handler has run
done:
    ...                             # a0 = the answer; print the buffer; power off

m_trap:
    li      t0, PLIC_CLAIM0
    lw      a1, 0(t0)               # claim: which source?
    lw      a2, V_INTERRUPT_STATUS(s1)
    sw      a2, V_INTERRUPT_ACK(s1) # the disk lowers its line
    sw      a1, 0(t0)               # complete
    li      s0, 1
    mret
```

## 1. Concept

**The PLIC.** Every device has one interrupt line, a numbered **source**: on this machine the
virtio disk is source 1, the UART source 10. The PLIC has a **context** for each place an
interrupt can go: context 0 is the hart's machine mode (it drives `mip.MEIP`), context 1 its
supervisor mode. For each source and context the program sets three things:

| What | Where | This program |
|---|---|---|
| priority of source n (0 = never) | `0x0C000000 + 4 × n` | source 1: priority 1 |
| enable bits of context c, one per source | `0x0C002000 + 0x80 × c` | context 0: bit 1 |
| threshold of context c | `0x0C200000 + 0x1000 × c` | context 0: 0, so priority 1 gets through |
| claim / complete of context c | threshold + 4 | read = claim, write = complete |

When an enabled source with a priority above the threshold raises its line, the PLIC raises
the context's output, and the hart takes a machine external interrupt: `mcause = 0x8000000B`
(bit 31 says interrupt, 11 is the cause). The handler **reads** the claim register: the PLIC
answers with the source number and will not offer that source again until the handler
**writes** the same number back, "complete". In between, the handler deals with the device.

**The virtio disk.** A virtio device sits in a 4 KiB window of registers ("virtio-mmio"). This
machine has eight; slot 0, at `0x10001000`, is the disk. The program talks to it through a
**virtqueue**, three tables in ordinary RAM that both sides read and write:

```text
  descriptor table (desc)        available ring (avail)      used ring (used)
  the driver's buffers           driver -> device            device -> driver
  +----+-----+------+------+     +-------+-----+---------+   +-------+-----+------------+
  |addr| len |flags | next |     | flags | idx | ring[]  |   | flags | idx | ring[]     |
  +----+-----+------+------+     +-------+-----+---------+   +-------+-----+------------+
  0: header  16  NEXT    1        idx 1: one request,         idx 1: one answer,
  1: buffer 512  NEXT|W  2        ring[0] = descriptor 0      ring[0] = id 0, len 513
  2: answer   1  W       -
```

A request is a chain of descriptors. The first points at a 16-byte **header**: the type (0 is a
read) and the sector number. The next points at the buffer the data goes into, and the last at
one byte where the disk writes its **answer** (0 is OK). `W` means the device writes that
buffer. The driver puts the chain's first descriptor into the available ring, adds 1 to
`avail.idx`, and writes the queue number to **QueueNotify**. The device does the work, puts
the chain into the used ring with the number of bytes it wrote, adds 1 to `used.idx`, sets bit
0 of **InterruptStatus** and raises its line.

The disk on this machine does the whole request during the store to QueueNotify, so the
interrupt is waiting before the next instruction starts. A real disk takes milliseconds; the
program waits on the flag the handler sets either way. A real kernel would sleep with `wfi`
in that loop. xv6's `virtio_disk.c` builds the same three-descriptor request, and puts the
process that asked for the sector to sleep until the interrupt comes.

## 2. Run

From the course folder, with either program:

```text
retrocore --machine riscv32-bare --script labs/08-virtio/run.txt
retrocore-cli --machine riscv32-bare --script labs/08-virtio/run.txt
```

The script mounts `disk.img` read-only in slot `vda`, then loads the program. The console
prints `Hello from sector 1.` and the machine switches itself off.

(screenshot: the console with the sector's text)

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv32-bare --script labs/08-virtio/run.txt --dap
retrocore-cli --machine riscv32-bare --script labs/08-virtio/run.txt --dap
```

The steps use the debugger commands at the program's command line. RetroCore has no VS Code
extension for RISC-V yet.

1. Stop just before the notify. The disk is set up and the request is in memory:

   ```text
   break.set 0x80000164
   cpu.continue
   cpu.reg s2
   cpu.reg s3
   mem.dump 0x10001070 4
   mem.dump 0x80004000 16
   mem.dump 0x80001000 48
   mem.dump 0x80002000 6
   mem.dump 0x80004010 1
   mem.dump 0x80003000 12
   ```

   | Read | You see | What it is |
   |---|---|---|
   | `s2` | `0x74726976` | the magic value: the letters `v i r t`, lowest byte first |
   | `s3` | `0x2` | device ID 2: a block device |
   | `0x10001070` | `0F 00 00 00` | device status 15: ACKNOWLEDGE, DRIVER, FEATURES_OK, DRIVER_OK |
   | header at `0x80004000` | `00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00` | type 0 (read), reserved, sector 1 |
   | `avail` at `0x80002000` | `00 00 01 00 00 00` | flags 0, idx 1, ring[0] = descriptor 0 |
   | `answer` at `0x80004010` | `FF` | the disk has not answered |
   | `used` at `0x80003000` | twelve `00` | nothing used yet |

   The three descriptors, 16 bytes each:

   ```text
   80001000  00 40 00 80 00 00 00 00 10 00 00 00 01 00 01 00   header 0x80004000, 16, NEXT, next 1
   80001010  00 50 00 80 00 00 00 00 00 02 00 00 03 00 02 00   buffer 0x80005000, 512, NEXT W, next 2
   80001020  10 40 00 80 00 00 00 00 01 00 00 00 02 00 00 00   answer 0x80004010, 1, W
   ```

   (screenshot: the descriptors in mem.dump)

2. Let the notify run. The hart stops in the handler:

   ```text
   break.set 0x800001AC
   cpu.continue
   cpu.reg mcause
   cpu.reg mepc
   mem.dump 0x80004010 1
   mem.dump 0x80003000 12
   mem.dump 0x80005000 21
   mem.dump 0x10001060 4
   ```

   `mcause = 0x8000000B`: a machine external interrupt. `mepc = 0x80000168`, the `wait` loop:
   the interrupt was taken right after the notify store, before the loop ran once. The answer
   byte is `00`, OK. The used ring reads `00 00 01 00 00 00 00 00 01 02 00 00`: idx 1, then
   id 0 (the chain that starts at descriptor 0) and length `0x201`, 513 bytes, the 512 data
   bytes and the answer byte. The buffer holds `Hello from sector 1.` and a newline.
   InterruptStatus at `0x10001060` reads `01 00 00 00`: the used ring has news.

3. Stop at the handler's `mret`:

   ```text
   break.set 0x800001C8
   cpu.continue
   cpu.reg a1
   cpu.reg a2
   mem.dump 0x10001060 4
   ```

   `a1 = 0x1`: the claim said source 1, the disk. `a2 = 0x1`: the InterruptStatus the handler
   read. InterruptStatus now reads `00 00 00 00`: the handler wrote it to InterruptAck, and the
   disk lowered its line. `cpu.continue` prints the text and switches the machine off.

You may `mem.dump` the claim register at `0x0C200004` while you look around. When the
program reads that register, the read **is** the claim. The debugger does not read it: it
asks the PLIC what a read would return, so `mem.dump 0x0C200004 4` stopped at `m_trap`
shows `01 00 00 00` (source 1) and claims nothing, and the handler still gets source 1.

## 4. Try

Change one line in `virtio.S`:

```asm
    .equ SECTOR, 2                  # was: .equ SECTOR, 1
```

**Predict:** the header asks for sector 2, so the console prints `And this is sector 2.`.
Everything else is the same: the same interrupt, the same claim, the same 513 bytes.

Only one instruction changes: `li t1, 1` at `0x800000B8` (the word `0x00100313`) becomes
`li t1, 2`, the word `0x00200313`. Check it in the debugger: start the program with `--dap` as in
step 3, then before `cpu.continue` type:

```text
mem.write 0x800000B8 13032000
cpu.continue
```

The console prints `And this is sector 2.`.

If you have the RISC-V GCC toolchain, rebuild the ELF instead. Run this inside the lab
folder:

```text
riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -static -T link.ld virtio.S -o virtio-rv32.elf
```

RetroCore's unit test `RiscVLabTests.Lab08_Try_SectorTwo_PrintsTheNextSector` writes the same word and
checks the text. `Lab08_DiskRead_RequestThroughTheQueue_InterruptThroughThePlic` checks every
value in this chapter, and `RiscVLabDebuggerTests.Lab08_WatchTheRequest_TheAnswer_AndTheInterrupt`
runs every debugger step.

## 5. Under the hood

The registers of a virtio slot are in
`VirtioMmio.cs`: a write
to QueueNotify calls `Notify`, which walks every chain added to the available ring since the
last one, hands each to the device, fills the used ring and raises the line. The disk's part,
reading the header and copying sectors, is `Process` in
`VirtioBlk.cs`.

The PLIC is
`Plic.cs`: `Claim` and
`Complete` are the two halves of the claim register. The machine wires context 0 to `mip.MEIP`
and context 1 to the supervisor line in `RiscVVirt.cs`.
