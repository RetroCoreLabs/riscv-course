# A — atomics

Source: The RISC-V Instruction Set Manual, Volume I (CC BY 4.0), chapter "A Extension for
Atomic Instructions" (Zalrsc and Zaamo).

## What it adds

Two ways to change memory so no other hart can get in between:

- **Load-reserved / store-conditional**: `lr.w` reads a word and sets a reservation on it;
  `sc.w` writes only if the reservation still holds, and returns 0 in its destination when it
  did, non-zero when it did not.
- **Atomic memory operations (AMOs)**: read a word, combine it with a register, write it back,
  all in one step: `amoswap`, `amoadd`, `amoand`, `amoor`, `amoxor`, `amomin`, `amomax`,
  `amominu`, `amomaxu`.

RV64 adds the `.d` forms for 8-byte values. Two bits on every instruction, `aq` and `rl`,
order it against the memory accesses before and after it.

The address must be aligned to the size of the access.

## Why it exists

With more than one hart, or with interrupts, a plain load and store pair can be split by
someone else's write. Locks and counters need a step that cannot be split.

## What it is used for

Spinlocks (xv6's `acquire` uses `amoswap`), reference counts, lock-free queues, and the C11
and C++ atomic types.

## Key instructions

| Instruction | Example | Result |
|---|---|---|
| `amoswap.w` | `amoswap.w.aq t0, t1, (a0)` | t0 = old word at a0, the word at a0 = t1 |
| `amoadd.w` | `amoadd.w t0, t1, (a0)` | t0 = old word, the word at a0 = old + t1 |
| `lr.w` | `lr.w t0, (a0)` | t0 = the word at a0, and a0 is reserved |
| `sc.w` | `sc.w t2, t1, (a0)` | store t1 if still reserved; t2 = 0 on success |

## Who needs it

See the `A (atomics)` row in [`../support-matrix.md`](../support-matrix.md). xv6 and Linux
need it.

## In RetroCore

Flag `IsaExtensions.A`. Tested with the official `rv32ua` and `rv64ua` tests. RetroCore runs
one hart. The reservation covers the bytes the `lr` read; the next `sc`, whether it succeeds
or not, ends it, and so does a reset. A trap does not end it: software that switches tasks
runs an `sc` of its own to drop a stale reservation.
