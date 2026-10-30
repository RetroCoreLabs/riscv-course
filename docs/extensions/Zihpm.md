# Zihpm — hardware performance counters

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "Zihpm", and
Volume II for `mhpmcounter`, `mhpmevent` and `mcountinhibit`.

## What it adds

29 more counters for software to read: `hpmcounter3` to `hpmcounter31` (with high halves on
RV32). Each is a read-only view of a machine-mode counter, `mhpmcounter3` to
`mhpmcounter31`. Machine mode picks what each counts by writing an event number into
`mhpmevent3` to `mhpmevent31`: cache misses, branch mispredictions, whatever the chip offers.
The event numbers are the chip's own; the spec does not define them.

The same `mcounteren` and `scounteren` bits as for [Zicntr](Zicntr.md) decide who may read
them, and `mcountinhibit` can stop each one.

## Why it exists

To find where time goes: profiling tools need counts the program cannot see from its own
code.

## What it is used for

Profilers. An S-mode kernel cannot program the event registers itself; it asks the firmware
through the SBI PMU calls, which OpenSBI offers (`pmu` in its list of SBI extensions).
OpenSBI also probes which counters exist at start-up and reports them ("Boot HART MHPM Info").

## Key instructions

No new instructions; the counters are read with [Zicsr](Zicsr.md):

| Instruction | Example | Result |
|---|---|---|
| `csrr` | `csrr t0, hpmcounter3` | t0 = counter 3 |
| `csrw` (M-mode) | `csrw mhpmcounter3, zero` | counter 3 = 0 |

## Who needs it

See the `Zihpm (performance counters)` row in [`../support-matrix.md`](../support-matrix.md).
Nothing in the targets needs it; Linux uses it when present.

## In RetroCore

Flag `IsaExtensions.Zihpm` for the `hpmcounter` views; the machine-mode registers exist
without it. RetroCore has no events, so `mhpmevent3` to `mhpmevent31` read 0 and no counter
ever counts, which the spec allows. `CpuRiscV.HpmCounters` sets how many counters, from 3
up, hold what software writes (default none); the others read 0. The virt machines have 16,
counters 3 to 18.
