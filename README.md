# GOLF — the frozen minimal language

A tiny **concatenative, stack-based language** whose compiler is written in
itself and emits standalone **ELF64 x86-64 Linux** executables — no assembler,
no linker, no libc. One ASCII byte per operation.

This is the **`minimal` branch**: the original 760-byte self-hosted compiler,
which compiles itself to a byte-identical binary (strict fixpoint). It is
deliberately tiny — a complete, readable example of a self-compiling compiler —
and it is **frozen**. Nothing here changes except the packaging around it.

```sh
cd minimal
python3 boot/golf0.py < self/golf.golf > golf && chmod +x golf
./golf < examples/hello.golf > hello && chmod +x hello && ./hello   # Hello, world!
bash test/run.sh
```

See [`minimal/README.md`](minimal/README.md) for the full language spec and
[`minimal/self/ANNOTATED.md`](minimal/self/ANNOTATED.md) for a line-by-line
reading of the compiler's own source.

## Where the rest of the language went

The "fully featured" language grown from this one — lists, higher-order
functions, implicit vectorization, tacit combinators, strings, named variables,
per-call locals, syscalls, and a compiler that self-hosts in *its own* expanded
dialect — lives on **`main`**, in `expanded/`. It is not on this branch, and
this branch is not a dependency of it in source form.

## What main consumes from here

`main`'s bootstrap ladder still starts at this compiler:

```
v1c  -->  seed  -->  golf2  -->  golf2'      (fixpoint: golf2 == golf2')
```

but it consumes `v1c` as a **pinned release binary**, not as a source tree. The
`Release (minimal)` workflow builds `v1c` here, verifies the fixpoint, and
publishes it; `main`'s `SEEDS` file pins the tag, asset name and sha256, and its
build downloads and hash-checks the binary. So this branch is the *provenance*
of that seed, and the release is the interface between the two.

`main` also carries two frozen artifacts derived from this tree, because they
are build inputs to the v2 compiler rather than things a binary can supply:

| on `main` | derived from | what it is |
|---|---|---|
| `expanded/data/v1.hex` | `minimal/tools/mkblob.py` | v1's machine-code template blob, as data — the table the v2 blob is built on top of |
| `expanded/self/seed.golfv1` | `minimal/tools/mkblob.py`'s `WORDS` | v1-GOLF compiler source, the rung `v1c` compiles |

The release workflow re-derives `expanded/data/v1.hex` from this branch and
fails the release if it does not match what `main` has committed, so the frozen
copy cannot silently drift from its origin.

## Cutting a release

```sh
git tag minimal-v1.0
git push origin minimal-v1.0
```

`.github/workflows/release-minimal.yml` runs `minimal/test/run.sh` (the full
milestone suite plus the self-hosting fixpoint), builds `v1c`, checks it against
`main`'s pinned artifacts, and publishes `v1c-x86_64-linux`, `golf.golf` and
`SHA256SUMS`. A release therefore cannot be cut from a compiler that does not
reproduce itself. `workflow_dispatch` runs everything but skips publishing — a
dry run.

To point `main` at a new release, bump the tag and sha256 in `main`'s `SEEDS`.
