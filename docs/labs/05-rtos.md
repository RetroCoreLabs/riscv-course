# Lab 5: an RTOS context switch

Source for the program: the FreeRTOS QEMU virt demo, `FreeRTOS/Demo/RISC-V-Qemu-virt_GCC`, from
FreeRTOS release 202411.00 (MIT licence). Its RISC-V port is `portASM.S` and `portContext.h`
in `FreeRTOS/Source/portable/GCC/RISC-V`. The only text quoted from it is one `xTaskCreate`
call in step 4; every address and value below comes from objdump of the built demo and from
the debugger.

You will stop FreeRTOS at the moment it swaps one task for another, find where it put the
old task's registers, and watch the new task's registers come back.

The demo has four tasks you will meet:

| Task | Priority | What it does |
|---|---|---|
| `Tmr Svc` | 6 | FreeRTOS's own timer task; the demo gives it no work, so it waits at once |
| `Rx` | 2 | waits for a message on a queue, then prints `Blink1` or `Blink2` |
| `Tx` | 1 | prints `Transfer1` or `Transfer2`, waits one second, sends a message |
| `IDLE` | 0 | runs when nothing else can |

A higher number wins. The hart has one set of registers, so only one task runs at a time.

## 1. Concept

Each task has its own stack and a **task control block** (TCB): a small record FreeRTOS keeps
for it. The global `pxCurrentTCB` points at the TCB of the task that is running. The first
word of every TCB is that task's saved stack pointer.

A task gives up the hart in one of two ways:

- **It waits.** It runs `ecall`, which traps on purpose (`mcause = 11`, chapter 2).
- **The timer ticks.** Every 1 ms the CLINT interrupts the hart (`mcause = 0x80000007`,
  chapter 4). If the tick wakes a task with a higher priority, it takes over.

Both go to one trap handler, `freertos_risc_v_trap_handler` at `0x80002000`:

```text
  task A runs ... ecall, or a timer tick
          |
          v
  trap handler
    1. push 31 words onto A's own stack:
       word 0 = where A goes on, words 1-28 = its registers,
       word 29 = critical nesting, word 30 = mstatus
    2. A's TCB, first word = sp                    <- A is now saved
    3. vTaskSwitchContext  (0x80001436)            <- pxCurrentTCB = B
    4. sp = B's TCB, first word                    <- processed_source, 0x800020D0
    5. pop B's 31 words: mepc, mstatus, registers
    6. mret  (0x8000212E)                          <- B runs
```

Nothing else is swapped. A context switch is: save the registers on the old stack, change one
pointer, load the registers from the new stack.

The addresses that matter, from objdump of the demo:

| Name | Address |
|---|---|
| `freertos_risc_v_trap_handler` | `0x80002000` |
| `vTaskSwitchContext` | `0x80001436` |
| the `mret` at the end of the handler | `0x8000212E` |
| `pxCurrentTCB` | `0x80080024` |
| `prvQueueSendTask` (Tx) | `0x8000013A` |
| `prvQueueReceiveTask` (Rx) | `0x800001B6` |
| `prvIdleTask` | `0x80000C94` |

## 2. Run

This chapter has no program of its own. The `riscv32-rtos` machine loads a FreeRTOS demo
from RetroCore's media folder, `RiscV/freertos/`. That demo comes with RetroCore, not with
this course; [Getting RetroCore](../getting-retrocore.md) will say how to get it. Then, with
either program:

```text
retrocore --machine riscv32-rtos
retrocore-cli --machine riscv32-rtos
```

The console shows:

```text
Hello FreeRTOS!
0: Tx: Transfer1
0: Rx: Blink1
0: Tx: Transfer2
0: Rx: Blink2
```

and one more pair each second.

(screenshot: the FreeRTOS console)

## 3. Debug

Start the program with `--dap`, so the machine waits for the debugger:

```text
retrocore --machine riscv32-rtos --dap
retrocore-cli --machine riscv32-rtos --dap
```

The steps use the debugger commands at the program's command line. A DAP client on the debugger
port sees the same session. RetroCore has no VS Code extension for RISC-V yet.

1. Stop where FreeRTOS picks the next task:

   ```text
   break.set 0x80001436
   cpu.continue
   cpu.reg mcause
   cpu.reg mepc
   ```

   `mcause = 0xB`: an `ecall`. `mepc = 0x80001948` is that `ecall`, inside the timer task.
   The timer task has nothing to do, so it gives the hart away.

2. Find the task that is stopping:

   ```text
   mem.dump 0x80080024 --count 4
   mem.dump 0x80082E80
   ```

   `pxCurrentTCB` is `80 2E 08 80`, which is `0x80082E80`. That TCB starts `94 2D 08 80`:
   the saved stack pointer, `0x80082D94`. At byte 52 of the TCB the ASCII column shows the
   task's name, `Tmr Svc`.

