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
space; **68** are now spent, leaving **43** free. It is partitioned as follows
so waves never contend:

| Range         | Owner / purpose                                            |
|---------------|------------------------------------------------------------|
| `0x91`–`0x97` | Raw scalar atoms (wave 0) — the non-polymorphic arithmetic the prelude's own pointer math uses, so M-VEC can make the ASCII bytes polymorphic without the dispatcher recursing |
| `0xA0`–`0xA7` | M4 atoms (wave 1) — signed compare, shifts, 64-bit fetch/store, `brk` |
| `0xB0`–`0xBF` | Future compiler-logic ops (prefixes/tokens handled in golf2's `t`, like `ref`/`str`/`→`/`←`) — since M-SELF written in `self/golf2.golfj`, and mirrored into `mkblob2.py`'s v1-GOLF seed |
| `0xC0`–`0xCF` | High-byte prelude words (wave 2) — words that need a byte of their own instead of a scarce ASCII letter |
| `0xD0`–`0xD7` | High-byte prelude words, continued (W11-0 opened it: `0xC0`–`0xCF` is full) — still only for a word that earns a byte of its own; the default for a new prelude word is a long name |
| `0xD8`–`0xEF` | High-byte prelude words, continued again (W12-0 released the old "chain syntax / M4c" reservation: chain syntax shipped at `0xB0`). Same rule as `0xD0`–`0xD7`: only for a word that earns a byte |
| `0xF0`–`0xFF` | User extension space — never allocated by the language      |

Gaps between the ranges (`0x98`–`0x9F`, `0xA8`–`0xAF`) are deliberate headroom
for the range immediately above them; do not fill them opportunistically.
W11-0 spent the first of that headroom deliberately: `0xA8`–`0xAB` continue
the M4 atom range (`0xA0`–`0xA7` is full) for W11-3A's stack-pointer atoms
(§1.3). The budget line above counts only what the tables in
`tools/mkblob2.py` / `tools/codepage.py` hold, so a `reserved` row in §1.3
moves it when it ships, not before.

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
| `0x88` | `\max` | `⌈` | signed max (`cmovl`, W9-1A; was unsigned); unsigned max stays available as `⊔` | shipped |
| `0x89` | `\min` | `⌊` | signed min (`cmovg`, W9-1A; was unsigned); unsigned min stays available as `⊓` | shipped |
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
| `0xB1` | `\dloc` | `⊡` | define a word WITH a frame of per-call locals, one cell per local it names (≤ 16; sized at `;` since M-FRAME2, W9-4D): `⊡name … ;` (compiler logic, no template) | shipped |
| `0xB2` | `\lset` | `⇒` | pop TOS into local `x`, `x` in `a`–`h` or a `‹long name›` (W9-4D) (compiler logic, no template) | shipped |
| `0xB3` | `\lget` | `⇐` | push local `x`, `x` in `a`–`h` or a `‹long name›` (W9-4D) (compiler logic, no template) | shipped |
| `0xB4` | `\lname` | `‹` | open a long name `‹name›` — a word, quotation, chain link or variable name of `0-9 A-Z a-z _ -` bytes (M2, W9-3A; compiler logic, no template) | shipped |
| `0xB5` | `\rname` | `›` | close a long name (M2, W9-3A; only ever read by the `‹` case) | shipped |
| `0xC0` | `\vadd` | `∔` | polymorphic add | shipped |
| `0xC1` | `\vsub` | `∸` | polymorphic sub | shipped |
| `0xC2` | `\vmul` | `⨰` | polymorphic mul | shipped |
| `0xC3` | `\vmin` | `⩍` | polymorphic min | shipped |
| `0xC4` | `\vmax` | `⩌` | polymorphic max | shipped |
| `0xC5` | `\comp` | `∘` | compose two quotations (writes a 39-byte thunk into the code arena) | shipped |
| `0xC6` | `\pipe` | `⇉` | pipeline (thread a value through a list of quotations) | shipped |
| `0xC7` | `\fork` | `⑂` | fork: `x ′f ′g ′h -> h(f x, g x)` | shipped |
| `0xC8` | `\match` | `≣` | structural equality of two values, recursing into nested lists: `a b -> -1/0` (W9-3B) | shipped |
| `0xC9` | `\depth` | `⍤` | nesting depth: an int is 0, a flat list 1, a list of lists 2 … (W9-3B) | shipped |
| `0xCA` | `\free` | `⌫` | `list ->`: release a list (tagged) or raw `A` block to the allocator's size-classed free list; explicit only (W9-3C, M-MEM2) | shipped |
| `0xCB` | `\cat` | `⧺` | concatenate two lists (W9-4A) | shipped |
| `0xCC` | `\take` | `↑` | `list n -> list`: the first n elements (W9-4A) | shipped |
| `0xCD` | `\drop` | `↓` | `list n -> list`: all but the first n elements (W9-4A) | shipped |
| `0xCE` | `\sort` | `⍋` | ascending signed sort, returns a new list (W9-4B) | shipped |
| `0xCF` | `\memb` | `∊` | `list x -> f`: 0 if x is an element (zero-is-true, like `T`), 1 otherwise (W9-4B) | shipped |

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

### 1.3 W11 assignments — reserved in W11-0, do not re-pick

Allocated up front for the W11 waves (round 3, Python/Rust gaps). None of these
is in `mkblob2.ATOMS` / `codepage.COMPILER` / `codepage.LIB` yet: each row is
added there — and flipped to `shipped` here — by the task named, in the same
commit as its implementation. W11-0 ran `python3 tools/codepage.py check` with
the five rows below added to the tables temporarily, and it passed: no byte
reuse, no mnemonic prefix pair (`\spr` `\spw` `\import` `\rec` `\bind` are
prefix-free against the 75 mnemonics of the three tables and each other), no glyph reuse.

| Byte | Mnemonic | Glyph | Meaning | Wave | Status |
|------|----------|-------|---------|------|--------|
| `0xA8` | `\spr` | `⊷` | atom: push the data-stack pointer and the return-stack pointer, `-> sp bp` (rsp as it was before the atom pushed anything, then rbp; template `push rsp; push rbp`) — what `‹catch›` saves | W11-3A | shipped |
| `0xA9` | `\spw` | `⊶` | atom: `sp bp ->` set rbp, then rsp (pops both first, so the values are consumed before rsp moves; template `pop rbp; pop rsp`) — what `‹throw›` restores | W11-3A | shipped |
| `0xAA`, `0xAB` | — | — | spare, **W11-3A only** (e.g. if the read/set split wants four atoms); anyone else asks. W11-3A did not need them (two atoms were enough); W13 took them for the bit atoms (§1.5) | W11-3A | released |
| `0xB6` | `\import` | `⎘` | compiler op, include prefix: `⎘“path“` compiles that file's source in place (fd-0 swap, include-once, search `.` then `lib/` then `vendor/` — the last added by W11-4A) — see the decision below; `codepage.COMPILER` row, cases in `self/golf2.golfj`, the seed and `boot/golfref.py` | W11-2A | shipped |
| `0xB7` | `\rec` | `⊜` | compiler op, record definition header: `⊜‹point›‹x›‹y›;` defines a constructor `‹point›` and per-field accessors `‹point-x›` / setters `‹set-point-x›` over a plain list, synthesized at compile time from `⍳ ⊇ & \ _ ≪ > ﹢ ⊛`; `codepage.COMPILER` row, cases in `self/golf2.golfj`, the seed and `boot/golfref.py` | W11-4A | shipped |
| `0xB8` | — | — | spare compiler op, for the W11 front-end owners (2A / 3B / 4A); unused in W11, now W12-A7's `\else` `⋄` (§1.4 below) | W11-2A/3B/4A | released |
| `0xD0` | `\bind` | `⊸` | prelude word at a high byte: `x ′f ⊸ -> ′g`, `g` = push x, call f (a thunk in the `∘` arena, bound-checked like `∘`) | W11-2C | shipped |

The atom semantics in the table are W11-0's intent, not a spec: W11-3A owns the
two templates (and their `boot/golfref.py` mirror) and may refine the order of
the two values, provided the row here is updated in the same commit. **W11-3A
shipped `0xA8`/`0xA9`** with the order as allocated: `⊷` is `push rsp; push rbp`
(x86 `push rsp` stores rsp's value before that push, so `sp` is the stack
exactly as it was before the atom) and `⊶` is `pop rbp; pop rsp`. The oracle
inherits both from `mkblob2.ATOMS`.

**`‹include›` decision (W11-0).** Include is a **compiler op byte** (`0xB6`),
not a long name the compiler recognises. Reasons: every other compiler-level
construct (`′ “ → ← ⊚ ⊡ ⇒ ⇐ ‹ ›`) is a byte the tokenizer `t` dispatches on,
so this is one more case there and in the seed; recognising the text
`include` would mean either pre-interning a name at compiler start (one of the
1024 long-name slots gone from every program, and the name numbering shifted
for every existing test) or comparing the bytes of every *new* long name
against `include`, in both compilers. Spelled `⎘“path“` (glyph) or
`\import“path“` (mnemonic) — `\include` is impossible, since `\inc` exists
and the prefix rule forbids a mnemonic that extends it. `‹include›` is **not**
reserved and stays an ordinary user name. **Records (`⊜`, W11-4A)** follow the
same reasoning: an op byte in the compiler-logic range.

**Codepage rows are deferred.** No `codepage.LIB` row for `⊸` exists before
W11-2C ships the word: a LIB row would put the word in REFERENCE.md's generated
table (run2.sh requires it to match `codepage.py reference`) and make the
encoder accept `⊸` while the byte compiles to an undefined word — documented
but not real. W11-2C adds the row, the REFERENCE regeneration and the prelude
definition together; likewise W11-3A for `0xA8`/`0xA9` (ATOMS) and
W11-2A / W11-4A for `0xB6` / `0xB7` (COMPILER). **W11-2C shipped `0xD0`:** the
LIB row, the generated REFERENCE row and the `⊸` definition (prelude section
`# === W11-2C bind ===`) landed together; its thunk is 38 bytes in the `∘`
arena, on `∘`'s bump pointer and bound.

---

### 1.4 W12 assignments — reserved in W12-0, do not re-pick

Allocated up front for the W12 waves ([`PLAN_W12.md`](PLAN_W12.md)). As in
W11, none of these is in `mkblob2.ATOMS` / `codepage.COMPILER` /
`codepage.LIB` yet: the task named adds its row there, and flips it to
`shipped` here, in the same commit as its implementation. W12-0 checked the
thirteen mnemonics below against the 75 shipped ones and each other: no prefix
pair (`\sortby` was renamed `\ksort`, because `\sort` is a prefix of it), and
no glyph is in use.

| Byte | Mnemonic | Glyph | Meaning | Task | Status |
|------|----------|-------|---------|------|--------|
| `0xB8` | `\else` | `⋄` | compiler op: the separator in `c[a⋄b]` (if-else: `a` when c is 0, else `b`) and `{c⋄body}` (top-tested while: `body` while c is 0). The plan's `{?c⋄body}` is spelled without the `?`, which stays byte fetch. This is W11's unused spare | A7 | shipped |
| `0xB9` | `\vinc` | `⇡` | compiler op, prefix: `⇡x` increments variable `x` (`←x⊕→x`) as one `inc qword [cell]`; `x` a letter or `‹long name›`; inside a `⊡` word a local already named there wins (`inc qword [rbp+d]`). No not-a-number check | Z2 | shipped |
| `0xBA` | `\vdec` | `⇣` | compiler op, prefix: `⇣x` decrements variable `x` (`←x⊖→x`), `dec qword`; same operand and local rules as `⇡` | Z2 | shipped |
| `0xD1` | `\scan` | `⍀` | prelude: `l ′f ⍀ -> l'` inclusive scan, the first element is the seed | A2 | shipped |
| `0xD2` | `\reduce` | `⍁` | prelude: `l ′f ⍁ -> x` fold with no seed; empty list throws `empty reduce` | A2 | shipped |
| `0xD3` | `\eachi` | `⍸` | prelude: `l ′f ⍸ -> l'` map, `f` gets `x i` | A3 | shipped |
| `0xD4` | `\ksort` | `⍒` | prelude: `l ′k ⍒ -> l'` stable sort by key `k x`, ascending (k once per element, A1 threading); with `‹grade›` (W12-A4) | A4 | shipped |
| `0xD5` | `\putat` | `⍈` | prelude: `l i v ⍈ -> l` store into a list in place (bounds- and free-checked). Planned as `\put1`; renamed because `codepage.encode` reads a mnemonic as letters only, so `\put1` could not be typed (W12-Z4) | Z4 | shipped |
| `0xD6` | `\push` | `⍆` | prelude: `v x ⍆ -> v` vector push (capacity doubles; returns the possibly-new v); on a `‹deque›`, its back | Z4 | shipped |
| `0xD7` | `\pop` | `⍅` | prelude: `v ⍅ -> v x` vector pop (empty throws `pop from empty`); on a `‹deque›`, its back | Z4 | shipped |
| `0xD8` | `\win` | `⊟` | prelude: `l n ′f ⊟ -> l'` reduce of every length-`n` window (monotonic deque for `⌈`/`⌊`) | A5 | shipped |
| `0xD9` | `\fix` | `⍣` | prelude: `x ′f ⍣ -> y` apply `f` until the result `≣` the previous one | A6 | shipped |
| `0xDA` | `\next` | `⍞` | prelude: `s ⍞ -> s x 0 \| s 1` pull the next value of a stream (W12-A8; the stream words are long names, see REFERENCE "Streams") | A8 | shipped |
| `0xDB` | `\ints` | `ℤ` | prelude: one-byte alias of `‹ints›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |
| `0xDC` | `\readall` | `⎕` | prelude: one-byte alias of `‹readall›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |
| `0xDD` | `\readline` | `⏎` | prelude: one-byte alias of `‹readline›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |
| `0xDE` | `\dict` | `Ḋ` | prelude: one-byte alias of `‹dict›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |
| `0xDF` | `\dget` | `Ġ` | prelude: one-byte alias of `‹get›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |
| `0xE0` | `\dput` | `Ṗ` | prelude: one-byte alias of `‹put›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |
| `0xE1` | `\keys` | `Ḳ` | prelude: one-byte alias of `‹keys›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |
| `0xE2` | `\bump` | `Ḃ` | prelude: one-byte alias of `‹bump›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |
| `0xE3` | `\vec` | `Ṿ` | prelude: one-byte alias of `‹vec›` (a one-call word; the long name stays), picked from measured usage (W12-6) | Z1 | shipped |

W12-6 used all nine Z1 bytes, so none goes back to free. `0xE4`–`0xEF`
(twelve bytes of the W12-0-released range) are still free. The Z1
mnemonics are letters only and prefix-free against the shipped ones:
`\dget` and `\dput` because `\get` (`←`) is a compiler op and `\puts` and
`\putat` exist.

### 1.5 W13 assignments (W13-B's part)

W13's bytes were decided up front (the W13 brief); these rows are the ones
W13-B ships. The mnemonics are letters only and prefix-free against every
shipped one (`\pcnt`, not `\popc`: `\pop` is `⍅`), checked by
`python3 tools/codepage.py check`; no glyph was in use.

| Byte | Mnemonic | Glyph | Meaning | Task | Status |
|------|----------|-------|---------|------|--------|
| `0xAA` | `\pcnt` | `♯` | atom: `x -> n` popcount (`popcnt`), raw (no list dispatch) | W13-B | shipped |
| `0xAB` | `\ctz` | `⊣` | atom: `x -> n` trailing zero bits (`tzcnt`), 64 for 0, raw | W13-B | shipped |
| `0xAC` | `\clz` | `⊢` | atom: `x -> n` leading zero bits (`lzcnt`), 64 for 0, raw | W13-B | shipped |
| `0xAD` | `\lsb` | `⊥` | atom: `x -> x & -x`, the lowest set bit (0 for 0), raw | W13-B | shipped |
| `0xBD` | `\dig` | `ʘ` | compiler op, prefix: `ʘB` (B any byte) compiles exactly as the long name `‹_dgHH›`, HH = B in upper-case hex — a call, `′`, a chain link, a prefix's operand (`→ ← ⇒ ⇐ ⇡ ⇣ : ⊡ ⊚ ⊜`), a forward reference; undefined is `GOLF: undefined word ‹_dgHH›`. Cases in `self/golf2.golfj` (‹digraph›), the seed (`O`, `p`) and `boot/golfref.py` | W13-B | shipped |

#### Digraph page

`ʘ` + byte B is the long name `‹_dgHH›`; a library gives a word a digraph by
defining `:‹_dgHH›‹realname›;` (or the word itself under that name), and
`tools/codepage.py reference` lists every such prelude definition in
REFERENCE.md's generated "Digraph page" table. The second byte is
partitioned so the W13 agents never contend (printable ASCII only;
`+` and `-` are W13-B's test bytes, used only in test programs, never in
the prelude). One row per digraph the prelude defines:

| Digraph | Bytes | Long name | Word | Task | Status |
|---------|-------|-----------|------|------|--------|
| `ʘA`–`ʘZ` | `BD 41`–`BD 5A` | `‹_dg41›`–`‹_dg5A›` | existing popular long names | W13-C | reserved (partition) |
| `ʘa`–`ʘm`, `ʘ0`–`ʘ4` | `BD 61`–`BD 6D`, `BD 30`–`BD 34` | | | W13-D | reserved (partition) |
| `ʘn`–`ʘz`, `ʘ5`–`ʘ9` | `BD 6E`–`BD 7A`, `BD 35`–`BD 39` | | | W13-E | reserved (partition) |
| `ʘ+`, `ʘ-` | `BD 2B`, `BD 2D` | `‹_dg2B›`, `‹_dg2D›` | test programs only (run2 block W13-B) | W13-B | reserved (tests) |

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
or — since M2 (W9-3A) shipped — a **long name** `‹name›`, which costs nothing
scarce: 1024 per program (W10-A; 256 before), up to 60 bytes each, and a library word with a long
name may even be defined after the words that call it. Long names need no
allocation here, but a prelude long name is visible to every user program, so
prelude long names should still be listed below their wave's anchor in
`lib/prelude.golfj` and kept few: they count against the program's 1024.

Prelude long names in use (all **shipped**):

| names | wave | anchor |
|---|---|---|
| `‹getc›` `‹readall›` `‹readline›` `‹words›` `‹num›` `‹ints›` `‹args›`, and the helper `‹_inread›` (names starting `‹_in` are reserved for it) | W9-4C | `W9-4C-INPUT` |
| `‹throw›` | W11-0 (the stub; W11-3A rewrites it in place) | `W11-0` — defined right after `H`, ahead of `X` |
| `‹open›` `‹create›` `‹close›` `‹fread›` `‹fwrite›` `‹readfile›` `‹writefile›`, and the helpers `‹_1b_tobytes›` `‹_1b_tolist›` `‹_1b_dec›` `‹_1b_ename›` `‹_1b_fail›` `‹_1b_wr›` | W11-1B (**shipped**) | `W11-1B Files` |
| `‹flush›`, and the helpers `‹_1c_put›` `‹_1c_init›` | W11-1C (**shipped**) | `W11-1C buffered output` |
| `‹fmt›` `‹hex›` `‹parsehex›` `‹split›` `‹trim›` `‹startswith›` `‹joinwith›` `‹pad›`, and the helpers `‹_1d_utoa›` `‹_1d_sub›` `‹_1d_put›` | W11-1D (**shipped**) | `W11-1D Text` |
| `‹hash›` `‹dict›` `‹put›` `‹get›` `‹has›` `‹del›` `‹keys›` `‹vals›` `‹set›` `‹add›`, and the helpers `‹_2b_h8›` `‹_2b_zero›` `‹_2b_find›` `‹_2b_grow›` `‹_2b_col›` | W11-2B (**shipped**) | `W11-2B dict and set` |
| `‹heapstats›`, and the helpers `‹_2d_chk›` `‹_2d_ix›` (defined up by `L`/`I`, ahead of their callers) | W11-2D (**shipped**) | `W11-2D use after free` |
| `‹catch›`, and the helpers `‹_3a_raise›` `‹_3a_spill›` `‹_3a_div0›` `‹_3a_init›` (`‹_3a_pop›` is defined up by `‹throw›`, ahead of it) | W11-3A (**shipped**; `‹throw›` above is 3A's too) | `W11-3A catch` |
| `‹cadd›` `‹csub›` `‹cmul›` | W11-3C (**shipped**) | `W11-3C checked arithmetic` |
| `‹assert›` `‹expect›`, and the helpers `‹_4b_show›` `‹_4b_exit›` `‹_4b_fail›` | W11-4B (**shipped**) | `W11-4B test words` |
| `‹stack›` | W11-4C (**shipped**) — the plan's `‹.s›` is not spellable: `.` is not a long-name byte | `W11-4C REPL stack` |
| `‹getor›` `‹bump›` `‹upd›`, and the helpers `‹_12p2_ins›` `‹_12p2_huge›` (W12-P2 also rewrote the W11-2B words `‹_2b_find›` `‹_2b_grow›` `‹_2b_zero›` `‹put›` `‹get›` `‹has›` `‹del›` `‹dict›` in place) | W12-P2 (**shipped**) | `W12-P2 dicts that hash once` |

The table heading says shipped, and after W11 wave 4 every W11 row is: `‹throw›`
and the W11-1B, 1C, 1D, 2B, 2D, 3A, 3C, 4B and 4C rows (4A, 4D and 4E added no
prelude long names). **W11 helper names:** a W11 task that
needs a private helper word names it `‹_<id>…›` with its lowercase task id,
e.g. `‹_1b_errno›`, `‹_2b_probe›`, `‹_3a_unwind›` — the prefixes `‹_1a` …
`‹_4e` are reserved, one per task, and nothing else may use them. Keep helpers
few: every prelude long name (helpers included) is one of the 1024 a user
program has. **4A decision (shipped):** `.` is not a long-name byte, and W11-4A
did not add it — the plan's accessor spelling `‹point.x›` is `‹point-x›`, and
the setter `‹set-point-x›`, `-` joining the parts. These names are invented by
the compiler at each `⊜` (not prelude names, no rows here); each one, like the
record and field names themselves, is one of the program's 1024. W11-1B's `“…“` messages and errno names are
data, not names, and need no row.

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
| `0x400000`–`0x42FFFF` | 4194304–4390911 | **a compiled program's image**: the ELF header and code, one `PT_LOAD` whose `p_filesz` is the file's true size (W11-1E; v1's fixed `0x10000` before), at most **196608 bytes = 192 KB** (`mkblob2.PROGRAM_CAP`) — the image may not reach `0x430000`, the lowest address a compiled program uses at run time. Both compilers refuse a bigger one (`GOLF: program too large`, exit 2). Everything from here down to `0x43FFFF` is **compiler-process-only** state: it lives above the compiler's own image (~12 KB, which must stay under 64 KB so it ends below `m`) and is never touched by a compiled program, so a user image may cover it | shipped (W11-1E) |
| `0x410000` | 4259840 | compiler data base `D` (`m`), **compiler-only** | shipped |
| `m+4` … `m+16` | | v1 compiler scratch (`P`, `S`, `Q`) | shipped |
| `m+20`, `m+24`, `m+28` | | golf2 compiler scratch: `′` jmp-site / thunk addr, `“` len-site / count | shipped |
| `m+32`, `m+36` | | M-CHAIN2 chain state in the **seed** only: the in-a-chain flag, the link count | shipped |
| `m+40`, `m+44`, `m+48` | | M-CHAIN2 in the **seed** only: the first three buffered link bytes | shipped |
| `m+52` | 4259892 | `e`'s undefined-word diagnostic: the offending name byte with a newline stacked above it (`name + 10<<8`), staged for one `write(2, m+52, 2)`. Compiler-only — a compiled program never sees this address | shipped |
| `m+56` | 4259896 | M-FRAME's in-a-`⊡`-definition flag, in the **seed** only — `^` and `;` read it to decide whether to release a locals frame (`self/golf2.golfj` holds the same flag in its variable bank, as `J`) | shipped |
| `m+60`…`m+84` | 4259900–4259924 | M2 long-name state in the **seed** only, seven 4-byte cells: name count · length being read · entry being read into · entry compared against · compare countdown · table index · a body address (`self/golf2.golfj` keeps the same state in its variable bank, under long names) (W9-3A) | shipped |
| `m+88`, `m+92` | 4259928 · 4259932 | M-FRAME2 in the **seed** only: the current `⊡` word's local count · the head of its frame-size patch list (`self/golf2.golfj` keeps both in its variable bank, as `‹locals›` and `‹frame›`) (W9-4D) | shipped |
| `m+96`…`m+159` | 4259936–4259999 | M-FRAME2 slot table, **both** compilers: the name number of the current `⊡` word's local `i` (`i` < 16) at `m+96+4*i`, in order of first appearance. Compiler-only (W9-4D) | shipped |
| `m+160`…`m+172` | 4260000 · 4260004 · 4260008 · 4260012 | **W11-2A** include state in the **seed** only: open-include depth · include-once table count · the fd being entered or left · the table-copy countdown. The path's length is M2's `m+64`. (`self/golf2.golfj` keeps the first three in its variable bank, as `‹depth›` `‹includes›` `‹fd›`) | shipped (W11-2A) |
| `m+176`…`m+188` | 4260016 · 4260020 · 4260024 · 4260028 | **W11-3B** compiler scratch, four 4-byte cells — **unused**: W11-3B shipped without them. Source positions and the `-g` flag live in `self/golf2.golfj`'s variable bank (`‹pos›` = line·64 + file, `‹debug›`, `‹at›`), the saved position of include level `k` (0–7) in the bank cell of the unspellable name `k` (`0x4E0000 + 8k`, golf2's process only), and a forward reference's first-use `‹pos›` in the last placeholder of its pending-site list (where `0` used to end it). The seed reports no messages, so it keeps none of this. Spare for a later front-end owner | spare (W11-3B) |
| `m+192`…`m+204` | 4260032 · 4260036 · 4260040 · 4260044 | **W11-4A** record state in the **seed** only, four 4-byte cells: the record's name number · its field count · the field being emitted · the spelling copy's byte pointer (`self/golf2.golfj` keeps them in its variable bank, as `‹record›` `‹fields›` `‹field›` `‹from›`, plus `‹upto›`) | shipped (W11-4A) |
| `m+208` | 4260048 | **first free compiler scratch** | free |
| `m+2048`–`m+4095` | 0x410800–0x410FFF | **RETIRED** (W10-A) — v1's dictionary (`m+2048 + 4*name`; M2 ran its long names into `m+3072`…). Neither `golf2` nor `seed` touches it any more (v1c, a frozen binary, still uses it in its own process); do not encroach anyway, it is what v1 documents | free |
| `m+4096`–`0x42FFFF` | 0x411000 | **RETIRED** (W11-1E) — the compilers' old output buffer (64 KB, to `0x420FFF`); it moved to `0x494000` below so a program may be 192 KB. Free in the compiler's process; part of a big program's image in a compiled one | free |
| `0x430000`–`0x43FFFF` | 4390912– | **RETIRED** (W10-A) — M2's long-name region (the 256-name table and its heads), moved up below. W11-0 re-allocated parts of it (next three rows); the rest stays free | free |
| `0x430000`–`0x431FFF` | 4390912–4399103 | **W11-1C output buffer**, 8192 bytes, compiled programs only: `Ṅ ⍕ ␤ 🗲 ⊐` (and `‹fmt›`-based printers) append here; the pending-byte count is `0x4F0980` below. BSS, so untouched it costs no RAM | shipped (W11-1C) |
| `0x432000`–`0x437FFF` | 4399104–4423679 | free (headroom, e.g. if 1C's buffer grows) | free |
| `0x438000`–`0x43BFFF` | 4423680–4440063 | **W11-2A include state, compiler-only**, both compilers. `0x438000` (4423680): the path being included as `[len:4][≤250 bytes][0]`; `open` takes the C string at `0x438004`, and for the `lib/` retry the length cell is overwritten with the bytes `lib/`, making `0x438000` the C string `lib/path`. `0x438100` (4423936): the saved `dup(0)` of each open include level, 4 bytes each, 8 levels. `0x438200` (4424192): the include-once table, 60 entries of 256 bytes, path `k` at `0x438200 + 256*k` in the same `[len:4][bytes]` form; ends `0x43BE00`. `mkblob2.IMPORT_*` names them | shipped (W11-2A) |
| `0x43C000`–`0x43FFFF` | 4440064–4456447 | **W11-4A record state, compiler-only**, both compilers. `0x43C000` (4440064): the field table of the `⊜` being read, field `k`'s name number at `0x43C000 + 4*k`, 256 fields (to `0x43C3FF`). `0x43F000` (4452352): the C string `vendor/path` for the third include try — `vendor/` then the path and its NUL copied from `0x438004` (≤ 258 bytes). `0x43FF00` (4456192): the seed's spelling-copy countdown. The rest is free. `mkblob2.REC_FIELDS` / `REC_MAX` / `VENDOR_PATH` name them | shipped (W11-4A) |
| `0x440000`–`0x47FFFF` | 4456448–4718591 | **scratch spill stack** (the region `X`/`Y` push and pop; offset in `0x4F0030`) — 4096 frames of 64 bytes (8 cells × 8 bytes) = 256 KB; it was 28 frames at `0x4F0900` until W10-C, 56 × 32 before W4A. `X` checks the bound (offset 262144 = full): `GOLF: spill stack exhausted` on fd 2, exit 1 — or, with a `‹catch›` armed, that message thrown to it (W11-3A; a handler record is one frame here). BSS that is never touched costs no RAM (W10-C) | shipped |
| `0x47C000`+ | 4702208 + 64*E | M2 long-name table, **compiler-only**: name `E` (256–1279) has a 64-byte entry at `0x47C000 + 64*E`, `[len:4][≤60 bytes]`, so the entries fill `0x480000`–`0x48FFFF` (E < 256 has no entry: nothing below `0x480000` is touched, which is W10-C's spill-stack range); `0x490000`–`0x49003F` (E = 1280) is scratch — `‹readname›` reads every name into the next free entry before it knows the name is new. 1024 names (W10-A; 256 at `0x430000` before) | shipped |
| `0x490400`–`0x4917FF` | 4785152 + 4*N | forward-reference heads, **compiler-only**: the last unpatched `call`/`jmp rel32` site for ANY name `N` (0–1279, one-byte names included since W10-A), each placeholder holding the next (M2, W9-3A); the last one holds the first use's source position in `self/golf2.golfj` (W11-3B; `0` before, and still `0` in the seed) — a value below `0x494000`, so it ends the list either way | shipped |
| `0x492000`–`0x4933FF` | 4792320 + 4*N | the compiler's **dictionary**, **compiler-only**: the body address of name `N` (0–1279). Moved here from `m+2048` by W10-A — that table had room for 512 names before it met the output buffer | shipped |
| `0x494000`–`0x4C3FFF` | 4800512–4997119 | the compilers' **output buffer** `B`, **compiler-only** (W11-1E; it was `m+4096`): the byte at file offset `f` is at `B+f`, so a target address is `bufaddr - 606208`. 196608 bytes, the cap; `a` (the one word that moves the cursor, in both compilers) refuses a cursor past `B+196608` (it tests `< 4997121`), and `0x4C4000`–`0x4CFFFF` is slack for the at most 255-byte template written before that test | shipped (W11-1E) |
| `0x4D0000`–`0x4DFFFF` | 5046272– | **RETIRED (W12-O2)** — the M-CHAIN runtime-thunk code arena, where `∘` bump-allocated 39 bytes (and `⊸` 38) per call, 1680 thunks, never freed. Thunks are `A` blocks on the RWX heap now; nothing writes here | free |
| `0x4E0000`–`0x4E07FF` | 5111808–5113855 | user variable bank (`→x`/`←x`), **8 bytes per name** (M3W; it was 4), 256 names = 2 KB — **user space** | shipped |
| `0x4E0800`–`0x4E27FF` | 5113856–5121023 | long-named variables (`→‹name›`/`←‹name›`): the bank above, continued by its own formula `0x4E0000 + 8*name` for name numbers 256–1279 — **user space** (W9-3A; W10-A extended it from `0x4E0FFF`, so no long-named variable moved) | shipped |
| `0x4F0000` | 5177344 | heap pointer (word `H`) | shipped |
| `0x4F0010`–`0x4F002C` | 5177360–5177388 | **RETIRED** — the old 4-byte-stride scratch bank `s0`–`s7`; W4A moved the bank to `0x4F0060` and nothing reads these eight cells any more | free |
| `0x4F0030` | 5177392 | spill-stack pointer (a byte offset; BSS-zero at start) | shipped |
| `0x4F0034` | 5177396 | **heap base cell** — the `brk` the prelude's init was handed; `A` adds the bump offset `H` to it. ASLR-shifted every run, so it is never spelled out anywhere. Since M-TAG2 (W9-2A) it is **allocator state only**: `T` and the M-VEC templates test the list tag and no longer read it | shipped |
| `0x4F0038` | 5177400 | **heap span cell** — how far the break has been pushed since; `A` grows the break when a block would pass it. Allocator state only since M-TAG2 (it was `T`'s `v - base <u span` bound) | shipped |
| `0x4F003C` | 5177404 | **RETIRED (W12-O2)** — the code-arena pointer (a byte offset into `0x4D0000`); nothing reads or writes it | free |
| `0x4F0040`–`0x4F0047` | 5177408 | **entry `rsp`** — the process stack pointer as the kernel left it, stashed by `STARTUP` before anything pushes; `argc` is at `[cell]`, `argv[i]` at `[cell]+8+8*i` (W8, M-TOOL) | shipped |
| `0x4F0048`–`0x4F004F` | 5177416 | reserved for future scratch (run2.sh's W1 atom test round-trips a value through it) | free |
| `0x4F0050` | 5177424 | **prelude input buffer** (W9-4C): the RAW address of the stdin buffer block `[pos][len][8192 bytes][8 spare]` (1027 cells since W12-P1: the spare cell takes `‹ints›`'s sentinel byte) that `‹getc›`/`‹readline›`/`‹readall›`/`‹ints›`/`‹readbytes›` share; 0 (BSS) until the first read allocates it with `A` | shipped |
| `0x4F0058`–`0x4F005F` | 5177432 | reserved for future scratch | free |
| `0x4F0060`–`0x4F0098` | 5177440–5177496 | prelude scratch `s0`–`s7`, **stride 8** — **all eight in use** (`s0` list, `s1` index, `s2` accumulator, `s3` fn addr, `s4` result, `s5` alloc temp (`A` and `⌫` only), `s6` filter count, `s7` zip's 2nd list / K's + G's parked broadcast scalar). Decimals in order: 5177440 · 5177448 · 5177456 · 5177464 · 5177472 · 5177480 · 5177488 · 5177496 | shipped |
| `0x4F00A0`–`0x4F00B8` | 5177504 · 5177512 · 5177520 · 5177528 | `lib/tio.golfj` state, **stride 8**: output-buffer base (a heap address, allocated by the library's init line) · bytes pending in it · the fd `f`/`g` write to (1 until a tool stores another) · `a`'s staging cell (the message address, then the byte holding its newline) | shipped |
| `0x4F00C0`–`0x4F00F8` | 5177536 · 5177544 · … · 5177592 | **free-list heads** for `A`/`⌫` (W9-3C, M-MEM2), **stride 8**, one per size class: class `k` = 0…6 at `5177536+8k` holds blocks of exactly `4<<k` cells (4, 8, … 256); class 7 at 5177592 holds every larger block (`max(c, 512)` cells, popped only when the head fits). Each head is a raw payload address or 0 (BSS) = empty; a free block's payload cell 0 links to the next. See the note below on the block header | shipped |
| `0x4F0100`–`0x4F08FF` | 5177600–5179647 | M-VEC hook table: 256 entries × 8 bytes, stride 8, indexed by op byte. Cell for byte `B` is `0x4F0100 + 8*B`; non-zero = the polymorphic template for `B` calls it. Installed by the prelude's last line: `+` 5177944 → `∔` · `-` 5177960 → `∸` · `*` 5177936 → `⨰` · `⌈` 5178688 → `⩌` · `⌊` 5178696 → `⩍` | shipped |
| `0x4F0900`–`0x4F0CFF` | 5179648–5180671 | **W11 runtime cells** (W11-0): the old spill stack's first 1 KB, re-allocated as sixteen 64-byte slots, one per W11 task, eight 8-byte cells each (stride 8, read with `⊙`, written with `⊛`). Slot of task `t` = `0x4F0900 + 64*t`, t = 0…15 for 1A 1B 1C 1D 2A 2B 2C 2D 3A 3B 3C 4A 4B 4C 4D 4E. Named cells are listed in the W11 table below; every other cell of a task's slot is that task's **spare** and nobody else's | reserved (W11) |
| `0x4F0D00`–`0x4F0FFF` | 5180672–5181439 | **W12 runtime cells** (W12-0): the rest of the old scratch spill stack (W10-C moved it to `0x440000`), re-allocated as twelve 64-byte slots, one per W12 task, eight 8-byte cells each. Slot of task `t` = `0x4F0D00 + 64*t`, t = 0…11 for P1 P2 P3 O1 Z4 A2 A3 A4 A5 A6 A8 O2. See §3.2 | reserved (W12) |
| `0x4F1000`–`0x4F1FFF` | 5181440–5185535 | **return-stack guard page** — `PROT_NONE`, set by `STARTUP2`'s `mprotect` (`mkblob2.GUARD_LO`); the return stack bottoms out at `0x4F2000` (`mkblob2.RSTACK_FLOOR`), so overflow faults here instead of corrupting the bank below. Not in `seed` (built by v1c with v1's startup) (W9-2C) | shipped |
| `0x600000` | 6291456 | **return-stack top and BSS end** — one number, `mkblob2.RSTACK_TOP` (= `golf0.BASE + MEMSZ`, `p_memsz` = `0x200000`); grows **down**, and nothing grows up to meet it | shipped |
| the `brk` | — | **the list heap**, above the whole load segment, grown by `⌸`. Not a fixed address: the kernel ASLR-shifts the initial break, which is why it lives in the two cells above | shipped |

Notes:

- **Scratch is exhausted.** All eight of `s0`–`s7` are live in `lib/prelude.golfj`
  today. A new prelude word that needs a temporary must either use one of the
  cells above or push a spill frame (`X`/`Y`) — it may not invent an address.
- **The entry-`rsp` cell is a full 8 bytes and must be read with `⊙`.** It is
  written by `tools/mkblob2.STARTUP2` (mirrored by `boot/golfref.py`), which is
  v1's `mov ebp, 0xC00000` with a `mov [0x4F0040], rsp` in front — so every
  binary the v2 toolchain emits is 8 bytes longer than it used to be (and 15
  more since W9-2C put the guard page's `mprotect` between the two). Unlike
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
  that are < 2^31 in practice, and plain `@`/`!` on them is therefore exact.
  Until M-TAG2 `0x4F0034` was also baked into every M-VEC template as a 32-bit
  compare operand; it no longer is — the templates test a value's high word for
  the list tag (`addr | 0x7FFF<<48` since W11-1A) and read no cell but their hook — so the base and
  span are now private to `A`, and widening them would touch only the prelude.
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
  one exception: `s5` is A-only (and `⌫`'s, since W9-3C — the other leaf of
  the allocator) and never held across a call, so neither needs a frame, and
  `I` is scratch-free.
- **Every `A` block has a header cell (W9-3C, M-MEM2).** `A` returns the
  payload address `p`; the cell at `p-8` holds the block's capacity in cells
  (the request rounded up to its size class), or **minus** that capacity while
  the block sits on a free list (that sign is `⌫`'s double-free guard). Every
  caller — the prelude, `lib/t*.golfj`, `gtools/` — only ever touches the
  payload, so the header changed no caller; it costs 8 bytes per block plus
  the rounding (at most 2x, and only for blocks of ≤ 256 cells).
- **The heap/return-stack collision is gone.** Until M-MEM a bump heap grew up
  from `0x500000` while the return stack grew down from `0xC00000` inside the
  same 8 MB BSS: a list of ~917k cells met the stack and the program died. The
  heap is now the kernel's, grown with `brk` (`0xA6`) above the load segment, so
  `p_memsz` reserves only what is statically addressed (`0x200000`) and the
  return stack has its ~1.07 MB — ≈138k frames, above the W9-2C guard page — entirely to itself. That is why
  `0x4F0034`/`0x4F0038` exist: the base cannot be a constant any more, and `A`
  needs both it and the span to know when to move the break.
  **Do not add a fixed heap-base row to this table.**
- **A list value is tagged (M-TAG2).** What a list word hands user code is
  `addr | 0x7FFF<<48` — the heap address with the top 16 bits `0x7FFF`, so
  `v >> 48 == 0x7FFF` (W11-1A; it was `addr | 2^48` through W10) — and
  every list word masks it back off (`(v<<16)>>16`, idempotent, so a raw `A`
  block is accepted too). The tag is a property of the *value*, not an address:
  it needs no cell, and nothing in this table records it.
  The other top-16 values in use: `0x7FFE`, `⍕`'s internal nested-list marker
  (W9-3B), and `0x7FFD`, a **deque** (W12-Z4: `‹deque›`'s block, which is not a
  list, so `T` calls it an int while the entry mask still strips it for `≢`
  and `⌫`).
- The M-VEC hook table is at stride 8 (not 4) so it stayed correct when M4
  widened list cells to 64 bits — which W4A has now done, with no change to the
  templates, the hook cells or the seed.

### 3.1 W11 runtime cells (reserved in W11-0)

Slot base per task, then the named cells. A task may use the unnamed cells of
**its own** slot as spares without asking; anything beyond its slot goes back
to the integrator. Decimals are what you type.

| Task | Slot (hex) | Slot base (dec) | Named cells | Spare cells (dec) |
|------|------------|-----------------|-------------|-------------------|
| 1A | `0x4F0900`–`0x4F093F` | 5179648 | — | 5179648 … 5179704 (all eight) |
| 1B | `0x4F0940`–`0x4F097F` | 5179712 | `0x4F0940` 5179712: last errno, positive, stored before the throw (never cleared) · shipped, private to the file words: 5179720 the errno-name list · 5179728 the message's path (0 = an fd word) · 5179736 the message's fd · 5179744 the path buffer, then `‹_1b_dec›`'s n · 5179752 / 5179760 `‹_1b_dec›`'s buffer / cursor | 5179768 |
| 1C | `0x4F0980`–`0x4F09BF` | 5179776 | `0x4F0980` 5179776: bytes pending in the output buffer at `0x430000` (0 = empty, BSS) · `0x4F0988` 5179784: the buffer's fd (0 = use fd 1) · `0x4F0990` 5179792: the **flush hook** — the address of `‹flush›`, stored by the prelude's init; `.` `)` `(`, the end-of-program exit and the divide-by-zero exit call it when non-zero (`tools/mkblob2.FLUSH_HOOK`; BSS 0 in a bare program and in the compiler) · `0x4F0998` 5179800: `‹flush›`'s drain offset (shipped) · `0x4F09A0` 5179808: the **end hook** (W13-B, S3 implicit output) — the address of `‹_13b_end›`, stored by the prelude's init; ONLY the end-of-program exit calls it, before the flush hook (`tools/mkblob2.END_HOOK`; BSS 0 in a bare program and in the compiler) | 5179816 … 5179832 |
| 1D | `0x4F09C0`–`0x4F09FF` | 5179840 | — | 5179840 … 5179896 (all eight) |
| 2A | `0x4F0A00`–`0x4F0A3F` | 5179904 | — (compiler work; its state is in `m+160` and `0x438000`) | 5179904 … 5179960 |
| 2B | `0x4F0A40`–`0x4F0A7F` | 5179968 | dict scratch (shipped, private to the dict words): `0x4F0A40` 5179968 `‹_2b_h8›`'s byte source · `0x4F0A48` 5179976 / `0x4F0A50` 5179984 / `0x4F0A58` 5179992 short-lived temps (entry address, probe slot, new entry) · spares used: 5180008 `‹_2b_zero›`'s end address (5180000 / 5180016 free again since W12-P2's unrolled `‹_2b_zero›`; W12-P2 also uses 5179984 for a moment in `‹_2b_find›`) | 5180000 · 5180016 · 5180024 |
| 2C | `0x4F0A80`–`0x4F0ABF` | 5180032 | — (`⊸` uses the `∘` arena pointer `0x4F003C`) | 5180032 … 5180088 (all eight) |
| 2D | `0x4F0AC0`–`0x4F0AFF` | 5180096 | shipped: `0x4F0AC0` 5180096: live blocks · `0x4F0AC8` 5180104: live bytes, each block `(cap+1)*8` (header included); `A` adds, `⌫` subtracts, `‹heapstats›` reads; BSS 0 | 5180112 … 5180152 |
| 3A | `0x4F0B00`–`0x4F0B3F` | 5180160 | shipped: `0x4F0B00` 5180160: **catch handler chain head** — the address of the newest handler record, a 64-byte spill-stack frame `[sp][bp][previous head]…` (0 = no handler: `‹throw›` prints and exits) · `0x4F0B08` 5180168: the message in flight · `0x4F0B10` 5180176: the **divide-by-zero hook** — the address of `‹_3a_div0›`, stored by the prelude's init; the `/ % ÷ ∣` zero exit calls it first when non-zero (`tools/mkblob2.DIV0_HOOK`; BSS 0 in a bare program and in the compiler) · `0x4F0B18` 5180184: `‹_3a_pop›`'s record address | 5180192 … 5180216 |
| 3B | `0x4F0B40`–`0x4F0B7F` | 5180224 | — (compiler work; `m+176`) | 5180224 … 5180280 |
| 3C | `0x4F0B80`–`0x4F0BBF` | 5180288 | shipped, private to the checked words: `0x4F0B80` 5180288 a · `0x4F0B88` 5180296 b · `0x4F0B90` 5180304 the wrapped result (short-lived; the words call nothing but `‹throw›`) | 5180312 … 5180344 |
| 4A | `0x4F0BC0`–`0x4F0BFF` | 5180352 | — (compiler work; `m+192`, `0x43C000`) | 5180352 … 5180408 |
| 4B | `0x4F0C00`–`0x4F0C3F` | 5180416 | shipped: `0x4F0C00` 5180416: failure count (`‹assert›`/`‹expect›`; BSS 0) · spares used: `0x4F0C08` 5180424 the flush hook (`‹flush›`) saved when the first failure installs `‹_4b_exit›` in the 1C hook cell 5179792 · 5180432 / 5180440 / 5180448 `‹expect›`'s actual, expected, msg (`‹assert›` uses 5180448 too) · 5180456 `‹_4b_exit›`'s rbp | 5180464 … 5180472 |
| 4C | `0x4F0C40`–`0x4F0C7F` | 5180480 | shipped: `0x4F0C40` 5180480: the data-stack base `‹stack›` prints from (rsp at the end of prelude init) · `0x4F0C48` 5180488 sp · `0x4F0C50` 5180496 depth · `0x4F0C58` 5180504 index (‹stack›'s loop state) | 5180512 … 5180536 |
| 4D | `0x4F0C80`–`0x4F0CBF` | 5180544 | — | 5180544 … 5180600 (all eight) |
| 4E | `0x4F0CC0`–`0x4F0CFF` | 5180608 | — | 5180608 … 5180664 (all eight) |

**The W11-2D poison value** is a constant, not a cell: **`-559038737`**
(`0xFFFFFFFFDEADBEEF` as a 64-bit word), spelled `559038737±` (the literal is
under `2^31`, so the seed can compile it). `⌫` writes it into a freed list's
**length cell** (payload cell 0); no live list has a negative length.
**Shipped (W11-2D):** a freed block is `[-cap][poison][link][…]` — the
free-list link moved to payload cell 1 (every block has at least 4 cells), `A`'s
pop reads it there and writes `0` over the poison, and the list words check
cell 0 on entry through `‹_2d_chk›` (`I` clamps a negative length instead).

---

### 3.2 W12 runtime cells (reserved in W12-0)

Same rules as §3.1: a task may use the cells of **its own** slot freely;
anything beyond it goes back to the integrator. Decimals are what you type.

| Task | Slot (hex) | Slot base (dec) | Cells (dec) |
|------|------------|-----------------|-------------|
| P1 input | `0x4F0D00`–`0x4F0D3F` | 5180672 | 5180672 … 5180728 — all eight used (shipped): `‹ints›` `‹words›` `‹num›` `‹readbytes›` `‹readall›` state, see the prelude's W12-P1 section |
| P2 dicts | `0x4F0D40`–`0x4F0D7F` | 5180736 | shipped, all eight: 5180736 d (masked) · 5180744 k · 5180752 D (the key's stored hash) · 5180760 the probe's slot (shift+2 for a moment) · 5180768 the value / default · 5180776 index table · 5180784 cap-1 (5180776 / 5180784 are also `‹_12p2_huge›`'s temps) · 5180792 the multiplier 0x9E3779B97F4A7C15, stored by `‹dict›` |
| P3 list loops | `0x4F0D80`–`0x4F0DBF` | 5180800 | 5180800 … 5180856 (W12-P3 uses three, shipped: 5180800 `⌽`'s result base · 5180808 `⍳`'s end pointer, `⌽`'s source base · 5180816 the `∑`/`∏` accumulator, `⌽`'s mirror constant; 5180824 … 5180856 spare) |
| O1 atoms on lists | `0x4F0DC0`–`0x4F0DFF` | 5180864 | 5180864 … 5180920 (W12-O1 uses one: 5180864, the not-a-number hook cell `mkblob2.NAN_HOOK` that the prelude fills with `‹_12o1_nan›`; 5180872 … 5180920 spare) |
| Z4 store-at / vector / deque / O3 heap | `0x4F0E00`–`0x4F0E3F` | 5180928 | 5180928 … 5180960 used (shipped, W12-Z4): block · value · index/new block · count · deque head for `⍈ ⍆ ⍅ ‹first› ‹last› ‹pushf› ‹popf›`, see the prelude's W12-Z4 section; 5180968 … 5180984 used by W12-O3 (shipped): the queue's payload P · i (push) / &q[i] (pop) · the value being pushed or sifted down, for `‹pqpush› ‹pqpop›`, see the prelude's W12-O3 section |
| A2 scan / reduce | `0x4F0E40`–`0x4F0E7F` | 5180992 | 5180992 … 5181048 |
| A3 each-indexed | `0x4F0E80`–`0x4F0EBF` | 5181056 | 5181056 … 5181112 |
| A4 sort-by / grade | `0x4F0EC0`–`0x4F0EFF` | 5181120 | 5181120 … 5181128 used (shipped, W12-A4): the key list's element 0 · the merge step's take-right flag F, live only inside `‹grade›`'s sort loop (no user code runs there); 5181136 … 5181176 free |
| A5 window | `0x4F0F00`–`0x4F0F3F` | 5181184 | 5181184 … 5181240 — all eight used (shipped, W12-A5): `⊟`'s set-up (f · n · l · result · result length) and the deque engine (end · 8n · deque block · push word · head · tail · write pointer), see the prelude's W12-A5 section; the general path keeps its state in s0..s7 under X/Y |
| A6 fixpoint | `0x4F0F40`–`0x4F0F7F` | 5181248 | 5181248 … 5181304 — none used (W12-A6 shipped: `⍣` keeps its state in s0..s3 under X/Y because it calls user code); all eight spare |
| A8 streams | `0x4F0F80`–`0x4F0FBF` | 5181312 | 5181312 5181320 5181336 … 5181368 used (shipped, W12-A8), each live only across a stretch with no user call: the record being built · ⍞'s x while s is unparked · ‹sints›'s end of bytes / sign / byte and accumulator, constructor arguments, x under an accumulator, ‹szip›'s f — see the prelude's W12-A8 section; 5181328 free. Stream state itself lives in the records on the heap and in one-cell parks on the spill stack |
| O2 freeable thunks | `0x4F0FC0`–`0x4F0FFF` | 5181376 | W12-O2 needs none (thunks are `A` blocks). W12-O3, the same task's pair, uses two (shipped): 5181376 E = &q[n'] · 5181384 &q[c], the chosen child, live only inside `‹pqpop›`'s sift-down (no user code runs there); 5181392 … 5181432 free |

---

## W9 — the gap-fix waves

Allocated up front (W9-0A) so the parallel tasks never contend. Every other
W9 word — slice, unique, index-of, flatten, the input words (shipped by W9-4C,
§2) — waits for W9-3A
(multi-character names, now **shipped** as `‹name›`, `0xB4`/`0xB5`) and takes a
*name*, not a byte; `0xC8`–`0xCF` is now
fully allocated. **Shipped** (W9-4B part 2): `‹slice›` `‹indexof›` `‹unique›`
`‹flatten›`, the prelude's first long names. With W9-4C's input words the
prelude now uses 188 of the long-name slots (W11-0 added `‹throw›`; W11-1B, 1C and 1D 27 more, W11-2B 15, W11-2D 3, W11-3A 6, W11-3C 3, W11-4B 5, W11-4C 1, W12-P1 8, W12-O1 2, W12-P2 5, W12-Z4 12, W12-P3 23, W12-A4 1, W12-A5 10, W12-O3 4, W12-A8 47, W12-O6 1 and W13-B 2, helpers included) — 1024 since W10-A, so 836 are left
for a program (run2.sh's W9-3A block counts them, so this stays honest). A task that needs anything not listed here asks the
integrator; it does not pick it.

String literals (W9-1B): the encoder copies everything between two `“` as
UTF-8 bytes, verbatim — no mnemonics, no glyph encoding — except the escape
`\“`, which stands for the UTF-8 bytes of `“` itself. A string whose UTF-8
contains the raw byte `0x8E` (the delimiter) is an encode error. **Shipped**
(W9-1B): `\str` opens and closes a literal too, and either spelling closes
either; the decoders copy a literal's bytes back out raw.

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
