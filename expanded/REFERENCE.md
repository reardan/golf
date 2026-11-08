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
`⋄` (W12-A7) splits either block in two, with the same convention:
`c[a⋄b]` runs `a` when `c` is `0` and `b` otherwise, and `{c⋄body}` computes
`c` before every pass and runs `body` while `c` is `0` (see "Special forms").

**Words.** `:x … ;` defines a word named `x`. The name is any single byte (a
letter, usually), or a **long name** written `‹name›` (see "Long names" at the
end of section 3). Writing `x` later calls it. A one-byte word must be
**defined before it is used**: the compiler makes one pass and looks a name up
when it meets it. A call to a name that was never defined stops the compile with
`GOLF: undefined word x at line 3` on stderr and exit status 2 (see "Compile
errors" at the end of section 3). A long name may be used
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

The unary arithmetic atoms `± ⊕ ⊖ ² ⊗ ⊘` do not vectorize. Given a list, they
raise `GOLF: not a number` through `‹throw›`, so the program exits 1, or a
`‹catch›` gets the message (W12-O1). Before W12 they quietly computed on the
list's tagged address.

```
5⍳⊕⍕  ->  GOLF: not a number
:‹f›3⍳²;′‹f›‹catch›⊐  ->  not a number
3⍳′⊕€⍕  ->  1 2 3
9223372036854775807⊖Ṅ  ->  9223372036854775806
```

(The first prints on stderr and exits 1.)

On integers they are unchanged. The cost is one compare and branch on the
value's top byte, about 0.1 to 0.2 ns per op. Only a value whose top byte
is `0x7F` reaches the prelude's check, which raises the error only for a
tagged value whose address is in the list heap. So `INT64_MAX` and the other
large integers still work as numbers. Without the prelude (`golfc -n`, and the
compiler itself) the hook cell is zero, so nothing is ever called and the
atoms compute on the bits. To map one of them over a list, write `′⊕€`.

The bitwise atoms `~ $ | = > ≪ ≫` stay **raw** on purpose. They work on a
list's bits with no check, because building and stripping the tag
(`32767 48≪|`, `16≪16>`) is bit arithmetic on exactly those values. The same
goes for the raw forms `﹢ ﹣ ﹡ ⊓ ⊔ ﹤`, and for the comparisons `< » ≡ ≺ ≻`.

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
| `0xB8` | `c[a⋄b]` | if-else (W12-A7): pop `c`, run `a` when it is `0`, `b` otherwise. `⋄` ends `a` with a jump past `]` |
| `0xB8` | `{c⋄body}` | top-tested while (W12-A7): run `c`, pop it, and leave the loop unless it is `0`; else run `body` and jump back to `{`. `body` may run zero times. `}` pops nothing here |
| `0x60` | `` `N bbb `` | raw blob: a decimal count `N`, one space, then `N` bytes that are copied into the program and jumped over. Pushes their address. In `.golfj` source the encoder still rewrites glyphs, `\` and `#` inside the blob, so keep those bytes plain ASCII there |
| `0x23` | `#` | comment to the end of the line |
| `0x00`–`0x20` | whitespace | ignored, except that it separates two numbers |
| any other | `x` | call the word named `x`, or compile its template if `x` is an atom |

**If-else and while: `⋄` (`\else`, W12-A7).** `⋄` belongs to the innermost
`[` or `{` that is still open, and may appear once in it.

- In `[ … ]` it is the else. `c[a⋄b]` compiles to `pop; test; jnz B`, then
  `a`, then `jmp END`, then `B: b`, then `END:`.
- In `{ … }` it ends the condition. `{c⋄body}` compiles to `TOP: c`, then
  `pop; test; jnz END`, then `body`, then `jmp TOP`, then `END:`. Unlike a plain
  `{ … }`, the body can run zero times, and the closing `}` pops nothing.
- Both use only the jumps `[ ] { }` already emit, plus one `jmp`, so there is
  no run-time cost. A `[a⋄b]` may sit inside the condition or the body of a
  while, and a while inside either branch of an if-else. A `⋄` inside `“…“`, in
  a `'⋄` literal or in a comment is not an operator.
- Truth is zero-is-true, as for `[` and `}`. Run the body while `i < n` with
  `{←i←n<1+⋄ … }`. Run it while `x` is non-zero with `{"[1⋄0]⋄ … }`, or test
  it the other way round with `≡`.
- `?` keeps its meaning (fetch a byte). PLAN_W12 wrote the loop `{?c⋄body}`,
  but the `?` there is only a marker: `{` followed by `?` already means "fetch
  a byte at the top of the loop", so the form is spelled `{c⋄body}`.
- A `⋄` with no open `[`/`{` (at top level, in the body of a word, after the
  `]`) is `GOLF: ⋄ outside [ ] or { }`, and a second one in the same block is
  `GOLF: ⋄ twice in one block` (see "Compile errors").

```golfj
0[1Ṅ⋄2Ṅ]  5[1Ṅ⋄2Ṅ]                      ->  12
:s"[_“zero“⋄0≺1+[“neg“⋄“pos“]]🗲;0s 7s 0 3-s ->  zeroposneg
0→i{←i5<1+⋄←iṄ←i1+→i}                   ->  01234
{1⋄99Ṅ}7Ṅ                               ->  7     (the body never runs)
0→i{←i4<1+⋄←i2%[“e“⋄“o“]🗲←i1+→i}        ->  eoeo
```

**Counters: `⇡x` and `⇣x` (`\vinc` / `\vdec`, W12-Z2).** Prefix ops, like
`→`/`←`: `⇡x` adds 1 to variable `x` and `⇣x` subtracts 1, in place.
`( -- )`: the data stack is not touched.

- `⇡x` means `←x⊕→x` and `⇣x` means `←x⊖→x`: 2 bytes of source instead of 5.
  Each compiles to one instruction, `inc qword [cell]` / `dec qword [cell]`
  (`48 FF 04 25 imm32` / `48 FF 0C 25 imm32`, 8 bytes instead of 20).
- `x` is a letter (`a`–`z`, `A`–`Z`) or a long name: `⇡‹count›` bumps the
  variable `‹count›`. In the examples, `⊡f` bumps its local `a` and leaves the
  variable alone; `⊡g` bumps the variable `a` until `⇒a` names the local.
- Inside a `⊡` word, a local the word has **already named** (with `⇒x` or
  `⇐x` earlier in its body) wins: `⇡a` then bumps that local,
  `inc qword [rbp+8k]` (`48 FF 45 disp8`; `⇣`: `48 FF 4D disp8`). `⇡` never
  claims a slot itself, so before the first `⇒a`/`⇐a`, and in a plain `:`
  word, `⇡a` is the variable `a`.
- There is no not-a-number check: `⇡` bumps the raw cell, whatever it holds
  (a variable holding a list gets a bad address, as `←x1﹢→x` would). Use it on
  counters.
- `⇡` followed by anything else (a digit, a space, a string, end of input) is
  `GOLF: ⇡ needs a variable` (`⇡1` gives `GOLF: ⇡ needs a variable at line 1`) (`⇣ needs a variable` for `⇣`). A `⇡` inside
  `“…“` or a comment is not an operator.

```golfj
5→x⇡x⇡x←xṄ⇣x⇣x⇣x←xṄ                  ->  74
0→i{←i5<1+⋄←iṄ⇡i}                    ->  01234
0→‹count›⇡‹count›⇡‹count›←‹count›Ṅ    ->  2
⊡f⇒a⇡a⇡a⇐a;10fṄ 50→a⇡a←aṄ             ->  1251
⊡g⇡a←aṄ⇒a⇡a⇐aṄ;100→a 7g               ->  1018
```

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
| `0x80` | `±` | `\neg` | negate TOS (a list: not a number) |
| `0x81` | `⊕` | `\inc` | TOS + 1 (a list: not a number) |
| `0x82` | `⊖` | `\dec` | TOS - 1 (a list: not a number) |
| `0x83` | `²` | `\sqr` | TOS * TOS (a list: not a number) |
| `0x84` | `⊗` | `\dbl` | TOS * 2 (a list: not a number) |
| `0x85` | `⊘` | `\hlv` | TOS >> 1 (a list: not a number) |
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
| `0xA8` | `⊷` | `\spr` | -> sp bp: push rsp (as before the atom), then rbp |
| `0xA9` | `⊶` | `\spw` | sp bp ->: set rbp, then rsp (both stacks jump) |

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
| `0xB2` | `⇒` | `\lset` | prefix: ⇒x pops TOS into local x (a..z or ‹name›) |
| `0xB3` | `⇐` | `\lget` | prefix: ⇐x pushes local x (a..z or ‹name›) |
| `0xB4` | `‹` | `\lname` | opens a long name: ‹name› stands wherever a one-byte name can |
| `0xB5` | `›` | `\rname` | closes a long name |
| `0xB6` | `⎘` | `\import` | prefix: ⎘“path“ compiles that file in place (once; searches . then lib/ then vendor/) |
| `0xB7` | `⊜` | `\rec` | prefix: ⊜‹point›‹x›‹y›; defines ‹point› (x y -> rec), ‹point-x› (rec -> x), ‹set-point-x› (rec v -> rec) |
| `0xB8` | `⋄` | `\else` | separator: c[a⋄b] runs a when c is 0, else b; {c⋄body} tests c before each pass, runs body while it is 0 |
| `0xB9` | `⇡` | `\vinc` | prefix: ⇡x adds 1 to variable x in place (←x⊕→x; in a ⊡ word, a local already named there) |
| `0xBA` | `⇣` | `\vdec` | prefix: ⇣x subtracts 1 from variable x in place (←x⊖→x; in a ⊡ word, a local already named there) |

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
| `0xD0` | `⊸` | `\bind` | — | bind: x ′f -> ′g; g pushes the captured x, then calls f |
| `0xD1` | `⍀` | `\scan` | — | scan: l ′f -> l'; inclusive, l'[0] = l[0], l'[i] = f(l'[i-1], l[i]) |
| `0xD2` | `⍁` | `\reduce` | — | reduce: l ′f -> x; fold seeded by l[0] (empty: empty reduce) |
| `0xD3` | `⍸` | `\eachi` | — | each-indexed: l ′f -> l'; l'[i] = f(l[i], i) |
| `0xD4` | `⍒` | `\ksort` | — | sort by key: l ′k -> l'; stable, ascending by k x (k once per element) |
| `0xD5` | `⍈` | `\putat` | — | store-at: list i v -> list; list[i] = v in place (bounds-checked) |
| `0xD6` | `⍆` | `\push` | — | push: v x -> v'; append x (vector or deque back); use the returned v' |
| `0xD7` | `⍅` | `\pop` | — | pop: v -> v x; remove the last element (empty: pop from empty) |
| `0xD8` | `⊟` | `\win` | — | window reduce: l n ′f -> f-reduce of every length-n window (deque for ⌈ ⌊) |
| `0xD9` | `⍣` | `\fix` | — | fixpoint: x ′f -> y; apply f until the result ≣ the previous one |
| `0xDA` | `⍞` | `\next` | — | stream next: s -> s x 0 \| s 1 (zero-is-true, like ‹readline›) |
| `0xDB` | `ℤ` | `\ints` | — | alias of ‹ints›: -> list, all of stdin as integers |
| `0xDC` | `⎕` | `\readall` | — | alias of ‹readall›: -> list, the rest of stdin as a code list |
| `0xDD` | `⏎` | `\readline` | — | alias of ‹readline›: -> list flag, the next line without its \n (flag 0), 1 at end |
| `0xDE` | `Ḋ` | `\dict` | — | alias of ‹dict›: -> d, a new empty dict |
| `0xDF` | `Ġ` | `\dget` | — | alias of ‹get›: d k -> v (missing: key not found) |
| `0xE0` | `Ṗ` | `\dput` | — | alias of ‹put›: d k v -> d |
| `0xE1` | `Ḳ` | `\keys` | — | alias of ‹keys›: d -> list, the keys in insertion order |
| `0xE2` | `Ḃ` | `\bump` | — | alias of ‹bump›: d k -> d, add 1 to k's value (missing: 1) |
| `0xE3` | `Ṿ` | `\vec` | — | alias of ‹vec›: -> v, a new empty vector |
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
  such an address as their function argument. `∘ ⇉ ⑂` combine them, and `⊸`
  binds a value into one (see Closures below).
