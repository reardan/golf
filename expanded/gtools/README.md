# `gtools/` — the repo's own build tools, written in GOLF

The compiler's *logic* has been written in GOLF since M-SELF
([`self/golf2.golfj`](../self/golf2.golfj)). Everything *around* it — assembling
the template blob, encoding glyph source into raw code-page bytes — was still
Python. This directory is the other half: the same tools, written in expanded
GOLF, compiled by the compiler they help build.

They **shadow** the Python originals; they do not replace them.
[`tools/mkblob2.py`](../tools/mkblob2.py) and
[`tools/codepage.py`](../tools/codepage.py) remain the source of truth and the
build path, exactly as [`boot/golfref.py`](../boot/golfref.py) shadows the
compiler without ever being on the bootstrap ladder. What makes the GOLF version
trustworthy is [`test/gtools.sh`](../test/gtools.sh): every tool here must emit
**byte-identical** output to its Python counterpart, for every real source file
in the repo. The ladder never depends on a tool in this directory, so the
`golf2 == golf2'` fixpoint stays exactly as trustworthy as it was before.

## Building and running

```sh
gtools/build gtools/encode.golfj build/gencode      # prelude + tool libs + program
build/gencode < self/golf2.golfj > /tmp/out.gb
```

`gtools/build` is `tools/golfc` plus the tool libraries: it concatenates
`lib/prelude.golfj`, then every `lib/t*.golfj`, then the program, and compiles
the lot with the freshly bootstrapped `golf2`.

## What makes this possible

Two additions in wave 8 (M-TOOL), both recorded in [`../REGISTRY.md`](../REGISTRY.md):

- **`⎈` `\sys` (byte `0xA7`)** — a raw syscall, `a1 a2 a3 num ⎈ -> result`. Three
  arguments is exactly enough for `open`/`read`/`write`/`close`/`exit`/`brk`.
  Before it, GOLF's entire I/O surface was one byte in from fd 0 and one byte
  out to fd 1.
- **the entry-`rsp` cell** (`0x4F0040`) — `STARTUP` stashes the stack pointer as
  the kernel left it, before anything is pushed, which is the only moment `argc`
  and `argv` are reachable. So a tool here can take file paths as arguments.

## Layout

| Path | What |
|------|------|
| `build` | the driver: prelude + `lib/t*.golfj` + program → executable |
| `hexcat.golfj` | hex ⇄ binary; the smoke test for libraries + syscalls + driver |
| `encode.golfj` | `codepage.py encode` in GOLF: glyph/mnemonic source → raw bytes |
| `decode.golfj` | `codepage.py decode` in GOLF, including `-m` mnemonic form |
| `mkblob.golfj` | `data/blob.hex` → the `` ` `` blob escape, as `mkblob2.blob_escape()` emits it |
| `mkgolf2.golfj` | the capstone: encode `self/golf2.golfj`, splice the blob, write `self/golf2.golf` |

The shared GOLF words these programs are built from live one level up, in
[`../lib/`](../lib): `tio.golfj` (files, streams, argv), `ttext.golfj` (byte
buffers, compare/find/slice, decimal and hex parsing), `tutf.golfj` (the
`data/codepage.tsv` loader and glyph matching). They take **lowercase** letters —
a pool the prelude has never touched — so adding a tool word costs nothing
scarce. See `../REGISTRY.md` §2.1.

The two tables they read — [`../data/codepage.tsv`](../data/codepage.tsv) (byte
· mode · source · mnemonic · hex-encoded glyph, one row per code-page entry) and
[`../data/blob.hex`](../data/blob.hex) (one `[key][len][data]` blob record per
line, in emission order with the M-VEC overrides already substituted) — are
**generated and checked in**. [`../tools/mktables.py`](../tools/mktables.py)
writes them from `mkblob2.ATOMS` and `codepage.COMPILER`/`LIB`, so the Python
tables stay the single source of truth and the registry discipline still applies
to every byte; the GOLF tools only ever read the serialised form, because they
cannot read a Python literal (and cannot carry the glyphs as GOLF string
literals either — a `“...“` block cannot contain byte `0x8E`). Regenerate with
`python3 tools/mktables.py` after touching either table; `test/selfcheck.sh`
fails if what is committed is stale.

## Not ported — no longer on purpose

`mkblob2.build_seed()` is still Python, but the reason it *had* to be is gone.
It used to reuse `minimal/tools/mkblob.py`'s `WORDS` — the v1 compiler's own
source text — and its `golf()` substring-rewrite pass, so porting it would have
duplicated source that lived in the frozen `minimal/` tree, and a second copy of
that string is exactly the kind of drift this repo's whole test discipline
exists to prevent.

Since the minimal language moved to its own branch, the seed's source is
`self/seed.golfv1` in this tree and `build_seed()` does what `mkgolf2` already
does — strip comments and whitespace, splice the blob in at `@BLOB@`. The only
difference is which comment syntax it strips. It is now an ordinary candidate
for the next rung rather than a standing exception.
