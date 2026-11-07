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
letter, usually). Writing `x` later calls it. A word must be **defined before
it is used**: the compiler makes one pass and looks a name up when it meets it.
A call to a name that was never defined stops the compile with
`GOLF: undefined word x` on stderr and exit status 2. A word may call itself,
because its name is bound when its body starts. `^` returns early from the
current word. `;` returns at the end.

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
| `0x2F` | `/` | `( a b -- a/b )` | **unsigned** 64-bit divide (`0 1-2/` is 2^63-1). `÷` is the signed one. Dividing by 0 raises SIGFPE |
| `0x25` | `%` | `( a b -- a%b )` | **unsigned** 64-bit remainder. `∣` is the signed one |
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
| `0xB1` | `⊡` | `\dloc` | prefix: ⊡name ... ; defines a word with a frame of 8 per-call locals |
| `0xB2` | `⇒` | `\lset` | prefix: ⇒x pops TOS into local x (a..h) |
| `0xB3` | `⇐` | `\lget` | prefix: ⇐x pushes local x (a..h) |

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
  `⇒x` / `⇐x` reach slots `a`–`h` of the current call's frame.
- **Chains.** `⊚name f g h;` defines a tacit train. One link is a call, two
  links are a composition, and three are a fork `h(f x, g x)`. A fourth or later
  link is an ordinary call made on the result.

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

**9. Recursion with locals.** A `⊡` word gets eight private slots `a`–`h` per
call, so recursion is safe. Global `→`/`←` variables would be overwritten by
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
