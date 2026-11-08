# GOLF language reference

Everything the expanded (v2) language has, in one place: how a program runs,
the core ops it inherited from the frozen v1 language, the v2 atoms, compiler
ops and library words, and a short tutorial.

How this file is kept true:

- The v2 tables (section 3) are **generated** by `python3 tools/codepage.py
  reference` and spliced in between two marker lines. `test/run2.sh` requires
  that block to equal the generator's current output, and requires every
  allocated op byte to appear in this file. After you change the code page, run
  `python3 tools/codepage.py reference --update REFERENCE.md`.
- The v1 core table (section 2) is written by hand. Every row was checked
  against the templates in `data/v1.hex` (read by `boot/v1.py`) and the special
  forms in `boot/golfref.py`, and by compiling small programs with `golf2`.
- Every tutorial example (section 4) is compiled and run by `test/run2.sh`, and
  its output must match the `text` block under it.

## 1. How a program runs

**The machine.** A GOLF program is a sequence of bytes, one operation per byte,
read once from left to right. It works on a **data stack** of 64-bit integers
(the hardware `rsp`). Calls use a separate **return stack** (`rbp`). There are
no types: a list, a string, a word address and a boolean are all just 64-bit
numbers on the stack. The compiler (`golf2`) copies a fixed piece of x86-64
machine code for each op, so the output is a standalone ELF64 Linux executable.
There is no libc and no runtime beyond what the program and the prelude contain.

**Stack effects** are written `( before -- after )`, with the top of stack
(TOS) on the right. `a b -` computes `a - b`.

**Truth: zero is true.** `[ … ]` runs its block when the value it pops is `0`.
`{ … }` jumps back to `{` while the value `}` pops is `0`. So `a b -` doubles as
an equality test: it is `0` exactly when `a == b`. The comparison atoms
(`<`, `≡`, `»`, `≺`, …) push `-1` (true) or `0` (false). That is the opposite
convention, so add `1` before `[`: `a b<1+[ … ]` runs the block when `a < b`.

**Words.** `:x … ;` defines a word named `x`. The name is any single byte (a
letter, usually), or a **long name** written `‹name›` (see "Long names" at the
end of section 3). Writing `x` later calls it. A one-byte word must be
**defined before it is used**: the compiler makes one pass and looks a name up
when it meets it. A call to a name that was never defined stops the compile with
`GOLF: undefined word x` on stderr and exit status 2. A long name may be used
before its definition, which is how mutual recursion is written. A word may call
itself, because its name is bound when its body starts. `^` returns early from
the current word. `;` returns at the end.

**The prelude.** `tools/golfc` puts `lib/prelude.golfj` in front of your
program, so the library words in section 3 are already defined. The prelude
uses most **uppercase letters** as word names (the `word` column, plus internal
helpers such as `D` `G` `H` `K` `T` `X` `Y`), and the high bytes `0xC0`–`0xC7`.
Name your own words with lowercase letters. The prelude also runs a few
instructions first. They find the heap (`⌸ brk`) and switch on the list
dispatch of `+ - * ⌈ ⌊`. Without the prelude (`golfc -n`) those five ops work
on integers only.

**Ending.** Running off the end of the program calls `exit(0)`. `.` exits
earlier with the status it pops.

**Three spellings of one program.** The compiler reads **raw bytes**. Bytes
0–127 are ASCII ops and names. Bytes 0x80–0xFF are atoms, compiler ops and
library words, and each one has a **glyph** (for reading) and a
**`\mnemonic`** (for typing in ASCII). `tools/codepage.py encode` turns
glyph/mnemonic source (`.golfj`) into raw bytes (`.gb` / `.g2`). `decode`
turns raw bytes back into glyphs, and `decode -m` turns them into mnemonics.
These three are the same program, and all three sum the squares of `0..4`:

```
5⍳′²€∑Ṅ                       glyphs
5\range\ref\sqr\map\sum\num   mnemonics
5R<0x8C><0x83>MSN             raw bytes  (⍳ is the letter R, € is M, …)
```

A library word's glyph and mnemonic are only other ways to type its letter:
`⍳`, `\range` and `R` all compile to the byte `R`.

**Source rules in `.golfj`.** The encoder treats a few characters specially.
A `#` starts a comment to the end of the line wherever it appears. So `'#`
cannot be written, and you write the number `35` instead. A `\` starts a
mnemonic, so v1's swap op `\` is written `\\`, and `'\` cannot be written
(use `92`). Bytes 0–32 are whitespace. They matter only between two numbers:
`3 4+` is 7, and `34+` is 34 plus whatever is below it.

