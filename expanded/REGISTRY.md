# Expanded GOLF — resource registry

GOLF has three global, flat namespaces — **op bytes**, **`\mnemonics`**, and
**glyphs** — plus two scarce address spaces: **prelude word letters** (one byte
per word) and **fixed runtime memory**. All five are collision-prone and none of
them used to be written down, so two parallel changes could pick the same byte
and only find out when the fixpoint broke.

**Rule: no one picks a byte, glyph, mnemonic, prelude letter, or scratch address
on their own. It is assigned here first, then implemented.** Adding a row here
is cheap and reversible; discovering a collision after `self/golf2.golf` has
been regenerated is not.

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
compiler prefixes). **`0x91`–`0xFF` — 111 bytes — is the entire remaining op
space**, partitioned as follows so waves never contend:

| Range         | Owner / purpose                                            |
|---------------|------------------------------------------------------------|
| `0x91`–`0x97` | Raw scalar atoms (wave 0) — the non-polymorphic arithmetic the prelude's own pointer math uses, so M-VEC can make the ASCII bytes polymorphic without the dispatcher recursing |
| `0xA0`–`0xA7` | M4 atoms (wave 1) — signed compare, shifts, 64-bit fetch/store, `brk` |
| `0xB0`–`0xBF` | Future compiler-logic ops (prefixes/tokens handled in golf2's `t`, like `ref`/`str`/`→`/`←`) |
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
| `0x91` | `\radd` | `﹢` | raw add | shipping in wave 0 |
| `0x92` | `\rsub` | `﹣` | raw sub | shipping in wave 0 |
| `0x93` | `\rmul` | `﹡` | raw mul | shipping in wave 0 |
| `0x94` | `\rmin` | `⊓` | raw unsigned min | shipping in wave 0 |
| `0x95` | `\rmax` | `⊔` | raw unsigned max | shipping in wave 0 |
| `0x96` | `\rlt` | `﹤` | raw unsigned less | shipping in wave 0 |
| `0x97` | — | — | spare (raw-atom range) | reserved |
| `0xA0` | `\slt` | `≺` | signed less | shipped |
| `0xA1` | `\sgt` | `≻` | signed greater | shipped |
| `0xA2` | `\shl` | `≪` | shift left | shipped |
| `0xA3` | `\sar` | `≫` | arithmetic shift right | shipped |
| `0xA4` | `\fetch` | `⊙` | 64-bit fetch | shipped |
| `0xA5` | `\store` | `⊛` | 64-bit store | shipped |
| `0xA6` | `\brk` | `⌸` | `brk` syscall (wave 6) | reserved |
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

---

## 2. Prelude word letters

A prelude word is a single byte, so every word costs one ASCII letter forever.
Uppercase letters are the pool.

**In use (shipped):** `A` alloc · `D` shape dispatch · `E` newline · `F` fold ·
`G` broadcast int⊙list · `H` heap-pointer address · `I` index · `J` join ·
`K` broadcast list⊙int · `L` len · `M` map · `N` print uint · `O` puts ·
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

---

## 3. Memory map

GOLF has no hex literals, so every address is spelled in decimal in the source;
both forms are given here and the decimal is the one you type.

| Address (hex) | Decimal | Use | Status |
|---------------|---------|-----|--------|
| `0x410000` | 4259840 | compiler data base `D` (`m`) | shipped |
| `m+4` … `m+16` | | v1 compiler scratch (`P`, `S`, `Q`) | shipped |
| `m+20`, `m+24`, `m+28` | | golf2 compiler scratch: `′` jmp-site / thunk addr, `“` len-site / count | shipped |
| `m+32` | | **first free compiler scratch** | free |
| `m+2048`, `m+4096` | | v1 name table / buffer — do not encroach | shipped |
| `0x4D0000`–`0x4DFFFF` | 5046272– | M-CHAIN runtime-thunk code arena — `∘` bump-allocates 39 bytes of machine code per call (1680 thunks; never freed) | shipped |
| `0x4E0000` | 5111808 | user variable bank (`→x`/`←x`), 4 bytes per name — **user space** | shipped |
| `0x4F0000` | 5177344 | heap pointer (word `H`) | shipped |
| `0x4F0010`–`0x4F002C` | 5177360–5177388 | prelude scratch `s0`–`s7` — **all eight in use** (`s0` list, `s1` index, `s2` accumulator, `s3` fn addr, `s4` result, `s5` alloc temp, `s6` filter count, `s7` zip's 2nd list) | shipped |
| `0x4F0030` | 5177392 | spill-stack pointer (a byte offset; BSS-zero at start) | shipped |
| `0x4F0034` | 5177396 | heap base cell | shipped |
| `0x4F0038` | 5177400 | heap span cell | shipped |
| `0x4F003C` | 5177404 | code-arena pointer (a byte offset into `0x4D0000`; BSS-zero at start) | shipped |
| `0x4F0040`–`0x4F00FF` | 5177408–5177599 | reserved for future scratch | free |
| `0x4F0100`–`0x4F08FF` | 5177600–5179647 | M-VEC hook table: 256 entries × 8 bytes, stride 8, indexed by op byte. Cell for byte `B` is `0x4F0100 + 8*B`; non-zero = the polymorphic template for `B` calls it. Installed by the prelude's last line: `+` 5177944 → `∔` · `-` 5177960 → `∸` · `*` 5177936 → `⨰` · `⌈` 5178688 → `⩌` · `⌊` 5178696 → `⩍` | shipped |
| `0x4F0900`–`0x4F0FFF` | 5179648–5181439 | scratch spill stack (the region `X`/`Y` push and pop) — 56 frames of 32 bytes | shipped |
| `0x500000` | 5242880 | heap base today (bump allocator) | shipped |
| `0xC00000` | 12582912 | return stack top (grows **down** into the heap) | shipped |

Notes:

- **Scratch is exhausted.** All eight of `s0`–`s7` are live in `lib/prelude.golfj`
  today. A new prelude word that needs a temporary must either use one of the
  cells above or push a spill frame (`X`/`Y`) — it may not invent an address.
- **Scratch is callee-saved, not caller-saved.** Every scratch-using looping
  word in the prelude opens with `X` and closes with `Y` (lifting its result
  onto the data stack first, since `Y` is stack-neutral), so higher-order words
  nest: a mapped function may itself call `R`/`S`/`M`/… . `X` and `Y` touch no
  scratch themselves — only the data stack and absolute addresses. `A` is the
  one exception: `s5` is A-only and never held across a call, so `A` needs no
  frame, and `I` is scratch-free.
- **Heap/return-stack collision** is real: the bump heap at `0x500000` grows up
  and the return stack grows down from `0xC00000` in the same 8 MB segment.
  W6/M-MEM moves the heap above `0xC00000` and sizes it with `brk` (`0xA6`),
  which is why `0x4F0034`/`0x4F0038` exist.
- The M-VEC hook table is at stride 8 (not 4) so it stays correct after M4
  widens cells to 64 bits.

---

## 4. Adding something

1. Add the row here first, `reserved`, with the wave that will ship it.
2. Run `python3 tools/codepage.py check` — it must exit 0 *before* you write
   any code (the row is not yet in the tables) *and* after (the tables agree).
3. Implement: `tools/mkblob2.py` (`ATOMS` template, for a real op) **and**
   `boot/golfref.py` (oracle parity), a `tools/codepage.py` `LIB`/`COMPILER`
   row, a `lib/prelude.golfj` definition for a word, and a `test/run2.sh` case.
4. Flip `reserved` → `shipped` in the same commit.
