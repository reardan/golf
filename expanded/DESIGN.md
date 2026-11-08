# Expanded GOLF (v2) — design & roadmap

This is the evolving, "fully featured" version of GOLF. The minimal 760-byte
self-hosting compiler is frozen on the `minimal` branch (tag `v1.0-minimal`) and
reaches this tree as a pinned release binary (`../SEEDS`); nothing
here changes it. The goal here is a language you'd actually write real programs
in, grown one testable milestone at a time while **never breaking the
self-hosting bootstrap**.

## Vision: hybrid

Two useful languages hide inside GOLF:

1. **A usable minimal language** (Forth/C-flavored): multi-character names,
   locals & parameters, signed 64-bit values, a small standard library. The core
   you can write programs — and the rest of the compiler — in.
2. **A terse golf surface** (Jelly-flavored), via a **code page**: operators are
   single bytes from the full 0..255 space, each shown as a glyph. The minimal
   ASCII language stays valid underneath (bytes 0..127); the golf atoms live at
   0x80+. See "Code page" below.

The plan was (1) then (2); what actually happened was (2) then most of (1). The
code page removed the pressure that multi-character names were supposed to
relieve, so the golf surface, the library and 64-bit values came first. Per-call
locals landed with M-FRAME (`⊡name … ;`, slots `a`–`h`), and **multi-character
names** with M2 (W9-3A): `‹name›` stands wherever a one-byte name can, and may
be used before its definition — locals included, since M-FRAME2 (W9-4D) sized
each `⊡` frame to the locals its word names.

Bytes 128..255 were entirely unused and the compiler's `e` word already
dispatches *any* byte it finds in the template blob, so the code page costs
almost nothing on the compiler side. It is a better answer to "GOLF ran out of
single-byte op slots" than multi-character identifiers, and it leans into the
golf heritage. Multi-char identifiers (M2, shipped as `‹name›`) are *optional*
— useful for readable user-defined names, but not required to grow the built-in
op set; a program that never writes `‹` compiles to exactly the bytes it did
before them.

## Code page (Jelly-style)

Like Jelly, the canonical program form is raw bytes, one byte per operation, and
humans read/write them through a code page. `tools/mkblob2.py` is the single
source of truth: each atom has a byte, a display glyph, an ASCII mnemonic, and a
machine-code template. `tools/codepage.py` converts between forms:

```
codepage.py encode <prog.golfj >prog.gb   # \sqr / glyph / ASCII  ->  raw bytes
codepage.py decode <prog.gb               # raw bytes  ->  glyphs (3² 4⊕ …)
codepage.py decode -m <prog.gb            # raw bytes  ->  ASCII \mnemonic form
codepage.py table                         # the atom reference
codepage.py reference                     # the same, as REFERENCE.md's Markdown
```

Author in ASCII with `\`-mnemonics (`3\sqr` = "3 squared"), store as raw bytes,
compile with `golf2`. The round-trip is exact. First atoms: `± neg`, `⊕ inc`,
`⊖ dec`, `² sqr`, `⊗ dbl`, `⊘ hlv`, plus the M1 bitwise/shift ops.

## The bootstrap ladder (how v2 gets built)

We keep the property that makes this project worth doing: **there is always a
compiler that can build the current source, and the bootstrap reaches a
byte-identical fixpoint.** The chain is:

```
../SEEDS  --pins------>  v1c      # the frozen minimal compiler, a release binary
v1c       --compiles-->  seed     # self/seed.golf,  compiler logic in v1 GOLF
seed      --compiles-->  golf2    # self/golf2.golf, compiler logic in v2 GOLF
golf2     --compiles-->  golf2'   # same source — require golf2 == golf2'
golf2'    --compiles-->  your v2 programs
```

**Since M-SELF the compiler's logic is written in v2 GOLF.** The source a human
edits is `self/golf2.golfj` — named variables (`→x` / `←x`), one op per line,
every op explained — instead of v1's single-char stack juggling. The last rung is
therefore a *true* self-hosting fixpoint: golf2 compiles its own source back to
itself, byte for byte, in the richer language it grew.

The gate is **golf2 == golf2'**. Both are built from `self/golf2.golf`, so they
embed the same template blob and emit the same code for the same source: the
self-hosted compiler has already converged at iterate 1.

`self/seed.golf` is the **bootstrap rung and nothing more**. It is generated from
`self/seed.golfv1`, the same compiler written in v1 GOLF, purely so `v1c` —
which has never heard of v2 — can build
something able to compile `golf2.golf`. Because v1c embeds *v1's* blob it emits
different bytes than golf2 would, but **that divergence is absorbed at the
v1c→seed rung**: `seed` is only ever used to produce golf2 and is never compared
against anything. (Before M-SELF this showed up as the `seed-stable:`
informational line; there is nothing left to report, so it is retired.)

### Where v1 stops and this tree starts

v1 is frozen and is not a source tree here. It crosses into this one at exactly
three places, and nowhere else:

| what | how it arrives | why it cannot be anything else |
|---|---|---|
| the `v1c` **binary** | pinned in `../SEEDS`, downloaded and sha256-checked by `tools/seed.sh` | it is the one rung nothing in this tree can build; a binary is the whole interface |
| v1's **op templates + ELF header** | `data/v1.hex`, read by `boot/v1.py` | the v2 blob is v1's table plus atoms and overrides, so the table is a build *input*, and a binary cannot hand it over |
| the **seed's compiler source** | `self/seed.golfv1`, hand-edited here | it is v2 logic in v1's language — v1 never had these cases, so this was never v1's to own |

`boot/v1.py` reconstructs everything the old `import golf0` supplied out of those
229 bytes of records: `EPILOGUE` is the template for `^`, and `BASE`/`FILESZ` are
`p_vaddr`/`p_filesz` inside the header record. So the tree builds offline once
the seed is fetched, and no Python from the minimal language is vendored.

The frozen copies cannot drift from their origin unnoticed. Neither branch's CI
can see both trees at once, so the check lives in the one place that does: the
`minimal` branch's release workflow re-derives `data/v1.hex` from
`minimal/tools/mkblob.py` and refuses to publish if the bytes differ, and it
verifies that the `v1c` it is about to publish still walks *this* tree, as
committed, to `golf2 == golf2'`.

Two sources for one compiler is a real risk of drift, so `test/selfcheck.sh`
gates what the ladder cannot see: that `seed` and `golf2` emit **byte-identical
binaries for every input** — they are the same compiler written twice, in two
languages — and that the generated `self/*.golf` are exactly what
`tools/mkblob2.py` emits from `self/golf2.golfj`.

The standing rule is unchanged: golf2's **source must always be compilable by
the current toolchain.** That toolchain is now `seed`, so `golf2.golfj` may use
only ASCII plus the ops the seed implements (the four compiler prefixes and the
atom bytes) — `selfcheck.sh` enforces exactly that. The seed stays as small as
possible: just enough to make the real compiler pleasant to write. New compiler
features go in `golf2.golfj`; `seed.golf` is frozen in shape.

**Reference oracle.** `boot/golfref.py` is v1's Python reference plus v2's new
op templates. It is not on the bootstrap path — it's a debugging oracle to
cross-check the self-hosted `golf2` while a milestone is in flux.

Run everything: `bash test/run2.sh`.

## Where things stand

Every number in this table is asserted by the `W7A` block of `test/run2.sh`
against the thing it describes, so none of it can go stale quietly.

| Measured | Now |
|----------|-----|
| operator atoms in `mkblob2.ATOMS` | **34** |
| the template blob itself | **1278** bytes |
| the generated bootstrap seed (`self/seed.golf`) | **4633** bytes |
| the generated v2 compiler (`self/golf2.golf`) | **15212** bytes |
| assertions in the run2 suite | **869** |
| assertions in the selfcheck suite | **66** |
| assertions in the gtools differential suite | **44** |
| the capstone, in op bytes | **46** |
| the legacy capstone, in op bytes | **54** |
| the v2 p_memsz (`mkblob2.MEMSZ`) | **0x200000** |
| the return-stack top address (`mkblob2.RSTACK_TOP`) | **0x600000** |
| clean return-stack frames | ≈**138**k |