**Compiling.**

```sh
cd expanded
tools/golfc -j prog.golfj out && ./out   # glyph/mnemonic source, with prelude
tools/golfc prog.g2 out && ./out          # raw bytes, with prelude
tools/golfc -n -j prog.golfj out          # no prelude: the bare language
python3 tools/codepage.py table           # the code page as plain text
```

The first `golfc` run builds the compiler ladder into `build/`
(`v1c → seed → golf2`) and later runs reuse it.

## 2. The v1 core

These are the ops GOLF had before v2. They are inherited unchanged, except
that `+ - *` now also act on lists (see the note below the table). The cells
are 64-bit, so `+ - * / %` work on all 64 bits.

### Operators

| byte | op | stack effect | meaning |
|---|---|---|---|
| `0x22` | `"` | `( a -- a a )` | dup |
| `0x5F` | `_` | `( a -- )` | drop |
| `0x5C` | `\` | `( a b -- b a )` | swap. In `.golfj` source, write it as `\\` |
| `0x26` | `&` | `( a b -- a b a )` | over |
| `0x2B` | `+` | `( a b -- a+b )` | add, wrapping at 64 bits. On lists it works elementwise |
| `0x2D` | `-` | `( a b -- a-b )` | subtract. The result is `0` when `a == b`, so it also tests equality. On lists it works elementwise |
| `0x2A` | `*` | `( a b -- a*b )` | multiply (low 64 bits). On lists it works elementwise |
| `0x2F` | `/` | `( a b -- a/b )` | **unsigned** 64-bit divide (`0 1-2/` is 2^63-1). `÷` is the signed one. Dividing by 0 prints `GOLF: divide by zero` to fd 2 and exits 1 |
| `0x25` | `%` | `( a b -- a%b )` | **unsigned** 64-bit remainder. `∣` is the signed one. Dividing by 0 prints `GOLF: divide by zero` to fd 2 and exits 1 |
| `0x3C` | `<` | `( a b -- f )` | `-1` if `a < b` **unsigned**, else `0`. `≺` is the signed one |
| `0x40` | `@` | `( addr -- v )` | fetch a **32-bit** value, zero-extended. `⊙` fetches a full 64-bit cell |
| `0x21` | `!` | `( v addr -- )` | store the low **32 bits** of `v`. `⊛` stores a full 64-bit cell |
| `0x3F` | `?` | `( addr -- b )` | fetch a byte, zero-extended |
| `0x2C` | `,` | `( v addr -- )` | store the low byte of `v` |
| `0x28` | `(` | `( -- b )` | read one byte from stdin. Pushes `0` at end of file |
| `0x29` | `)` | `( b -- )` | write the low byte to stdout |
| `0x2E` | `.` | `( status -- )` | `exit(status)` |
| `0x5E` | `^` | `( -- )` | return from the current word now. Inside a `⊡` word, it also releases the frame. Use it only inside a word |

When the prelude is loaded, `+ - *` (and the atoms `⌈ ⌊`) first check the
**shape** of their two operands. Two integers get the plain machine
instruction. If either operand is a list, the op works elementwise and
broadcasts: `4⍳3+` is `3 4 5 6`, and `4⍳4⍳*` is `0 1 4 9`. The raw forms
`﹢ ﹣ ﹡ ⊓ ⊔` never dispatch. The dispatch decides by address: any integer
that falls inside the heap's address range is taken for a list. See
`DESIGN.md`, Known limits.

### Special forms

| byte | syntax | meaning |
|---|---|---|
| `0x30`–`0x39` | `0`–`9`… | integer literal: reads every digit that follows, then pushes the number. The value is read into 64 bits. For a negative number, write `0 n-` |
| `0x27` | `'c` | character literal: pushes the next byte, whatever it is (`'A` pushes 65). After encoding, `'⍳` pushes `0x52` |
| `0x3A` | `:x … ;` | define word `x` (any single byte) |
| `0x3B` | `;` | end any definition (`:`, `⊚`, `⊡`) and return |
| `0x5B` | `[ … ]` | if: pop a value, and run the block when it is `0` |
| `0x5D` | `]` | end of an `if` block |
| `0x7B` | `{ … }` | loop: `{` emits nothing and marks the loop top |
| `0x7D` | `}` | pop a value, and jump back to `{` while it is `0`. The body therefore runs at least once |
| `0x60` | `` `N bbb `` | raw blob: a decimal count `N`, one space, then `N` bytes that are copied into the program and jumped over. Pushes their address. In `.golfj` source the encoder still rewrites glyphs, `\` and `#` inside the blob, so keep those bytes plain ASCII there |
| `0x23` | `#` | comment to the end of the line |
| `0x00`–`0x20` | whitespace | ignored, except that it separates two numbers |
| any other | `x` | call the word named `x`, or compile its template if `x` is an atom |

