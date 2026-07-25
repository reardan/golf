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
golf0.py --> v1c --> stage1 --> stage2 --> stage3 --> your v2 programs
                                ^^^^^^^^^^^^^^^^^^
                                fixpoint: stage2 == stage3
```

Every compiler built from `self/golf2.golf` embeds the same template blob, so the
chain converges after two iterations and **stage2 == stage3** is the fixpoint that
gates the build. `stage1 == stage2` holds as well today, but only because golf2's
blob overrides none of v1's op templates; the moment it overrides one, v1c and
golf2 emit different code for the same source and only the stage2/stage3 rung
stays byte-identical.

A **Jelly-style** language: operators are single bytes from the full 0..255
space, shown as glyphs; `tools/codepage.py` converts glyph/mnemonic source ⇄ raw
bytes and the compiler dispatches any byte in its template table. What it can do
now, all while the compiler keeps self-hosting to a byte-identical fixpoint:

- **29 operator atoms** — arithmetic, bitwise/shift, comparison, min/max, signed
  div/mod, negate/inc/dec/square/double/halve.
- a **list type** (heap `[len, e0, …]`) with a GOLF standard library
  (`lib/prelude.golfj`): range, len, index, sum, product, reverse, filter, and a
  number/list printer.
- **higher-order functions** via quotations — `′f`/`′atom` push a callable, `⍎`
  calls it — so `map`, `fold`, and `zip` work; `4⍳4⍳′*⊞∑` is a dot product.
- **strings** as `“...“` byte blocks that convert to code lists, so every list op
  works on them (`“Hello“U′⊕€J` maps +1 → `Ifmmp`).
- **named variables** `→x`/`←x`, so `←a←b+←a←b-*` is `(a+b)*(a-b)` with no juggling.

So `100⍳∑Ṅ` prints `4950`, and `3→k:f←k+;“Hello“U′f€J` is a Caesar cipher. The
plan and status live in [`expanded/DESIGN.md`](expanded/DESIGN.md); the
prioritized queue of what's next is [`expanded/NEXT_STEPS.md`](expanded/NEXT_STEPS.md).

```sh
cd expanded
bash test/run2.sh
python3 tools/codepage.py table                        # atoms + library glyphs
tools/golfc -j examples/capstone.golfj out && ./out    # compile a glyph program
```

## The idea, in one paragraph

No parser, no AST. The compiler tokenizes one byte at a time, copies a fixed
machine-code template per op, concatenates the bytes, and backpatches the 32-bit
relative offsets of forward jumps. A single embedded blob of templates makes
adding a "dumb" operator cost nothing but its bytes. The whole thing is validated
by a three-stage bootstrap that must come out byte-identical.
