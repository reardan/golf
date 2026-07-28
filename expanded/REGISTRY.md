# Expanded GOLF — resource registry

GOLF has three global, flat namespaces — **op bytes**, **`\mnemonics`**, and
**glyphs** — plus two scarce address spaces: **prelude word letters** (one byte
per word) and **fixed runtime memory**. All five are collision-prone and none of
them used to be written down, so two parallel changes could pick the same byte
and only find out when the fixpoint broke.

**Rule: no one picks a byte, glyph, mnemonic, prelude letter, or scratch address
on their own. It is assigned here first, then implemented.** Adding a row here
is cheap and reversible; discovering a collision after `self/seed.golf` and
`self/golf2.golf` have been regenerated is not.

`Status` is `reserved` (allocated here, not implemented yet — do not use the
byte/glyph/mnemonic for anything else) or `shipped` (live in
`tools/mkblob2.py` / `tools/codepage.py` / `lib/prelude.golfj`).

The op-byte, mnemonic and glyph invariants are **machine-checked**:

```
python3 tools/codepage.py check     # also run as an assertion by test/run2.sh
```

It asserts, across `mkblob2.ATOMS` ∪ `codepage.COMPILER` ∪ `codepage.LIB`:
op bytes are unique; **no mnemonic is a proper prefix of another**; glyphs are
unique; and every byte ≥ `0x80` has a glyph. `tools/mkblob2.py` additionally
checks ATOMS against the compiler prefixes and the v1 template bytes.

### Why the prefix rule matters

