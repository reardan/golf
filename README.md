# GOLF

A tiny **concatenative, stack-based programming language** whose compiler is
written in itself and emits standalone **ELF64 x86-64 Linux** executables — no
assembler, no linker, no libc. Every token is a single ASCII byte. The whole
design exists to make one number small: the size of the self-hosted compiler.

**Self-hosted compiler: `self/golf.golf` — 809 bytes.** It compiles itself to a
byte-identical binary (strict fixpoint).

Inspiration: [Jelly](https://github.com/DennisMitchell/jellylanguage) (one byte =
one operation, maximal terseness) and
[cc500](https://homepage.ntlworld.com/edmund.grimley-evans/cc500/) /
[StoneKnifeForth](https://github.com/kragen/stoneknifeforth) (a compiler small
enough to read in one sitting that compiles itself).

```
   source (stdin)  ──►  compiler  ──►  ELF64 executable (stdout)
```

## Quick start

```sh
# bootstrap the self-hosted compiler with the Python reference compiler
python3 boot/golf0.py < self/golf.golf > golf && chmod +x golf

# now use it: it reads GOLF source on stdin, writes an executable on stdout
./golf < examples/hello.golf > hello && chmod +x hello && ./hello   # Hello, world!
./golf < examples/fizzbuzz.golf > fb && chmod +x fb && ./fb          # 1 2 Fizz 4 Buzz ...

# it compiles itself, identically, forever:
./golf < self/golf.golf > golf2 && cmp golf golf2 && echo same

# run the full suite (milestones + fixpoint)
bash test/run.sh
```

## The language

The machine has two stacks. The **data stack** is the hardware `rsp`; every value
is a 64-bit integer. The **return stack** is a separate region addressed by `rbp`.
There is a flat 4 KiB **data region** for variables and a 256-entry dictionary.

Programs are read left to right. Each op is one byte. Numbers are the only
multi-byte tokens.

### Truth convention: **zero is true**

`[block]` runs its block when the top of stack is `0`. This makes `-` double as an
equality test (`a b -` is `0` exactly when `a == b`), so there is no separate `=`
op. The unsigned-compare idiom `a b <1+` yields `0` (true) exactly when `a < b`.

### Operations

| Op  | Effect | Op  | Effect |
|-----|--------|-----|--------|
| `"` | dup    | `@` | fetch 32-bit `addr → v` |
| `_` | drop   | `!` | store 32-bit `v addr →` |
| `\` | swap   | `?` | fetch byte `addr → b` |
| `&` | over   | `,` | store byte `v addr →` |
| `+` | add    | `(` | read a byte from stdin (`→ b`, `0` at EOF) |
| `-` | sub / equality test | `)` | write low byte to stdout (`b →`) |
| `*` | multiply | `.` | `exit(status)` |
| `/` | unsigned divide | `^` | return early from the current word |
| `%` | unsigned modulo | | |
| `<` | unsigned less → `-1`/`0` | | |

### Special forms

| Syntax | Meaning |
|--------|---------|
| `0`-`9` | integer literal (greedy, multi-digit) → push |
| `'c` | character literal: push the byte after the quote |
| `:x … ;` | define word named `x` (any byte); must be defined before use |
| `[ … ]` | if: run the block when top-of-stack is `0` |
| `{ … }` | loop: at `}`, jump back to `{` while top-of-stack is `0` |
| `` `N␠bbb… `` | raw blob: `N` (decimal) then one space then `N` literal bytes are copied into the output program, wrapped in a jump; pushes the runtime address of those bytes |
| `#` | comment to end of line |
| byte ≤ 32 | whitespace (only meaningful between two numbers) |
| any other byte | call the word of that name |

Word names are single bytes, so the dictionary is a flat 256-slot array — no name
table, no hashing.

### Example — a `cat`

```
{("[0.])0}      # loop: read a byte; if it's 0 (EOF) exit(0); else write it
```

## How compilation works

There is no parser and no AST. The compiler is a single left-to-right pass:

1. **Tokenize** one byte at a time.
2. For a "dumb" op, **copy a fixed machine-code template** for it into the output
   buffer. For literals/definitions/control-flow, run a small handler.
3. **Backpatch** the 32-bit relative offsets of forward jumps (`[ … ]`) and word
   definitions once their targets are known.
4. Prepend a fixed ELF header, append `exit(0)`, and write the buffer out.

The self-hosted compiler is **table-driven**: 18 dumb ops are compiled by copying
bytes from one raw-byte *blob* embedded in the source, so per-op emission code
costs almost nothing. Only ~10 "smart" ops have real handlers.

The single cleverest trick is that the compile-time **backpatch stack is the
compiler's own data stack**. Opening a block (`:` `[` `{`) pushes one patch
address; closing it (`;` `]` `}`) pops one. Because the token loop is otherwise
stack-neutral and a called word never leaves its return address on the data stack
(the prologue moves it to the return stack), those pending patches simply sit at
the bottom of the stack across iterations. No separate stack structure exists.

## Runtime & binary layout

- **Load address** `0x400000`; a single **RWX `PT_LOAD`** segment maps the whole
  file. Entry point is `0x400078`, right after the 120-byte header.
- The header is **fully static** — `p_filesz` is a fixed `0x10000` and `p_memsz`
  is `0x800000`, so nothing in the header is ever backpatched. Pages past the real
  end of file are never touched. The BSS tail (file end → `p_memsz`) provides
  zeroed memory for the data region and the return stack.
- **Data region** `D = 0x410000` (BSS): a few scalar variables at `D+0…D+16`, the
  dictionary at `D+2048` (256 × 4 bytes), and the compiler's output buffer at
  `B = D+4096`.
- **Return stack** grows down from `0xC00000`; the **data stack** is the kernel's
  initial stack. I/O is one `read`/`write` syscall per byte — plenty fast at this
  scale, and the output is buffered in memory anyway because backpatching needs
  random access.

Exact header bytes and every machine-code template live in `boot/golf0.py`
(`HEADER`, `TEMPLATES`, `PROLOGUE`, …) — the single source of truth.

## Repository layout

| Path | What |
|------|------|
| `boot/golf0.py` | Stage-0 reference compiler in Python (clarity, not golfed). Bootstraps everything. |
| `self/golf.golf` | **The self-hosted compiler — the golfed artifact.** Contains raw blob bytes. |
| `self/ANNOTATED.md` | A human-readable, exploded listing of `self/golf.golf`. |
| `tools/mkblob.py` | Regenerates `self/golf.golf` from readable code sections + the template blob (imported from `golf0.py`). Edit the compiler here, not in the binary file. |
| `examples/` | `hello.golf`, `fizzbuzz.golf`. |
| `test/run.sh` | Milestones M1–M4 and the self-hosting fixpoint. |

Because `self/golf.golf` contains raw bytes (the template blob) that text editors
would corrupt, **edit `tools/mkblob.py` and regenerate**:

```sh
python3 tools/mkblob.py && bash test/run.sh
```

## Verification

`test/run.sh` builds and runs small programs for every op, compiles both examples,
and then performs the bootstrap:

```
stage1 = golf0(golf.golf)        # Python compiles the compiler
stage2 = stage1(golf.golf)       # the compiler compiles itself
stage3 = stage2(golf.golf)       # and again
require stage2 == stage3         # fixpoint (this build also gives stage1 == stage2)
```

## Limits & caveats

- Linux x86-64 only. The segment is RWX; hardened kernels that forbid RWX
  mappings will refuse to run the output.
- `/` and `%` are unsigned; division by zero raises `SIGFPE` (not defended).
- 32-bit memory cells and address space — every value the compiler manipulates is
  well under `2³¹`. Integer literals must be `< 2³¹`; make negatives with `0 n -`.
- The compiler does no error checking: malformed input miscompiles silently. The
  Python reference compiler (`golf0.py`) does validate and is the one to debug with.
