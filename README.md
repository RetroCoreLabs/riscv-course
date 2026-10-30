# riscv-course

[![site](https://github.com/RetroCoreLabs/riscv-course/actions/workflows/docs.yml/badge.svg)](https://github.com/RetroCoreLabs/riscv-course/actions/workflows/docs.yml)
[![website](https://img.shields.io/website?url=https%3A%2F%2Fretrocorelabs.github.io%2Friscv-course%2F&label=retrocorelabs.github.io)](https://retrocorelabs.github.io/riscv-course/)
[![licence](https://img.shields.io/github/license/RetroCoreLabs/riscv-course)](LICENSE)
[![last commit](https://img.shields.io/github/last-commit/RetroCoreLabs/riscv-course)](https://github.com/RetroCoreLabs/riscv-course/commits/main)

**riscv-course is a free course that teaches the RISC-V instruction set by running real programs on an emulated RISC-V machine and stepping through them in a debugger.**

[Read it](https://retrocorelabs.github.io/riscv-course/) · [What is in it](#what-you-can-use-it-for) · [Quick start](#quick-start) · [About RISC-V](#about-risc-v)

## Why it exists

Most RISC-V material either describes the instruction set on paper or starts from a full
Linux system. Neither lets you watch one instruction change one register. This course puts a
small, ready-built program in front of every topic and a debugger on every step, so each idea
is something you see happen.

The machine it runs on is RetroCore, an emulator for old and not-so-old computers. RetroCore
is not published yet; the course's [Getting RetroCore](https://retrocorelabs.github.io/riscv-course/getting-retrocore/)
page will say where to get it.

## What you can use it for

- **Learn the base instruction set** - registers, encodings, loads, stores, branches and the
  calling convention, one step at a time.
- **See how an operating system meets the hardware** - traps, timers, privilege levels,
  delegation, Sv39 paging, a virtio disk and the OpenSBI hand-over to Linux.
- **Look up an extension** - one page each for I, M, A, F, D, C, Zicsr, S and the rest: what it
  adds, why it exists, and who needs it.

## Status

- Eleven lab chapters (0 to 10), fifteen extension pages and a support matrix.
- Every chapter's steps are checked by RetroCore's own unit tests, which run each lab and its
  debugger session.
- RetroCore itself is not public yet, so the labs can be read but not run until it is.

## Prerequisites

| # | Requirement | Needed for | How to check |
|---|---|---|---|
| P1 | RetroCore (`retrocore` or `retrocore-cli`) | running the labs | coming soon, see Getting RetroCore |
| P2 | The RISC-V GCC bare-metal toolchain (`riscv64-unknown-elf-gcc`) | only when you change a lab program | `riscv64-unknown-elf-gcc --version` |
| P3 | Python 3 and the packages in `docs-site/requirements.txt` | only to build the web site yourself | `python --version` |

## Quick start

Read the course on its [web site](https://retrocorelabs.github.io/riscv-course/). To run a lab,
clone this repository, open a terminal in it, and start either RetroCore program:

```text
retrocore --machine riscv32-bare --script labs/00-registers/run.txt
retrocore-cli --machine riscv32-bare --script labs/00-registers/run.txt
```

## Building from source

The site is MkDocs Material. The pages are in `docs/`, the settings in `docs-site/`:

```text
pip install -r docs-site/requirements.txt
mkdocs build --strict -f docs-site/mkdocs.yml -d <a folder outside the checkout>
```

Every push to `main` builds the site the same way and publishes it to GitHub Pages.

## About RISC-V

RISC-V is an open instruction set, started at the University of California, Berkeley in 2010
and now looked after by RISC-V International. Anyone may build a RISC-V processor without a
licence fee, which is why it is used in everything from small microcontrollers to Linux
servers. Its base is small and fixed; everything else comes as named extensions you pick. The
specifications are at [riscv.org](https://riscv.org/specifications/).

## Documentation

- [The course](https://retrocorelabs.github.io/riscv-course/) - the web site, built from `docs/`
- [The labs](docs/labs/README.md) - the chapter list
- [The lab files](labs/) - programs, link scripts, ready-built ELF files and start-up scripts

## Contributing

See [CONTRIBUTING.md](.github/CONTRIBUTING.md). Security problems go through
[SECURITY.md](.github/SECURITY.md), never a public issue.

## Licence

MIT. See [LICENSE](LICENSE).