- **Variables.** `→x` / `←x` store and load one global 64-bit cell per name
  byte. They are global, so a recursive word should use `⊡` locals instead:
  `⇒x` / `⇐x` reach local `x` in the current call's frame (see Locals below).
  `⇡x` / `⇣x` add / subtract 1 in place (W12-Z2; see "Counters" in section 2).
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
name per-call locals: any one lowercase letter `a`–`z` (W12-Z3; `a`–`h`
before) or any long name, mixed freely.
Each distinct name gets the next slot at its first appearance in the
definition, so a `⊡` word that names *k* locals reserves exactly *k* cells
(`⊡‹inc›1+;`, with none, costs what a `:` word does) and recurses that much
deeper. At most 16 locals per word: a 17th is `GOLF: too many locals ‹name›`,
exit 2. A one-letter local that is not a lowercase letter (`⇒A`, `⇒_`) is
`GOLF: local out of range A`. Outside a `⊡` word only M-FRAME's fixed `a`–`h`
slots exist: `⇒q` there is `GOLF: local out of range q`, and a long local is
`GOLF: local out of range ‹name›`.

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
`GOLF: undefined word ‹name› at line N` (or `GOLF: undefined word q at line N`
for a one-byte name), N being the line of its first use, and exit status 2,
and no binary is written. Only a name not defined *yet*
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

### One-byte aliases

W12-Z1 gives the nine most used prelude long names a byte each, `0xDB`–`0xE3`.
They were picked by counting uses in `examples/`, `bench/leetcode/golf/`,
`gtools/`, `lib/` and this reference. Each alias is a prelude word that calls
its long name, so the two spellings mean the same thing: same stack effect,
same errors, same speed apart from one extra call and return. The long names
stay, and the rest of this reference keeps using them. A long name costs its
length plus 2 bytes, so `ℤ` saves 5 bytes over `‹ints›` and `⏎` saves 9 over
`‹readline›`.

| glyph | mnemonic | long name | stack effect | meaning |
|---|---|---|---|---|
| `ℤ` | `\ints` | `‹ints›` | `-> list` | all of stdin as integers (see Input) |
| `⎕` | `\readall` | `‹readall›` | `-> list` | the rest of stdin as a code list |
| `⏎` | `\readline` | `‹readline›` | `-> list flag` | the next line without its `\n`; `flag` is `0`, or `1` at end of input |
| `Ḋ` | `\dict` | `‹dict›` | `-> d` | a new, empty dict (see Dicts and sets) |
| `Ġ` | `\dget` | `‹get›` | `d k -> v` | the value of `k`; a missing key is `GOLF: key not found` |
| `Ṗ` | `\dput` | `‹put›` | `d k v -> d` | set `k` to `v` |
| `Ḳ` | `\keys` | `‹keys›` | `d -> list` | the keys, in insertion order |
| `Ḃ` | `\bump` | `‹bump›` | `d k -> d` | add 1 to the value of `k` (a missing key gets 1) |
| `Ṿ` | `\vec` | `‹vec›` | `-> v` | a new, empty vector (see Vectors and deques) |

The dict mnemonics are `\dget` and `\dput` because `\get` is `←` and
`\puts` and `\putat` already exist: the encoder reads the longest mnemonic
that matches, so no mnemonic may be a prefix of another.

```
Ḋ"1 10Ṗ"2 20Ṗ"1ĠṄ                ->  10
Ḋ"7Ḃ"7Ḃ"9Ḃ‹vals›⍕                ->  2 1
Ḋ"5 1Ṗ"6 2Ṗ"5‹del›"5 3ṖḲ⍕        ->  6 5
Ṿ3⍆1⍆4⍆⍕                         ->  3 1 4
Ḋ9Ġ                              ->  GOLF: key not found
```

```
ℤ∑Ṅ                      # printf '1 2 3' | ./sum     prints 6
⎕≢Ṅ                      # printf 'ab\n' | ./len      prints 3
{⏎"[_⊐␤0]}               # echo stdin line by line, until end of input
```

The last `->` example prints on stderr and exits 1, as `‹get›` does.

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

**Booleans (W12-O6).** LeetCode answers are often `true` or `false`.

| word | stack effect | meaning |
|---|---|---|
| `‹tf›` | `f -> list` | the code list `true` when `f` is `0`, else `false`, printed with `⊐`. This is zero-is-true, like `[`, `∊` and `‹has›`. A comparison `≡ ≺ ≻ < »` pushes `-1` for true, so add `1+` first (`-1` becomes `0`). Each call makes a new list |

