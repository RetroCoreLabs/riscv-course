# Zicntr — cycle, time and instruction counters

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "Zicntr", and
Volume II for `mcounteren` and `scounteren`.

## What it adds

Three read-only CSRs that any privilege level can read, when allowed:

- `cycle`: clock cycles since some point in the past;
- `time`: wall-clock time, from the platform's timer;
- `instret`: instructions the hart has retired.

They are 64 bits wide. On RV32 the high halves are separate CSRs: `cycleh`, `timeh`,
`instreth`.

Machine mode decides who may read them: a clear bit in `mcounteren` makes a read from S- or
U-mode raise an illegal instruction exception, and `scounteren` does the same for U-mode on a
hart with S-mode.

## Why it exists

Programs need to measure time and speed without a system call each time.

## What it is used for

Reading the clock without a system call (`time`), benchmarks, and the official tests that
check the counters.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `rdcycle` (`csrr rd, cycle`) | `rdcycle t0` | t0 = cycle count |
| `rdtime` (`csrr rd, time`) | `rdtime t0` | t0 = time |
| `rdinstret` | `rdinstret t0` | t0 = instructions retired |
| `rdcycleh` (RV32) | `rdcycleh t1` | t1 = the high 32 bits of cycle |

On RV32, read the high half, the low half, then the high half again; if the two high reads
differ, the low half wrapped in between and the read is repeated.

## Who needs it

See the `Zicntr (counters)` row in [`../support-matrix.md`](../support-matrix.md).

## In RetroCore

Flag `IsaExtensions.Zicntr`. `mcycle` and `minstret`, the machine-mode registers behind
`cycle` and `instret`, exist without the flag. `time` needs a platform timer: on the virt
machines it reads the CLINT's `mtime`, which runs at 10 MHz, one tick per instruction.