## 3. The v2 code page

The v2 language uses one byte for each operation, from the full 0–255 range.
`tools/mkblob2.py` (atoms) and `tools/codepage.py` (compiler ops and library
words) are the source of truth. `REGISTRY.md` records which bytes are taken.
The tables below are generated from those files. Do not edit them by hand.

<!-- BEGIN GENERATED: python3 tools/codepage.py reference -->
### Atoms

Single-byte machine-code ops (`tools/mkblob2.py` `ATOMS`): the compiler copies each one's template inline.

| byte | glyph | mnemonic | meaning |
|---|---|---|---|
| `0x7E` | `~` | `\not` | bitwise NOT |
| `0x24` | `$` | `\and` | bitwise AND |
| `0x7C` | `\|` | `\or` | bitwise OR |
| `0x3D` | `=` | `\xor` | bitwise XOR |
| `0x3E` | `>` | `\shr` | shift right (by TOS) |
| `0x80` | `±` | `\neg` | negate TOS |
| `0x81` | `⊕` | `\inc` | TOS + 1 |
| `0x82` | `⊖` | `\dec` | TOS - 1 |
| `0x83` | `²` | `\sqr` | TOS * TOS |
| `0x84` | `⊗` | `\dbl` | TOS * 2 |
| `0x85` | `⊘` | `\hlv` | TOS >> 1 |
| `0x86` | `»` | `\gt` | a b -> (a>b unsigned ? -1 : 0) |
| `0x87` | `≡` | `\eq` | a b -> (a==b ? -1 : 0) |
| `0x88` | `⌈` | `\max` | a b -> max(a,b) signed |
| `0x89` | `⌊` | `\min` | a b -> min(a,b) signed |
| `0x8A` | `÷` | `\sdv` | a b -> a/b signed (b=0: error exit 1) |
| `0x8B` | `∣` | `\smd` | a b -> a%b signed (b=0: error exit 1) |
| `0x8D` | `⍎` | `\exec` | pop a word address, call it |
| `0x91` | `﹢` | `\radd` | raw add (never polymorphic) |
| `0x92` | `﹣` | `\rsub` | raw sub (never polymorphic) |
| `0x93` | `﹡` | `\rmul` | raw mul (never polymorphic) |
| `0x94` | `⊓` | `\rmin` | raw unsigned min (never polymorphic) |
| `0x95` | `⊔` | `\rmax` | raw unsigned max (never polymorphic) |
| `0x96` | `﹤` | `\rlt` | raw unsigned less -1/0 (never polymorphic) |
| `0xA0` | `≺` | `\slt` | a b -> (a<b signed ? -1 : 0) |
| `0xA1` | `≻` | `\sgt` | a b -> (a>b signed ? -1 : 0) |
| `0xA2` | `≪` | `\shl` | shift left (by TOS) |
| `0xA3` | `≫` | `\sar` | arithmetic shift right (by TOS) |
| `0xA4` | `⊙` | `\fetch` | addr -> v, full 64-bit cell |
| `0xA5` | `⊛` | `\store` | v addr -> ; full 64-bit cell |
| `0xA6` | `⌸` | `\brk` | addr -> break; brk(2) |
| `0xA7` | `⎈` | `\sys` | a1 a2 a3 num -> result: raw syscall |

### Compiler ops

Single-byte tokens the compiler handles itself (prefixes, delimiters, definition headers) — there is no template behind them.

| byte | glyph | mnemonic | meaning |
|---|---|---|---|
| `0x8C` | `′` | `\ref` | prefix: ′name pushes that word's address |
| `0x8E` | `“` | `\str` | string literal delimiter: “text“ -> byte block |
| `0x8F` | `→` | `\set` | prefix: →x pops TOS into variable x |
| `0x90` | `←` | `\get` | prefix: ←x pushes variable x |
| `0xB0` | `⊚` | `\chain` | prefix: ⊚name f g h; defines a tacit chain (a train of links) |
| `0xB1` | `⊡` | `\dloc` | prefix: ⊡name ... ; defines a word with a frame of per-call locals, one cell each |
| `0xB2` | `⇒` | `\lset` | prefix: ⇒x pops TOS into local x (a..h or ‹name›) |
| `0xB3` | `⇐` | `\lget` | prefix: ⇐x pushes local x (a..h or ‹name›) |
| `0xB4` | `‹` | `\lname` | opens a long name: ‹name› stands wherever a one-byte name can |
| `0xB5` | `›` | `\rname` | closes a long name |