3. Read the saved context, 124 bytes from the saved stack pointer:

   ```text
   mem.dump 0x80082D94 --count 124
   ```

   The first word, `4C 19 00 80`, is `0x8000194C`: the instruction after the `ecall`, where
   the timer task will go on. The second, `46 19 00 80`, is its `ra`. The last, at byte 120,
   is `80 18 00 00`: its `mstatus`, `0x1880`.

   (screenshot: the TCB and the saved context)

4. Stop at the `mret` that ends the switch:

   ```text
   break.set 0x8000212E
   cpu.continue
   mem.dump 0x80080024 --count 4
   cpu.reg mepc
   cpu.reg sp
   ```

   `pxCurrentTCB` is now `80 12 08 80`, `0x80081280`, and `mem.dump 0x80081280` shows the
   name `Rx` at byte 52. `mepc = 0x800001B6` is `prvQueueReceiveTask`, the first instruction
   of Rx: Rx has never run, so FreeRTOS made its first saved context when it created the task.
   `sp = 0x80081250` is on Rx's own stack.

5. Step the `mret`:

   ```text
   cpu.step
   cpu.pc
   ```

   `PC = 0x800001B6`. Rx is running.

6. Keep going. Each `cpu.continue` stops first in `vTaskSwitchContext` (the task that stops),
   then at the `mret` (the task that runs next):

   | Stops | `mcause` | `mepc` at the first stop | Runs next | `mepc` at the `mret` |
   |---|---|---|---|---|
   | Rx, TCB `0x80081280` | `0xB` | `0x8000089C`, in `xQueueReceive`: the queue is empty | Tx, TCB `0x80082300` | `0x8000013A`, its first instruction |
   | Tx, TCB `0x80082300` | `0xB` | `0x800013A4`, in `xTaskDelayUntil`: wait one second | IDLE, TCB `0x80082B80` | `0x80000C94`, its first instruction |

7. Now only IDLE can run. From here every 1 ms tick goes through the handler and ends at the
   same `mret`, without a switch. To see the tick that wakes Tx, take that breakpoint away:

   ```text
   break.clear --addr 0x8000212E
   cpu.continue
   cpu.reg mcause
   mem.dump 0x80080024 --count 4
   ```

   `mcause = 0x80000007`: the timer, not an `ecall`. `pxCurrentTCB` is IDLE's,
   `0x80082B80`. `mem.dump 0x0200BFF8` shows `mtime` a little over 10,130,000: one second
   has passed.

8. Set the `mret` breakpoint again and continue:

   ```text
   break.set 0x8000212E
   cpu.continue
   mem.dump 0x80080024 --count 4
   cpu.reg mepc
   ```

   `pxCurrentTCB` is Tx's, `0x80082300`, and `mepc = 0x800013A8`: the instruction after the
   `ecall` where Tx started to wait. The timer took the hart away from IDLE, which never
   asked to stop.

## 4. Try

The demo creates Tx with priority 1, in `main_blinky.c`:

```c
xTaskCreate( prvQueueSendTask, "Tx", configMINIMAL_STACK_SIZE * 2U, NULL,
             mainQUEUE_SEND_TASK_PRIORITY, NULL );
```

Change that one argument to 3, above Rx's 2.

**Predict:** the timer task still runs first, because 6 beats 3. When it gives the hart
away, Tx runs, not Rx: at the first `mret`, `pxCurrentTCB = 0x80082300` and
`mepc = 0x8000013A`.

The priority reaches `xTaskCreate` in register `a4`. In the built demo that is `c.li a4, 1`
at `0x80000288`; `c.li a4, 3` is the half-word `0x470D`. Check it in the debugger: start the
program with `--dap` as in step 3, then before `cpu.continue` type:

```text
mem.write 0x80000288 0D47
break.set 0x8000212E
cpu.continue
mem.dump 0x80080024 --count 4
cpu.reg mepc
```

You see `00 23 08 80` and `mepc = 0x8000013A`.

To rebuild the demo itself with the change, edit `main_blinky.c` in the FreeRTOS checkout that
`build-guests` uses, run `make PICOLIBC=1` in the demo folder, and copy `build/RTOSDemo.axf`
over `RTOSDemo-rv32.axf` in the media root. Do not run `build-guests` for this: it checks out
the pinned release again, which undoes the edit.

RetroCore's unit test `RiscVLabTests.Lab05_Try_TxPriorityThree_RunsTxFirst` writes the same half-word
and checks the result. `Lab05_FirstSwitch_SavesTmrSvc_AndStartsRx` checks steps 1 to 5, and
`RiscVLabDebuggerTests.Lab05_FollowTheSwitches_FromTmrSvcToRx_AndOn` runs every step of this
chapter through the debugger. Without the demo in the media root, these tests fail and say
how to build it.

## 5. Under the hood

The CPU side of a switch is the trap in and the `mret` out. `ecall` runs in `OpECALL` and
`mret` in `OpMRET`, both in
`System.cs`.
Everything between them is FreeRTOS code.