The roadmap that this file used to carry as a plan is now history; the forward
queue lives in [`NEXT_STEPS.md`](NEXT_STEPS.md).

## The record: what shipped

Each milestone was independently testable and had to keep `test/run2.sh` green,
the golf2 fixpoint included. In order:

- **M1 — new operators.** `$ | = ~ >` (AND, OR, XOR, NOT, SHR) as pure templates:
  the compiler's `e` word dispatches *any* byte it finds in the blob, so a "dumb"
  op costs its template and zero compiler-logic change. It also spent the **last**
  five free printable ASCII slots — which is what forced the code page.
- **M-CP — the code page.** The whole 0..255 byte space for ops, rendered through
  glyphs, plus `tools/codepage.py` (encode/decode/table/check). Terse and
  Jelly-like, instead of multi-character identifiers.
- **M-LIST — the list type and a prelude.** A list is a heap block
  `[len, e0, e1, …]`; the library is written in GOLF (`lib/prelude.golfj`,
  prepended by `tools/golfc`), so the compiler's fixpoint never notices it.
- **M-HOF — quotations.** `′name` (compiler prefix) pushes a word's runtime
  address, `⍎` calls one. The first change to golf2's logic vs v1 — and with it
  `map`, `fold`, `filter`, `zip` are ordinary library words.
- **M5 — strings.** `“...“` emits a length-prefixed byte block; `U` turns one
  into a list of char codes, so every list op works on text, and `J` prints a
  code list back. Since W9-1B the encoder treats a literal as *text*: between
  two delimiters (`“` or `\str`, either closes either) the UTF-8 is copied
  verbatim — no mnemonics, no glyph bytes, `#` is not a comment — with `\“` as
  the one escape (the bytes of `“`). The compiler did not change; it still
  copies bytes up to the next `0x8E`.
- **M3 — named variables.** `→x` / `←x` over a name-indexed **global** bank at
  `0x4E0000`: `(a+b)*(a-b)` is `←a←b+←a←b-*`. Global, not per-frame (see limits).
- **M-SOUND — a total list runtime.** Every prelude loop is guarded, so the empty
  list is a fixed point rather than garbage, and `Z` truncates to the shorter of
  its two inputs instead of reading off the end.
- **M-TAG — shape polymorphism as a library.** `T` answers "list or int" by range
  (`v - base <u span` against the runtime heap-bounds cells — a range test that
  M-TAG2 replaced with a real tag), `D` dispatches a binary op on the shapes of
  both operands, and `∔ ∸ ⨰ ⩍ ⩌` are the polymorphic arithmetic words built on it.
- **M-VEC — the bare operators vectorize.** `4⍳3+` is `3 4 5 6`, `4⍳4⍳*∑` is a
  dot product, with no type tag on the value and no change to the compiler's
  logic. Each of `+ - * ⌈ ⌊` keeps its scalar body and gains a preamble (38 bytes
  then, 36 since M-TAG2):
  `cmp qword [hook],0; je scalar` (hook table: 256 cells of 8 bytes at `0x4F0100`,
  indexed by op byte — REGISTRY.md §3), then a conservative `(a|b) <u heap-base`
  filter (exact on the tag since M-TAG2), then `call qword [hook]`. **The prelude is authoritative, not the
  filter:** the hooks point at `∔ ∸ ⨰ ⩌ ⩍`, whose dispatcher re-tests both
  operands with `T` and falls back to the raw scalar op — so a `-1` flag from
  `<`, which the cheap filter cannot reject, is still added, not indexed. The
  prelude's own pointer math uses the never-polymorphic raw atoms
  `﹢ ﹣ ﹡ ⊓ ⊔` (0x91–0x96), so nothing recurses. **Why the bootstrap survives
  it:** the hook cells are BSS and no compiler on the ladder ever runs the
  prelude, so its cells stay zero and it always takes the scalar path.
- **M-CHAIN — tacit combinators.** `∘` compose writes a 39-byte thunk into the
  RWX code arena at `0x4D0000` and returns its address, so composed quotations
  are ordinary callables; `⇉` pipeline and `⑂` fork are built on it —
  `5⍳′∑′≢′÷⑂` is a mean. Library only, no compiler change.
- **M4 — 64 bits, signed, big literals.** List cells and the prelude scratch bank
  widened to 8 bytes (the bank was *relocated* to `0x4F0060` rather than widened
  in place); signed compare/shift atoms (`≺ ≻ ≪ ≫`) and 64-bit `⊙`/`⊛` landed;
  `Ṅ` grew a sign check; and the compiler's `W` word gained a
  `mov rax,imm64; push rax` path for constants that `push imm32` cannot carry.
- **M-SELF — the compiler's source moved to v2 GOLF.** The ladder grew its last
  rung and `self/golf2.golfj` became the file a human edits; `self/seed.golf` was
  demoted to a bootstrap rung, and `test/selfcheck.sh` began gating that the two
  are one compiler.
- **M-MEM — the heap belongs to the kernel.** `⌸` (`brk`, 0xA6) grows the list
  heap on demand, so v2 binaries reserve only what is *statically* addressed:
  `p_memsz` shrank from `0x800000` to `0x200000`, the return stack moved with it
  to `0x600000`, and the heap base/span moved into the runtime cells at
  `0x4F0034`/`0x4F0038` because ASLR means they cannot be spelled out anywhere.
