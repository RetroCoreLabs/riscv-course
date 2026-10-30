# Contributing to riscv-course

Thanks for looking. This file says how the course is laid out, what every page must look like,
and what will get a change sent back.

---

## What is where

| Folder | What is in it |
|---|---|
| `docs/` | The pages. `index.md` is the front page; `labs/` holds one chapter per topic, `extensions/` one page per RISC-V extension, `support-matrix.md` the one support table. |
| `docs/assets/` | The course icon and the pictures the pages use. |
| `labs/<nn>-<name>/` | One folder per chapter: the program source, its link script, the ready-built ELF files and the start-up script (`run.txt`) that RetroCore runs with `--script`. |
| `docs-site/` | The web site's settings (`mkdocs.yml`) and the pinned build tools (`requirements.txt`). |
| `eng/` | `check-docs.py`, the document checker, and its waivers. |

## Checking a change

```text
python eng/check-docs.py
pip install -r docs-site/requirements.txt
mkdocs build --strict -f docs-site/mkdocs.yml -d <a folder outside the checkout>
```

Both must pass. `--strict` turns a broken link or a missing anchor into a failed build. The
workflow in `.github/workflows/docs.yml` runs the same two steps on every pull request.

> [!WARNING]
> **Never put an absolute path in anything committed here.** A drive letter or a home directory is
> correct on exactly one machine, and this repository is public. `check-docs.py` fails on one.

## Page shapes

**A lab chapter** has the same five steps every time:

1. **Concept**: plain words, one picture.
2. **Run**: a ready-built ELF file, started with one command line for each program:

    ```text
    retrocore --machine <id> --script labs/<nn>-<name>/run.txt
    retrocore-cli --machine <id> --script labs/<nn>-<name>/run.txt
    ```

    Always name the programs. Never a build command such as `dotnet run`.
3. **Debug**: a guided session started with `--dap`. Breakpoint, step, registers by ABI name,
   CSRs, memory, the UART.
4. **Try**: change one line, predict the result, check it.
5. **Under the hood**: the RetroCore file and handler that does it, by name. No code walk-through.

**An extension page**: what it adds, why it exists, what it is used for, key instructions with
one example each, who needs it (its row in `support-matrix.md`), and how RetroCore handles it.

## Rules

- Write from what the emulator really does today. Never describe a plan as if it were working.
- A support-matrix cell becomes a tick only when a RetroCore test proves it.
- A chapter's numbers come from running it. When a lab program changes, rebuild its ELF files
  with the command the chapter gives, and run the chapter again.
- Plain words. Short sentences.
- Name the licence of anything quoted: the RISC-V specifications, `riscv-tests`, SoftFloat.
- Do not copy code or text from other emulators.

## Submitting a change

1. Branch off `main`. Do not commit to `main` directly.
2. One logical change per commit, with a message that says what changed and why.
3. Say in the pull request what you checked and how.

## Licence

By contributing you agree your work is licensed under the MIT licence in [LICENSE](../LICENSE).