`codepage.encode` reads the alpha run after a `\` and takes the **longest known
mnemonic prefix** of it (so `\sqr48` is `\sqr` then `48`, and `\sqrp` is `\sqr`
then the word `p`). Therefore a *new* mnemonic that has an *existing* mnemonic
as a proper prefix would silently re-parse existing sources: adding `\shrink`
is harmless, but adding `\str` when `\strong` exists — or `\sq` when `\sqr`
exists — changes what already-written programs mean. Never add a mnemonic that
is a proper prefix of another, or that has another as a proper prefix.

---

## 1. Op bytes

Bytes `0x00`–`0x7F` are ASCII: v1's templates, the prelude word letters, digits
and whitespace live there and the printable space is essentially full (M1 took
the last five: `~ $ | = >`). Bytes `0x80`–`0x90` are shipped (atoms + the four
compiler prefixes). `0x91`–`0xFF` — 111 bytes — was the entire remaining op
space; **23** are now spent, leaving **88** free. It is partitioned as follows
so waves never contend:

| Range         | Owner / purpose                                            |
|---------------|------------------------------------------------------------|
| `0x91`–`0x97` | Raw scalar atoms (wave 0) — the non-polymorphic arithmetic the prelude's own pointer math uses, so M-VEC can make the ASCII bytes polymorphic without the dispatcher recursing |
| `0xA0`–`0xA7` | M4 atoms (wave 1) — signed compare, shifts, 64-bit fetch/store, `brk` |
| `0xB0`–`0xBF` | Future compiler-logic ops (prefixes/tokens handled in golf2's `t`, like `ref`/`str`/`→`/`←`) — since M-SELF written in `self/golf2.golfj`, and mirrored into `mkblob2.py`'s v1-GOLF seed |
| `0xC0`–`0xCF` | High-byte prelude words (wave 2) — words that need a byte of their own instead of a scarce ASCII letter |
| `0xD0`–`0xEF` | Reserved: chain syntax / M4c                               |
| `0xF0`–`0xFF` | User extension space — never allocated by the language      |

Gaps between the ranges (`0x98`–`0x9F`, `0xA8`–`0xAF`) are deliberate headroom
for the range immediately above them; do not fill them opportunistically.

### 1.1 Shipped today

| Byte | Mnemonic | Glyph | Meaning | Status |
|------|----------|-------|---------|--------|
| `0x7E` | `\not` | `~` | bitwise NOT | shipped |
| `0x24` | `\and` | `$` | bitwise AND | shipped |
| `0x7C` | `\or` | `\|` | bitwise OR | shipped |
| `0x3D` | `\xor` | `=` | bitwise XOR | shipped |
| `0x3E` | `\shr` | `>` | shift right | shipped |
| `0x80` | `\neg` | `±` | negate TOS | shipped |
| `0x81` | `\inc` | `⊕` | TOS + 1 | shipped |
| `0x82` | `\dec` | `⊖` | TOS - 1 | shipped |
| `0x83` | `\sqr` | `²` | TOS * TOS | shipped |
| `0x84` | `\dbl` | `⊗` | TOS * 2 | shipped |
| `0x85` | `\hlv` | `⊘` | TOS >> 1 | shipped |
| `0x86` | `\gt` | `»` | unsigned greater | shipped |
| `0x87` | `\eq` | `≡` | equal | shipped |
| `0x88` | `\max` | `⌈` | unsigned max | shipped |
| `0x89` | `\min` | `⌊` | unsigned min | shipped |
| `0x8A` | `\sdv` | `÷` | signed divide | shipped |
| `0x8B` | `\smd` | `∣` | signed modulo | shipped |
| `0x8C` | `\ref` | `′` | push a word's address (compiler prefix) | shipped |
| `0x8D` | `\exec` | `⍎` | pop a word address, call it | shipped |
| `0x8E` | `\str` | `“` | string-literal delimiter (compiler op) | shipped |
| `0x8F` | `\set` | `→` | store TOS to variable (compiler prefix) | shipped |
| `0x90` | `\get` | `←` | push variable (compiler prefix) | shipped |

`0x8C` is free of a template (it is pure compiler logic), as are `0x8E`–`0x90`.

### 1.2 Assignments — FINAL, do not re-pick

| Byte | Mnemonic | Glyph | Meaning | Status |
|------|----------|-------|---------|--------|
| `0x91` | `\radd` | `﹢` | raw add | shipped |
| `0x92` | `\rsub` | `﹣` | raw sub | shipped |
| `0x93` | `\rmul` | `﹡` | raw mul | shipped |
| `0x94` | `\rmin` | `⊓` | raw unsigned min | shipped |
| `0x95` | `\rmax` | `⊔` | raw unsigned max | shipped |
| `0x96` | `\rlt` | `﹤` | raw unsigned less | shipped |
| `0x97` | — | — | spare (raw-atom range) | reserved |
| `0xA0` | `\slt` | `≺` | signed less | shipped |
| `0xA1` | `\sgt` | `≻` | signed greater | shipped |
| `0xA2` | `\shl` | `≪` | shift left | shipped |
| `0xA3` | `\sar` | `≫` | arithmetic shift right | shipped |
| `0xA4` | `\fetch` | `⊙` | 64-bit fetch | shipped |
| `0xA5` | `\store` | `⊛` | 64-bit store | shipped |
| `0xA6` | `\brk` | `⌸` | `brk` syscall — the list heap's growth primitive | shipped |
| `0xA7` | `\sys` | `⎈` | raw syscall: `a1 a2 a3 num -> result` (wave 8, M-TOOL) | shipped |
| `0xB0` | `\chain` | `⊚` | chain definition prefix: `⊚name f g h;` (compiler logic, no template) | shipped |
| `0xC0` | `\vadd` | `∔` | polymorphic add | shipped |
| `0xC1` | `\vsub` | `∸` | polymorphic sub | shipped |
| `0xC2` | `\vmul` | `⨰` | polymorphic mul | shipped |
| `0xC3` | `\vmin` | `⩍` | polymorphic min | shipped |
| `0xC4` | `\vmax` | `⩌` | polymorphic max | shipped |
| `0xC5` | `\comp` | `∘` | compose two quotations (writes a 39-byte thunk into the code arena) | shipped |
| `0xC6` | `\pipe` | `⇉` | pipeline (thread a value through a list of quotations) | shipped |
| `0xC7` | `\fork` | `⑂` | fork: `x ′f ′g ′h -> h(f x, g x)` | shipped |

`0x91`–`0x96` are the raw scalar atoms M-VEC needs (see NEXT_STEPS.md §3): they
keep the non-polymorphic behavior of `+ - * ⌊ ⌈ <` so the prelude's own pointer
arithmetic can migrate to them before the ASCII bytes start dispatching on
shape. `0xC0`–`0xC7` are prelude *words* at high bytes, not templates — they
have no entry in `mkblob2.ATOMS`; they get `codepage.LIB` rows (which, being
≥ `0x80`, decode as well as encode).

`0xA7 \sys` is the last slot of the M4 range and the language's first general
syscall. Its ABI is three arguments and a number, `a1 a2 a3 num ⎈ -> result`,
which covers every syscall the tools need — `open`(path,flags,mode) (number 2,
**not** `openat`, which would need a 4th argument in `r10`), `read`/`write`
(fd,buf,n), `close`(fd,_,_), `exit`(code,_,_), `brk`(addr,_,_), `lseek`. Push `0`
for unused arguments; the kernel's return value is pushed back (negative errno on
failure). A syscall needing `r10`/`r8`/`r9` would need its own op — deliberately
out of scope. `⌸ \brk` shipped separately in W6/M-MEM and stays: the heap's
growth primitive wants a dedicated one-argument op, not a raw number and three
pushes, and the prelude — which must never pay for what it does not use — calls
it on every allocation that outgrows the break.

---

## 2. Prelude word letters

A prelude word is a single byte, so every word costs one ASCII letter forever.
Uppercase letters are the pool.

**In use (shipped):** `A` alloc · `D` shape dispatch · `E` newline · `F` fold ·
`G` broadcast int⊙list · `H` heap-pointer address · `I` index · `J` join ·
`K` broadcast list⊙int · `L` len · `M` map · `N` print signed decimal · `O` puts ·
`P` product · `Q` show · `R` range · `S` sum · `T` shape test · `U` chars ·
`V` reverse · `W` filter · `X` push spill frame · `Y` pop spill frame · `Z` zip.

**Assigned (do not use for anything else):**

| Letter | Meaning | Wave | Status |
|--------|---------|------|--------|
| `X` | push scratch spill frame | W1 | shipped |
| `Y` | pop spill frame | W1 | shipped |
| `T` | shape test (is this value a list?) | W2 | shipped |
| `D` | binary shape dispatcher | W2 | shipped |
| `K` | broadcast `list ⊙ int` | W2 | shipped |
| `G` | broadcast `int ⊙ list` | W2 | shipped |

**Free:** `B`, `C` — reserved, unassigned. That is the *entire* remaining
uppercase pool. Anything after them needs a high byte from `0xC0`–`0xCF` (§1.2)
or M2 multi-char identifiers.

> **Rule: the prelude must NEVER use `→x` / `←x`.** The variable bank at
> `0x4E0000` is user space — one global cell per name — so a prelude word that
> stored to `→i` would silently clobber a user's `i`. Prelude state goes in the
> fixed scratch cells of §3.

### 2.1 Tool-library letters (lowercase)

The uppercase pool above is the *prelude's*, and it is nearly gone. The GOLF
tool libraries — `lib/tio.golfj`, `lib/ttext.golfj`, `lib/tutf.golfj`, prepended
by `gtools/build` after the prelude and only for programs under `gtools/` — take
**lowercase** letters, which no prelude word has ever used. They are a separate,
much roomier pool, so a new tool word costs nothing scarce.

The same discipline applies: allocate here first. Ranges are partitioned by
library — which is what let the three be written in parallel without
contending; each range is detailed per letter below its own heading.

| Range | Owner | Wave | Status |
|-------|-------|------|--------|
| `a`–`h` | `lib/tio.golfj` — file/stream I/O on `⎈`, argv (per letter below) | W8 | shipped |
| `i`–`r` | `lib/ttext.golfj` — byte-buffer text words (per letter below) | W8 | shipped |
| `s`–`z` | `lib/tutf.golfj` — code-page table loader + glyph matching (per letter below) | W8 | shipped |

#### `s`–`z` — `lib/tutf.golfj`, the code-page table (W8, shipped)

`lib/tutf.golfj` loads `data/codepage.tsv` into a flat array of six-cell
records and answers the
four lookups an encoder and a decoder need; `s` is spent on the library's one
**variable** (`→s`/`←s`, written `\sets`/`\gets`), which holds the base of the
16-cell heap block all its state lives in, so the library claims no fixed
scratch in §3 at all.

| Letter | Signature | Meaning | Wave | Status |
|--------|-----------|---------|------|--------|
| `s` | — | *not a word*: the variable holding `tutf`'s state block | W8 | shipped |
| `t` | `buf len -> n` | parse `data/codepage.tsv` from a buffer; → record count | W8 | shipped |
| `u` | `a -> b` | the byte spelled by the two hex digits at address `a` | W8 | shipped |
| `v` | `p e -> b k` | longest **glyph** matching the bytes at `p`, never past `e`; `k = 0` = none | W8 | shipped |
| `w` | `p e -> b k` | longest **mnemonic** that is a prefix of the bytes at `p`, never past `e`; `k = 0` = none | W8 | shipped |
| `x` | `b -> p k` | byte → glyph bytes, `ED` rows only; `k = 0` = not decodable | W8 | shipped |
| `y` | `b -> p k` | byte → mnemonic bytes, `ED` rows only; `k = 0` = not decodable | W8 | shipped |
| `z` | `p q k -> f` | `0` iff the `k` bytes at `p` equal the `k` bytes at `q` | W8 | shipped |

#### `a`–`h` — `lib/tio.golfj`, files, streams and argv (W8, shipped)

| Letter | Signature | Meaning |
|--------|-----------|---------|
| `a` | `str ->` | die: the `“…“` block to fd 2, a newline, `exit(1)` |
| `b` | `path w -> fd` | open: `w`=0 read-only, `w`≠0 create/truncate for writing |
| `c` | `fd buf n -> got` | one `read`; `got` is 0 at EOF, never negative |
| `d` | `fd buf n ->` | write **all** n bytes, looping over short writes |
| `e` | `fd -> buf len` | slurp the whole fd into a fresh heap buffer |
| `f` | `->` | flush the output buffer |
| `g` | `byte ->` | emit one byte into the output buffer (auto-flushes at 8192) |
| `h` | `i -> ptr` | `argv[i]`, or 0 when `i >= argc` |

Eight letters is the entire budget for the file, so two things stayed phrases:
`argc` is `5177408 ⊙ ⊙` and `close(fd)` is `fd 0 0 3 ⎈ _`. `h` already does the
bounds comparison (which is the only spelling that cannot read past the end of
the array), and `close` is a courtesy on a short-lived process whose `exit`
closes every descriptor — so neither was worth displacing `a` (the whole error
policy) or `h` (the 64-bit argv arithmetic). Every wrapper checks the kernel's
return value and dies through `a` rather than returning a status a build script
could forget to test.

#### `i`–`r` — `lib/ttext.golfj`, byte-buffer text words (W8, shipped)

The `i`–`r` range is spent in full; there is no room left in it, which is why
is-hex-digit is `k 0≺` rather than a word of its own. A **text buffer** here is
a raw `(addr, len)` pair on the data stack — what `read(2)` hands back — not a
`“…“` block; a block is fed in as `←t 4﹢` plus `←t @`. Flags are zero-is-true
(0 = yes) like `T`; "not found" and "not a hex digit" are `-1`, so they must be
tested with the signed `≺` and never with the unsigned `»`/`﹤`, which see `-1`
as the largest number there is. Parking one in a `→x`/`←x` variable is safe
**since W8A/M3W** and was not before it: the 4-byte bank's zero-extending load
turned `-1` into `4294967295` and silently disabled the not-found branch. The
64-bit bank fixed that for every caller at once; `test/run2.sh` keeps a
regression case on it.

| Letter | Signature | Meaning | Wave | Status |
|--------|-----------|---------|------|--------|
| `i` | `ch -> f` | is-digit: 0 for `'0'`–`'9'`, 1 otherwise | W8 | shipped |
| `j` | `ch -> f` | is-ASCII-letter: 0 for `A`–`Z` `a`–`z` only, 1 otherwise | W8 | shipped |
| `k` | `ch -> v` | hex-digit value 0–15, or -1; `k 0≺` is the is-hex-digit test | W8 | shipped |
| `l` | `addr -> b` | the two hex digits at `addr` as one byte 0–255, or -1 | W8 | shipped |
| `m` | `src dst n ->` | copy `n` bytes, ascending | W8 | shipped |
| `n` | `addr len -> v used` | parse an unsigned decimal run: value and bytes consumed | W8 | shipped |
| `o` | `v addr -> nb` | write `v` as unsigned decimal at `addr`; bytes written | W8 | shipped |
| `p` | `a alen b blen -> f` | 0 iff `(a,alen)` starts with `(b,blen)`; equality at equal lengths | W8 | shipped |
| `q` | `addr len ch -> i` | index of the first `ch` in the range, or -1 | W8 | shipped |
| `r` | `a alen b blen -> i` | index of the first `(b,blen)` inside `(a,alen)`, or -1 | W8 | shipped |

`ttext` allocates **no** variable name and **no** new fixed address: every
looping word frames with `X`/`Y` and then uses the prelude's own `s0`–`s7`, so
a `gtools/` program's `→x`/`←x` can never collide with it and a pointer can
never be truncated by the bank's 4-byte cells. `k` is a leaf (no scratch, no
frame) and is callable with someone else's scratch live.

Two rules carry over from the prelude and one does not:

- Tool libraries obey the same scratch discipline (`X`/`Y` frames, §3) and the
  same raw-atom rule (`\radd` and friends, never the polymorphic ASCII ops).
- A tool library **may** use `→x`/`←x`: unlike the prelude it is not linked into
  user programs, only into `gtools/` programs, which own their whole process.
  Variable names are still allocated per library in the file's own header.
- A `gtools/` program may use any letter not claimed above, plus digits.

---

## 3. Memory map

GOLF has no hex literals, so every address is spelled in decimal in the source;
both forms are given here and the decimal is the one you type.

| Address (hex) | Decimal | Use | Status |
|---------------|---------|-----|--------|
| `0x410000` | 4259840 | compiler data base `D` (`m`) | shipped |
| `m+4` … `m+16` | | v1 compiler scratch (`P`, `S`, `Q`) | shipped |
| `m+20`, `m+24`, `m+28` | | golf2 compiler scratch: `′` jmp-site / thunk addr, `“` len-site / count | shipped |
| `m+32`, `m+36` | | M-CHAIN2 chain state in the **seed** only: the in-a-chain flag, the link count | shipped |
| `m+40`, `m+44`, `m+48` | | M-CHAIN2 in the **seed** only: the first three buffered link bytes | shipped |
| `m+52` | | **first free compiler scratch** | free |
| `m+2048`, `m+4096` | | v1 name table / buffer — do not encroach | shipped |
| `0x4D0000`–`0x4DFFFF` | 5046272– | M-CHAIN runtime-thunk code arena — `∘` bump-allocates 39 bytes of machine code per call (1680 thunks; never freed) | shipped |
| `0x4E0000`–`0x4E07FF` | 5111808–5113855 | user variable bank (`→x`/`←x`), **8 bytes per name** (M3W; it was 4), 256 names = 2 KB — **user space** | shipped |
| `0x4F0000` | 5177344 | heap pointer (word `H`) | shipped |
| `0x4F0010`–`0x4F002C` | 5177360–5177388 | **RETIRED** — the old 4-byte-stride scratch bank `s0`–`s7`; W4A moved the bank to `0x4F0060` and nothing reads these eight cells any more | free |
| `0x4F0030` | 5177392 | spill-stack pointer (a byte offset; BSS-zero at start) | shipped |
| `0x4F0034` | 5177396 | **heap base cell** — the `brk` the prelude's init was handed, published for `T` and the five M-VEC templates. ASLR-shifted every run, so it is never spelled out anywhere | shipped |
| `0x4F0038` | 5177400 | **heap span cell** — how far the break has been pushed since; `T` is `v - base <u span` | shipped |
| `0x4F003C` | 5177404 | code-arena pointer (a byte offset into `0x4D0000`; BSS-zero at start) | shipped |
| `0x4F0040`–`0x4F0047` | 5177408 | **entry `rsp`** — the process stack pointer as the kernel left it, stashed by `STARTUP` before anything pushes; `argc` is at `[cell]`, `argv[i]` at `[cell]+8+8*i` (W8, M-TOOL) | shipped |
| `0x4F0048`–`0x4F005F` | 5177416–5177439 | reserved for future scratch | free |
| `0x4F0060`–`0x4F0098` | 5177440–5177496 | prelude scratch `s0`–`s7`, **stride 8** — **all eight in use** (`s0` list, `s1` index, `s2` accumulator, `s3` fn addr, `s4` result, `s5` alloc temp, `s6` filter count, `s7` zip's 2nd list / K's + G's parked broadcast scalar). Decimals in order: 5177440 · 5177448 · 5177456 · 5177464 · 5177472 · 5177480 · 5177488 · 5177496 | shipped |
| `0x4F00A0`–`0x4F00B8` | 5177504 · 5177512 · 5177520 · 5177528 | `lib/tio.golfj` state, **stride 8**: output-buffer base (a heap address, allocated by the library's init line) · bytes pending in it · the fd `f`/`g` write to (1 until a tool stores another) · `a`'s staging cell (the message address, then the byte holding its newline) | shipped |
| `0x4F00C0`–`0x4F00FF` | 5177536–5177599 | reserved for future scratch | free |
| `0x4F0100`–`0x4F08FF` | 5177600–5179647 | M-VEC hook table: 256 entries × 8 bytes, stride 8, indexed by op byte. Cell for byte `B` is `0x4F0100 + 8*B`; non-zero = the polymorphic template for `B` calls it. Installed by the prelude's last line: `+` 5177944 → `∔` · `-` 5177960 → `∸` · `*` 5177936 → `⨰` · `⌈` 5178688 → `⩌` · `⌊` 5178696 → `⩍` | shipped |
| `0x4F0900`–`0x4F0FFF` | 5179648–5181439 | scratch spill stack (the region `X`/`Y` push and pop) — 28 frames of 64 bytes (8 cells × 8 bytes; it was 56 × 32 before W4A) | shipped |
| `0x600000` | 6291456 | **return-stack top and BSS end** — one number, `mkblob2.RSTACK_TOP` (= `golf0.BASE + MEMSZ`, `p_memsz` = `0x200000`); grows **down**, and nothing grows up to meet it | shipped |
| the `brk` | — | **the list heap**, above the whole load segment, grown by `⌸`. Not a fixed address: the kernel ASLR-shifts the initial break, which is why it lives in the two cells above | shipped |

Notes:

- **Scratch is exhausted.** All eight of `s0`–`s7` are live in `lib/prelude.golfj`
  today. A new prelude word that needs a temporary must either use one of the
  cells above or push a spill frame (`X`/`Y`) — it may not invent an address.
- **The entry-`rsp` cell is a full 8 bytes and must be read with `⊙`.** It is
  written by `tools/mkblob2.STARTUP2` (mirrored by `boot/golfref.py`), which is
  v1's `mov ebp, 0xC00000` with a `mov [0x4F0040], rsp` in front — so every
  binary the v2 toolchain emits is 8 bytes longer than it used to be. Unlike
  every other fixed cell here it holds a *stack* address, which on Linux x86-64
  is far above 2^32 — `@` would truncate it. So are the `argv[i]` pointers it
  leads to, and any buffer address handed to `⎈`: all of that arithmetic is
  64-bit, `⊙`/`⊛` and the raw atoms, never `@`/`!`.
- **Scratch is 64-bit and 8-strided; the four fixed cells are not.** A list cell
  has been 8 bytes since M4/W4A, so every scratch slot has to hold a full 64-bit
  value — which is why the bank was *relocated* to `0x4F0060` rather than
  widened in place (at a 4-byte stride `s0`'s high half is `s1`). All scratch
  access is `⊙`/`⊛` (`\fetch`/`\store`). The four cells at `0x4F0030`–`0x4F003C`
  deliberately did **not** move or widen: they hold pointers and byte offsets
  that are < 2^31 in practice, plain `@`/`!` on them is therefore exact, and
  `0x4F0034` in particular is baked into every M-VEC template as a 32-bit
  compare operand. That is a real 4 GB ceiling on the break (DESIGN.md, known
  limits) — widening the cells means widening five templates with them.
  The **user variable bank at `0x4E0000` was 4 bytes per name for the same
  reason and is now 8** (M3W): unlike the four fixed cells, no template hard-codes
  a bank address — the compiler computes `0x4E0000 + 8*name` when it emits the
  store — so the stride could be changed by changing the two emitters, in
  `self/golf2.golfj`, `mkblob2.py`'s seed cases and `boot/golfref.py` alike.
  Widening it *in place* was as impossible as it was for the scratch bank: at a
  4-byte stride, name `x`'s high half is name `x+1`'s cell.
  A string is still `[len:4][bytes]`, so `O`/`U` read its length with
  the 32-bit `@`; only `U`'s *output* is an 8-byte-cell list.
- **Scratch is callee-saved, not caller-saved.** Every scratch-using looping
  word in the prelude opens with `X` and closes with `Y` (lifting its result
  onto the data stack first, since `Y` is stack-neutral), so higher-order words
  nest: a mapped function may itself call `R`/`S`/`M`/… . `X` and `Y` touch no
  scratch themselves — only the data stack and absolute addresses. `A` is the
  one exception: `s5` is A-only and never held across a call, so `A` needs no
  frame, and `I` is scratch-free.
- **The heap/return-stack collision is gone.** Until M-MEM a bump heap grew up
  from `0x500000` while the return stack grew down from `0xC00000` inside the
  same 8 MB BSS: a list of ~917k cells met the stack and the program died. The
  heap is now the kernel's, grown with `brk` (`0xA6`) above the load segment, so
  `p_memsz` reserves only what is statically addressed (`0x200000`) and the
  return stack has its 1.08 MB — ≈138k frames — entirely to itself. That is why
  `0x4F0034`/`0x4F0038` exist: the base cannot be a constant any more.
  **Do not add a fixed heap-base row to this table.**
- The M-VEC hook table is at stride 8 (not 4) so it stayed correct when M4
  widened list cells to 64 bits — which W4A has now done, with no change to the
  templates, the hook cells or the seed.

---

## 4. Adding something

1. Add the row here first, `reserved`, with the wave that will ship it.
2. Run `python3 tools/codepage.py check` — it must exit 0 *before* you write
   any code (the row is not yet in the tables) *and* after (the tables agree).
3. Implement: `tools/mkblob2.py` (`ATOMS` template, for a real op) **and**
   `boot/golfref.py` (oracle parity), a `tools/codepage.py` `LIB`/`COMPILER`
   row, a `lib/prelude.golfj` definition for a word, and a `test/run2.sh` case.
   For a **compiler-logic** op (a prefix/token, not a template): write it in
   `self/golf2.golfj` — the compiler's source since M-SELF — *and* mirror it
   into `tools/mkblob2.py`'s v1-GOLF seed cases, or `test/selfcheck.sh`'s
   byte-for-byte `seed == golf2` comparison will catch the drift.
4. Flip `reserved` → `shipped` in the same commit.
5. Regenerate: `cd expanded && python3 tools/mkblob2.py`, then commit both
   `self/seed.golf` and `self/golf2.golf` — they are generated, never edited.
