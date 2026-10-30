# Getting RetroCore

!!! note "Coming soon"
    RetroCore is not published yet. This page will say where to download it as soon as it is.
    The labs are written against it already, so everything below is how they will run.

## Two programs

RetroCore comes as two programs. Either one runs every lab, with the same command line:

| Program | What it is |
|---|---|
| `retrocore` | The RetroCore app: menus, a machine gallery, and the machine's screen in a window. |
| `retrocore-cli` | A plain window with the machine's screen and a command line on top of it. |

## Starting a lab

Open a terminal in the course folder (the one that holds `labs/`) and give the program three
flags:

```text
retrocore --machine riscv32-bare --script labs/00-registers/run.txt
retrocore-cli --machine riscv32-bare --script labs/00-registers/run.txt
```

| Flag | What it does |
|---|---|
| `--machine <id>` | Starts that machine, for example `riscv32-bare` or `riscv64-xv6`. |
| `--script <path>` | Runs a start-up script once the machine is there. A lab's script loads its program with `machine.load <file>`. |
| `--dap` | Turns the debugger on and holds the machine before its first instruction, so you can set breakpoints first. `cpu.continue` runs it. |

Each chapter gives both lines; use whichever program you have.

## The command line

Every chapter types commands such as `cpu.reg a0`, `break.set 0x80000000` and `cpu.step`.

- In `retrocore-cli`, press **F12** to show and hide the command line.
- In `retrocore`, open the **Console** panel: **View > Console**, or the **>_ Console** button.

`help` lists every command.

## Another debugger

With `--dap` the program also listens for debugger clients that speak the Debug Adapter
Protocol (DAP), on the debugger port: 4711 for `retrocore-cli`, and for `retrocore` the port
set in Preferences > DAP (4712 unless you change it). `--dap=<port>` picks the port for one
run in either program. Such a client sees the same breakpoints and registers as the
command line. RetroCore has no VS Code extension for RISC-V yet, so the chapters use the
command line.
