# GOLF

A tiny **concatenative, stack-based language** whose compiler is written in
itself and emits standalone **ELF64 x86-64 Linux** executables — no assembler,
no linker, no libc. One ASCII byte per operation.

## The minimal language — frozen, and on its own branch

The original is a **760-byte self-hosted compiler** that compiles itself to a
byte-identical binary (strict fixpoint): deliberately tiny, a complete and
readable example of a self-compiling compiler. It is **frozen**, and it lives on
the [**`minimal`**](../../tree/minimal) branch (tag `v1.0-minimal`) rather than
in this tree.

This branch consumes it as a **pinned release binary**. [`SEEDS`](SEEDS) names a
release tag, an asset and a sha256; `expanded/tools/seed.sh` downloads `v1c` on
first use and refuses to run it if the hash does not match. That is the only
thing here that comes from outside the tree, and the only network the build ever
needs.

```sh
git checkout minimal        # the frozen v1 language, its spec and its tests
```

## [`expanded/`](expanded/) — the "fully featured" language (in progress)

A usable language grown from the minimal one, one testable milestone at a time,
**without ever breaking the self-hosting bootstrap**. The neat part is the
bootstrap ladder: the frozen minimal compiler (v1) compiles the expanded
compiler's seed, which then self-hosts.

```
v1c --> seed --> golf2 --> golf2' --> your v2 programs
 ^               ^^^^^^^^^^^^^^^^
 |               fixpoint: golf2 == golf2'
 pinned release binary (SEEDS)
```

The compiler's logic is written in **v2 GOLF** (`expanded/self/golf2.golfj` —
named variables, one op per line), so the last rung is a true self-hosting
fixpoint: golf2 compiles its own source back to itself, byte for byte, and
**golf2 == golf2'** gates the build.

`self/seed.golf` is the bootstrap rung only: the same compiler written in v1
GOLF (hand-edited as `self/seed.golfv1`), so that `v1c` — which has never heard
of v2 — can build something able to
compile `golf2.golf`. v1c carries *v1's* template blob and so emits different
code, but that divergence stops at the v1c→seed rung; `seed` is only ever used to
produce golf2. That the two source forms really are one compiler is gated
separately, by `expanded/test/selfcheck.sh`: `seed` and `golf2` must emit
byte-identical binaries for every input.

A **Jelly-style** language: operators are single bytes from the full 0..255
space, shown as glyphs; `tools/codepage.py` converts glyph/mnemonic source ⇄ raw
bytes and the compiler dispatches any byte in its template table. What it can do
now, all while the compiler keeps self-hosting to a byte-identical fixpoint:

- **32 operator atoms** — arithmetic, bitwise/shift, comparison, min/max, signed
  div/mod, shifts, 64-bit fetch/store, `brk`, negate/inc/dec/square/double/halve.
- a **list type** on a `brk`-grown heap (`[len, e0, …]`, 64-bit cells) with a
  GOLF standard library (`lib/prelude.golfj`): range, len, index, sum, product,
  reverse, filter, and a number/list printer.
- **higher-order functions** via quotations — `′f`/`′atom` push a callable, `⍎`
  calls it — so `map`, `fold`, and `zip` work; `5⍳′²€∑` is a sum of squares.
- **implicit vectorization** — the bare `+ - * ⌈ ⌊` dispatch on the *shape* of
  their operands, so the operator is the loop: `4⍳4⍳*∑` is a dot product and
  `4⍳3+` is `3 4 5 6`. The explicit pre-M-VEC spellings still work and stay
  regression-tested: `4⍳4⍳′*⊞∑` is that same dot product the long way.
- **tacit combinators** built at runtime — `∘` compose, `⇉` pipeline, `⑂` fork,
  so `5⍳′∑′≢′÷⑂` is a mean.
- **chain definitions** — `⊚name f g h;` defines a word as a train of links and
  the compiler supplies every `′`, so `⊚m∑≢÷;` *is* `:m′∑′≢′÷⑂;`, byte for byte.
  The link count picks the shape: one is a call, two compose, three fork.
- **strings** as `“...“` byte blocks that convert to code lists, so every list op
  works on them: `“Hello“U1+J` maps +1 → `Ifmmp` (long form: `“Hello“U′⊕€J`).
- **named variables** `→x`/`←x` over a 64-bit-per-name bank, so `←a←b+←a←b-*` is
  `(a+b)*(a-b)` with no juggling — and, since M-FRAME, **per-call locals**:
  that bank is global, so `⊡name … ;` defines a word owning a frame of eight
  slots reached by `⇒x`/`⇐x`, and `⊡s"0-[_0^]⇒a⇐a1-s⇐a+;` sums `1..n` correctly
  at depth where the global spelling quietly returns `n`.
- **syscalls and files** — `⎈` (`\sys`) is a raw three-argument syscall and
  `STARTUP` stashes the entry `rsp`, so a GOLF program can open a file and read
  its own `argv` instead of being a stdin-to-stdout filter forever.
- **the repo's own build tools, written in GOLF** — `expanded/gtools/` holds
  `encode`, `decode`, `mkblob`, `mkgolf2` and `hexcat`. They *shadow* the Python
  originals rather than replacing them, and `test/gtools.sh` requires
  byte-identical output over the repo's real sources. `mkblob | encode |
  mkgolf2` regenerates the compiler's own source with no Python in the pipeline,
  and that source still reaches the `golf2 == golf2'` fixpoint.

So `100⍳∑Ṅ` prints `4950`, and a Caesar cipher is `3→k“Hello“U←k+J` — which
before implicit vectorization needed a closure, `3→k:f←k+;“Hello“U′f€J`. Both
spellings are compiled and output-checked by the suite, as
`examples/capstone.golfj` and its `examples/legacy_capstone.golfj` twin.

The design, the shipped record and the known limits live in
[`expanded/DESIGN.md`](expanded/DESIGN.md); the prioritized queue of what's next
is [`expanded/NEXT_STEPS.md`](expanded/NEXT_STEPS.md). What the language still
lacks measured against the two it sits between — and which of that is refused
rather than unbuilt — is [`expanded/GAPS.md`](expanded/GAPS.md).

```sh
cd expanded
bash test/run2.sh                                      # ladder + language + docs
bash test/selfcheck.sh                                 # seed and golf2 are one compiler
bash test/gtools.sh                                    # the GOLF tools match their Python twins
python3 tools/codepage.py table                        # atoms + library glyphs
tools/golfc -j examples/capstone.golfj out && ./out    # compile a glyph program
```

The first of those downloads `v1c` per [`SEEDS`](SEEDS) and leaves it at `./v1c`
(gitignored); everything after is offline. To build the seed yourself instead of
trusting the release, check out the `minimal` branch, run its
`python3 minimal/boot/golf0.py < minimal/self/golf.golf`, and point at the
result:

```sh
GOLF_V1C=/path/to/v1c bash test/run2.sh
```

`bash test/run2.sh` is **298 assertions green**, the fixpoint included. Every
number quoted in this README and in `expanded/DESIGN.md` — atom count, artifact
sizes, this assertion count — is itself asserted by that suite, so a doc that
drifts out of date fails the build instead of lying quietly.

## The idea, in one paragraph

No parser, no AST. The compiler tokenizes one byte at a time, copies a fixed
machine-code template per op, concatenates the bytes, and backpatches the 32-bit
relative offsets of forward jumps. A single embedded blob of templates makes
adding a "dumb" operator cost nothing but its bytes. The whole thing is validated
by a three-stage bootstrap that must come out byte-identical.
