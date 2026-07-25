# GOLF

A tiny **concatenative, stack-based language** whose compiler is written in
itself and emits standalone **ELF64 x86-64 Linux** executables — no assembler,
no linker, no libc. One ASCII byte per operation.

This repo holds two versions:

## [`minimal/`](minimal/) — the frozen minimal language

The original: a **760-byte self-hosted compiler** that compiles itself to a
byte-identical binary (strict fixpoint). Deliberately tiny; a complete, readable
example of a self-compiling compiler. This version is **frozen** (git tag
`v1.0-minimal`) and won't change.

```sh
cd minimal
python3 boot/golf0.py < self/golf.golf > golf && chmod +x golf
./golf < examples/hello.golf > hello && chmod +x hello && ./hello   # Hello, world!
bash test/run.sh
```

See [`minimal/README.md`](minimal/README.md) for the full language spec.

## [`expanded/`](expanded/) — the "fully featured" language (in progress)

A usable language grown from the minimal one, one testable milestone at a time,
**without ever breaking the self-hosting bootstrap**. The neat part is the
bootstrap ladder: the frozen minimal compiler (v1) compiles the expanded
compiler's seed, which then self-hosts.

```
golf0.py --> v1c --> golf2 --> golf2  (fixpoint) --> your v2 programs
```

It's heading in a **Jelly-style code page** direction: operators are single bytes
from the full 0..255 space, shown as glyphs, so `3\sqr` (authored in ASCII)
becomes `3²` and compiles to two raw bytes. `tools/codepage.py` converts between
the glyph/mnemonic form and raw bytes; the compiler reads the raw bytes and
already dispatches any byte it finds in its template table. The plan lives in
[`expanded/DESIGN.md`](expanded/DESIGN.md).

```sh
cd expanded
bash test/run2.sh
python3 tools/codepage.py table                 # see the atom code page
python3 tools/codepage.py encode <examples/atoms.golfj >a.gb   # -> raw bytes
```

## The idea, in one paragraph

No parser, no AST. The compiler tokenizes one byte at a time, copies a fixed
machine-code template per op, concatenates the bytes, and backpatches the 32-bit
relative offsets of forward jumps. A single embedded blob of templates makes
adding a "dumb" operator cost nothing but its bytes. The whole thing is validated
by a three-stage bootstrap that must come out byte-identical.