### Library words

Words defined by the prelude (`lib/prelude.golfj`). A letter word is called by its ASCII letter; its glyph and mnemonic are input aliases for that letter. A high-byte word has no letter.

| byte | glyph | mnemonic | word | meaning |
|---|---|---|---|---|
| `0x52` | `⍳` | `\range` | `R` | range(n) -> [0..n-1] |
| `0x53` | `∑` | `\sum` | `S` | sum(list) |
| `0x4C` | `≢` | `\len` | `L` | len(list) |
| `0x49` | `⊇` | `\index` | `I` | index(list, i) |
| `0x41` | `⍶` | `\alloc` | `A` | alloc(cells) -> addr |
| `0x4E` | `Ṅ` | `\num` | `N` | print signed decimal |
| `0x45` | `␤` | `\nl` | `E` | print newline |
| `0x4D` | `€` | `\map` | `M` | map(list, fn) -> list |
| `0x46` | `⇤` | `\fold` | `F` | fold(list, init, fn) -> x |
| `0x51` | `⍕` | `\show` | `Q` | print a list, space-separated; inner lists as [a b] |
| `0x50` | `∏` | `\prod` | `P` | product(list) |
| `0x56` | `⌽` | `\rev` | `V` | reverse(list) -> list |
| `0x57` | `⌿` | `\filter` | `W` | filter(list, pred) -> list (keep where pred==0) |
| `0x4F` | `🗲` | `\puts` | `O` | print a “...” byte string |
| `0x55` | `⊃` | `\chars` | `U` | byte string -> list of char codes |
| `0x4A` | `⊐` | `\join` | `J` | print a code list as text (cell -> byte) |
| `0x5A` | `⊞` | `\zip` | `Z` | zip(l1, l2, fn) -> list (elementwise) |
| `0xC0` | `∔` | `\vadd` | — | polymorphic add (int/list, elementwise, broadcast) |
| `0xC1` | `∸` | `\vsub` | — | polymorphic sub (int/list, elementwise, broadcast) |
| `0xC2` | `⨰` | `\vmul` | — | polymorphic mul (int/list, elementwise, broadcast) |
| `0xC3` | `⩍` | `\vmin` | — | polymorphic signed min (int/list, elementwise, broadcast) |
| `0xC4` | `⩌` | `\vmax` | — | polymorphic signed max (int/list, elementwise, broadcast) |
| `0xC5` | `∘` | `\comp` | — | compose: ′f ′g -> ′(x -> g(f x)) |
| `0xC6` | `⇉` | `\pipe` | — | pipeline: x qlist -> y (apply each quotation in turn) |
| `0xC7` | `⑂` | `\fork` | — | fork: x ′f ′g ′h -> h(f x, g x) |
| `0xC8` | `≣` | `\match` | — | match: a b -> -1/0, structural equality into nested lists |
| `0xC9` | `⍤` | `\depth` | — | depth: int 0, flat list 1, list of lists 2, ... |
| `0xCB` | `⧺` | `\cat` | — | concatenate: l1 l2 -> new list (l1 then l2) |
| `0xCC` | `↑` | `\take` | — | take: list n -> first n (n<0: last \|n\|; clamped to len) |
| `0xCD` | `↓` | `\drop` | — | drop: list n -> all but first n (n<0: all but last \|n\|) |
| `0xCA` | `⌫` | `\free` | — | free(list\|block): release an A block to the free list |
| `0xCE` | `⍋` | `\sort` | — | sort: list -> new list, ascending signed (stable merge sort) |
| `0xCF` | `∊` | `\memb` | — | member: list x -> 0 if x is an element, else 1 |
<!-- END GENERATED -->

A few notes on what the tables leave out:

- **Lists** are heap blocks `[len, e0, e1, …]` of 64-bit cells. A list value is
  the block's address. `⍳ ∑ ≢ ⊇ € ⇤ ⌿ ⌽ ∏ ⍕ ⊞` and the vectorized `+ - * ⌈ ⌊`
  all work on lists.
- **Nested lists** (W9-3B). A list may hold lists. `⍕` prints an inner list in
  brackets, so `3⍳′⍳€⍕` prints `[] [0] [0 1] `. The bare `+ - * ⌈ ⌊` recurse to
  any depth: `3⍳′⍳€ 10+⍕` prints `[] [10] [10 11] `. `≣` tests structural
  equality (`-1`/`0`, like `≡`) and `⍤` gives the nesting depth (an int is 0,
  a flat list 1).