- **M-CHAIN2 — chain definitions.** `⊚name f g h;` (byte `0xB0`) defines a word
  as a *train of links* and lets the compiler supply every `′`: how many links
  there are decides the shape — one is a call, two are two calls, three are
  `′f ′g ′h ⑂`, more are the fork then the rest in turn — so `⊚m∑≢÷;` compiles to
  byte-for-byte what `:m′∑′≢′÷⑂;` compiles to. The count is the whole mechanism:
  only the first three link bytes are buffered, so there is no driver word, no
  new prelude state and no runtime list of quotations. The `′` case's body moved
  into the shared word `X` ("push the address of the word or atom named by this
  byte"), which the chain calls three times. First new compiler logic since
  M-SELF, and the first written in `self/golf2.golfj` as the primary source.
- **M3W — the variable bank goes 64-bit.** The last narrow place on the value
  path: `→x`/`←x` went through a 4-byte-per-name bank and `←x` was a `mov eax`,
  so `4294967296→x←x` was `0` and `0 5-→x←x` was `4294967291`. Stride 4 → 8 plus
  a REX.W on both emitters — in `self/golf2.golfj`, `mkblob2.py`'s v1-GOLF seed
  cases and `boot/golfref.py`, which `selfcheck.sh` gates for drift. 256 names ×
  8 bytes = 2 KB, still inside the `0x4E0000`–`0x4F0000` hole, so no address was
  reallocated. **Every value a GOLF program can hold is now 64 bits wide
  everywhere it can sit.**
- **M-TOOL — the repo's own build scripts, written in GOLF.** The compiler's
  logic moved to GOLF at M-SELF; everything *around* it — assembling the
  template blob, encoding glyph source — stayed Python, because GOLF could not
  reach a file. Its entire I/O surface was `(` and `)`, one byte on fd 0 and fd
  1. Three additions closed that: `⎈` (`\sys`, `0xA7`), a raw syscall
  `a1 a2 a3 num -> result` — three arguments is exactly enough for
  `open`/`read`/`write`/`close`/`exit`, which means `open` (2), not `openat`;
  the entry `rsp` stashed by `STARTUP` at `0x4F0040`, the only moment `argc` and
  `argv` are reachable, since GOLF uses `rsp` as its data stack; and three tool
  libraries on **lowercase** letters (`lib/tio.golfj` files/streams/argv,
  `lib/ttext.golfj` compare/find/slice/parse, `lib/tutf.golfj` the code-page
  table) — a pool the prelude has never touched, so a tool word costs nothing
  from the uppercase budget, which is down to `B` and `C`.
  The tools then landed in `gtools/`: `hexcat`, `encode`, `decode`, `mkblob`,
  and `mkgolf2`. **They shadow the Python originals rather than replacing
  them** — `tools/*.py` stays the build path and the source of truth, exactly
  as `boot/golfref.py` shadows the compiler from off the ladder — and what
  makes them trustworthy is `test/gtools.sh`: byte-identical output to their
  Python counterparts over the repo's real sources, never hand-written
  fixtures. The tables they read (`data/codepage.tsv`, `data/blob.hex`) are
  generated by `tools/mktables.py` and staleness-gated, because a GOLF program
  can read neither a Python literal nor a glyph table held as `“…“` blocks (a
  block cannot contain byte `0x8E`). The end of it: `mkblob | encode |
  mkgolf2` regenerates `self/golf2.golf` byte for byte with no Python in the
  pipeline, and that source still walks the ladder to `golf2 == golf2'`.
  `mkblob2.build_seed()` deliberately stayed Python at the time, because it
  reused the frozen minimal tree's own `WORDS` source text and a second copy of
  that string was the drift this repo's whole test discipline exists to prevent.
  That reason has since expired: the seed's source is `self/seed.golfv1` in this
  tree, and `build_seed()` is now the same strip-and-splice `mkgolf2` already
  does, so a GOLF port is available whenever it is worth the rung.
- **M-DIAG — the two silent failures got names.** GOLF reported nothing, ever;
  these are the first two diagnostics in the language, and both were audited into
  existence by [`GAPS.md`](GAPS.md) rather than hit in normal use.
  **The compose arena is bounded.** `0x4D0000`–`0x4DFFFF` holds exactly 1680
  39-byte thunks, and nothing enforced it: the 1681st `∘` started at `0x4E0017`,
  inside the user variable bank, so a program that composed in a loop overwrote
  its own `→x`/`←x` cells with machine code and ran on to exit 0. `∘` now tests
  the bump pointer and dies at offset 65498. `brk`-growing the arena instead is
  not available — `brk` memory is not executable and a thunk is code — and
  nothing can be freed, since a thunk's address may have escaped anywhere.
  (W12-O2 later took the other road: the prelude makes the brk heap
  executable with `mprotect`, thunks become `A` blocks, and freeing one is
  the program's explicit `⌫`. See Known limits.)
  **An undefined word is reported.** `e` emitted `call rel32` with
  `rel32 = dict[name] - (p+4)` without ever reading `dict[name]`; for a
  never-defined name that cell is BSS-zero, so the *compile* succeeded and the
  binary died with SIGSEGV when the word was reached — the symptom of every typo,
  and of every attempt at mutual recursion. Both compilers now test the slot and
  exit 2; golf2 also writes `GOLF: undefined word <name>` to fd 2, and neither
  leaves a partial binary on fd 1. The whole cost was moving `232o` below the
  lookup so the slot could be tested before a byte was written; `rel32` is
  unchanged, so the fixpoint and `seed == golf2` both held with no adjustment.
  The seed exits 2 *without* a message — v1 GOLF has no way to reach fd 2, and
  fd 1 is carrying the binary — which is the one deliberate divergence between
  the two source forms, and `test/selfcheck.sh` asserts both halves of it rather
  than letting it drift. The `′` path was a separate bug, fixed in W9-1C: `X`
  read any name with no dictionary entry as an atom (that is how `′atom`
  auto-wrapping works), so `′typo` wrapped a template that does not exist and
  the binary died with SIGILL. `X` now also reads the blob, and hands a byte that
  is neither word nor atom to `e` — whose own lookups then fail and give the same
  `GOLF: undefined word <name>`, exit 2 (the seed: exit 2, silently). It covers
  chain links too, since they go through `X`. Cost: 7 bytes of seed, 61 of golf2;
  every program that compiled before compiles to the same bytes.
- **M-FRAME — per-call locals, opt in.** `⊡name … ;` defines a word that owns a
  frame of eight slots; `⇒x` and `⇐x` reach them. It closes the last M3 shortcut:
  the variable bank behind `→x`/`←x` is **global**, one cell per name for the
  whole program, so a recursive word's frames overwrote each other and returned a
  quietly wrong number — `sum 1..10` came back 10 instead of 55.
  **Why it is opt-in, which the plan did not anticipate:** whatever a prologue
  does to `rbp`, the epilogue must undo — and `^` *is* an epilogue, is a plain
  template, and can appear anywhere in a body. A single-pass compiler does not
  know a definition's frame size until `;`, long after its `^`s were emitted.
  Giving *every* word a frame makes `^` fixed-size again, but at eight slots a
  frame is 72 bytes instead of 8 and the return stack holds ~15k frames instead
  of ~138k — measured, and it kills the suite's 50,000-deep recursion case.
  Sizing the frame per definition needs a backpatch chain threaded through every
  `^`'s unpatched immediate (still queued, and still the better language). So the
  frame is opt-in: `^` became compiler logic, but only to test one flag, and a
  `:` word emits byte-for-byte what it always did — which is why the ladder, the
  fixpoint and 50,000-deep recursion were all undisturbed.
  Slots are `a`–`h` at `[rbp + 8*(name-'a')]`, with the return address above them
  at `[rbp+64]`; the displacement does not depend on how many slots a word uses,
  which is what keeps `⇒`/`⇐` fixed-size. An out-of-range name is refused rather
  than wrapped: `⇒z` would be displacement 200, a *negative* disp8 landing in the
  frame of a word not yet called, and `⇒A` would wrap to 0 and silently alias
  slot `a`.
- **M-FRAME2 (W9-4D) — a frame sized to its locals, and locals with long
  names.** The backpatch chain M-FRAME deferred. `⊡` emits `sub rbp, imm32` and
  every `^` inside it `add rbp, imm32`, each immediate left holding the previous
  site (the `⊡`'s holds 0) — a list threaded through the unpatched immediates,
  one compiler variable for its head. A local is a *name* now, `a`–`h` or any
  `‹long›`, and takes the next slot at its first appearance, so its displacement
  is known on the spot and `⇒`/`⇐` stay five bytes; only the count waits, and
  `;` walks the list writing 8 × count into every site. A word naming k locals
  has a frame of k+1 cells: 24 bytes for two, 8 — a `:` word's — for none, so a
  two-local word recurses ≈46k deep where M-FRAME's slab allowed ≈15k. At most
  16 locals (a 17th is `GOLF: too many locals ‹name›`), which keeps every
  displacement a disp8; a frame is then at most 136 bytes. The slot table is 16
  name numbers at `m+96` (REGISTRY §3). `:` words compile byte-for-byte as
  before; `⊡` words compile differently but compute the same (run2.sh's M2
  byte-identity case holds `⊡` programs to their old output instead). Outside a
  `⊡` word `⇒a`…`⇒h` keep M-FRAME's fixed slots and a long local is refused.
  Cost: seed +183 bytes (2539 → 2722), golf2 +617 (7895 → 8512).
  W12-Z3 widened the one-letter names inside a `⊡` word from `a`–`h` to
  `a`–`z`: the slot table already holds any name number, so only the range
  check moved (the 16-local cap and the `m+96` table are unchanged). Outside
  a `⊡` word `⇒i`…`⇒z` are still refused. Cost: seed +11 bytes (4201 → 4212), golf2 +64 (13834 → 13898).
- **M2 (W9-3A) — long names, with forward references.** `‹name›` (`0xB4` …
  `0xB5`, bytes `0-9 A-Z a-z _ -`) works wherever a one-byte name does — `:`,
  `⊚`, `⊡` headers, calls, `′`, chain links, `→`/`←`. The compiler interns each
  long name at its first appearance to a **name number** 256 + index, and from
  there on it is simply a name that does not fit a byte: the dictionary slot
  (`m+2048 + 4*name`) and the variable cell (`0x4E0000 + 8*name`) are the
  one-byte formulas, continued into `0x410C00…` and `0x4E0800…`. That is why
  every program without `‹` compiles to the same bytes as before — checked by
  run2.sh against the pre-M2 compiler logic on every example and gtools
  program (since W9-4B part 2, on the prelude with its four long-named
  definitions cut out, since the pre-M2 compiler cannot read them). What a long name adds is a **forward reference**: a call to one not
  yet defined is `call rel32` whose placeholder threads the name's pending-site
  list (a `′` gets a jumped-over `jmp rel32` thunk on the same list), the
  definition patches the list, and anything still pending at end of input is
  `GOLF: undefined word ‹name›`, exit 2, before a byte is written. So mutual
  recursion needs no declaration. One-byte names stayed define-before-use: their
  pending lists were always empty, and their error stayed at the call (until
  W10-A, below). The
  compiler's own M2 words and state carry long names (`‹readname›`,
  `‹count›`, …) — every letter was already taken in `golf2.golfj` — so the seed
  implements them too, and the fixpoint now exercises them. Cost: `golf2`'s
  binary 9292 → 11482 bytes, `seed`'s 5919 → 7970.
- **The capstone shrank.** `examples/capstone.golfj` went from **54** op bytes to
  **46** by letting the bare polymorphic operators do the looping; the pre-M-VEC
  spellings are kept verbatim and output-checked as
  `examples/legacy_capstone.golfj`, because they are still how a list meets a
  function that is not one of the five hooked operators.
- **W9-1A — `⌈ ⌊` are signed.** They were the last unsigned arithmetic in a
  signed language (`0 5-3⌈` was `-5`). The templates now use `cmovl`/`cmovg`;
  the raw `⊔ ⊓` keep the old unsigned `cmovb`/`cmova` for the prelude's pointer
  math. `⩌ ⩍` (the hooks behind the bare ops) could not just hand `D` a `′⌈`
  thunk — that thunk holds the polymorphic template, whose filter sends any
  negative int straight back to the hook — so they compute int,int in place as
  `⊔`/`⊓` on operands xor `2^63`, and pass themselves to `D` for every list
  shape, which makes lists (and their elements) signed too.
- **W9-2B — runtime checks for `⊇`, `÷`, `∣`.** `3⍳9⊇Ṅ` used to print whatever
  cell lay past the block and exit 0, and `7 0÷` died of SIGFPE (status 136).
  Both now write a `GOLF: …` line to fd 2 and exit 1, leaving fd 1 exactly as
  it was. `I` opens with `&⊙&»[…]` — one *unsigned* `len > i` rejects `i ≥ len`
  and every negative `i` at once — and keeps its address arithmetic untouched
  after it; no prelude or tool-library code indexed out of range, so nothing
  needed a raw accessor. `÷`/`∣` embed their check: `test rcx,rcx`, then a
  position-independent write/exit with the 21-byte message addressed
  rip-relative, so it survives being copied inline, into `′` thunks and into
  chain links. A shared stub at a fixed address would save ~40 bytes per use but
  couple every template to the emitter's layout; most programs use `÷` once or
  never. **INT64_MIN ÷ -1** (x86's other `#DE`) is *defined*, not an error: a
  divisor of `-1` skips `idiv`, `÷` negates (wrapping, so INT64_MIN ÷ -1 is
  INT64_MIN, like `*`) and `∣` gives 0. Cost: the two templates grew from 8 to
  71/70 bytes, the blob from 714 to 839.
- **W10-B — v1's `/` `%` checked too.** They are v1's *unsigned* templates from
  the frozen `data/v1.hex` (`xor edx,edx; div rcx`), so `7 0/` still died of
  SIGFPE after W9-2B. `v1.hex` stays untouched: the v2 blob now `OVERRIDES` the
  two records (`mkblob2._udivchk`) with W9-2B's zero check — the shared
  `_DIV0_GUARD` head, rip-relative message included — in front of v1's own
  `xor edx,edx; div rcx; push` tail. Unsigned `div` has no other `#DE`, so
  every nonzero divisor gives exactly v1's result (`0 1-2/` is still 2^63-1).
  The compiler, prelude, tool libraries and gtools only ever divide by nonzero
  constants, so nothing changed behaviour; every v2-built binary (golf2
  included) carries the checked templates, and only the throwaway seed rung,
  built by the frozen v1c, keeps v1's. Cost: 52 bytes per template, the blob
  from 844 to 948.
- **M-MEM2 (W9-3C) — a free list for the allocator.** `A` bump-allocated and
  nothing was ever freed, so `M` in a loop climbed the break forever (a
  1,000,000-iteration map over `5⍳` took ~71 MB). New word `⌫` (`\free`, 0xCA):
  `list ->` pushes a block onto a free list and `A` pops one before it bumps;
  the same loop with a `⌫` after each map now leaves the break exactly where it
  was. Every `A` block grew a **header cell** in front of the address `A`
  returns — `[cap][payload]` — because an `A` block is not always a list (the
  tool libraries' byte buffers have no length cell), and no caller ever touched
  anything but the payload, so the prelude, `lib/t*.golfj` and `gtools/` were
  unchanged and gtools parity held. **Size classes, no search:** eight heads at
  `0x4F00C0`–`0x4F00F8`; class `k` = 0…6 holds blocks of exactly `4<<k` cells
  (4 … 256), so any request of the class fits the head; class 7 holds the rest
  at `max(c, 512)` cells and is popped only when its head is big enough
  (first-fit at the head, never a walk). The class is seven unsigned compares,
  so `A` stays a loop-free leaf on `s5` with no frame; `⌫` is the same shape.
  Accepts a tagged list or a raw `A` block (it masks, like every list word).
  Guards, both exit 1 with a `GOLF:` line on fd 2: a value whose header would
  lie outside the heap ("free of a non-heap value": an int, a string literal, a
  code address) and a block whose header is already negative — a freed block's
  header holds `-cap` — ("double free"). Explicit only: no existing word frees
  its inputs.
- **M-TAG2 (W9-2A) — a real tag bit.** `T` was a range test, so an *integer*
  that happened to equal a heap address — the heap base read out of its own
  cell, say — was vectorized as a list. Now a list value handed to user code is
  its address with bit 48 set (`addr | 2^48`; W11-1A moved it to
  `addr | 0x7FFF<<48`, see W11 decisions): `T` was `v >> 48 == 1` (now
  `== 0x7FFF`), and the M-VEC filter is exact — `cmp word [rsp+6],1` per operand, the top 16 bits of
  each, no cell read, two bytes *shorter* than the range filter it replaced. The
  sign bit was never an option (every negative number has it); a high-byte tag
  sacrifices only the integers in `[2^48, 2^49)` and leaves negatives and
  everything below `2^48` as ints. Every list word masks on the way in with
  `(v<<16)>>16` — idempotent, so a raw `A` block still works as input — and tags
  its result on the way out with `1 48≪|` (not the literal `2^48`, which the seed
  would truncate and so break seed ≡ golf2 on the prelude). `A` stays a plain
  allocator returning a raw address; the heap base/span cells are now its state
  alone. Library and template only: the compiler's logic did not change, and its
  hook cells stay zero, so the fixpoint held. A list of lists stores tagged
  inner lists, so the per-element "is this a list?" that nested data needs is
  now a shift and a compare rather than a heuristic.
- **W9-4A — `⧺` cat, `↑` take, `↓` drop.** Prelude words at the high bytes
  `0xCB`–`0xCD`, so `2⍳2⍳⧺⍕` finally prints `0 1 0 1`. Each returns a NEW tagged
  list and never writes its inputs; cells are copied verbatim, so nested
  (tagged inner) lists ride along shared. Edge rules: `↑`'s `|n|` is clamped to
  the length (an over-take is the whole list — no APL padding), `↓` past the
  end is empty, and a negative `n` counts from the END, APL-style (`5⍳¯2↑` is
  `3 4`, `5⍳¯2↓` is `0 1 2`). `↓` is implemented as a `↑` of the kept count.
  Demo: `examples/listwords.golfj`.
- **W9-3B — nested lists above the storage layer.** With the tag exact per
  element, the prelude now asks it of every element and recurses. `⍕` prints an
  inner list in brackets (`3⍳′⍳€⍕` → `[] [0] [0 1] `) while a flat top-level
  list prints byte-for-byte as before; the inner call is `Q` itself, handed the
  element with a second tag bit (`v | 2^49`; since W11-1A `v - 2^48`, top
  bits `0x7FFE`) that its entry mask strips. The
  bare `+ - *` now go to depth like `⌈ ⌊` always did: `∔ ∸ ⨰` answer int,int
  in place and otherwise hand `D` the word *itself*, so `Z`/`K`/`G` re-enter it
  per element (`3⍳′⍳€ 10+⍕` → `[] [10] [10 11] `). Two new high-byte words:
  `≣` (`0xC8`) structural equality (`-1`/`0`, an int never matches a list) and
  `⍤` (`0xC9`) depth (int 0, flat or empty list 1, then 1 + the deepest
  element). Prelude only; the templates' scalar fast path is untouched.
- **W9-4B — `⍋` sort and `∊` member.** Prelude words at `0xCE`/`0xCF`. `⍋`
  returns a NEW tagged list in ascending SIGNED order and leaves its input
  alone; it is an iterative bottom-up merge sort (stable, O(n log n), one
  `X`/`Y` frame whatever the length — no recursion to exhaust the spill
  stack, 28 frames then, 4096 since W10-C), ping-ponging between a `0↓` copy of the input and one block from `A`,
  with a branch-free merge step that reads both run heads at clamped indices.
  100,000 elements sort in well under a second. It is meant for int lists: an
  inner list compares by its tagged value (after every int below the tag band, and by
  address among lists). `∊` is `list x -> 0/1` — zero-is-true like `T`, raw
  cell equality like `≡`, stopping at the first hit; the empty list gives 1.
- **W9-4C — input for user programs (M6b).** The first prelude words with LONG
  names, so no letter or high byte was spent: `‹readall›` `‹readline›`
  `‹getc›` `‹words›` `‹num›` `‹ints›` `‹args›`, ported from `lib/tio.golfj` and
  `lib/ttext.golfj` to the prelude's rules (X/Y frames, raw atoms, masked
  inputs, tagged results, no `→x`). The stdin words share one 8 KB read buffer,
  allocated on first use; its raw address lives in the cell `0x4F0050`
  (REGISTRY §3), the only new fixed state. `‹readline›` returns the line and a
  zero-is-true flag (1 = end of input with nothing read); `‹num›` skips leading
  whitespace, takes one `+`/`-`, and stops at the first non-digit (no digits →
  0). `‹words›` is two passes (count, then copy) so the result is allocated
  once; `‹readall›` grows by doubling and gives each outgrown block back with
  `⌫`. A 1.2 MB input reads in well under a second. The prelude's eight long
  names count against a program's 256; run2's M2 "same bytes as before M2"
  check now feeds the pre-M2 compiler a prelude with those definitions cut out.
  Demo: `examples/input.golfj`.
- **W9-4B part 2 — `‹slice›` `‹indexof›` `‹unique›` `‹flatten›`.** The first
  prelude words with LONG names (the high bytes are spent). `‹slice›`
  (`list i n`) is `↓` then `↑` with the intermediate freed by `⌫`; a negative
  `i` counts from the end and is then clamped to 0, `n` is clamped to what is
  left, and a negative `n` is 0. `‹indexof›` is `∊`'s loop that keeps the
  index (`-1` on a miss). `‹unique›` keeps first occurrences in order through
  an open-addressing hash set of 2^k ≥ 2n slots (Fibonacci hashing, the 64-bit
  golden-ratio constant built from 16-bit pieces for the seed; slots hold
  i+1, 0 is empty; the table is zeroed, since `A` may hand back a used block,
  and freed at the end), so it is O(n) expected: 400,000 cells take about
  40 ms. `‹flatten›` neither recurses nor keeps a work stack: each pass
  splices one level and notes whether a spliced cell was itself a list, and
  passes repeat (freeing every intermediate) until none was. That is
  O(size · depth) in one `X`/`Y` frame, so a list nested 200 deep flattens
  at any depth, while the recursive `⍕`/`⍤` are bounded by the spill stack (4096 frames
  since W10-C, so they reach ~4,000 levels now). The four
  take 4 of the 256 long-name slots, so a program now has 252. None of them
  uses swap, because `decode -m` writes the swap byte as a bare `\`, which
  does not encode back (gtools' prelude round trip caught it). A one-byte
  program's own code compiles to the same bytes as before; only the prelude
  part of the binary grows (run2 checks this).
- **W10-A — forward references for every name; 1024 long names.** M2's
  pending-site lists were already indexed by name number, so a one-byte name
  needed no new mechanism, only permission: `e` and `X` now send any name that
  is not a template and not defined *yet* down the same `call rel32` /
  `jmp rel32`-thunk path, and the end-of-input check walks the 256 one-byte
  names before the long ones (`GOLF: undefined word b`, exit 2, no binary — the
  M-DIAG message, now at end of input instead of at the call). Templates still
  dispatch first, and a call after a definition binds to it directly, so a
  redefinition keeps its earlier callers. Programs that only call backwards
  compile to the same bytes. The long-name cap went 256 → 1024: the name table
  keeps its `64*E` formula but now sits at `0x47C000 + 64*E` (entries
  `0x480000`–`0x48FFFF`, plus one scratch entry `‹readname›` reads into), the
  heads moved to `0x490400 + 4*N` and the dictionary — for every name, one-byte
  ones too, since `m+2048` had room for only 512 — to `0x492000 + 4*N`, all
  compiler-only and clear of W10-C's spill stack at `0x440000`–`0x47FFFF`. The
  variable bank keeps `0x4E0000 + 8*name`, now through `0x4E27FF`, so a
  long-named variable's address did not move. The compiler got smaller: `e`
  and `X` lost their special cases. Cost (measured before W10-B/C merged): `golf2`'s
  binary −74 bytes (11841 → 11767), `seed`'s −97 (8722 → 8625); `golf2.golf`
  −37, `seed.golf` −19.

## W11 decisions

Recorded in W11-0, before the round-3 (Python/Rust gaps) waves start; the
allocations they need are in [`REGISTRY.md`](REGISTRY.md) §1.3, §2 and §3.1.

1. **The list tag moves to the top of the range (W11-1A).** A list value
   becomes `addr | 0x7FFF<<48` instead of `addr | 2^48`: the top 16 bits read
   `0x7FFF`, not `0x0001`. Afterwards only integers within `2^48` of
   `INT64_MAX` are mistaken for lists, instead of the everyday range
   `[2^48, 2^49)` (281 to 562 trillion). **Shipped (W11-1A):** `T` is
   `v >> 48 == 0x7FFF`, list words tag on exit with `32767 48≪|`, the M-VEC
   filter is `cmp word [rsp+6],0x7FFF` (imm16, so each of the five templates
   grew 2 bytes: blob 958), and `Q`'s nested-call marker is the tag minus 2^48
   (top 16 bits `0x7FFE`) instead of `| 2^49`, which the new tag already sets.
2. **Include is done in the compiler, by swapping fd 0 (W11-2A).** At an
   include the compiler `dup`s its current fd 0, `dup2`s the opened file onto
   fd 0, and restores the saved fd at that file's EOF; a stack of saved fds
   gives nesting, a table of compiled paths gives include-once, and the search
   order is the current directory, then `lib/` (then `vendor/`, added by
   W11-4A). It is a compiler **op byte** (`0xB6`, `⎘“path“` or
   `\import“path“`), not a recognised long name — REGISTRY §1.3 says why.
   **Shipped (W11-2A):** `t` has one more case, `‹import›`, and `g` reads
   through `‹inbyte›`, which at end of file inside an include `dup2`s the saved
   fd back (`‹unnest›`) and reads on; `(` itself is unchanged. Limits: 8
   levels, 60 distinct files, 250-byte paths, each refused with a
   `GOLF: …` line and exit 2 (`cannot include <path>` for a missing file).
   Include-once compares the path's **bytes as written** (`x.g2` and
   `lib/x.g2` are two paths); the main program is not in the table. A file's
   end ends its last token, so nothing runs across it. The included bytes are
   the compiler's input form, raw code page: `tools/golfc` encodes an
   included `.golfj` into a temp copy first (recursively, one copy per real
   file) and rewrites the path — the compiler stays one-format, and the
   encoders (`tools/codepage.py`, `gtools/encode.golfj`) needed no change,
   since a `“…“` literal is already copied verbatim. The seed is v1 GOLF,
   which has no syscall op, so it gained one: its word `K` is a raw blob
   escape holding `⎈`'s template plus `jmp +5` (`mkblob2.SEED_SYS`, spliced
   at `@SYS@`), armed once at startup by zeroing the rel32 of the escape's own
   jmp-over (v1's segment is RWX). `boot/golfref.py` splices the file's bytes
   (plus a newline) in place, with the same search, bounds and messages, and
   emits the same bytes. State: `0x438000`–`0x43BE00` and, in the seed,
   `m+160`…`m+172` (REGISTRY §3). Cost: the `golf2` binary +1789 bytes
   (12634 → 14423), `seed` +1926 (8923 → 10849); `self/golf2.golf` +1459
   (8958 → 10417), `self/seed.golf` +526 (2965 → 3491). A program without
   `⎘` compiles to the same bytes as before.
3. **A caught error's value is its message (W11-3A).** `′f‹catch›` leaves `0`
   when `f` returns normally and, when `f` throws, the error's message as a
   code list — the text after `GOLF: `, like Python's exception text. Every
   runtime error goes through one word, `‹throw›` (`msg ->`, msg a code list);
   W11-0 shipped it as a stub that prints `GOLF: <msg>` and a newline to fd 2
   and exits 1, and routed the prelude's index, compose-arena and two `⌫`
   errors through it with unchanged output. **W11-3A shipped the catch**:
   `‹catch›` pushes a handler record — one 64-byte spill-stack frame holding
   `sp bp` from the new atom `⊷` (`push rsp; push rbp`, taken in `‹catch›`'s
   OWN frame, whose return address stays live while `f` runs) and the previous
   chain head (cell `0x4F0B00`) — runs `f`, and on return unlinks it and
   pushes `0`. `‹throw›` with a handler armed unlinks it, sets the spill-stack
   offset back to the record (so every `X` frame pushed since is dropped), `Y`s
   the caller's scratch back, and `⊶` (`pop rbp; pop rsp`) restores both
   stacks; its epilogue then returns through `‹catch›`'s return address, so
   `‹catch›` returns with the message. The data-stack DEPTH is restored, not
   the contents of cells `f` consumed (Forth's `CATCH` rule); globals, memory,
   the heap and output are not rolled back. The two errors W11-0 left inline
   became catchable too, by unwinding BEFORE the message is built
   (`‹_3a_raise›`): `X`'s overflow (with a handler armed, `X` calls
   `‹_3a_spill›`) and the `/ % ÷ ∣` divide-by-zero exit, whose template now
   calls a second BSS hook cell, `0x4F0B10`, ahead of the flush hook (15 bytes
   per divide site; 0 in a bare program and the compiler, which fall through
   to the old exit). Uncaught errors print exactly what they printed before.
   Still outside it: signals (the return-stack guard page's SIGSEGV), `.`, and
   the compiler's own messages.
4. **Records are expanded by the compiler, into plain words over plain lists
   (W11-4A).** `⊜‹point›‹x›‹y›;` is a compiler op byte (`0xB7`, `\rec`), not
   a prelude word: at compile time `t`'s new case (`‹defrecord›`) reads the
   record name and the fields up to `;`, then emits three kinds of ordinary
   `:` definitions, token for token what their source would compile to —
   `‹point›` = `n⍳` then, last field first, `\&16≪16>(8k+8)﹢⊛` (store each
   value in its cell); `‹point-x›` = `k⊇`; `‹set-point-x›` =
   `&k⊇_&16≪16>(8k+8)﹢⊛` (in place, the `⊇` keeping the index and
   use-after-free checks). So there is no runtime support at all, a record IS
   a list (every list word works on it, `⍕` prints its fields), and the words
   are ordinary names: forward references, `′`, chain links and
   `GOLF: undefined word ‹point-z›` for a field that does not exist all come
   for free. The names are invented with `-` as the joiner, since `.` is not a
   long-name byte (the plan's `‹point.x›` is `‹point-x›`); the compiler builds
   each in the next free long-name entry and interns it exactly as
   `‹readname›` would (‹readname› was split into ‹fresh› ‹legal› ‹intern› for
   this), so they count against the 1024, two per field. The same task added
   `vendor/` as the third include location, after the path as written and
   `lib/` (for W11-4E's packages): the C string `vendor/path` is built in the
   W11-4A region at `0x43F000`, since `vendor/` does not fit the 4-byte length
   cell the `lib/` retry overwrites. Malformed headers stop the compile, exit 2:
   `record without fields`, `record without ;`, `bad record field`,
   `bad record name`, `too many record fields` (256), each ` at line N`; the
   seed mirrors all of it (exit 2 silently) and `boot/golfref.py` the bytes
   and messages. State: the field table at `0x43C000` and, in the seed,
   `m+192`…`m+204` (REGISTRY §3). Cost: the `golf2` binary +2341 bytes
   (16073 → 18414), `seed` +2254 (10917 → 13171); `self/golf2.golf` +2030
   (11804 → 13834), `self/seed.golf` +642 (3559 → 4201). A program without
   `⊜` compiles to the same bytes as before.

## Invariants we do not break

- `test/run2.sh` stays green, **including the golf2 self-hosting fixpoint**
  (`golf2 == golf2'`), at every commit.
- The frozen v1 substrate is never touched: `data/v1.hex` (v1's templates and
  ELF header) and the `v1c` binary `../SEEDS` pins are ground truth, and the
  tree they came from is frozen on the `minimal` branch.
- `self/golf2.golf` and `self/seed.golf` are **generated** — never hand-edited.
  Run `python3 tools/mkblob2.py` from `expanded/` and commit the result;
  `test/selfcheck.sh` fails if what is committed is not what it emits.
- A change to the compiler's logic goes in `self/golf2.golfj` **and** in
  `tools/mkblob2.py`'s v1-GOLF seed, or `test/selfcheck.sh`'s byte-for-byte
  `seed == golf2` comparison catches the drift.
- Every new "dumb" op is added as a template in `tools/mkblob2.py` (and mirrored
  in `boot/golfref.py`), so the reference oracle and the self-hosted compiler
  always agree.
- Every byte, glyph, mnemonic, prelude letter and fixed address is allocated in
  [`REGISTRY.md`](REGISTRY.md) **before** it is implemented, and
  `python3 tools/codepage.py check` enforces the namespace invariants.
- The prelude never uses `→x` / `←x`: the variable bank is user space, so a
  prelude word that stored to `→i` would clobber a user's `i`.
- The numbers quoted in this file and in the top-level `README.md` are asserted
  by `test/run2.sh` against what they describe. Change the thing, change the doc,
  or the suite fails.

## Deliberate non-goals

Three things a reader coming from Python or Jelly will look for and not find.
None of them is queued, because none of them is unbuilt — they are refused, and
[`GAPS.md`](GAPS.md) measures what the refusal costs. Recorded here so the next
person does not have to guess whether they were forgotten.

- **A numeric tower.** One type, a 64-bit machine word: no floats, no bignums,
  no rationals, no complex, and no character distinct from its code. This is
  what lets an atom be a raw one-instruction template, which is what keeps the
  blob at 958 bytes, which is what keeps the compiler re-derivable in an
  afternoon. Floats would put an SSE calling convention in every arithmetic
  template; bignums would put an allocator on the arithmetic path. Either ends
  the property this project exists to demonstrate.
- **Arity.** GOLF has no notion of how many arguments a word takes; words are
  variadic by stack discipline and nothing checks them, so a word that
  under-pops silently eats its caller's values. Jelly's compression comes from
  a parse-time arity algebra, and matching it means a real front end — a
  different project, not a milestone. `⊚` chain definitions are as far as the
  single-pass model goes.
- **Diagnostics, in general.** The compiler is single-pass, and the failures
  worth naming are named (an undefined word, an exhausted compose arena, a
  local out of range, a malformed long name, a missing include) and each cost
  a byte-count that had to be justified. Since W11-3B every compile message
  but `program too large` also says **where**: `GOLF: undefined word b at
  line 3`, or `at x.golfj line 3` inside an included file, with lines counted
  per file and from the user's program (golfc's form feed after the prelude
  restarts the count). An undefined word, only known at end of input, is
  reported at its first use, whose position rides in the last placeholder of
  its forward-reference list. That cost golf2 about 1.5 KB of binary,
  together with `-g`'s symbol map (`name 0xaddr` per word, tools/golfc
  `-g` → `OUT.map`). Still not coming: a column, a caret under the source, a
  second error after the first, or any check that would need a second pass.
  The seed still exits 2 silently (its v1 GOLF has no stderr).

The first two are permanent. The third is a budget, not a principle — a
specific silent failure can earn its diagnostic, as those two did.

## Known limits

These are real, currently true, and none of them is a bug in the bootstrap. The
fixes are queued in [`NEXT_STEPS.md`](NEXT_STEPS.md).

- **Long names (M2) are bounded and global.** 1024 per program since W10-A
  (the prelude's 73 count too, as of W11 wave 4), at most 60 bytes each, interned in a fixed
  compiler table; a 1025th is refused. Every name, one-byte or long, may be
  forward-referenced (W10-A). Locals take long names too (W9-4D), up to 16 per
  `⊡` word. And there are no scopes: a long name, like a letter, is
  one dictionary entry and one variable cell for the whole program.
- **A compiled program is at most 192 KB (196608 bytes), header included
  (W11-1E).** It is one `LOAD` segment at `0x400000` and may not reach
  `0x430000`, the W11-1C output buffer (the lowest address a running program
  uses; REGISTRY §3). Both compilers check it as they emit: `golf2` writes
  `GOLF: program too large` to fd 2 and exits 2 with nothing on fd 1, the seed
  exits 2 silently. The prelude alone is about 43 KB (an empty program is 43047
  bytes, after W11 wave 4), which leaves about 150 KB; an empty word costs 20 bytes. `p_filesz`
  is now the file's true size (it was v1's fixed `0x10000`, and before W11-1E a
  program past 64 KB compiled cleanly and then crashed in its unmapped tail).
  Raising the cap further means moving the 1C buffer and the spill stack up
  (and the compilers' buffer at `0x494000`, which has 240 KB to the arena).
  A compiler image (`golf2`, the seed) must stay under 64 KB, below its own
  data base `m` = `0x410000`; it is about 12 KB.
- **`(` and the input words are two readers.** `‹readall›`, `‹readline›`,
  `‹getc›` and `‹ints›` read through the prelude's 8 KB buffer; `(` is a raw
  one-byte `read` that bypasses it, so mixing the two loses or reorders bytes.
- **Output is buffered, and three writers stay outside the buffer (W11-1C).**
  `Ṅ ⍕ ␤ 🗲 ⊐` append to an 8 KB buffer at `0x430000` (REGISTRY §3), drained
  by `‹flush›`. Every exit path that runs code drains it first: the end of the
  program, `.`, `‹throw›`, X's spill-stack error, the `/ % ÷ ∣` divide-by-zero
  exit; so do `‹getc›`'s refills (prompts appear before a read). An error
  a `‹catch›` takes does not exit and does not flush: the pending bytes stay
  pending, in order (W11-3A). The templates
  do it through one BSS hook cell, `0x4F0990`, which only the prelude fills
  (`tools/mkblob2._FLUSH_CALL`), so a bare program and the compiler itself call
  nothing. The raw `)` stays one `write` per byte, but **flushes the buffer
  first**, so `)` mixed with the printers keeps program order (decided in
  W11-1C instead of documenting a reordering: it costs 15 bytes per `)` site
  and a load+test per byte, against a whole class of surprises); `(` likewise
  flushes before it reads. What still reorders: a raw `⎈` write (call
  `‹flush›` first), `lib/tio.golfj`'s own separate buffer (`f`/`g`) against the
  printers (call `‹flush›` before `f`), and output pending when the process
  dies of a signal (the return-stack guard page's SIGSEGV, a kill) is lost.
  The buffer is 8 KB because that is what REGISTRY allocated: `1000000⍳⍕`
  (6,888,890 bytes) takes ceil(6888890/8192) = 841 writes, not 6.9 million.

For the limits that only show up when GOLF is held against another language —
what Python and Jelly have that this does not, which of it is refused rather than
unbuilt, and three defects this list does not yet cover — see
[`GAPS.md`](GAPS.md).

- **`‹catch›` restores depth, not contents, and rolls nothing else back
  (W11-3A).** On a throw the data stack goes back to its depth at the
  `‹catch›` call, but a cell `f` consumed holds whatever `f` last wrote there;
  variables, memory, allocations (they leak unless the handler frees them)
  and output are not undone. A handler record is one spill-stack frame, so
  catches nest as deep as the 4096-frame spill stack allows (sharing it with
  the list words). A return-stack overflow is a SIGSEGV on the guard page and
  is not catchable.
- **Only the unary arithmetic atoms check for a list (W12-O1).** `± ⊕ ⊖ ² ⊗
  ⊘` on a list raise `GOLF: not a number` through `‹throw›`. Their templates
  test TOS's top byte for `0x7F` and only then call the hook cell `0x4F0DC0`
  (REGISTRY §3.2, slot O1). The prelude fills that cell with `‹_12o1_nan›`,
  which throws only for a tagged value whose address lies in the list heap.
  So `INT64_MAX` and the rest of `[0x7F<<56, 2^63)` stay numbers, and the
  only integers lost are those whose bits are exactly a live heap list's
  tagged address. The hot path is one `cmp byte [rsp+7]` and a not-taken
  `jne`, measured at +0.1 to +0.2 ns per op in a loop
  (`bench/micro`, `loop` and `inc2`). Each use costs 22 more bytes of code.
  A bare program (`golfc -n`) and the compilers never fill the cell, so they
  call nothing. **Not checked, by design:** the bitwise atoms `~ $ | = > ≪ ≫`
  (the prelude builds and strips the tag with them), the raw `﹢ ﹣ ﹡ ⊓ ⊔ ﹤`,
  and the comparisons. On a list these still work on its tagged address.
  The binary `+ - * ⌈ ⌊` vectorize instead (M-VEC).
- **Raw memory access is unchecked.** `⊙`/`⊛`/`@`/`!` are raw memory access
  by design; only `⊇` (prelude `I`) bounds-checks, and only `/ % ÷ ∣` check
  their divisor.
- **Two things cannot be written inside a string literal.** The text `\str`
  (it closes the literal — the ASCII spelling of the delimiter), and any
  character whose UTF-8 contains byte `0x8E` (e.g. `Ď`, `C4 8E`), since the
  compiler ends a literal at the first `0x8E`; the encoder rejects the latter
  with an error rather than emit a broken block. A byte block that needs either
  must be built at run time.
- **The allocator's cells are 32-bit.** `A` keeps the heap base and how far it
  has pushed the break in the 4-byte cells `0x4F0034`/`0x4F0038`, and its bump
  pointer `H` is a 4-byte offset, so one process's list heap must stay under
  4 GB. Nothing else reads them any more — since M-TAG2 neither `T` nor the
  M-VEC templates do — so widening them is a prelude-only change.
- **`⌫` is manual, and the free list is simple.** Nothing frees on its own:
  a program that wants a flat heap calls `⌫` on what it is done with, and a
  freed list must not be used again. Caught: freeing a non-heap value, freeing
  one block twice in a row (`double free`, from the header's `-cap`), and —
  since W11-2D — USING a freed list: `⌫` writes the poison `-559038737` into
  its length cell (the free-list link lives in payload cell 1), every list
  word checks that cell on entry and throws `use after free`, and `⊇` clamps a
  negative length so it fails too. Not caught: a pointer into the middle of a
  block, and any stale copy of a block that was freed and then handed out
  again — `A` clears the poison on reuse, so the stale copy silently reads,
  or frees, the new owner's list. Also unchecked: a raw `A` block read with
  `\fetch` directly, and words outside the prelude's list set that read cells
  themselves (`lib/t*.golfj`). `‹heapstats›` (`-> blocks bytes`) counts what
  `A` handed out and `⌫` has not taken back. Cost: one call per list word, no
  per-element work in the prelude's loops (they index through `‹_2d_ix›`),
  five ops per user `⊇`. Blocks are never split or coalesced; small
  blocks round up to a power of two (≤ 2x), and the >256-cell class checks only
  its head, so a large freed block can be passed over by a bigger request.
- **Thunks are heap blocks, and the heap is executable (W12-O2).** `∘` and
  `⊸` take their 39/38-byte thunk from `A` (a 5-cell request, one 72-byte
  class-1 block), so `⌫` frees one, `‹heapstats›` counts it, and the old
  lifetime cap (1680 thunks in the fixed 64 KB arena at `0x4D0000`, then
  `compose arena exhausted`) is gone. For that the prelude `mprotect`s the
  whole brk heap `PROT_READ|PROT_WRITE|PROT_EXEC` at startup and again each
  time `A` moves the break: two prelude lines, no compiler or ELF change
  (x86-64 Linux never makes brk memory executable by itself; a separate
  `mmap(PROT_EXEC)` arena would have needed a second free list, a second `⌫`
  path and its own counters). **Costs:** list memory is executable too, so
  W^X is not kept (the load segment never kept it), and a kernel or policy
  that refuses an executable heap (SELinux `execheap`, PaX) breaks `∘`/`⊸`.
  **Checked:** freeing a thunk twice (`double free`) and freeing a non-heap
  address. **Not checked:** calling a freed thunk (`⍎` is a bare `call`; the
  poison `⌫` writes over its first bytes is a privileged instruction, so it
  dies with SIGSEGV, or, once the block is reused, runs whatever is there),
  and freeing a thunk another thunk still calls. The old arena is unused.
  Thunk code addresses must stay below 2^32 (each is written as a 4-byte
  imm64 low half), which the allocator's 32-bit cells already require.
- **The integers in `[0x7FFF<<48, 2^63)` are lists.** A list value is
  `addr | 0x7FFF<<48` (W11-1A; it was `addr | 2^48`, which sacrificed the
  everyday `[2^48, 2^49)`), so an integer whose top 16 bits are exactly `0x7FFF`
  — the 2^48 values from 9223090561878065152 up to and including `INT64_MAX` — is
  shape-tested as a list by `T`, `D` and the bare `+ - * ⌈ ⌊`. That is the
  deliberate price of an exact tag in an untagged word (NEXT_STEPS.md history,
  M-TAG2); negatives (top bits `0xFFFF`) and everything below `0x7FFF<<48` are
  ints, so the largest int the list words treat as a number is
  9223090561878065151. Non-polymorphic atoms (`⊕`, `Ṅ`, `\radd`) still take
  `INT64_MAX` as a plain word.
- **Nesting depth is bounded by the spill stack, now generously (W10-C).**
  Every scratch-using looping word frames its scratch with `X`/`Y` (`⍳ ∑ ∏ ⌽`
  use none since W12-P3); recursive `⍕`, `≣` and `⍤` take one frame per level,
  and so, since W12-P3, does deep `+ - * ⌈ ⌊` (it took two, `D` and
  `Z`/`K`/`G`, before).
  The stack was 28 frames at `0x4F0900` (about 13 levels of nested arithmetic,
  27 of printing, then a bare SIGSEGV in the guard page); W10-C moved it to
  free BSS at `0x440000`–`0x47FFFF` (REGISTRY §3), 4096 frames = 256 KB, so
  about 4,000 levels of nested arithmetic, `⍕`, `≣` or `⍤` (2,000 of arithmetic before W12-P3). Untouched
  BSS pages cost no RAM. `X` checks the bound with one compare-and-branch and,
  past it, writes `GOLF: spill stack exhausted` to fd 2 and exits 1 (as the
  compose arena did before W12-O2); `Y` needs no check.
- **`seed` and `golf2` genuinely diverge above `2^31`.** The frozen v1-GOLF seed
  emits `push imm32` for every literal; golf2's `W` word switched to
  `mov rax,imm64; push rax` at `v >> 31`. So the two compilers produce different
  (and, for the seed, *wrong*) bytes for a source containing a literal ≥ `2^31`.
  This is harmless — `self/golf2.golfj` contains no such literal, every address
  it names is under `0x600000`, and the seed's only job is to build golf2 once —
  but it is a genuine property of the ladder, not an oversight.
  `test/selfcheck.sh` proves seed ≡ golf2 on the sources that matter.
- **The return stack is smaller than it was, and better.** M-MEM shrank
  `p_memsz` to `0x200000`, so the stack now runs from `0x600000` down to the
  W9-2C guard page just above the `0x4F` bank: about 1.07 MB, ≈**138**k frames,
  all of them *its own*. Before,
  it nominally had ~917k frames but shared them with a bump heap growing up from
  `0x500000` — every 8 bytes allocated cost a frame, and the two met without
  complaint. Deterministic and smaller beats large and shared.
- **FIXED (W9-2C) — the return stack has a guard page.** Nothing in a prologue
  checks `rbp` (a compare there would sit on the hottest path there is), so
  before W9-2C a runaway recursion grew straight down through the `0x4F`
  runtime cells, the variable bank and the code arena, and a plain `:` word
  recursing 200,000 deep still exited 0. Now `STARTUP2` (`tools/mkblob2.py`,
  mirrored by `boot/golfref.py`) spends 15 bytes on `mprotect(0x4F1000, 1 page,
  PROT_NONE)`, so the first frame past the bottom faults — SIGSEGV, exit 139 —
  before a byte below it is touched; run2.sh checks that with a `→x` canary. The
  guard comes out of the return stack (the page under it is live `0x4F` state),
  which costs 512 of ~138.7k frames; a `⊡` word naming all eight of `a`–`h`
  (a 72-byte frame) faults at about 15k deep. One page suffices because no frame
  is larger than 136 bytes (16 locals, M-FRAME2). The
  ELF-level alternative — a second `PT_LOAD` leaving the page unmapped — would
  have moved the code start and entry point of every binary for the same
  effect. **Limits:** it is a bare SIGSEGV, not a message (a handler needs a
  `sigaltstack`, more startup than it is worth), and it covers what `golf2`
  emits — `golf2` and `golf2'` included — but not `seed`, which the frozen v1c
  builds with v1's startup and `0xC00000` stack; the seed's only job is to
  compile golf2 once, a handful of frames deep.

## Layout

| Path | What |
|------|------|
| `self/golf2.golfj` | **the v2 compiler's source** — its logic, written in v2 GOLF (edit this) |
| `self/golf2.golf` | GENERATED: `golf2.golfj` code-page encoded + the template blob |
| `self/seed.golf` | GENERATED: the same compiler in v1 GOLF — the bootstrap rung only |
| `tools/mkblob2.py` | builds both `self/*.golf`; source of truth for the atom table + the v1 seed |
| `REFERENCE.md` | **the language reference**: v1 core ops, the generated v2 code-page tables, a checked tutorial |
| `tools/codepage.py` | code page: encode/decode glyph/mnemonic ⇄ raw bytes; `table` / `reference` (REFERENCE.md's generated tables) |
| `tools/golfc` | compile a program (prepends the prelude; `-j` to encode glyph source) |
| `tools/golftest` | W11-4B test runner: compile and run every `*_test.golfj`, PASS/FAIL per file, non-zero exit on any failure |
| `examples/tests/`, `test/fixtures/golftest/` | a passing test file, and the deliberately failing one run2 feeds `golftest` |
| `lib/prelude.golfj` | the standard library: list runtime, map/fold, number/list printing |
| `boot/golfref.py` | Python reference/oracle for v2 (debugging only) |
| `examples/` | v2 programs (`capstone.golfj`, `legacy_capstone.golfj`, `bigheap.golfj`, …) |
| `test/run2.sh` | bootstrap ladder, language tests, oracle differentials, doc assertions |
| `test/selfcheck.sh` | M-SELF: `seed` and `golf2` are the same compiler; the generated files are fresh |
| `gtools/` | M-TOOL: the build tools written in GOLF — `hexcat` `encode` `decode` `mkblob` `mkgolf2`, plus the `build` driver |
| `lib/t*.golfj` | the tool libraries (lowercase letters): `tio` files/streams/argv, `ttext` text, `tutf` the code page |
| `data/` | GENERATED tables the GOLF tools read: `codepage.tsv`, `blob.hex` (`tools/mktables.py`) |
| `test/gtools.sh` | M-TOOL: every GOLF tool matches its Python counterpart byte for byte |
| `REGISTRY.md` | the allocation ledger: op bytes, mnemonics, glyphs, prelude letters, memory |
| `NEXT_STEPS.md` | the forward queue |
| `GAPS.md` | the audit against Python and Jelly: what is missing, what is refused, what is broken |