```
0‹tf›⊐                   ->  true
7‹tf›⊐                   ->  false
3 3≡1+‹tf›⊐              ->  true
“abc“⊃98∊‹tf›⊐           ->  true
“abc“⊃“x“⊃‹startswith›‹tf›⊐  ->  false
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
| `‹ints›` | `-> list` | all of stdin as integers, the same list as `‹readall›‹words›′‹num›€`: words split on the same whitespace, each parsed like `‹num›`, so a word that is not a number counts as `0` (`12ab` is 12, `x` is 0) and overflow wraps. Since W12-P1 it scans the input buffer directly into one list (1M ints: 0.05 s, 16 MB peak), with no code list or word lists in between |
| `‹readbytes›` | `-> block` | the rest of stdin as a byte block in the `“…“` layout, a 32-bit length then one byte per byte, so `🗲` prints it and `⊃` turns it into a code list. A raw block, not a tagged list (as a `“…“` literal is): list words do not take it, `⌫` frees it. Empty input gives length `0` |
| `‹args›` | `-> list` | the command-line arguments after the program name, as a list of code lists |

```
‹ints›∑Ṅ                 # printf '1 2 3' | ./sum   prints 6
{‹readline›"[_⊐␤0]}      # echo stdin line by line, until end of input
‹args›′‹num›€∑Ṅ          # ./add 2 40               prints 42
‹readbytes›🗲             # cat, at one byte per byte of input
‹readbytes›⊃≢Ṅ           # printf 'ab\n' | ./len   prints 3
```

`ℤ`, `⎕` and `⏎` are one-byte aliases of `‹ints›`, `‹readall›` and
`‹readline›` (see "One-byte aliases").

The stdin words share one 8 KB buffer, so `‹readline›`, `‹getc›`,
`‹readall›`, `‹readbytes›` and `‹ints›` may be mixed freely (`‹readall›`,
`‹readbytes›` and `‹ints›` read to the end). `‹readall›` is `‹readbytes›`
widened into a list, so it peaks at about 10 bytes per input byte. The raw `(`
reads around that buffer: do not use it in a program that uses these words.
Names that start with `‹_in` or `‹_12p1` are the prelude's own helpers. See `examples/input.golfj`.

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
has 198 in all after W13-G's twelve helpers, helpers included), so a program has 826 for itself.

### Sorting by key

`⍋` sorts the elements themselves. Two words sort by something else (W12-A4):

| word | stack effect | meaning |
|---|---|---|
| `⍒` (`0xD4`, `\ksort`) | `l ′k -> l'` | a new list: `l` sorted ascending by the key `k x` of each element. It is stable, so elements with equal keys keep their order. Descending is a negating key, `′±` or `′(k ±)` |
| `‹grade›` | `l -> perm` | the permutation that sorts `l`: a new list of the indices `0 … n-1` such that `l[perm[0]] ≤ l[perm[1]] ≤ …`. Stable: equal elements keep index order |

```
:f7%;10⍳′f⍒⍕                 ->  0 7 1 8 2 9 3 4 5 6
5⍳′±⍒⍕                       ->  4 3 2 1 0
5⍳⌽‹grade›⍕                  ->  4 3 2 1 0
:f7919*1000%;6⍳′f€"⍕"‹grade›⍕ ->  0 919 838 757 676 595 0 5 4 3 2 1
:k\\⊕\\±;0 5⍳′k⍒⍕Ṅ           ->  4 3 2 1 0 5
:i±;:k′i⍒0⊇;3⍳1+′⍳€⌽′k⍒⍕     ->  [0] [0 1] [0 1 2]
0⍳′±⍒≢Ṅ                      ->  0
```

- **Keys** compare as `⍋` compares: signed, on the raw 64-bit cell. An int
  key at or above `0x7FFF<<48` is a list value, and a list key compares by its
  tagged value (after every smaller int, among lists by address), so there is
  no lexicographic order on list keys. To sort by two ints, pack them into
  one, as `bench/leetcode/golf/topk.golfj` does: `x - (count<<32)` sorts by
  count descending, then by `x`.
- **`k` runs once per element**, in order, through `€`. So it sees the
  caller's stack under its element (see "Threading state" below) and may run
  `⍒` itself. The keys are computed first and then sorted with `⍋`'s merge
  sort, comparing keys by index: O(n log n) compares and n calls of `k`.
- Both words check their list for use after free and return a tagged list,
  and neither writes its input. Their scratch blocks (the keys and a merge
  buffer) go back to `⌫`. A throw inside `k` unwinds through `‹catch›` like
  any other, though the half-built key list is not freed.
- Cost at 1M elements: `‹grade›` is about as fast as `⍋` (~650 ns per
  element on the shared bench machine), and `⍒` adds about 15% for the key
  calls and the gather.

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

### Records

`⊜‹point›‹x›‹y›;` (byte `0xB7`, mnemonic `\rec`) declares a record: a name,
then its fields, up to `;` (W11-4A). The compiler turns the header into
ordinary words at compile time. Nothing runs at the `⊜` itself:

| word | stack effect | meaning |
|---|---|---|
| `‹point›` | `x y -> rec` | constructor: pops one value per field, the first field deepest, and returns a new list of that length |
| `‹point-x›` | `rec -> x` | accessor: field *k* is element *k*, read with `⊇`, so `index out of range` and `use after free` still apply |
| `‹set-point-x›` | `rec v -> rec` | setter: stores `v` in the field **in place** and leaves the record |

A record is a plain list underneath, so every list word works on it: `⍕`
prints its fields, `≢` counts them, `⊇` indexes them, `≣` compares two, and
`⌫` frees one. A word that takes a "point" takes any list long enough.

```
⊜‹point›‹x›‹y›; 3 4‹point›‹point-y›Ṅ                         ->  4
⊜‹point›‹x›‹y›; 3 4‹point›9‹set-point-x›⍕                    ->  9 4 
⊜‹point›‹x›‹y›; 3 4‹point›"‹point-x›²&‹point-y›²+Ṅ           ->  25
⊜‹pair›a b; 1 2‹pair›"≢Ṅ 1 2‹pair›≣Ṅ                         ->  2-1
⊜p‹first›‹rest›; 7 3⍳p‹p-rest›⍕                              ->  0 1 2 
```

- **Names.** The accessor and setter names join the parts with `-`. `.` is
  not a long-name byte, so the plan's `‹point.x›` is spelled `‹point-x›`.
  The record name and each field are either a long name or one byte that may
  stand in a long name (`0-9 A-Z a-z _ -`), because that byte becomes part of
  `‹p-x›`. Whitespace may separate the fields. The record name follows `⊜`
  directly. At most 256 fields.
- **They are just words.** You can call them before the `⊜` (forward
  references), quote them (`′‹point-x›`), and use them as chain links. A field
  that does not exist is an ordinary undefined word:
  `GOLF: undefined word ‹point-z› at line N`, exit 2. A record declared in an
  included file works the same way.
- **Limits.** Every invented name counts against the 1024 long names, two
  per field, and so do the record and field names themselves. A name that
  would pass 60 bytes (`‹set-…›` is 4 longer than the record name plus the
  field) is `GOLF: bad long name ‹…›`.
- **Errors** (exit 2): `GOLF: record without fields ‹point›` (`⊜‹point›;`),
  `GOLF: record without ; ‹point›` (end of input first),
  `GOLF: bad record field (` (a byte that is not a name), `GOLF: bad record
  name (`, and `GOLF: too many record fields ‹point›`. Each ends with
  ` at line N`.

They compile to exactly what these definitions would (`8k+8` is field *k*'s
cell, past the length cell):

```golfj
:‹point› 2⍳ \\&16≪16>16﹢⊛ \\&16≪16>8﹢⊛ ;   # last field first
:‹point-x› 0⊇;
:‹set-point-x› &0⊇_ &16≪16>8﹢⊛;
```

### Modules

`⎘“path“` (byte `0xB6`, mnemonic `\import“path“`) includes a file (W11-2A).
The compiler reads that file's bytes as if they stood where the `⎘` is, then
goes on after the closing `“`. It is textual, like C's `#include`: the file's
definitions become the program's, and there are no namespaces. It may stand
anywhere a token may, but by convention the includes come first.

- **Search order:** the path as written, relative to the directory the
  compiler runs in, then `lib/` + path, then `vendor/` + path (W11-4A; where
  packages are fetched). An absolute path is used as it is.
- **Include-once:** a path that was already included is skipped, so a file
  included twice compiles once, and a file that includes itself is harmless.
  Paths are compared byte for byte as written, so `x.g2` and `lib/x.g2` count
  as two paths. The main program is not in the table.
- **Nesting:** an included file may include others, 8 levels deep. At most 60
  distinct files may be included, and a path may be at most 250 bytes.
- **Boundaries:** a file's end also ends its last token. So a number, a name or
  a `#` comment at the very end of a file never runs into the includer.
- **Form:** the compiler reads the bytes raw. That is code-page bytes, the form
  `golf2` reads on stdin (`.g2`). `tools/golfc` encodes every included `.golfj`
  file on the way, as it encodes the program itself (`-j`). So glyph source may
  include glyph source.

```
# lib/geom.golfj
:‹sq›"*;
:‹hyp2›‹sq›→a‹sq›←a+;          # a b -> a²+b²

# main.golfj — tools/golfc -j main.golfj main && ./main   prints 25
⎘“geom.golfj“⎘“geom.golfj“      # found in lib/; the second one is skipped
3 4‹hyp2›Ṅ
```

A missing file stops the compile: `GOLF: cannot include <path>` on stderr,
exit status 2, and no binary. So do a 9th level of nesting
(`GOLF: includes nested too deeply <path>`), a 61st file
(`GOLF: too many includes <path>`), and a path that is too long, unclosed, or
not a `“…“` literal (`GOLF: cannot include …`).

### Packages

A project pins the GOLF packages it uses in **`golf.deps`**, and
`tools/golfdeps` fetches them into **`vendor/<name>/`** next to that file
(W11-4E). The manifest is shaped like the repo's root `SEEDS` file. A `#`
starts a comment, at the start of a line or after a blank, and blank lines are
ignored. Every other line is one package with four fields:

```
# golf.deps — name  git-url                                 tag    sha256
mathx   https://github.com/example/golf-mathx.git    v1.2   3f1c8a0e5b2d4c6f8091a2b3c4d5e6f708192a3b4c5d6e7f8091a2b3c4d5e6f7
textx   file:///srv/git/textx                        v0.3   0000000000000000000000000000000000000000000000000000000000000000
```

- **name** is the directory under `vendor/`. It may use letters, digits, `_`,
  `-` and `.`, and may not start with `.`.
- **git-url** is anything `git clone` accepts: `https://`, ssh, `file://` or a
  local path.
- **tag** is cloned with `--depth 1 --branch <tag>`.
- **sha256** is the package hash (below), 64 lowercase hex digits. An all-zero
  pin asks for the hash: `fetch` refuses the package and prints the hash it
  got, as `SEEDS` does before a release.

```
tools/golfdeps fetch  [-f golf.deps]   # clone, check, install into vendor/<name>/
tools/golfdeps verify [-f golf.deps]   # re-hash vendor/<name>/; exit 1 if missing or modified
tools/golfdeps list   [-f golf.deps]   # name tag ok|missing|modified, one per line
tools/golfdeps hash   DIR              # the package hash of DIR, to fill in a pin
```

**The package hash** covers the files only, not git's metadata. So it is the
same for any clone, depth, git version or mirror. Take every regular file under
the package directory except the top-level `.git/`, by its relative path. Sort
the paths bytewise (`LC_ALL=C`). Write one line per file:
`<sha256 of its bytes> <path>` and a newline. The package hash is the sha256 of
those lines. File modes, timestamps and empty directories do not count. A
symlink, a device or a file name with a newline in it is refused.

`fetch` leaves alone a package whose `vendor/<name>/` already matches its pin,
so running it again does nothing ("up to date"). Any other package is cloned
into a temporary `vendor/.<name>.tmp/` and its `.git/` is removed. Then it is
hashed. On a match it replaces `vendor/<name>/`. On a mismatch, `fetch` removes
the clone and any old `vendor/<name>/`, prints the wanted and the computed
hash, and exits 1. So nothing unpinned is left in `vendor/` to be included.
`verify` changes nothing, and `fetch` puts a modified package back. The exit
status is 0 when all is well, 1 when a package failed (clone, hash or verify),
and 2 for a usage or manifest error (the message names the line).

**Using a package.** A package is plain GOLF source. A program in the
project directory includes its files through the include search path, which
W11-4A extends with `vendor/` after the path as written and `lib/`:

```
⎘“mathx/mathx.golfj“            # found as vendor/mathx/mathx.golfj (W11-4A)
3‹pkgcube›Ṅ                     # prints 27, with mathx.golfj holding :‹pkgcube›""**;
```

To be explicit, the same file can also be spelled
`⎘“vendor/mathx/mathx.golfj“`, its path as written. Inside a package, a file includes its siblings the same way, as
`⎘“<name>/<file>.golfj“`. Include-once compares paths as written, so a program
should spell a package's files one way only.

### Memory

`⌫` gives a list (or an `A` block) back to the allocator, and the next
allocation of the same size class reuses it. Since W11-2D a freed list is
**poisoned**: `⌫` writes `-559038737` into its length cell, and every list
word checks that cell on entry (`∑ ≢ ⍕ € ⇤ ∏ ⊇ ⌽ ⌿ ⊐ ⊞ ⧺ ↑ ↓ ⍋ ∊ ≣ ⍤`, the
bare `+ - *` on lists, and the long-named list and text words built on them).
A freed list that reaches one stops the program with `GOLF: use after free`
(exit 1). Freeing it again is still `GOLF: double free`.

| word | stack effect | meaning |
|---|---|---|
| `‹heapstats›` | `-> blocks bytes` | the number of allocator blocks now live (allocated and not yet freed) and their total size in bytes. A block counts whole: its header cell plus its size class, so `5⍳` (6 cells, class 8) is `(8+1)*8 = 72` bytes. The prelude's own blocks count too, so compare two readings |

```
‹heapstats›_→n 5⍳‹heapstats›_←n-Ṅ                          ->  1
‹heapstats›→b_ 5⍳‹heapstats›←b-Ṅ                           ->  72
:d⊗;5⍳→l‹heapstats›_→n 1000→i{←l′d€⌫←i1-"→i0≡}‹heapstats›_←n-Ṅ  ->  0
5⍳"⌫ 5⍳"≢Ṅ                                                 ->  5
5⍳"⌫∑Ṅ      # stderr: GOLF: use after free     exit status 1
```

In the fourth example the second `5⍳` gets the freed block back, and it is an
ordinary live list: `A` clears the poison when it hands a block out again.
That is also what is **not** caught: a stale copy of a list that was freed and
then reused reads (or frees) the new owner's list without an error. A value
pointing into the middle of a block is not checked either. Names that start
with `‹_2d` are helpers.

### Vectors and deques

W12-Z4 adds a store into a list, a growable **vector**, and a **deque**. None
of these words copies: each one changes its block in place.

| word | stack effect | meaning |
|---|---|---|
| `⍈` | `l i v -> l` | store `v` at index `i` of `l`, in place, and leave the same `l`. It is the twin of `⊇` and is checked the same way: an `i` at or past `≢l`, or any negative `i`, is `GOLF: index out of range` (a negative `i` does **not** count from the end, as with `⊇`). A freed `l` is `GOLF: use after free` |
| `‹vec›` | `-> v` | a new, empty vector: room for 3 elements before its first growth |
| `‹vecn›` | `n -> v` | a new, empty vector with room for at least `n` elements |
| `⍆` | `v x -> v` | push `x` on the end. **Use the returned `v`**: it is the same value while there is room and a new one after a growth (see below). On a deque, pushes at the back |
| `⍅` | `v -> v x` | pop the last element. `v` is left unchanged: the block never shrinks. An empty one is `GOLF: pop from empty`. On a deque, pops the back |
| `‹last›` | `v -> x` | the last element (a deque: the back), without removing it. Empty is `GOLF: index out of range` |
| `‹first›` | `v -> x` | the first element (a deque: the front), the same as `0⊇` on a vector |
| `‹deque›` | `-> d` | a new, empty deque (room for 6) |
| `‹pushf›` | `d x -> d` | push `x` at the front of a deque. Use the returned `d`, as with `⍆`. Anything but a deque is `GOLF: not a deque` |
| `‹popf›` | `d -> d x` | pop the front of a deque. Empty is `GOLF: pop from empty` |

**A vector is a list.** Every allocator block already records its capacity
in its header cell, and `A` rounds every request up to a size class, so most
lists have spare room: `5⍳` has room for 7. `⍆` writes into that room and
bumps the length cell. When the block is full, it allocates one of twice the
capacity, copies the elements, frees the old block with `⌫`, and returns the
new value. So a push is amortized O(1), and the rule is the one Go's `append`
has: keep what `⍆` returns (`←v x⍆→v`). After a growth the old value is a
freed list, and a list word on it is `GOLF: use after free`. Since the length
cell is still the first cell, every list word reads a vector: `≢ ⊇ ∑ ⍕ €`
and the rest. `⍆` works on any list, a `⍳` result included, and because it
appends in place, every other copy of that value sees the new element. `⌫`
of the current value frees the current block, and `‹heapstats›` stays exact.
A growth is one allocation and one free, so the block count does not change.

**A deque is not a list.** It is one block that holds the count, the head
index and a ring buffer, and its value carries its own tag (`0x7FFD<<48`
instead of the list tag `0x7FFF<<48`). `≢` gives its element count and `⌫`
frees it. `⍆ ⍅ ‹first› ‹last›` see the tag and work on either end; `⊇ ∑ ⍕ €`
and the other list words do not understand the ring and must not be given a
deque. A full ring doubles the same way a vector does, so both ends are
amortized O(1), and `⍆` and `‹pushf›` return the possibly new `d`.

```
5⍳2 9⍈⍕                                          ->  0 1 9 3 4
‹vec›3⍆1⍆4⍆⍕                                     ->  3 1 4
‹vec›3⍆1⍆5⍆⍅Ṅ∑Ṅ                                  ->  54
:p←v\\⍆→v0;‹vec›→v 1000⍳′p€_←v"≢Ṅ‹last›Ṅ         ->  1000999
5⍳→l ←l7⍆_ ←l≢Ṅ                                  ->  6
‹deque›1⍆2⍆0‹pushf›"≢Ṅ‹popf›Ṅ⍅Ṅ‹first›Ṅ           ->  3021
:p←v\\⍆→v0;1000⍳→l‹heapstats›_→n‹vec›→v←l′p€⌫‹heapstats›_←n-Ṅ  ->  1
‹vec›⍅                                           ->  GOLF: pop from empty
5⍳5 9⍈                                           ->  GOLF: index out of range
:‹f›‹vec›⍅;′‹f›‹catch›⊐                           ->  pop from empty
```

`Ṿ` is a one-byte alias of `‹vec›` (see "One-byte aliases").

In the third example `⍅` pops the `5` and leaves `3 1`. In the seventh,
the vector grows from 3 elements to 1023 over nine doublings and is still
one live block. The two `GOLF:` lines go to stderr with exit status 1, and
`‹catch›` turns the error into its message. The ten words use bytes `0xD5`
to `0xD7` and seven long names; names that start with `‹_12z4` are their
helpers.

### Priority queues

W12-O3 adds a min-priority queue: a binary heap kept in a vector, for
Dijkstra, merging k sorted lists and streaming top-k.

| word | stack effect | meaning |
|---|---|---|
| `‹pq›` | `-> q` | a new, empty queue |
| `‹pqpush›` | `q x -> q` | insert `x`, in O(log n). **Use the returned `q`**, as with `⍆`: a growth moves the queue to a new block and frees the old one |
| `‹pqpop›` | `q -> q x` | remove and return the smallest element, in O(log n). `q` itself is unchanged. An empty queue is `GOLF: pop from empty` |
| `‹pqtop›` | `q -> x` | the smallest element, without removing it. Empty is `GOLF: index out of range` |

Elements are ints compared **signed**, like the keys of `⍋` and `⍒`. There is
no key function. To order other things, pack the priority into the high bits:
`p 32≪ v|` sorts by `p` (any signed value that fits in 32 bits) and then by `v`
(0 to 2^32-1). `32≫` gets `p` back and `4294967295$` gets `v`. Equal elements
come out in no particular order.

A queue is a vector, so a list. `≢` is its size, `⌫` frees it, and
`‹heapstats›` counts it. `⍕` shows the heap's array order (smallest first,
each element no larger than its children at `2k+1` and `2k+2`), which is not
sorted order. Do not `⍆` or `⍈` into a queue: that breaks the heap order.

```
‹pq›5‹pqpush›1‹pqpush›4‹pqpush›"‹pqtop›Ṅ‹pqpop›Ṅ‹pqpop›Ṅ‹pqpop›Ṅ≢Ṅ  ->  11450
‹pq›3±‹pqpush›2‹pqpush›7±‹pqpush›⍕                    ->  -7 2 -3
‹pq›0→i{←i7*10%‹pqpush›←i1+"→i10<1+}{‹pqpop›Ṅ32)"≢0≡}_  ->  0 1 2 3 4 5 6 7 8 9
‹pq›2 32≪9|‹pqpush›1±32≪5|‹pqpush›‹pqpop›4294967295$Ṅ‹pqpop›32≫Ṅ  ->  52
‹pq›‹pqpop›                                          ->  GOLF: pop from empty
:‹f›‹pq›‹pqpop›;′‹f›‹catch›⊐                          ->  pop from empty
```

In the first example `‹pqtop›` sees `1` and leaves it in place. The fourth
packs priority `-1` with payload `5` and priority `2` with payload `9`, so the
payload `5` comes out first. On a million pushes followed by a million pops,
a push takes about 60 ns and a pop about 500 ns, against Python's C `heapq`
at 180 ns and 1.6 µs. Names that start with `‹_12o3` are reserved for the
queue's helpers.

### Dicts and sets

A **dict** (W11-2B) maps keys to values. A key is an int or a list, nested
to any depth. Keys are compared with `≣` (structural equality), so a code
list made at run time finds the entry that another, equal code list made.
Values can be anything. A **set** is a dict whose values are all `0`. It
uses the same words.

| word | stack effect | meaning |
|---|---|---|
| `‹hash›` | `v -> h` | FNV-1a, 64-bit. An int hashes its 8 bytes, low byte first. A list starts from the FNV basis and hashes each element's 8 bytes in turn. An inner list is replaced by its own `‹hash›`, so values that are `≣`-equal always hash equal |
| `‹dict›` | `-> d` | a new, empty dict |
| `‹put›` | `d k v -> d` | set key `k` to `v`. This inserts a new key or overwrites an existing one |
| `‹get›` | `d k -> v` | the value of `k`. A missing key throws `GOLF: key not found` (exit 1). Test with `‹has›` first if a key may be missing |
| `‹has›` | `d k -> f` | `0` if `k` is a key, else `1`. This is zero-is-true, like `∊`, so `‹has›[…]` runs on a hit |
| `‹del›` | `d k -> d` | remove `k`. Nothing happens if `k` is not a key |
| `‹keys›` | `d -> list` | the keys, in **insertion order**. A key that is deleted and then put again moves to the end. On a set, this lists the members. `‹keys›≢` is the count |
| `‹vals›` | `d -> list` | the values, in the same order as `‹keys›` |
| `‹set›` | `-> s` | a new, empty set (a dict) |
| `‹add›` | `s k -> s` | add `k` to the set. This is the same as `k 0‹put›`. `‹has›`, `‹del›` and `‹keys›` work on sets |
| `‹getor›` | `d k dflt -> v` | the value of `k`, or `dflt` when `k` is not a key. Nothing is inserted (W12-P2) |
| `‹bump›` | `d k -> d` | add 1 to the value of `k`. A missing key is inserted with the value 1. The counter word: `d k ‹bump›` is `d k 1 ‹put›` or `d k d k ‹get› 1+ ‹put›`, in one probe (W12-P2) |
| `‹upd›` | `d k ′f -> d` | replace the value `v` of `k` with `f(v)`. A missing key is inserted with `0` first, so `f` sees `0`. `f` runs with the caller's stack under `v`, as `€`'s function does (see "Threading state" below), and may use dicts itself, `d` included (W12-P2) |

```
‹dict›"1 10‹put›"2 20‹put›"1‹get›Ṅ                ->  10
‹dict›"“ab“⊃7‹put›"“ab“⊃‹get›Ṅ                    ->  7
‹dict›"3⍳3‹put›"3⍳‹has›Ṅ"4⍳‹has›Ṅ                 ->  01
‹dict›"5 1‹put›"6 2‹put›"5‹del›"5 3‹put›‹keys›⍕   ->  6 5
‹dict›"5 1‹put›"6 2‹put›‹vals›⍕                   ->  1 2
‹set›"4‹add›"2‹add›"4‹add›‹keys›⍕                 ->  4 2
3⍳′⍳€‹hash›3⍳′⍳€‹hash›≡Ṅ                          ->  -1
‹dict›9‹get›Ṅ                                     ->  GOLF: key not found
```

`Ḋ Ġ Ṗ Ḳ Ḃ` are one-byte aliases of `‹dict› ‹get› ‹put› ‹keys› ‹bump›` (see
"One-byte aliases").

The last example prints its message on stderr, not stdout, and exits with
status 1.

`‹getor›`, `‹bump›` and `‹upd›` find the key once, where `‹has›` then
`‹get›` then `‹put›` would hash and compare it three times:

```
‹dict›"7‹bump›"7‹bump›"9‹bump›‹vals›⍕              ->  2 1
‹dict›"1 10‹put›"1 0‹getor›Ṅ"2 0‹getor›Ṅ           ->  100
‹dict›"3′⊗‹upd›"3 5‹put›"3′⊗‹upd›3‹get›Ṅ           ->  10
‹dict›"“ab“⊃‹bump›"“ab“⊃‹bump›"“ab“⊃‹get›Ṅ‹keys›⍕   ->  2[97 98]
‹set›"4‹add›"4 9‹getor›Ṅ"5 9‹getor›Ṅ‹keys›⍕          ->  094
:f&+;‹dict›→d 7←d 3′f‹upd›_←d 3′f‹upd›_←d 3‹get›ṄṄ   ->  147
```

In the last one `f` is `&+`: it adds the `7` left under the dict's value
(threading), so the value goes `0`, `7`, `14` and the `7` is still there at
the end. `‹bump›` adds with the raw `﹢`, so it is meant for int values.

**A dict is changed in place.** `‹put›`, `‹del›`, `‹add›`, `‹bump›` and
`‹upd›` hand back the same `d`, so you can drop the result (`‹put›_`) or chain from it. A dict is
a tagged list of 6 cells, so `≢d` is 6, not the number of keys. Its contents
are internal. Keys that are lists are stored **by reference**, not copied:
do not change or `⌫` a list while it is a key. The table is a compact dict, as
in CPython: an insertion-ordered entry array plus an open-addressing index
(power-of-two size, linear probing, load at most 1/2, tombstones for deleted
keys). It grows by doubling (by four once it reaches 131,072 slots) and gives
the old blocks back with `⌫`. Inserts, lookups and deletes take O(1) expected
time. An int key is placed by a cheap hash of its own (not `‹hash›`), which
keeps runs of consecutive ints together in memory, and is compared with `≡`;
a list key is placed by its `‹hash›` and compared with `≣`. A million int
`‹put›`s, or a million `‹bump›`s, take about 0.13 s (W12-P2; 0.55 s before).

A word count over stdin:

```
:‹tally›←‹d›\\‹bump›;
:‹show›→‹k›←‹d›←‹k›‹get›Ṅ“ “🗲←‹k›⊐␤0;
‹dict›→‹d›‹readall›‹words›′‹tally›€_←‹d›‹keys›′‹show›€_
```

It prints `count word` once for each distinct word, in order of first
appearance. `‹tally›` gets each word with the stack under it, puts the dict
under it with `\\` (swap) and bumps. Names that start with `‹_2b` and
`‹_12p2` are these words' helpers. With them
(and W11-2D's `‹heapstats›` and two helpers, and W11-3A's `‹catch›` and five, and W11-3C's three checked words, and W11-4B's two test words and three helpers, and W11-4C's `‹stack›`, and W12-P1's `‹readbytes›` and seven helpers, and W12-O1's two helpers, and W12-P2's three dict words and two helpers, and W12-Z4's seven vector and deque words and five helpers, and W12-P3's twenty-three helpers, and W12-A4's `‹grade›`, and W13-G's twelve helpers), the prelude has 198 long
names, which leaves 826 for a program.

### Threading state through `€ ⇤ ⌿ ⊞`

A higher-order list word calls its function with **the caller's stack
underneath** the element (W12-0 made this a contract). The list words keep
their own loop state in the scratch cells and the spill stack, never on the
data stack. So the function may read the values below its element and leave
new ones there, and whatever it leaves is still there when the word returns.
That turns `€` into a map with an accumulator: a running sum, a running max,
an index counter.

```
:s+";0 5⍳1+′s€⍕Ṅ                 ->  1 3 6 10 15 15
:a⌈";0“31415“⊃48-′a€⍕_           ->  3 3 4 4 5
:f&+\\⊕\\;0 4⍳10*′f€⍕_            ->  0 11 22 33
:p\\⊕\\3∣;0 9⍳′p⌿⍕Ṅ               ->  0 3 6 9
:g+;0 3⍳10′g⇤ṄṄ                  ->  130
:z+\\⊕\\;0 3⍳3⍳10*′z⊞⍕Ṅ           ->  0 11 22 3
```

- **The running sum.** `s` is `+"`. With the accumulator `a` under the
  element `x`, `+` leaves `a+x`, and `"` keeps one copy as the result and the
  other below as the next accumulator. The `Ṅ` prints the final total, left
  under the list.
- **The counter.** `f` gets `c x` and leaves `c+1` below and `x+c` as the
  result.
- **The other words.** `⌿`'s predicate counts every element it sees (9).
  `⇤`'s step finds the `0` the caller left, under the accumulator: `13` is the
  fold and `0` is still there. `⊞` threads the same way, with `c a b`.

The function must consume exactly its own arguments (the element, or `⇤`'s
`acc x`, or `⊞`'s `a b`) and push exactly one result on top. Anything it
leaves or takes below that is the caller's business. Nesting works: a
function that runs `€` itself sees its own caller's stack under its own
element.

`⍒` (W12-A4) computes its keys with `€`, so its key function threads the same
way: `:k\\⊕\\±;0 5⍳′k⍒⍕Ṅ` prints `4 3 2 1 0 5`, the 5 being the count of calls.
### Scan, reduce and each-indexed

Three more higher-order list words (W12-A2, W12-A3). They keep the
threading contract above: the function sees the caller's stack under its
arguments, and the words keep their loop state in the scratch cells under
one spill frame, so they nest in each other and in `€ ⇤ ⌿ ⊞`. `⍀` and `⍸`
return a new tagged list and never write their input. A freed list is
`GOLF: use after free`.

| glyph | mnemonic | stack effect | meaning |
|---|---|---|---|
| `⍀` | `\scan` | `l ′f -> l'` | inclusive scan. `l'[0]` is `l[0]` and `l'[i]` is `f(l'[i-1], l[i])`, so `l'` is as long as `l`, and an empty `l` gives an empty list. `f` gets `acc x`, as `⇤`'s function does, and is called `≢l - 1` times. Scan from the right is `⌽…⍀⌽` |
| `⍁` | `\reduce` | `l ′f -> x` | fold with no seed: `l[0]` is the seed, then `x = f(x, l[i])`. It is the last element of `l ′f⍀`. An empty `l` is `GOLF: empty reduce` through `‹throw›` |
| `⍸` | `\eachi` | `l ′f -> l'` | map with the index: `l'[i]` is `f(l[i], i)`, counting from `0` |

```
5⍳1+′+⍀⍕                    ->  1 3 6 10 15
“31415“⊃48-′⌈⍀⍕             ->  3 3 4 4 5
3⍳′⍳€′⧺⍀⍕                   ->  [] [0] [0 0 1]
0⍳′+⍀≢Ṅ                     ->  0
5⍳1+′*⍁Ṅ                    ->  120
“31415“⊃48-′⌊⍁Ṅ             ->  1
1⍳7+′-⍁Ṅ                    ->  7
:f+;4⍳10*′f⍸⍕               ->  0 11 22 33
“abc“⊃′+⍸⊐                  ->  ace
:c+\\⊕\\;0 5⍳′c⍀⍕Ṅ           ->  0 1 3 6 10 4
:c+\\⊕\\;0 5⍳′c⍁ṄṄ           ->  104
:c+\\⊕\\;0 4⍳′c⍸⍕Ṅ           ->  0 2 4 6 4
:g⍳′+⍀∑+;5⍳′g⍀⍕             ->  0 0 1 5 15
:h′+⍸;3⍳′⍳€′h€⍕             ->  [] [0] [0 2]
0⍳′+⍁Ṅ                      ->  GOLF: empty reduce
```

The last one prints on stderr and exits 1; under `‹catch›` it gives back
`empty reduce`. In the counter lines `c` is `+\\⊕\\`: it bumps the `0` the
caller left under `acc x` (or under `x i`), so the count `4` is the number of
calls: `⍀` and `⍁` do not call `f` on the seed. `g` runs a scan inside the
scan's function, and `h` runs `⍸` inside `€`'s.

### Atoms as the function: fast paths (W13-G)

When the function given to `€ ⌿ ⇤ ⍁ ⍀ ⍸ ⊞` is one of these atoms, the word
runs the atom inline in its own loop, with no call per element:

| words | atoms |
|---|---|
| `⇤ ⍁ ⍀ ⍸ ⊞` (two operands) | `+ - * ⌈ ⌊`, and `∔ ∸ ⨰ ⩌ ⩍`, which they hook to |
| `€ ⌿` (one operand) | `⊕ ⊖ ± ² ⊗ ⊘` |

This changes nothing you can see except the time. The loop runs the same
atom on the same operands in the same order, so a list element still goes to
`∔` (or raises `not a number`) exactly as before, errors are the same and come
in the same order (`use after free`, `empty reduce`, `spill stack
exhausted`), and `‹heapstats›` is the same. An atom never touches the stack
under its operands, so threading is not affected either. The function is
recognised by its code: `′+`, S1's `+⇤`, and a word `:f+;`, whose body is
`′+`'s bytes, all count. Anything else, such as `:f1+;` or a `∘` or `⊸`
thunk, gets the ordinary call per element. Per element, on a list that stays
in cache: `0′+⇤` about 1.8 ns (4.1 before), `′⊕€` 2.1 (4.5), `′⌈⍀` 2.8
(4.9), `"′+⊞` 3.1 (5.6), `′±⌿` 1.5 (4.0). bench/RESULTS.md has the details
(W13-G).

```
5⍳′⊕€⍕                      ->  1 2 3 4 5
5⍳0′+⇤Ṅ                     ->  10
“31415“⊃48-′⌈⍀⍕             ->  3 3 4 4 5
5⍳"′*⊞⍕                     ->  0 1 4 9 16
6⍳′⊖⌿⍕                      ->  1
3⍳′⍳€"′+⊞⍕                  ->  [] [0] [0 2]
```

The last line takes the fast path too. Its elements are lists, so each `+`
hands them to `∔`, as the function call would have.
### Windows and fixpoints

W12-A5 and W12-A6 add two higher-order words. Both keep the threading
contract above: their function runs with the caller's stack underneath.

| word | stack effect | meaning |
|---|---|---|
| `⊟` | `l n ′f -> l'` | window reduce: `l'[i]` is `f` folded over the window `l[i] … l[i+n-1]` with no seed, `f(…f(l[i], l[i+1])…, l[i+n-1])`, so `≢l'` is `≢l-n+1`. `n = 1` copies `l` without calling `f`. `n > ≢l` (so any `n` on an empty list) gives the empty list. `n < 1` is `GOLF: window size < 1`. A freed `l` is `GOLF: use after free`. The result is a new list and `l` is unchanged |
| `⍣` | `x ′f -> y` | fixpoint (Jelly's `ÐL`): apply `f` until its result `≣` its argument, and leave that last result. `f` runs at least once. If `f` has no fixpoint from `x`, `⍣` never returns |

```
7⍳3′⌈⊟⍕                    ->  2 3 4 5 6
7⍳3′⌊⊟⍕                    ->  0 1 2 3 4
7⍳3′+⊟⍕                    ->  3 6 9 12 15
“31415926“⊃48-3′⌈⊟⍕        ->  4 4 5 9 9 9
5⍳1′+⊟⍕                    ->  0 1 2 3 4
5⍳9′+⊟≢Ṅ                   ->  0
3⍳4+′⍳€2′⧺⊟′∑€⍕            ->  16 25
:f+\\⊕\\;0 5⍳2′f⊟⍕Ṅ        ->  1 3 5 7 4
:d2/;100′d⍣Ṅ               ->  0
:h"≢1≻[^]1↓;5⍳′h⍣⍕         ->  4
:g\\⊕\\2/;0 100′g⍣ṄṄ       ->  08
```

- **`⊟` with `⌈` or `⌊` is O(≢l)**, whatever `n`: when `f` is `′⌈`, `′⌊`,
  `′⩌`, `′⩍`, or a word whose code is exactly that of `⌈` / `⌊` (`:m⌈;`),
  and no element of `l` is a list, `⊟` runs a monotonic deque instead of
  calling `f`. Any other `f` is called `n-1` times per window, so it costs
  O(≢l·n). Sliding-window maximum is `ℤ"1↓\\0⊇′⌈⊟⍕` (11 bytes; see "LeetCode in Golf" in section 4).
- **Threading.** `⊟`'s `f` gets `acc x`, as `⇤`'s does. The counter `f`
  above leaves `c+1` under the running sum, so the `4` printed last is the
  number of calls, `(n-1)·(≢l-n+1)`. `⍣`'s `f` gets just the value, and
  `g` counts its 8 calls (`100 50 25 12 6 3 1 0`, then `0` again).
- **`⍣` frees what it made.** Each intermediate value `⍣` got from `f`
  (never `x`, never the result) is given back with `⌫` once the next value has
  been computed and compared, so a long run holds two lists at a time, not
  all of them. It is kept when it is not a list, when `f` returned that same
  block (`f` may return its argument: that result `≣` itself, so `⍣` stops),
  or when `f`'s result is a list holding it as a direct element. So `f` must
  not `⌫` its argument, keep it in a variable, or nest it deeper than one level
  in its result. An `f` that changes its argument in place and returns it stops
  after one step.
- **`⍣` is O(n²) for rewrite-until-stable.** Each pass is a call of `f` plus
  one `≣`. Jelly's Valid Parentheses (delete every `()` until nothing changes)
  and Islands (flood one ring per pass) take up to n/2 passes over an input of
  size n: O(n²) in the worst case. A stack or a deque is O(n) there.

### Streams

A **stream** (W12-A8) hands out values one at a time, so a pipeline from
stdin to a result runs in constant memory. A stream is a small tagged list
`[step, free, state…]` on the heap. `⍞` (`0xDA`, `\next`) pulls one value:

| glyph | mnemonic | stack effect | meaning |
|---|---|---|---|
| `⍞` | `\next` | `s -> s x 0 \| s 1` | the next value `x` and `0`, or `1` when the stream has ended. The flag is zero-is-true, like `‹readline›`'s. An ended stream keeps answering `1`. `s` stays on the stack either way |

The other stream words have long names:

| word | stack effect | meaning |
|---|---|---|
| `‹sints›` | `-> s` | the integers on stdin, one per pull, read the same way as `‹ints›` (same whitespace, signs, `12ab` is 12, `x` is 0, overflow wraps). It parses straight out of the shared input buffer and leaves the buffer just past the number it returned, so `‹readline›`, `‹getc›` or `‹ints›` can carry on from there, and a pipeline that stops pulling reads no more input |
| `‹slines›` | `-> s` | the lines of stdin, as `‹readline›` returns them (a new code list each time, without the `\n`) |
| `‹sbytes›` | `-> s` | the bytes of stdin, `0`–`255`, as `‹getc›` returns them |
| `‹upto›` | `n -> s` | `0, 1, …, n-1`: a lazy `⍳` |
| `‹nat›` | `-> s` | `0, 1, 2, …` without end (it stops at `2^63-1`) |
| `‹stream›` | `l -> s` | the elements of the list `l`. The stream reads `l` in place and does not own it: keep `l` alive while the stream is in use |
| `‹smap›` | `s ′f -> s'` | `f x` for each `x` |
| `‹sfilter›` | `s ′p -> s'` | the `x` for which `p x` is `0`, like `⌿` |
| `‹sscan›` | `s ′f -> s'` | inclusive scan, like `⍀`: the first value, then `f(acc, x)` for each later one |
| `‹stake›` | `s n -> s'` | the first `n` values. After the `n`th it answers `1` without pulling `s` again, so `‹nat›n‹stake›` ends |
| `‹sdrop›` | `s n -> s'` | all but the first `n` values (skipped on the first pull) |
| `‹swhile›` | `s ′p -> s'` | the values up to the first one for which `p x` is not `0`. That one is dropped and the stream ends |
| `‹senum›` | `s ′f -> s'` | `f(x, i)` with `i` counting from `0`, like `⍸` |
| `‹szip›` | `s1 s2 ′f -> s'` | `f(a, b)` for each pair, until either stream ends |
| `‹swin›` | `s n -> s'` | the sliding windows of `n` values, from the `n`th value on. Each window is the stream's own list, shifted by one cell per value (O(n) a pull). It is valid until the next pull: copy it (`0↓`) to keep it, and do not `⌫` it. `n < 1` is `GOLF: window size` |
| `‹sfold›` | `s init ′f -> x` | fold, like `⇤`: `f(acc, x)` from `init` |
| `‹collect›` | `s -> l` | all the values as a new list |
| `‹sshow›` | `s ->` | print the values as `⍕` prints a list (an inner list as `[a b]`), each followed by a space |
| `‹sfind›` | `s ′p -> x 0 \| 1` | the first `x` for which `p x` is `0`, or `1` if there is none. It stops at the first hit and pulls nothing more |
| `‹sfree›` | `s ->` | free the stream and everything it owns |

```
5‹upto›‹collect›⍕                        ->  0 1 2 3 4
‹nat›′²‹smap›5‹stake›‹sshow›              ->  0 1 4 9 16
:p2∣;10‹upto›′p‹sfilter›‹sshow›           ->  0 2 4 6 8
“31415“⊃48-‹stream›′⌈‹sscan›‹sshow›       ->  3 3 4 4 5
‹nat›3‹sdrop›4‹stake›‹sshow›              ->  3 4 5 6
:p5≺1+;‹nat›′p‹swhile›‹sshow›             ->  0 1 2 3 4
“abc“⊃‹stream›′+‹senum›‹sshow›            ->  97 99 101
‹nat›5‹upto›′*‹szip›‹sshow›               ->  0 1 4 9 16
6‹upto›3‹swin›′∑‹smap›‹sshow›             ->  3 6 9 12
3‹upto›′⍳‹smap›‹sshow›                    ->  [] [0] [0 1]
10‹upto›0′+‹sfold›Ṅ                       ->  45
:p20≻1+;‹nat›′²‹smap›′p‹sfind›ṄṄ          ->  025
:p9≻1+;5‹upto›′p‹sfind›Ṅ                  ->  1
3‹upto›⍞_Ṅ⍞_Ṅ⍞_Ṅ⍞Ṅ‹sfree›                 ->  0121
:c\\⊕\\;0 5‹upto›′c‹smap›‹collect›⍕Ṅ       ->  0 1 2 3 4 5
:g+\\⊕\\;0 4‹upto›0′g‹sfold›ṄṄ             ->  64
‹heapstats›_→b 1000‹upto›9‹swin›′∑‹smap›0′+‹sfold›_‹heapstats›_←b-Ṅ  ->  0
5‹upto›"‹sfree›⍞                          ->  GOLF: use after free
```

On stdin:

```
‹sints›0′+‹sfold›Ṅ                       # printf '1 2 3' | ./sum    prints 6
‹slines›′≢‹smap›‹sshow›                  # the length of every line
:p10-;‹sbytes›′p‹sfilter›‹collect›≢Ṅ     # the number of newlines
:p\\&⌊\\&-;1 62≪‹sints›′p‹smap›0′⌈‹sfold›Ṅ_   # Stock: best x - min so far
```

- **Threading.** The function of `‹smap›`, `‹sfilter›`, `‹sscan›`,
  `‹swhile›`, `‹senum›`, `‹szip›`, `‹sfold›` and `‹sfind›` runs as `€`'s does
  (see "Threading state" above): with the stack of whoever called `⍞` or the
  sink underneath its arguments, so it may read and leave values there.
  Nothing a stream keeps is on the data stack while it runs: `⍞` and the
  sinks park the stream and the accumulator on the spill stack, one cell
  each. In the `c` line the counter under the pipeline ends at 5; in the `g`
  line `‹sfold›`'s function counts its 4 calls in the same way. The Stock
  line keeps the running minimum under the pipeline, and `p` turns each `x`
  into `x - min`.
- **Ownership.** A transformer owns the stream it was made from, and a sink
  owns the stream it is given. The sinks `‹sfold›`, `‹collect›`, `‹sshow›` and
  `‹sfind›` free the whole chain when they finish (`‹sfind›` too, after its
  hit). `‹sfree›` frees a stream you stop pulling by hand, with everything
  it owns: its upstream, recursively (both of `‹szip›`'s), and `‹swin›`'s
  window. `⌫` on a stream frees only its record. `‹stream›` does not own
  its list, and the lists `‹slines›` and the transformers hand out are the
  caller's (free them with `⌫` when done; `‹swin›`'s window is the exception
  above).
- **Constant memory.** A pull allocates nothing (except the list `‹slines›`
  returns and whatever the functions make). `‹sints›′⌊‹sscan›0′+‹sfold›`
  over 100M integers from a pipe keeps `‹heapstats›` within 8.5 KB of where it
  started, the input buffer included, and the process at 13 MB. 1M integers
  take about 70 ms (`‹ints›∑` takes about 55 ms and 16 MB).
- **Errors.** `⍞`, `‹sfree›` and the sinks check the record: a freed stream
  is `GOLF: use after free`, and so is a second `‹sfree›`. A throw inside a
  stream's function unwinds through `‹catch›` like one inside `€`, and the
  parked cells go with it. The stream is then not freed.
- Names that start with `‹_12a8` are these words' helpers.

### Closures

`⊸` (bind, W11-2C) makes a closure **by value**. `x ′f⊸` returns a new
quotation that pushes the `x` it captured and then calls `f`. Use it wherever
a quotation goes: `⍎ € ⇤ ⌿ ⊞`, or `∘` and `⊸` themselves.

| word | stack effect | meaning |
|---|---|---|
| `⊸` | `x ′f -> ′g` | `g` pushes `x`, then calls `f`. `x` is any 64-bit value, a list included. Since `x` lands above `g`'s own argument, `5′-⊸` is "subtract 5" (partial application of the right operand) |

The value is copied when `⊸` runs, so the variable it came from can change
afterwards. A word that reads a variable reads it at call time instead:

```
10→n ←n′+⊸→k 99→n 3⍳←k€⍕         ->  10 11 12
10→k :f←k+; 99→k 3⍳′f€⍕           ->  99 100 101
3⍳5′-⊸€⍕                          ->  -5 -4 -3
3⍳′⧺⊸→c 2⍳←c⍎⍕                    ->  0 1 0 1 2
:d⊗;3⍳10′+⊸′d∘€⍕                  ->  20 22 24
3 4′+⊸⊸⍎Ṅ                         ->  7
```

`⊸` builds its quotation like `∘` does: a 38-byte machine-code thunk
(`∘`'s are 39 bytes) in an ordinary heap block. Since W12-O2 there is no
limit on how many a program makes, and `⌫` gives one back: a thunk costs one
72-byte block in `‹heapstats›`, and freeing a thunk twice is `GOLF: double
free`. A composed or bound quotation is an int, not a list, to `T` and the
list words. Calling a thunk after it has been freed is not checked: it
usually dies with SIGSEGV, and if the block has been reused it runs whatever
is there. A quotation built from another one (`′f′g∘′h∘`, `x′f⊸⊸`) only
points at the inner one, so free the outer before the inner, and only when
neither is used again.

```
:f′⊕′⊗∘"⌫⌫;′f‹catch›⊐                          ->  double free
‹heapstats›→b_ 3′+⊸"4\\⍎Ṅ⌫ ‹heapstats›←b-Ṅ        ->  70
‹heapstats›_→n 0→i{′⊕′⊗∘⌫←i1+"→i100000<1+}‹heapstats›_←n-Ṅ  ->  0
```

The second example prints `7` and then `0`: the thunk was freed, so the
bytes in use are back where they were. The third makes and frees 100,000
compositions.

### Checked arithmetic

The bare `+ - *` (and `﹢ ﹣ ﹡`) wrap at 64 bits, silently. The checked words
(W11-3C) are Rust's `checked_add` / `checked_sub` / `checked_mul` turned into
errors: the exact signed result when it fits in 64 bits, otherwise
`GOLF: integer overflow` through `‹throw›` (exit 1; `′f‹catch›` catches it and
returns the message, like any other error: `:‹f›9223372036854775807 1‹cadd›;′‹f›‹catch›⊐`
prints `integer overflow` and the program goes on).

| word | stack effect | meaning |
|---|---|---|
| `‹cadd›` | `a b -> a+b` | signed add; overflow (`INT64_MAX 1`, `INT64_MIN -1`, …) throws `integer overflow` |
| `‹csub›` | `a b -> a-b` | signed subtract; overflow (`INT64_MIN 1`, `0 INT64_MIN`, …) throws `integer overflow` |
| `‹cmul›` | `a b -> a*b` | signed multiply; overflow (`-1 INT64_MIN`, `3037000500 3037000500`, …) throws `integer overflow`; `0` times anything is `0` |

They are **scalar only**: no shape test, no broadcasting. They work through
the raw atoms, so a number whose top 16 bits are `0x7FFF` (which the bare ops
would take for a list, see Known limits in `DESIGN.md`) is just a number here,
`INT64_MAX` included — and a list passed to them is likewise just its tagged
64-bit address, never an error. Map them over a list with `€` or `⊞`.
`INT64_MIN` is `1 63≪`; a negative is `n±`.

```
3 4‹cadd›Ṅ                                ->  7
1 63≪ 1‹cadd›Ṅ                            ->  -9223372036854775807
3 10‹csub›Ṅ                               ->  -7
3037000499"‹cmul›Ṅ                        ->  9223372030926249001
0 1 63≪‹cmul›Ṅ                            ->  0
9223372036854775807⊕Ṅ                     ->  -9223372036854775808
9223372036854775807 1‹cadd›Ṅ              ->  GOLF: integer overflow
1± 1 63≪‹cmul›Ṅ                           ->  GOLF: integer overflow
```

The last two exit with status 1 (the message is on stderr). The sixth shows
the bare increment wrapping. Overflow is found from the wrapped result `r`:
for `‹cadd›` when `(a^r)&(b^r)` is negative, for `‹csub›` when `(a^b)&(a^r)`
is, and for `‹cmul›` when `a≠0` and either `r÷a ≠ b` or `a = -1, b = INT64_MIN`
(the one case the divide test misses, since `÷` defines `INT64_MIN÷-1` as
`INT64_MIN`).

### Errors

A runtime error prints one line, `GOLF: <message>`, on stderr (fd 2) and exits
with status 1; stdout gets nothing more — unless a `‹catch›` is armed, in which
case the error comes back to it as a value. The prelude raises its errors
through one word, which a program may call too:

| word | stack effect | meaning |
|---|---|---|
| `‹throw›` | `msg ->` | raise an error whose message is the code list `msg`. With no `‹catch›` armed: print `GOLF: `, `msg` as text and a newline on fd 2, exit 1. Never returns |
| `‹catch›` | `… ′f -> … results 0` or `… msg` | run `f`. If it returns, push `0` above its results. If anything it runs throws, `‹catch›` returns at once with the message (a code list, never `0`) |

On the error path the data stack is put back to its depth at the `‹catch›`
call (`′f` dropped) and the message pushed on top: whatever `f` pushed is
discarded. Values below that depth that `f` did not touch are intact; a cell
`f` consumed holds whatever `f` last stored there (as with Forth's `CATCH`,
the depth is restored, not the contents), so keep anything you need after an
error out of `f`'s arguments, in a variable or below them. The return stack
is unwound too (the `⊡` frames of every word in between are dropped), and so
is the spill stack the list words nest on, so `€ ⇤ ⌿ ⍕ …` interrupted
mid-loop leave nothing behind and the caller's own loop state is restored.
Not undone: stores to variables and memory, allocations, and output — what
`f` printed before the error stays printed. Catches nest: an error goes to
the newest armed `‹catch›`; a handler that calls `‹throw›` again (a rethrow)
reaches the next one out, and one with none left prints and exits as usual.
`‹throw›` uses the atoms `⊷` (`-> sp bp`) and `⊶` (`sp bp ->`), which read and
set the two stack pointers.

```
:‹bad›3⍳9⊇;′‹bad›‹catch›⊐  ->  index out of range
:‹ok›5 6;1′‹ok›‹catch›ṄṄṄṄ  ->  0651
“oops“⊃′‹throw›‹catch›⊐  ->  oops
:‹f›1 2 3“no“⊃‹throw›;7′‹f›‹catch›⊐Ṅ  ->  no7
:‹in›“inner“⊃‹throw›;:‹out›′‹in›‹catch›⊐“outer“⊃‹throw›;′‹out›‹catch›⊐  ->  innerouter
:‹g›‹throw›;:‹h›“again“⊃′‹g›‹catch›‹throw›;′‹h›‹catch›⊐  ->  again
:‹d›7 0÷;′‹d›‹catch›⊐  ->  divide by zero
:‹r›1⍳′‹r›€;′‹r›‹catch›⊐ 3⍳′⍳€⍕  ->  spill stack exhausted[] [0] [0 1]
“no input“⊃‹throw›  ->  GOLF: no input
```

(The last line goes to stderr, with exit status 1.)

Everything the runtime checks raises through `‹throw›`, so all of it is
catchable: `⊇` (`index out of range`), `⌫` (`free of a non-heap value`,
`double free`), `⍅` and `‹pqpop›` (`pop from empty`), `‹get›` (`key
not found`), `‹cadd›` `‹csub›` `‹cmul›` (`integer overflow`, see Checked
arithmetic above), every list word (`use after free`, see Memory above), the file
words (`cannot open x.txt (ENOENT)` …), the spill stack (`spill stack
exhausted`, about 4000 nested list words deep) and the divisor check of `/ %
÷ ∣` (`divide by zero`). Not catchable: a return-stack overflow (a recursion
past ~138k plain calls dies of SIGSEGV on the guard page), any other signal,
`.` (exit is exit), and compile errors (`GOLF: undefined word x at line 3` …,
below), which exit 2. So does a program whose binary would pass 192 KB
(196608 bytes, the prelude's ~43 KB included): `GOLF: program too large`, and no binary.

### Compile errors

A compile error prints one line on stderr, exits with status 2, and writes no
binary. Since W11-3B the line says where the error is:

```
GOLF: undefined word b at line 3          # in the program
GOLF: undefined word ‹sq2› at geom.golfj line 7   # in an included file
```

The line is a line of **your** file. The compiler counts newlines as it reads,
per file: an included file starts at its line 1, and the includer's count
resumes after it. `tools/golfc` puts a form feed (byte 12) between the prelude
and the program, and a form feed between tokens restarts the count at line 1,
so the prelude's lines are not counted. (Feeding `golf2` by hand works the same
way: put `\f` after the prelude.) An included `.golfj` is named as its `⎘`
wrote it, not by the encoded copy `golfc` hands the compiler.

| message | when |
|---|---|
| `undefined word x at …` | a name was called (or quoted with `′`, or used as a chain link) and never defined. Reported at end of input, at the line of the **first** use |
| `bad long name ‹…› at …` | a byte that may not be in a long name, an empty `‹›`, a name over 60 bytes, or a missing `›` |
| `too many long names ‹…› at …` | the 1025th long name |
| `local out of range x at …` | `⇒`/`⇐` of a one-byte name outside `a`…`z` (outside `a`…`h` when not in a `⊡` word), or a long-named local outside a `⊡` word |
| `too many locals ‹…› at …` | a 17th local in one `⊡` word |
| `cannot include <path> at …` | a missing file, a path over 250 bytes, `⎘` without `“…“`, an unclosed path (the place is the `⎘`'s, in the includer) |
| `includes nested too deeply <path> at …` · `too many includes <path> at …` | a 9th level of nesting · a 61st file |
| `⋄ outside [ ] or { } at …` · `⋄ twice in one block at …` | a `⋄` with no `[` or `{` open (top level, the body of a word, after a `]`) · a second `⋄` in one `[ ]` or `{ }` (W12-A7) |
| `⇡ needs a variable at …` · `⇣ needs a variable at …` | a `⇡`/`⇣` not followed by a letter or a `‹long name›` (W12-Z2) |
| `program too large` | the binary would pass 192 KB. No place: it is the size of the whole image |

```
1Ṅ
5qṄ                  # stderr: GOLF: undefined word q at line 2   exit status 2
```

### REPL

`tools/golfi` (W11-4C) is an interactive loop: type a line of `.golfj`
source, see what it printed and then the data stack. Words, variables,
includes and the stack carry over from line to line. The stack line comes
from the prelude word `‹stack›`, which any program can call:

| word | stack effect | meaning |
|---|---|---|
| `‹stack›` | `->` | print the data stack bottom to top without changing it: `<depth>`, then each value (an int as `Ṅ` prints it, a list in brackets as `⍕` prints an inner one), then a newline |

```
1 2 3⍳‹stack›                    ->  <3> 1 2 [0 1 2]
‹stack›                          ->  <0>
3⍳′⍳€ 5±‹stack›                  ->  <2> [[] [0] [0 1]] -5
:‹s›9‹stack›_;1 2‹s›             ->  <3> 1 2 9
```

The data stack is the machine stack, and calls keep their return addresses
on a separate stack, so `‹stack›` shows the same values inside a word (the
last example), inside `€` (the element on top of the caller's values) or
under `‹catch›`. Its base is where the stack stood at the end of the
prelude's own start-up, recorded in cell 5180480. A value whose top 16 bits
are `0x7FFF` prints as a list (DESIGN.md, known limits).

A session (`golf> ` is the prompt; `....> ` continues an entry):

```text
golf> :‹sq›"*;
<0>
golf> 3 4
<2> 3 4
golf> ‹sq›+
<1> 19
golf> oops
GOLF: undefined word o
(not kept)
golf> 3⍳9⊇
GOLF: index out of range
(not kept)
golf> “sq: “🗲3⍳‹sq›∑Ṅ
sq: 5
<1> 19
golf> :f
....> 1+;
<1> 19
golf> f
<1> 20
golf> :quit
```

**How it works: replay.** golfi keeps the session, the entries accepted so
far. For each new entry it compiles one whole program with `tools/golfc -j`
(the session, a marker, the entry, a marker, `‹stack›`, an end marker), runs
it with stdin from `/dev/null`, and shows only what came after the first
marker. So every side effect of earlier entries runs again, silently, each
time (a slow entry slows all later ones; `:reset` starts over), and a program
that reads stdin sees end of input rather than waiting. Each entry takes
about 0.11 s (compile and run), nearly all of it in `golfc`.

An entry is kept only if it compiles, runs, exits 0 and reaches the end
marker, so the session is always a valid program. An entry that fails
prints the compiler's or the runtime's `GOLF:` line (` at line N` is
dropped for a one-line entry, or given as `at line K of this entry`), or
`killed by SIGSEGV`, `exit status N`, `timed out after 10 s`
(`GOLFI_TIMEOUT`), and then `(not kept)`.

An entry spans lines while a `:` `⊡` `⊚` `⊜` definition, a `[` or `{`, or a
`“` string is still open. Commands, as a whole line: `:show` prints the
session's source, `:reset` empties it, `:quit` (or end of input) leaves.
`golfi -t` adds each entry's time as `(0.110 s)`. Prompts appear only on a
terminal and everything goes to stdout, so `golfi < script` gives a clean,
ordered transcript (test/run2.sh's W11-4C block checks one).

### Debugging

`tools/golfc -g prog.golfj prog` (with `-j`, `-n` as usual) also writes
**`prog.map`**, the symbol map: one line per defined word,

```
NAME 0xADDR
```

NAME is the word as source spells it: a glyph (`⌫`), an ASCII byte (`f`) or a
long name with its brackets (`‹sq›`). ADDR is the runtime virtual address of
the word's body in hex, where a `call` to the word lands. The program is one
`PT_LOAD` at `0x400000`, so the body's file offset is ADDR - `0x400000`. Lines
come in name-number order: one-byte names by byte value, then long names in
order of first appearance. The prelude's words are listed too, and a word
defined twice shows its last body. The binary is byte-identical with and
without `-g`. The map comes from `golf2 -g`, which writes it to stderr after a
successful compile, with one-byte names as raw bytes (`golfc` turns them into
glyphs).

```
:‹sq›"*;:f‹sq›;5fṄ   # prog.map has, among the prelude's words:
                     #   f 0x40…       (its address)
                     #   ‹sq› 0x40…    (and ‹sq›'s, where f's call lands)
```

Every word body starts with the same prologue (`sub rbp,8; pop [rbp]`, bytes
`48 83 ED 08 8F 45 00`), so a map line is easy to check against the binary.

**gdb by word name (W11-4D).** A GOLF binary has no symbols, and its stacks
are not C's: `rsp` is the data stack and `rbp` the return stack (the prologue
parks each call's return address at `[rbp]`), so gdb's own `break NAME` and
`bt` see nothing. `tools/golfgdb prog [args…]` reads `prog.map` and the
binary, writes a gdb script, and starts `gdb -q -x script --args prog args…`.
The script adds five commands, and prints `golf-where` at every stop:

| Command | What it does |
|---|---|
| `golf-break NAME…` | break in each word just after its prologue, so its arguments are on the data stack. NAME as the map spells it (`⌫`, `f`, `‹sq›`), or a long name without brackets (`sq`) |
| `golf-bt` | backtrace by word name, innermost first: `#0` is the word `$pc` is in, then one frame per return address on the return stack (rbp up to its top, `0x600000`) |
| `golf-stack [N]` | the data-stack depth and the top N cells (default 8), top first; a list shows as `list @addr len n [elements…]` |
| `golf-where` | the word `$pc` is in, as `NAME+offset` |
| `golf-words [TEXT]` | the map's words (names containing TEXT) with their address ranges |

A word's range comes from the `jmp` that skips its body (`E9 rel32` just
before ADDR); code in no word is `(top level)`, code on the heap (a `∘` or `⊸` thunk)
`(thunk)`. A return-stack cell counts as a return address only when the bytes
before it are a `call`, so `⊡` locals (which share the return stack) are
skipped. Plain gdb still works alongside: `stepi`, `x/8gx $rsp`,
`break *0x…`, `info registers` (and `golf-bt` / `golf-stack` are right even
when stopped inside a prologue). `tools/golfgdb --emit FILE prog` only writes
the script (use it with `gdb -x FILE prog`); `--batch-script CMDS prog` runs
`gdb -batch` with the script and then the commands in CMDS, which is how the
suite tests it. It needs gdb with Python (any distribution gdb).

Walkthrough: a word reached through two nested calls.

```
# deb.golfj
:‹inner›"*;
:‹mid›1+‹inner›;
:‹outer›‹mid›2*;
5‹outer›Ṅ
```

```
$ tools/golfc -j -g deb.golfj deb && tools/golfgdb deb
(gdb) golf-break inner
Breakpoint 1 at 0x40a32e
golf-break: inner at 0x40a32e
(gdb) run
Starting program: /home/me/deb

Breakpoint 1, 0x000000000040a32e in ?? ()
golf: 0x40a32e in ‹inner›+7
(gdb) golf-bt
#0  0x40a32e in ‹inner›+7
#1  0x40a3a7 in ‹mid›+60
#2  0x40a3c0 in ‹outer›+12
#3  0x40a404 in (top level)
(gdb) golf-stack
data stack: depth 1
  [0] 6
(gdb) continue
Continuing.
72[Inferior 1 (process 4242) exited normally]
```

`‹inner›` was called by `‹mid›`, called by `‹outer›`, called from the
program's top level, and is about to square the 6 that `‹mid›` left (5 1+);
`‹outer›` doubles the 36. The addresses move whenever the prelude changes
(the suite compares this transcript with them masked).

### Testing

Two prelude words check values (W11-4B), and `tools/golftest` runs test files.

| word | stack effect | meaning |
|---|---|---|
| `‹assert›` | `f msg ->` | passes when `f` is exactly `-1`, the "true" that the comparisons `≡ ≣ ≺ ≻ < »` push, so `a b≡“msg“⊃‹assert›` says what it checks. **Every other value fails**: `0`, and also `1` and any zero-is-true flag (`∊ ‹has› ‹startswith› T`, a difference `a b-`), so a flag of the other convention can never pass by accident. Turn one into a `-1` first with `0≡`: `l x∊0≡“has x“⊃‹assert›` |
| `‹expect›` | `actual expected msg ->` | passes when `actual ≣ expected` (structural equality, so ints, lists and nested lists alike) |

`msg` is a code list, `“text“⊃` (plain ASCII: a glyph inside `“…“` is
encoded to its byte). A check that passes prints nothing. One that fails
prints one line through the buffered printers, so on stdout and in order with
the program's own output:

```
FAIL: <msg>                              ‹assert›
FAIL: <msg>: expected <e> got <a>        ‹expect›
```

where an int shows as `Ṅ` prints it and a list as `[0 1 2]` (`⍕`'s elements in
brackets, nested lists as `⍕` shows them, no trailing space; `[]` when empty).
Then the program **carries on**: every check in a file runs. The failures are
counted in the cell `0x4F0C00` (`5180416⊙` reads it), and once one has failed
the program's **exit status becomes 1**: the end of the program exits 1
instead of 0, and an explicit `0.` exits 1 too (any other `.` status is kept;
an uncaught error still exits 1). There is no closing word to call. (How: the
first failure wraps the output-flush hook that every exit runs, W11-1C, in a
word that flushes and then turns the exit status 0 into 1.)

There are no line numbers: the compiler's line count exists only at compile
time, so **the message is the check's name** — make each one distinct.

```
1 1≡“one is one“⊃‹assert›“ok“⊃⊐  ->  ok
1 2≡“one is two“⊃‹assert›  ->  FAIL: one is two
0“zero is not true here“⊃‹assert›  ->  FAIL: zero is not true here
5⍳3∊0≡“3 in 0..4“⊃‹assert›“ok“⊃⊐  ->  ok
3⍳⌽ 3⍳“reversed“⊃‹expect›  ->  FAIL: reversed: expected [0 1 2] got [2 1 0]
6 7“six“⊃‹expect›  ->  FAIL: six: expected 7 got 6
2⍳′⍳€ 0⍳“nested“⊃‹expect›  ->  FAIL: nested: expected [] got [[] [0]]
2 3≺“signed less“⊃‹assert›“ok“⊃⊐  ->  ok
```

Each example that prints `FAIL:` exits with status 1. A program that goes on
after a failure keeps printing: `1 2≡“a“⊃‹assert›“still here“⊃⊐␤5180416⊙Ṅ`
prints `FAIL: a`, `still here` and `1` on three lines, and exits 1.

**`tools/golftest [DIR|FILE …]`** finds every `*_test.golfj` under each DIR
(recursively; the current directory when no argument is given) plus each FILE
named, compiles each with `tools/golfc -j` from the current directory (so `⎘`
includes resolve as usual), runs it with stdin from `/dev/null`, and prints
one line per file, then a summary:

```
PASS examples/tests/lists_test.golfj
FAIL test/fixtures/golftest/fail_test.golfj (exit 1)
  FAIL: one is two
  FAIL: reverse is identity: expected [0 1 2] got [2 1 0]
  FAIL: six: expected 7 got 6
1 passed, 1 failed
```

A file fails when it does not compile (`FAIL f (compile error)` and the
compiler's message, e.g. `GOLF: undefined word q at line 2`), when it exits
non-zero (`FAIL f (exit N)`, then its `FAIL:` lines and its stderr, such as a
`GOLF:` runtime error), when it prints a line starting `FAIL: ` even with exit
0, or when it runs past `GOLFTEST_TIMEOUT` seconds (default 60; `FAIL f
(timeout)`). `golftest` exits 0 when every file passed and 1 when any failed
or none was found. A test file is an ordinary program: it may define words,
`⎘` the code under test, and print.

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

**9. Recursion with locals.** A `⊡` word gets private locals (`a`–`z` or long
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

### LeetCode in Golf

Here are three of the ten problems in `bench/leetcode/`, in the form the
benchmark runs (its README has all ten and the timings). Each one reads its
input from stdin: `tools/golfc -j ex.golfj ex && ./ex < input`. The `stdin`
block is a sample input and the `text` block is the exact output.
`test/run2.sh` (block W12-O5) checks both. It also checks that each program
here is the same text as its file in `bench/leetcode/golf/`.

<!-- LEETCODE BEGIN -->

**Best Time to Buy and Sell Stock (121), `stock.golfj`, 10 bytes.** Buy on one
day and sell on a later one, for the largest profit, or 0. `ℤ` reads the
prices. `"′⌊⍀` keeps them and makes the running minimum, the cheapest buy up
to each day. `-` subtracts it from every price, which gives the profit of
selling on that day, and `′⌈⍁` takes the largest. The first difference is
always `0`, so a falling market prints `0`.

```golfj
ℤ"′⌊⍀-′⌈⍁Ṅ
```

```stdin
7 1 5 3 6 4
```

```text
5
```

**Trapping Rain Water (42), `trap.golfj`, 16 bytes.** The water over a bar is
the lower of the highest bar to its left and the highest bar to its right,
less its own height. `"′⌈⍀` is the running maximum from the left. `&⌽′⌈⍀⌽`
reverses the heights, scans them and reverses back, which gives the running
maximum from the right. `⌊` takes the smaller of the two at each bar, `\\-`
subtracts the heights, and `∑` adds up the water. Both maxima include the bar
itself, so no term is negative.

```golfj
ℤ"′⌈⍀&⌽′⌈⍀⌽⌊\\-∑Ṅ
```

```stdin
0 1 0 2 1 0 1 3 2 1 2 1
```

```text
6
```

**Sliding Window Maximum (239), `slidemax.golfj`, 11 bytes.** The input is
the window size `k`, then the numbers. `"1↓` copies the list without its
first element, and `\\0⊇` takes `k` from the original. `′⌈⊟` is the window
reduce, the maximum of every window of `k` numbers. With `⌈` (or `⌊`), `⊟`
runs a monotonic deque, so it is O(n) for any `k`.

```golfj
ℤ"1↓\\0⊇′⌈⊟⍕
```

```stdin
3
1 3 -1 -3 5 3 6 7
```

```text
3 3 5 5 6 7
```

<!-- LEETCODE END -->