- **Strings.** `“text“` pushes the address of a byte block
  `[len:u32][bytes]`. `🗲` prints one. `⊃` turns one into a list of codes, so
  list ops work on text, and `⊐` prints such a list back as text.
- **Quotations.** `′x` pushes the address of word `x`. For an atom, it pushes a
  small wrapper around the atom. `⍎` calls the address it pops. `€ ⇤ ⌿ ⊞` take
  such an address as their function argument. `∘ ⇉ ⑂` combine them.
- **Variables.** `→x` / `←x` store and load one global 64-bit cell per name
  byte. They are global, so a recursive word should use `⊡` locals instead:
  `⇒x` / `⇐x` reach local `x` in the current call's frame (see Locals below).
- **Chains.** `⊚name f g h;` defines a tacit train. One link is a call, two
  links are a composition, and three are a fork `h(f x, g x)`. A fourth or later
  link is an ordinary call made on the result.

### Long names

One-byte names run out: the prelude holds most uppercase letters, and a program
with a dozen helpers is out of readable lowercase ones. A **long name** is any
run of the bytes `0-9 A-Z a-z _ -` between `‹` (`0xB4`, `\lname`) and `›`
(`0xB5`, `\rname`). It works everywhere a one-byte name does:

| form | meaning |
|---|---|
| `:‹square›²;` | define a word (also `⊚‹mean›∑≢÷;` and `⊡‹fact›…;`) |
| `5‹square›Ṅ` | call it |
| `′‹square›` | quote it, for `€ ⇤ ⌿ ⊞ ⍎` and the combinators |
| `⊚‹avg›‹total›‹count›÷;` | use it as a chain link |
| `→‹count›` / `←‹count›` | store / load a variable |

Because `›` ends the name, `5‹sq›3` is the call followed by the number 3, and
the ASCII spelling `\lnamesq\rname` is the same token as `‹sq›`. `‹ab›` and
`‹abc›` are different names, and so are `‹a›` and `a`: a long-named variable has
its own cell, beyond the 256 one-byte ones.

**Locals.** Inside `⊡name … ;` the prefixes `⇒` (pop into) and `⇐` (push)
name per-call locals: a one-letter `a`–`h` or any long name, mixed freely.
Each distinct name gets the next slot at its first appearance in the
definition, so a `⊡` word that names *k* locals reserves exactly *k* cells
(`⊡‹inc›1+;`, with none, costs what a `:` word does) and recurses that much
deeper. At most 16 locals per word: a 17th is `GOLF: too many locals ‹name›`,
exit 2. Outside a `⊡` word a long local is `GOLF: local out of range ‹name›`, and
a one-letter one past `h` is refused everywhere.

```golfj
⊡‹sum›"[_0^]⇒‹n›⇐‹n›1-‹sum›⇐‹n›+;   # one cell a call
⊡‹hyp›⇒a⇒‹y›⇐a⇐a*⇐‹y›⇐‹y›*+;        # two: a, then ‹y›
100‹sum›Ṅ␤3 4‹hyp›Ṅ␤                # 5050, then 25
```

**Forward references.** Any word — a long name or, since W10-A, a one-byte
one — may be called, quoted with `′`, or used as a chain link before its
definition. That is all mutual recursion needs:

```
:‹even›"[_0^]⊖‹odd›;
:‹odd›"[_1^]⊖‹even›;
10‹even›Ṅ            # 0: zero is true, 10 is even
:a"0-[_0^]1-b;       # the same with one-byte names
:b"0-[_1^]1-a;
5aṄ                  # 1: 5 is not even
```

A name that is called but never defined stops the compile at end of input with
`GOLF: undefined word ‹name›` (or `GOLF: undefined word q` for a one-byte name)
and exit status 2, and no binary is written. Only a name not defined *yet*
goes forward: a byte that is an atom is always its template, and once a word
is defined a call binds to that definition, so redefining a word later
changes only the calls after the redefinition (the forward calls made before
the first definition bind to the first).

**Limits.** A program may have 1024 different long names (256 before W10-A) of
up to 60 bytes each; the prelude's own long names count against them.
Anything else between `‹` and `›` (a space, a glyph, an empty name, or a
missing `›`) stops the compile with `GOLF: bad long name ‹…›`, and a 1025th
name with `GOLF: too many long names ‹…›`, both exit status 2. Locals take long
names inside a `⊡` word (M-FRAME2), up to 16 per word.

### Output

