# Lab 7: Sv39 paging, page faults and the TLB

Source for Sv39, `satp`, the page-table entry and the page-fault cause codes: The RISC-V
Instruction Set Manual, Volume II (CC BY 4.0), chapter "Supervisor-Level ISA", sections "Sv39"
and "Virtual Address Translation Process". Nothing is quoted from it; every value below comes
from the lab program.

You will build a three-level page table by hand, turn paging on, and walk one address through
the table yourself. Then you will ask the debugger to do the same walk, and compare. Last, a
store to a read-only page faults, and the kernel's handler makes the page writable.

**This lab runs on `riscv64-xv6`.** Its hart has supervisor mode and Sv39 paging. As in
chapter 6, the xv6 kernel is not needed: the lab program is loaded in its place.

The program is
[`paging.S`](https://github.com/RetroCoreLabs/riscv-course/blob/main/labs/07-paging/paging.S):

```asm
_start:                             # machine mode
    ...                             # PMP entry 0: S may use all memory
    ...                             # root[0]: VA 0 - 1 GiB onto physical 0 (UART, test device)
    ...                             # root[1]: a pointer to level1
    ...                             # root[2]: VA 2 GiB - 3 GiB onto physical 0x80000000 (this program)
    ...                             # level1[1]: a pointer to level0
leaf_flags:
    ori     t0, t0, PTE_V | PTE_R | PTE_A
    sd      t0, 8(t1)               # level0[1]: VA 0x40201000 onto data_page, read only
    ...                             # stvec = s_handler, medeleg = store page faults
    csrw    satp, t0                # paging on: MODE Sv39, the root's page number
    ...
    mret                            # to kernel, in S

kernel:                             # supervisor mode: every address is now virtual
    li      s0, 0                   # s0 counts page faults
    li      s2, VA
load:
    ld      a0, 0(s2)               # through the three-level walk
store:
    li      a1, 7
    sd      a1, 8(s2)               # the page is read only: a store page fault
after:
    ld      a2, 8(s2)               # the 7 just stored
    ...                             # print it, power off

s_handler:
    addi    s0, s0, 1
    ...                             # level0[1] |= PTE_W
    sfence.vma                      # forget the old translation
    sret                            # run the store again
```

## 1. Concept

With paging on, every address the program uses is a **virtual address** (VA). The hart turns
it into a **physical address** (PA) by looking it up in a **page table** in memory. Memory is
cut into 4 KiB pages; the table says which physical page each virtual page is, and what may be
done with it.

**Sv39** uses the low 39 bits of the address and a table in three levels. Each table is one
4 KiB page of 512 entries, 8 bytes each. The address is cut like this:

```text
   38        30 29        21 20        12 11           0
  +------------+------------+------------+--------------+
  |   VPN[2]   |   VPN[1]   |   VPN[0]   |    offset    |
  +------------+------------+------------+--------------+
     9 bits       9 bits       9 bits       12 bits

  VA 0x40201000 = VPN[2] 1, VPN[1] 1, VPN[0] 1, offset 0
```

Each **page-table entry** (PTE) holds a physical page number (PPN, bits 53:10) and flags:

| Bit | Flag | Meaning |
|---|---|---|
| 0 | V | valid: the entry is used |
| 1 | R | the page may be read |
| 2 | W | the page may be written |
| 3 | X | code on the page may run |
| 4 | U | user mode may use the page |
| 5 | G | global: the same in every address space |
| 6 | A | accessed: the page has been used |
| 7 | D | dirty: the page has been written |

An entry with V set and R, W and X all clear is a **pointer** to the next level's table. An
entry with R or X set is a **leaf**: it maps a page. A leaf at level 2 maps 1 GiB (a
gigapage), at level 1 2 MiB (a megapage), at level 0 4 KiB.

**`satp`** turns paging on: MODE in bits 63:60 (8 is Sv39, 0 is Bare, no paging) and the root
table's page number in bits 43:0. Paging is for S and U only; M-mode addresses are
physical (unless M sets `mstatus.MPRV` to borrow a lower mode's view for its loads and
stores, which this program does not).

The walk for one address, as the hart does it:

```text
  satp.PPN x 4096                     = the root table
  root  [VPN[2]]: a pointer -> PPN x 4096 = the level-1 table
  level1[VPN[1]]: a pointer -> PPN x 4096 = the level-0 table
  level0[VPN[0]]: a leaf    -> PPN x 4096 + offset = the physical address
```

Three memory reads for every load is slow, so the hart keeps the answers it has found in a
**TLB** (translation lookaside buffer): a small table from virtual page to physical page. When
the kernel changes the page table, the TLB may still hold the old answer. **`sfence.vma`**
empties it.

When the walk finds no valid leaf, or the leaf does not allow the access, the hart raises a
**page fault**: cause 12 for an instruction fetch, 13 for a load, 15 for a store. `stval` gets
the virtual address that failed. This program asks for store page faults to go to S with
`medeleg` (chapter 6), so its kernel handles them.

## 2. Run

From the course folder, with either program:

```text
retrocore --machine riscv64-xv6 --script labs/07-paging/run.txt
retrocore-cli --machine riscv64-xv6 --script labs/07-paging/run.txt
```

The console prints `7`, the value the kernel stored through the page it made writable, and
the machine switches itself off.

(screenshot: the console with 7)

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv64-xv6 --script labs/07-paging/run.txt --dap
retrocore-cli --machine riscv64-xv6 --script labs/07-paging/run.txt --dap
```

The steps use the debugger commands at the program's command line. RetroCore has no VS Code
extension for RISC-V yet.

1. Stop at the kernel, the first instruction run with paging on:

   ```text
   break.set 0x800000D8
   cpu.continue
   cpu.reg priv
   cpu.reg satp
   mmu.status
   ```

   `priv = 0x1`: S-mode. `satp = 0x8000000000080002`: MODE 8, Sv39, and the root table at
   page `0x80002`, address `0x80002000`. `mmu.status` prints `RISC-V Sv39  —  ENABLED` and
   then:

   | Field | Value |
   |---|---|
   | satp | `0x8000000000080002` |
   | Mode | `Sv39` |
   | Root page table | `0x80002000` |
   | Privilege | `S` |
   | Loads and stores translated | `yes` |
   | TLB entries | `0 of 256` |

   The TLB is empty: writing `satp` and `sfence.vma` emptied it, and the kernel's first
   instruction has not been fetched yet.

2. Walk VA `0x40201000` by hand. All three VPNs are 1, so each table's entry 1 is the one to
   read, 8 bytes in. M-mode built the tables at physical addresses, and the kernel's code
   page maps onto itself, so `mem.dump` reads them where they are:

   ```text
   mem.dump 0x80002008 8
   mem.dump 0x80003008 8
   mem.dump 0x80004008 8
   ```

   | Read | Bytes | The PTE | What it says |
   |---|---|---|---|
   | root[1] at `0x80002008` | `01 0C 00 20 00 00 00 00` | `0x20000C01` | V only: a pointer. PPN `0x20000C01 >> 10` = `0x80003`: level1 at `0x80003000` |
   | level1[1] at `0x80003008` | `01 10 00 20 00 00 00 00` | `0x20001001` | a pointer: level0 at `0x80004000` |
   | level0[1] at `0x80004008` | `43 04 00 20 00 00 00 00` | `0x20000443` | V R A: a leaf, read only. PPN `0x80001`: the page at `0x80001000` |

   The bytes come lowest first: `43 04 00 20` is the word `0x20000443`. The page is
   `0x80001000`, and the offset is 0, so the physical address is `0x80001000`.

   (screenshot: the three mem.dump lines)

3. Now ask the MMU, and read the page through its virtual address:

   ```text
   mmu.translate 0x40201000
   mem.dump 0x40201000 8
   mmu.translate 0x40202000
   ```

   `mmu.translate 0x40201000` gives:

   | Field | Value |
   |---|---|
   | Logical | `$40201000` |
   | Mapped | `yes` |
   | Physical | `$80001000` |
   | Kind | `4 KiB page` |
   | Detail | `leaf at level 0, V R A` |

   The same answer as the walk by hand. `mem.dump 0x40201000 8` shows
   `88 77 66 55 44 33 22 11`, `data_page`'s first word `0x1122334455667788`: while the hart is
   in S, the debugger reads at the address the program uses. `mmu.translate 0x40202000`
   says `Mapped no`: level0's entry 2 is empty, and a load there would be a page fault.
   Neither command changes anything: the debugger's walk sets no A bit and fills no TLB slot.

4. Run the load, and look at the TLB:

   ```text
   break.set 0x800000E0
   cpu.continue
   cpu.step
   cpu.reg a0
   mmu.map
   ```

   `a0 = 0x1122334455667788`. `mmu.map` lists what the hart has remembered, by virtual
   address:

   | Logical | Physical | Kind | Detail |
   |---|---|---|---|
   | `$40201000-$40201FFF` | `$80001000` | TLB | `V R A` |
   | `$80000000-$80000FFF` | `$80000000` | TLB | `V R W X A D` |

   The data page from the load, and the code page from fetching the kernel's instructions.
   The code page comes from the gigapage in `root[2]`; the TLB keeps one 4 KiB page of it.

5. Run the store; it faults:

   ```text
   break.set 0x80000118
   cpu.continue
   cpu.reg scause
   cpu.reg sepc
   cpu.reg stval
   ```

   The hart stops in `s_handler` with `scause = 0xF` (15, store page fault),
   `sepc = 0x800000E8` (the `sd`) and `stval = 0x40201008`, the virtual address the store
   tried. `mcause` is 0: M-mode saw nothing. Nothing was written to the page.

6. Stop at the handler's `sret`:

   ```text
   break.set 0x80000134
   cpu.continue
   mem.dump 0x80004008 8
   mmu.map
   ```

   The leaf now reads `47 04 00 20`: `0x20000447`, V R W A. `mmu.map` prints no rows:
   `sfence.vma` emptied the TLB, and the `sret` itself has not been fetched yet.

7. Stop after the store:

   ```text
   break.set 0x800000EC
   cpu.continue
   mem.dump 0x80004008 8
   mem.dump 0x40201008 8
   cpu.reg s0
   ```

   The store ran again and worked: `mem.dump 0x40201008 8` shows `07 00 00 00 00 00 00 00`.
   The leaf reads `C7 04 00 20`, `0x200004C7`: the hart set D (bit 7) when the page was
   written. `s0 = 0x1`: one page fault.

   (screenshot: the leaf before and after, 43 / 47 / C7)

## 4. Try

Change one line in `paging.S`:

```asm
leaf_flags:
    ori     t0, t0, PTE_V | PTE_R | PTE_W | PTE_A     # was: PTE_V | PTE_R | PTE_A
```

**Predict:** the page is writable from the start, so the store does not fault. `s_handler`
never runs: `s0` stays 0 and `scause` stays 0. The console still prints `7`. The leaf ends
as `0x200004C7`, V R W A D: D is set by the store, as before.

Only one instruction changes: `ori t0, t0, 0x43` at `0x8000007C` (the word `0x0432E293`)
becomes `ori t0, t0, 0x47`, the word `0x0472E293`. Check it in the debugger: start the program
with `--dap` as in step 3, then before `cpu.continue` type:

```text
mem.write 0x8000007C 93E27204
break.set 0x800000EC
cpu.continue
cpu.reg s0
cpu.reg scause
mem.dump 0x80004008 8
```

You see `s0 = 0x0`, `scause = 0x0` and `C7 04 00 20`.

If you have the RISC-V GCC toolchain, rebuild the ELF instead. Run this inside the lab
folder:

```text
riscv64-unknown-elf-gcc -march=rv64i -mabi=lp64 -nostdlib -nostartfiles -static -T link.ld paging.S -o paging-rv64.elf
```

RetroCore's unit test `RiscVLabTests.Lab07_Try_WritableLeaf_NoPageFault` writes the same word and
checks the results. `Lab07_ThreeLevelWalk_StorePageFault_HandlerMakesThePageWritable` checks
every value in this chapter, including the walk by hand, and
`RiscVLabDebuggerTests.Lab07_WalkByHand_ThenAskTheMmu_AndWatchThePageFault` runs every
debugger step, `mmu.*` commands included.

## 5. Under the hood

The walk is `Walk` in
`PageTranslation.cs`:
the same three steps as the diagram in section 1, with the checks on R, W, X, U and the A and D
bits. The TLB is `TranslationCache` in the same file: 256 slots, chosen by the low bits of the
virtual page number. `sfence.vma` and every write to `satp` empty it.

The debugger's walk is `Peek`, next to `Walk`: it follows the same entries but sets no A or D
bit, fills no TLB slot and raises no trap. `mmu.status`, `mmu.map` and `mmu.translate` read
the hart through
`CpuRiscV.Mmu.cs`, which
also makes `mem.dump` and `mem.write` use virtual addresses while the hart is in S or U.