The prelude's printers `Ṅ ⍕ ␤ 🗲 ⊐` write through one 8 KB output buffer
(W11-1C). It drains to fd 1 when it fills, when the program ends, at `.`,
before every `GOLF:` error message (so prior output comes first), before
`‹readline›`/`‹getc›`/`‹readall›` read stdin (so a prompt shows), and before
every raw `)` or `(`. `)` and `(` themselves are not buffered: still one
`write`/`read` per byte.

| word | stack effect | meaning |
|---|---|---|
| `‹flush›` | `->` | write the buffered output now. Needed only before raw output that bypasses it, i.e. a `⎈` write |

```
1000000⍳⍕                # 6.9 MB of output in about 840 write(2) calls
5Ṅ‹flush›1“b“4+1 1⎈_     # prints 5b; without ‹flush› the raw ⎈ write comes first: b5
```

Output still pending when the process dies of a signal (a kill, or the
return-stack guard page's SIGSEGV) is lost. The cell `0x4F0988` (`5179784`)
holds the fd the buffer drains to; `0` means fd 1.

### Input

The prelude's input words (W9-4C) have long names, so they take no letter
from your program. Text arrives as a **code list**, one byte per element, which
`⊐` prints back and every list word works on.

| word | stack effect | meaning |
|---|---|---|
| `‹readall›` | `-> list` | the rest of stdin as a code list; empty input gives the empty list |
| `‹readline›` | `-> list flag` | the next line without its `\n`. `flag` is `0` for a line (an empty line too) and `1` at end of input with nothing read, zero-is-true like `[`. A last line with no `\n` still comes back with `0` |
| `‹getc›` | `-> b` | the next byte, `0`–`255`, or `-1` at end of input |
| `‹words›` | `list -> list` | split a code list on runs of ASCII whitespace (tab, `\n`, `\v`, `\f`, `\r`, space) into a list of code lists. Never yields an empty word |
| `‹num›` | `list -> n` | parse a signed decimal: skip leading whitespace, one optional `+` or `-`, then digits up to the first non-digit. No digits gives `0` (`“12ab“⊃‹num›` is 12, `“x“⊃‹num›` is 0). Overflow wraps at 64 bits |
| `‹ints›` | `-> list` | all of stdin as integers: `‹readall›‹words›′‹num›€`. A word that is not a number counts as `0` |
| `‹args›` | `-> list` | the command-line arguments after the program name, as a list of code lists |

```
‹ints›∑Ṅ                 # printf '1 2 3' | ./sum   prints 6
{‹readline›"[_⊐␤0]}      # echo stdin line by line, until end of input
‹args›′‹num›€∑Ṅ          # ./add 2 40               prints 42
```

The stdin words share one 8 KB buffer, so `‹readline›`, `‹getc›` and
`‹readall›` may be mixed freely. The raw `(` reads around that buffer: do not
use it in a program that uses these words. Names that start with `‹_in` are
the prelude's own helpers. See `examples/input.golfj`.

### Files

The file words (W11-1B) are long names too, built on `⎈`. A path is a **code
list**, the shape `“x.txt“⊃` and `‹args›` give, and so is a file's contents:
one element per byte, `0`–`255`. Writing stores each element's low byte.

| word | stack effect | meaning |
|---|---|---|
| `‹open›` | `path -> fd` | open a file for reading |
| `‹create›` | `path -> fd` | open a file for writing: create it (mode `0644`) or truncate it |
| `‹close›` | `fd ->` | close a file descriptor |
| `‹fread›` | `fd n -> list` | one `read(2)` of up to `n` bytes. It may return fewer. The empty list means end of file. A negative `n` counts as `0` |
| `‹fwrite›` | `list fd ->` | write every byte of `list` to `fd`, retrying short writes. Writes to one fd follow each other; the output buffer (`‹flush›`) is drained first, so `7Ṅ“ab“⊃1‹fwrite›8Ṅ` prints `7ab8` |
| `‹readfile›` | `path -> list` | the whole file as a code list. An empty file gives the empty list |
| `‹writefile›` | `list path ->` | create or truncate `path`, write `list` to it, close it |

```
“hi“⊃“x.txt“⊃‹writefile›          # x.txt now holds the two bytes 'hi'
“x.txt“⊃‹readfile›⊐               # prints hi
‹args›0⊇‹readfile›⊐               # ./cat f   prints the file f
“x.txt“⊃‹open›"5‹fread›⊐‹close›   # the first 5 bytes
```

**A failure throws** through `‹throw›`. The message names what was being done,
the path, and the errno: `GOLF: cannot open x.txt (ENOENT)`, exit status 1.
The verb is `open`, `create`, `read`, `write` or `close`. The fd words, which
have no path, name the fd instead: `GOLF: cannot read fd 9 (EBADF)`. Named
errnos are `EPERM ENOENT EIO EBADF EACCES EEXIST ENOTDIR EISDIR EINVAL EMFILE
EFBIG ENOSPC EROFS ENAMETOOLONG ELOOP`; any other shows as `errno N`. Before it
throws, the word stores the positive errno in the cell `5179712`
(`5179712⊙`), which is never cleared. Opening a directory works, but reading it
fails, so `“d“⊃‹readfile›` is `GOLF: cannot read d (EISDIR)`. Files are written
directly with `write(2)`, not through the stdout printers. Names that start
with `‹_1b` are the file words' helpers.
### More list words

The prelude's newer list words have long names, because the high bytes ran
out. They have no codepage row, so they are listed here. Like `⧺ ↑ ↓ ⍋`, each
one that returns a list returns a NEW tagged list and never writes its input.

| word | stack effect | meaning |
|---|---|---|
| `‹slice›` | `list i n -> list` | the `n` elements starting at index `i`. A negative `i` counts from the end (`-1` is the last element) and is then clamped to `0`. An `i` at or past the end gives an empty list. `n` is clamped to what is left, and a negative `n` counts as `0` |
| `‹indexof›` | `list x -> i` | index of the first element equal to `x`, or `-1` when there is none. Equality is `≡`'s raw cell equality, so an inner list is found only as that very list |
| `‹unique›` | `list -> list` | the first occurrence of each distinct element, in the original order. It uses a hash set, so it runs in O(n) expected time |
| `‹flatten›` | `list -> list` | every int in a nested list, depth-first, as one flat list. It works at any depth, because it loops one level at a time instead of recursing |

```
5⍳1 3‹slice›⍕            ->  1 2 3
5⍳0 2-9‹slice›⍕          ->  3 4
5⍳3‹indexof›Ṅ            ->  3
5⍳7‹indexof›Ṅ            ->  -1
5⍳"⧺⌽‹unique›⍕           ->  4 3 2 1 0
:s⍳′⍳€;4⍳′s€‹flatten›⍕  ->  0 0 0 1
```

The four words use 4 of the 1024 long names a program may have (the prelude
has 13 in all), so a program has 1011 for itself.

### Text

The text words (W11-1D) work on **code lists**, the one-code-per-cell lists
that `⊃`, `‹readall›` and `‹readline›` make and `⊐` prints. Each one that
returns a list returns a NEW list and never writes its input. A flag is
zero-is-true, like `∊` and `T`.

| word | stack effect | meaning |
|---|---|---|
| `‹fmt›` | `n -> list` | `n` in signed decimal, with a `-` first when `n < 0`. INT64_MIN works. `‹num›` reads it back |
| `‹hex›` | `n -> list` | `n` in lowercase hex, with no `0x` prefix. `n` is read as **unsigned** 64-bit (two's complement, like Rust's `{:x}`), so `-1` gives sixteen `f`s and nothing gets a sign |
| `‹parsehex›` | `list -> n` | parse hex: skip leading whitespace, one optional `+` or `-`, then the digits `0-9 a-f A-F` up to the first other byte. It never fails: no digits gives `0`, a `0x` prefix stops at the `x` (so it gives `0`), and overflow wraps at 64 bits, so `‹hex›‹parsehex›` gives back any int |
| `‹split›` | `list sep -> lists` | split on every element equal to `sep` (one element, such as `44` for a comma; `≡` equality). Empty fields are kept, as in Python's `str.split(sep)`: `k` separators always give `k+1` fields, and the empty list gives one empty field |
| `‹trim›` | `list -> list` | drop ASCII whitespace (tab, `\n`, `\v`, `\f`, `\r`, space) from both ends |
| `‹startswith›` | `list prefix -> f` | `0` if `prefix` is a prefix of `list`, else `1` (zero-is-true, like `∊`). The empty prefix always matches. Elements are compared with `≡` |
| `‹joinwith›` | `lists sep -> list` | concatenate the inner lists with `sep` between each pair. `sep` is a list, or an int taken as a one-element list. An empty `lists` gives the empty list. Every element of `lists` must be a list |
| `‹pad›` | `list width -> list` | left-pad with spaces (32) to `width` (right-justify, like Python's `str.rjust`). It never truncates: a list already `width` long or longer, or a negative `width`, gives a copy |

```
“a, b,c“⊃44‹split›′‹trim›€124‹joinwith›⊐  ->  a|b|c
“,a,,“⊃44‹split›≢Ṅ                         ->  4
0 42-‹fmt›⊐                                ->  -42
255‹hex›⊐                                  ->  ff
“  -ff“⊃‹parsehex›Ṅ                        ->  -255
“ hi “⊃‹trim›≢Ṅ                            ->  2
“golf“⊃“go“⊃‹startswith›Ṅ                  ->  0
3⍳′‹fmt›€“, “⊃‹joinwith›⊐                  ->  0, 1, 2
7‹fmt›3‹pad›⊐                              ->    7
```

Names that start with `‹_1d` are these words' helpers.

### Errors

A runtime error prints one line, `GOLF: <message>`, on stderr (fd 2) and exits
with status 1; stdout gets nothing more. The prelude raises its errors through
one word, which a program may call too:

| word | stack effect | meaning |
|---|---|---|
| `‹throw›` | `msg ->` | print `GOLF: `, the code list `msg` as text, and a newline on fd 2, then exit 1. Never returns |

```
“no input“⊃‹throw›       # stderr: GOLF: no input     exit status 1
```

`⊇` (`index out of range`), `∘` (`compose arena exhausted`) and `⌫`
(`free of a non-heap value`, `double free`) go through `‹throw›`. The spill
stack's `spill stack exhausted` and the divide-by-zero check of `/ % ÷ ∣` print
the same way without it. Compile errors (`GOLF: undefined word x` …) exit 2.

## 4. Tutorial

Each example below is a complete program. Compile it with
`tools/golfc -j ex.golfj ex && ./ex`. The `text` block under each example is
its exact output, and `test/run2.sh` checks every one. A trailing space on a
line is ignored, because `⍕` ends every number with a space.

<!-- TUTORIAL BEGIN -->

**1. Arithmetic and output.** Numbers push themselves. Ops pop their operands
and push the result. `Ṅ` prints a signed decimal and `␤` prints a newline.

```golfj
2 3+4*Ṅ␤
0 5-Ṅ␤
```

```text
20
-5
```

**2. Bytes in, bytes out.** `'c` pushes a character code and `)` writes one
byte. This is the v1 language exactly: no prelude word is used.

```golfj
'H)'i)10)
```

```text
Hi
```

**3. Words, and zero-is-true.** `:s"*;` defines `s` (square). The `a` word
works out an absolute value. `"0≺` pushes `-1` for a negative number, and `1+`
turns that into `0`, which is "true" for `[`, so the block `±` negates it.

```golfj
:s"*;
:a"0≺1+[±];
7sṄ␤
0 5-aṄ␤
```

```text
49
5
```

**4. Loops.** `}` jumps back while the value it pops is `0`. `"0≡` is `-1` once
the counter reaches zero, which ends the loop. The final `_` drops the counter.

```golfj
5{"Ṅ␤1-"0≡}_
```

```text
5
4
3
2
1
```

**5. Variables.** `→x` stores and `←x` loads, so the expression needs no stack
juggling. Here it is (a+b)·(a−b). Note the signed output.

```golfj
3→a 4→b
←a←b+←a←b-*Ṅ␤
```

```text
-7
```

**6. Lists and quotations.** `⍳` builds `[0..n-1]`. `′²` quotes the square
atom, `€` maps it over the list, and `⍕` prints the list. A filter keeps the
elements for which the predicate gives `0`. Here that is the multiples of 3.

```golfj
10⍳∑Ṅ␤
5⍳′²€⍕␤
:t3%;
10⍳′t⌿⍕␤
```

```text
45
0 1 4 9 16
0 3 6 9
```

**7. Vectorization and folds.** A list on either side makes `+ - *` work
elementwise. `4⍳4⍳*∑` is a dot product. `⇤` folds a list from an initial
value, so the second line is 5!.

```golfj
4⍳4⍳*∑Ṅ␤
5⍳1+1′*⇤Ṅ␤
```

```text
14
120
```

**8. Tacit chains.** `⊚m∑≢÷;` defines `m` as the fork `÷(∑ x, ≢ x)`. That is
the (integer) mean of a list.

```golfj
⊚m∑≢÷;
10⍳mṄ␤
```

```text
4
```

**9. Recursion with locals.** A `⊡` word gets private locals (`a`–`h` or long
names, one cell each) per call, so recursion is safe. Global `→`/`←` variables would be overwritten by
the inner calls. This is the factorial of 10.

```golfj
⊡f"0-[_1^]⇒a⇐a1-f⇐a*;
10fṄ␤
```

```text
3628800
```

**10. Strings.** `“…“` is a byte string. `⊃` turns it into a list of codes,
`1+` shifts every code, and `⊐` prints the codes as text. This is a Caesar
shift by one.

```golfj
“Hello“⊃1+⊐␤
```

```text
Ifmmp
```

<!-- TUTORIAL END -->
