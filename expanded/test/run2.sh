#!/usr/bin/env bash
# Expanded GOLF (v2) test suite + bootstrap ladder.
#
#   golf0.py  --compiles-->  v1c      (the frozen minimal compiler)
#   v1c       --compiles-->  seed     ; self/seed.golf,  compiler logic in v1 GOLF
#   seed      --compiles-->  golf2    ; self/golf2.golf, compiler logic in v2 GOLF
#   golf2     --compiles-->  golf2'   ; same source — require golf2 == golf2'
#   golf2'    --compiles-->  examples using the new operators
#
# Since M-SELF the compiler's logic is written in v2 GOLF (self/golf2.golfj,
# encoded into self/golf2.golf), so the last rung is a TRUE self-hosting
# fixpoint: golf2 compiles its own source back to itself, byte for byte.
#
# self/seed.golf is the bootstrap rung and nothing more. It carries the same
# compiler in v1 GOLF, purely so v1c — which has never heard of v2 — can build
# something able to compile golf2.golf. Because v1c embeds *v1's* template blob
# it emits different bytes than golf2 would, but that divergence stops there:
# `seed` is only ever used to produce golf2, and is never compared against
# anything. Hence no "seed-stable" line any more — there is nothing to report.
#
# The gate is golf2 == golf2': both are built from self/golf2.golf, embed the
# same blob, and emit the same code for the same source, so iterate 1 of the
# self-hosted compiler has already converged.
set -u
cd "$(dirname "$0")/.."
EXP=$(pwd); MIN="$EXP/../minimal"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "Regenerate the generated compiler sources (self/seed.golf, self/golf2.golf)"
python3 tools/mkblob2.py 2>&1 | sed 's/^/  /'

echo "Bootstrap ladder"
python3 "$MIN/boot/golf0.py" < "$MIN/self/golf.golf" > "$TMP/v1c" 2>/dev/null && chmod +x "$TMP/v1c" \
  && ok "build v1c (minimal compiler)" || no "build v1c"
"$TMP/v1c" < self/seed.golf > "$TMP/seed" 2>/dev/null && chmod +x "$TMP/seed" \
  && ok "v1c compiles self/seed.golf -> seed" || no "v1c compiles seed.golf"
# The rung M-SELF bought: the compiler's own logic, written in v2 GOLF, built by
# the bootstrap seed.
"$TMP/seed" < self/golf2.golf > "$TMP/golf2" 2>/dev/null && chmod +x "$TMP/golf2" \
  && [ -s "$TMP/golf2" ] && ok "seed compiles self/golf2.golf -> golf2" || no "seed compiles golf2.golf"
"$TMP/golf2" < self/golf2.golf > "$TMP/golf2p" 2>/dev/null && chmod +x "$TMP/golf2p"
cmp -s "$TMP/golf2" "$TMP/golf2p" \
  && ok "golf2 self-hosts (fixpoint: golf2 == golf2')" || no "golf2 fixpoint (golf2 == golf2')"
# Everything below this line exercises the converged self-hosted compiler.
cp -f "$TMP/golf2p" "$TMP/golf2"

echo "The v2 compiler still handles all of v1"
"$TMP/golf2" < "$MIN/examples/hello.golf" > "$TMP/h" 2>/dev/null && chmod +x "$TMP/h"
[ "$("$TMP/h" 2>/dev/null)" = "Hello, world!" ] && ok "golf2 compiles v1 hello.golf" || no "golf2 hello"
"$TMP/golf2" < "$MIN/examples/fizzbuzz.golf" > "$TMP/fb" 2>/dev/null && chmod +x "$TMP/fb"
[ "$("$TMP/fb" 2>/dev/null | sed -n '15p')" = "FizzBuzz" ] && ok "golf2 compiles v1 fizzbuzz.golf" || no "golf2 fizzbuzz"

echo "New operators (Milestone 1): \$ AND | OR = XOR ~ NOT > SHR"
run(){ "$TMP/golf2" > "$TMP/p" 2>/dev/null && chmod +x "$TMP/p" && "$TMP/p"; }
[ "$(printf '%s' '12 10$48+)' | run)" = "8" ] && ok "AND" || no "AND"
[ "$(printf '%s' '13 10=48+)' | run)" = "7" ] && ok "XOR" || no "XOR"
[ "$(printf '%s' '4 1|48+)'   | run)" = "5" ] && ok "OR"  || no "OR"
[ "$(printf '%s' '40 3>48+)'  | run)" = "5" ] && ok "SHR" || no "SHR"
[ "$(printf '%s' '0~1+48+)'   | run)" = "0" ] && ok "NOT" || no "NOT"
"$TMP/golf2" < examples/bitwise.g2 > "$TMP/bw" 2>/dev/null && chmod +x "$TMP/bw"
[ "$("$TMP/bw" 2>/dev/null)" = "87550" ] && ok "examples/bitwise.g2 -> 87550" || no "bitwise.g2"

echo "Code page (Jelly-style byte<->glyph): ± neg ⊕ inc ⊖ dec ² sqr ⊗ dbl ⊘ hlv"
atom(){ python3 tools/codepage.py encode | "$TMP/golf2" > "$TMP/p" 2>/dev/null && chmod +x "$TMP/p" && "$TMP/p"; }
[ "$(printf '%s' '3\sqr48+)'        | atom)" = "9" ] && ok "atom sqr"     || no "atom sqr"
[ "$(printf '%s' '2\dbl48+)'        | atom)" = "4" ] && ok "atom dbl"     || no "atom dbl"
[ "$(printf '%s' '9\hlv48+)'        | atom)" = "4" ] && ok "atom hlv"     || no "atom hlv"
[ "$(printf '%s' '5\neg\inc\neg48+)'| atom)" = "4" ] && ok "atoms neg/inc/dec" || no "atoms neg/inc"
python3 tools/codepage.py encode < examples/atoms.golfj > "$TMP/atoms.gb" 2>/dev/null \
  && ok "encode examples/atoms.golfj" || no "encode atoms.golfj"
"$TMP/golf2" < "$TMP/atoms.gb" > "$TMP/atoms" 2>/dev/null && chmod +x "$TMP/atoms"
[ "$("$TMP/atoms" 2>/dev/null)" = "957444" ] && ok "code-page program compiles -> 957444" || no "code-page program"
python3 tools/codepage.py decode -m < "$TMP/atoms.gb" | python3 tools/codepage.py encode \
  | cmp -s - "$TMP/atoms.gb" && ok "code page round-trips exactly" || no "code page round-trip"

echo "Grown atom set: » gt ≡ eq ⌈ max ⌊ min ÷ sdv ∣ smd"
[ "$(printf '%s' '7 3\gt1+48+)' | atom)" = "0" ] && ok "gt"  || no "gt"
[ "$(printf '%s' '5 5\eq1+48+)' | atom)" = "0" ] && ok "eq"  || no "eq"
[ "$(printf '%s' '4 9\max48+)'  | atom)" = "9" ] && ok "max" || no "max"
[ "$(printf '%s' '4 9\min48+)'  | atom)" = "4" ] && ok "min" || no "min"
[ "$(printf '%s' '17 5\sdv48+)' | atom)" = "3" ] && ok "sdv" || no "sdv"
[ "$(printf '%s' '17 5\smd48+)' | atom)" = "2" ] && ok "smd" || no "smd"

echo "Raw scalar atoms (prelude-internal, never polymorphic): ﹢ ﹣ ﹡ ⊓ ⊔ ﹤"
[ "$(printf '%s' '3 4\radd48+)'   | atom)" = "7" ] && ok "radd" || no "radd"
[ "$(printf '%s' '9 4\rsub48+)'   | atom)" = "5" ] && ok "rsub" || no "rsub"
[ "$(printf '%s' '2 3\rmul48+)'   | atom)" = "6" ] && ok "rmul" || no "rmul"
[ "$(printf '%s' '4 9\rmin48+)'   | atom)" = "4" ] && ok "rmin" || no "rmin"
[ "$(printf '%s' '4 9\rmax48+)'   | atom)" = "9" ] && ok "rmax" || no "rmax"
[ "$(printf '%s' '3 4\rlt1+48+)'  | atom)" = "0" ] && ok "rlt"  || no "rlt"

# @@ W1-M4ATOMS @@
echo "M4 atoms: ≺ slt ≻ sgt (signed compare), ≪ shl ≫ sar, ⊙ fetch ⊛ store (64-bit)"
# slt/sgt are where signed differs from unsigned: -5 <s 3 is true, but as u64
# -5 is huge so v1's `<` would say false (and print 1 instead of 0).
[ "$(printf '%s' '0 5-3\slt1+48+)'   | atom)" = "0" ] && ok "slt (-5 <s 3)"  || no "slt"
[ "$(printf '%s' '3 0 5-\sgt1+48+)'  | atom)" = "0" ] && ok "sgt (3 >s -5)"  || no "sgt"
[ "$(printf '%s' '1 3\shl48+)'       | atom)" = "8" ] && ok "shl (1<<3)"     || no "shl"
[ "$(printf '%s' '16 2\sar48+)'      | atom)" = "4" ] && ok "sar (16>>2)"    || no "sar"
[ "$(printf '%s' '0 8-1\sar 6+48+)'  | atom)" = "2" ] && ok "sar (-8>>1=-4)" || no "sar negative"
# -1 >>a 63 is -1; an unsigned shr would give 1 and print 2 instead of 0.
[ "$(printf '%s' '0 1-63\sar1+48+)'  | atom)" = "0" ] && ok "sar keeps the sign bit" || no "sar sign"
# 64-bit cell round-trip through free scratch 0x4F0048 (REGISTRY.md §3).  Not
# 0x4F0040 any more: W8 gave that cell to the entry-`rsp` stash.
[ "$(printf '%s' '7 5177416\store 5177416\fetch48+)' | atom)" = "7" ] \
  && ok "store + fetch (64-bit cell round-trip)" || no "store/fetch"

echo "Quotations: ′ ref (push a word's address), ⍎ exec (indirect call)"
[ "$(printf '%s' ':d\dbl;3\refd\exec48+)' | atom)" = "6" ] && ok "ref + exec (′word)" || no "ref/exec"
[ "$(printf '%s' '3 4\ref+\exec48+)' | atom)" = "7" ] && ok "ref + exec (′atom, auto-wrapped)" || no "ref atom"

echo "List type (prelude library): A alloc R range L len I index S sum N num M map F fold Q print"
python3 tools/codepage.py encode < lib/prelude.golfj > "$TMP/pre.gb"    # encoded prelude
gc(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/p" 2>/dev/null \
        && chmod +x "$TMP/p" && "$TMP/p"; }
[ "$(printf '%s' '5R L N E'    | gc)" = "5" ]    && ok "range + len"       || no "range/len"
[ "$(printf '%s' '10R 4 I N E' | gc)" = "4" ]    && ok "index"             || no "index"
[ "$(printf '%s' '100R S N E'  | gc)" = "4950" ] && ok "sum of range(100)"  || no "sum range"
[ "$(printf '%s' '12345N E'    | gc)" = "12345" ]&& ok "decimal printer"   || no "printer"
[ "$(printf '%s' '5R\ref\dblMSNE'      | gc)" = "20" ] && ok "map (′atom double, sum)" || no "map"
[ "$(printf '%s' '6R 0\ref\maxFNE'     | gc)" = "5" ]  && ok "fold (′atom max)"  || no "fold"
[ "$(printf '%s' ':d\dbl;5R\refdMQE'   | gc)" = "0 2 4 6 8 " ] && ok "map (′word) + print" || no "map/print"
[ "$(printf '%s' ':i\inc;4R\refiMPNE'  | gc)" = "24" ]  && ok "product"  || no "product"
[ "$(printf '%s' '5RVQE'               | gc)" = "4 3 2 1 0 " ] && ok "reverse" || no "reverse"
[ "$(printf '%s' ':e2%;10R\refeWSNE'   | gc)" = "20" ]  && ok "filter (even, sum)" || no "filter"
tools/golfc -j examples/lists.golfj "$TMP/lists" 2>/dev/null
[ "$("$TMP/lists" 2>/dev/null)" = "$(printf '4950\n20\n5')" ] && ok "golfc examples/lists.golfj" || no "lists.golfj"

echo "Strings (M5): “...“ literal, O puts, U chars->list, J join; list ops reuse"
[ "$(printf '%s' '“Hello, world!“O'    | gc)" = "Hello, world!" ] && ok "string literal + puts" || no "puts"
[ "$(printf '%s' '“abcde“@N'           | gc)" = "5" ]        && ok "string length via @"  || no "str len"
[ "$(printf '%s' '“stressed“UVJ'       | gc)" = "desserts" ] && ok "reverse via list ops"  || no "str reverse"
[ "$(printf '%s' ':k\inc;“abc“U\refkMJ'| gc)" = "bcd" ]      && ok "map over a string"     || no "map str"
tools/golfc -j examples/strings.golfj "$TMP/str" 2>/dev/null
[ "$("$TMP/str" 2>/dev/null)" = "$(printf 'Hello, world!\ndesserts\nIfmmp')" ] && ok "golfc examples/strings.golfj" || no "strings.golfj"

echo "Named variables (M3): →x store, ←x load (global name-indexed bank)"
[ "$(printf '%s' '5→a3→b←a←b-48+)'      | atom)" = "2" ]  && ok "store / load"    || no "vars"
[ "$(printf '%s' '1→a2→b←b48+)←a48+)'   | atom)" = "21" ] && ok "swap via vars"   || no "vars swap"
[ "$(printf '%s' '7→a3→b←a←b+←a←b-*N10)'| gc)"   = "40" ] && ok "(a+b)*(a-b), no juggling" || no "vars expr"
tools/golfc -j examples/vars.golfj "$TMP/vars" 2>/dev/null
[ "$("$TMP/vars" 2>/dev/null)" = "40" ] && ok "golfc examples/vars.golfj" || no "vars.golfj"

echo "Reference oracle (boot/golfref.py): Python v2 compiler, differential check"
oracle(){ cat <(python3 tools/codepage.py encode < lib/prelude.golfj) \
              <(python3 tools/codepage.py encode < "examples/$1.golfj") \
            | python3 boot/golfref.py > "$TMP/o$1" 2>/dev/null \
            && chmod +x "$TMP/o$1" && "$TMP/o$1" 2>/dev/null; }
[ "$(oracle lists)" = "$(printf '4950\n20\n5')" ] \
  && ok "oracle: lists.golfj behaves identically"     || no "oracle lists.golfj"
[ "$(oracle vars)"  = "40" ] \
  && ok "oracle: vars.golfj behaves identically"      || no "oracle vars.golfj"
[ "$(oracle strings)" = "$(printf 'Hello, world!\ndesserts\nIfmmp')" ] \
  && ok "oracle: strings.golfj behaves identically"   || no "oracle strings.golfj"
# vectorize.golfj says the same three programs twice — the explicit ⊞/closure
# half, then the M-VEC bare-operator half — so its output is those three lines
# repeated.  Any divergence between the halves shows up here as a diff.
VECOUT=$(printf '0 2 4 6 8 \n14\n10 11 12 13 14 \n0 2 4 6 8 \n14\n10 11 12 13 14 ')
[ "$(oracle vectorize)" = "$VECOUT" ] \
  && ok "oracle: vectorize.golfj behaves identically" || no "oracle vectorize.golfj"

echo "Vectorization (M-JELLY slice): ⊞ zip (elementwise), broadcast via closures"
[ "$(printf '%s' '5R5R\ref+ZSNE'      | gc)" = "20" ] && ok "zip (′atom +) then sum" || no "zip"
[ "$(printf '%s' '4R4R\ref*ZSNE'      | gc)" = "14" ] && ok "dot product (′atom *)" || no "dot"
[ "$(printf '%s' '10→k:f←k+;5R′fMQE' | gc)" = "10 11 12 13 14 " ] && ok "broadcast (closure)" || no "broadcast"
tools/golfc -j examples/vectorize.golfj "$TMP/vec" 2>/dev/null
[ "$("$TMP/vec" 2>/dev/null)" = "$VECOUT" ] && ok "golfc examples/vectorize.golfj" || no "vectorize.golfj"
# The point of the file: the two halves are the same programs, so the first three
# printed lines and the last three must be equal.
VECHALF=$("$TMP/vec" 2>/dev/null | head -3)
[ -n "$VECHALF" ] && [ "$VECHALF" = "$("$TMP/vec" 2>/dev/null | tail -3)" ] \
  && ok "vectorize.golfj: the bare operators agree with ⊞ and the closure" || no "vectorize halves agree"

# Insertion anchors: each wave adds its tests directly under its own anchor, so
# concurrent waves never touch the same line. Comment-only; keep them in order.

# @@ W1-SOUND @@
echo "Totality (M-SOUND): every list word is correct on empty input; re-entrant scratch"
[ "$(printf '%s' '0R S N'          | gc)" = "0" ]    && ok "sum of the empty list"        || no "empty sum"
[ "$(printf '%s' '0R L N'          | gc)" = "0" ]    && ok "len of the empty list"        || no "empty len"
[ "$(printf '%s' '0R\ref\dblML N'  | gc)" = "0" ]    && ok "map over the empty list"      || no "empty map"
[ "$(printf '%s' ':e2%;0R\refeWL N'| gc)" = "0" ]    && ok "filter over the empty list"   || no "empty filter"
[ "$(printf '%s' '0RVL N'          | gc)" = "0" ]    && ok "reverse of the empty list"    || no "empty reverse"
[ "$(printf '%s' '\str\str UL N'   | gc)" = "0" ]    && ok "chars of the empty string"    || no "empty chars"
[ "$(printf '%s' '3R5R\ref+ZL N'   | gc)" = "3" ]    && ok "zip truncates to the shorter list" || no "zip min length"
[ "$(printf '%s' '5R3R\ref+ZQ'     | gc)" = "0 2 4 " ] && ok "zip never reads past the shorter list" || no "zip overread"
[ "$(printf '%s' ':g3RS;5R\refgMQE'| gc)" = "3 3 3 3 3 " ] && ok "re-entrant scratch (mapped fn calls range+sum)" || no "nested HOF"
[ "$(printf '%s' '100R S N'        | gc)" = "4950" ] && ok "regression: sum of range(100)" || no "regression sum"

# @@ W2-TAG @@
echo "Shape polymorphism (M-TAG): T shape test, D dispatcher, ∔ ∸ ⨰ ⩍ ⩌"
# The heap bounds are runtime cells (0x4F0034 base, 0x4F0038 span), set by the
# prelude's top-level init.  W6B/M-MEM made that init ask the kernel (`0⌸`), so
# the base is the ASLR-shifted program break and cannot be spelled out here; what
# is still checkable — and is the property this test always meant — is that the
# heap lies above everything statically addressed, i.e. above the BSS top, which
# M-MEM shrank from 0xC00000 to 0x600000.  W6B's own block checks the rest.
[ "$(printf '%s' '5177396@ 6291456\rlt1\radd N E' | gc)" = "1" ] \
  && ok "heap-bounds cells initialized (base above the 0x600000 BSS top)" || no "heap bounds cells"
[ "$(printf '%s' '5R T N E'  | gc)" = "0" ] && ok "T: a heap address is a list" || no "T list"
[ "$(printf '%s' '7 T N E'   | gc)" = "1" ] && ok "T: a small int is an int"    || no "T int"
# The one that would break a naive signed test: -1 is 0xFFFF… , above the heap.
[ "$(printf '%s' '0 1-T N E' | gc)" = "1" ] && ok "T: a -1 compare flag is an int" || no "T flag"
[ "$(printf '%s' '3 4\vadd N E'    | gc)" = "7" ]  && ok "∔ int,int  (fn applied directly)" || no "vadd int,int"
# D must be TRANSPARENT for scalars — M-VEC routes the bare + through it, so an
# int,int ∔ has to equal an int,int +, bit for bit.  D never parks a or b in
# 32-bit scratch, so -1 stays -1: had it, @ would zero-extend to 4294967295 and
# this would print 4294967300 rather than 4.
[ "$(printf '%s' '0 1- 5\vadd N E' | gc)" = "$(printf '%s' '0 1- 5+N E' | gc)" ] \
  && ok "∔ int,int is bit-identical to + (operands keep 64 bits)" || no "vadd width"
[ "$(printf '%s' '4R4R\vmul S N E' | gc)" = "14" ] && ok "⨰ list,list (via Z: dot product)" || no "vmul list,list"
[ "$(printf '%s' '5R10\vadd Q E'   | gc)" = "10 11 12 13 14 " ] && ok "∔ list,int (via K)" || no "vadd list,int"
[ "$(printf '%s' '3 5R\vadd S N E' | gc)" = "25" ] && ok "∔ int,list (via G)" || no "vadd int,list"
# K and G are separate words because fn need not commute: 10 ∸ ⍳3, not ⍳3 ∸ 10.
[ "$(printf '%s' '10 3R\vsub Q E'  | gc)" = "10 9 8 " ]   && ok "∸ int,list keeps the operand order" || no "vsub int,list"
[ "$(printf '%s' '5R2\vmin Q E'    | gc)" = "0 1 2 2 2 " ] && ok "⩍ list,int" || no "vmin list,int"
[ "$(printf '%s' '1 3R\vmax Q E'   | gc)" = "1 1 2 " ]     && ok "⩌ int,list" || no "vmax int,list"
[ "$(printf '%s' '0R 5\vadd L N E' | gc)" = "0" ] && ok "∔ over the empty list (K is total)" || no "empty vadd K"
[ "$(printf '%s' '5 0R\vadd L N E' | gc)" = "0" ] && ok "∔ over the empty list (G is total)" || no "empty vadd G"
# Nesting: h x = ∑(x ∔ ⍳2) = x + (x+1) = 2x+1, so ⍳3 maps to 1 3 5.  Proves D
# (and the G it dispatches to) survives being called from inside €'s own loop —
# every one of D/G/R/S restores the scratch € is holding.
[ "$(printf '%s' ':h2R\vadd S;3R\refh M Q E' | gc)" = "1 3 5 " ] \
  && ok "D/K/G re-enter safely inside map (h x = 2x+1)" || no "nested dispatch"
tools/golfc -j examples/polymorphic.golfj "$TMP/poly" 2>/dev/null
[ "$("$TMP/poly" 2>/dev/null)" = "$(printf '14\n25\n10 9 8 \n7')" ] \
  && ok "golfc examples/polymorphic.golfj" || no "polymorphic.golfj"
[ "$(oracle polymorphic)" = "$(printf '14\n25\n10 9 8 \n7')" ] \
  && ok "oracle: polymorphic.golfj behaves identically" || no "oracle polymorphic.golfj"

# @@ W2-CHAIN @@
echo "Tacit combinators (M-CHAIN): ∘ compose ⇉ pipeline ⑂ fork — quotations built at runtime"
# ∘ writes a 39-byte thunk [prologue][mov rax,f; call rax][mov rax,g; call rax]
# [epilogue] into the code arena and returns its address, so ⍎ calls it like any
# compiled word.  d = ⊗ double, i = ⊕ increment; (d ∘ i)(5) = i(d 5) = 11.
[ "$(printf '%s' ':d\dbl;:i\inc;5\refd\refi\comp\exec N E' | gc)" = "11" ] \
  && ok "compose (′d ∘ ′i applied to 5)" || no "compose"
# The thunk must NOT come from the list heap (>= 0x500000, where it would be
# indistinguishable from a list): the arena is 0x4D0000 = 5046272, an int.
[ "$(printf '%s' ':d\dbl;:i\inc;\refd\refi\comp N E' | gc)" = "5046272" ] \
  && ok "a composed quotation is an int in the code arena at 0x4D0000" || no "compose arena address"
# Two composes, second minus first (±negated because Ṅ prints unsigned).
[ "$(printf '%s' ':d\dbl;:i\inc;\refd\refi\comp\refi\refd\comp\rsub\neg N E' | gc)" = "39" ] \
  && ok "composing twice bumps the arena by exactly one 39-byte thunk" || no "compose twice"
[ "$(printf '%s' ':d\dbl;:i\inc;5\refd\refi\comp\refd\comp\exec N E' | gc)" = "22" ] \
  && ok "compose of a composed quotation: d(i(d 5))" || no "compose of compose"
[ "$(printf '%s' ':d\dbl;:i\inc;:c\refd\refi\comp\exec;5R\refcMQE' | gc)" = "1 3 5 7 9 " ] \
  && ok "compose inside map (a fresh thunk per element, 2x+1)" || no "compose in map"
# ⑂ fork: the APL/J train.  mean = ÷(∑, ≢); ∑(0..4)=10, ≢=5, 10÷5=2.
[ "$(printf '%s' '5R\refS\refL\ref\sdv\fork N E' | gc)" = "2" ] \
  && ok "fork: mean of range(5) = ÷(∑, ≢)" || no "fork mean"
[ "$(printf '%s' ':e\refS\refL\ref\sdv\fork;5R\refe\exec N E' | gc)" = "2" ] \
  && ok "fork reached through an extra ⍎ indirection" || no "fork via exec"
# fork inside map: f and g are looping words, so this only works if every frame
# nests.  means of [0,1] and [0,1,2,3] are 1÷2=0 and 6÷4=1.
# The three hand-built lists below spell out the cell layout, so W4A restrided
# them: cells are 8 bytes and are written with ⊛ (\store), not 4 and !.
[ "$(printf '%s' ':m\refS\refL\ref\sdv\fork;3A 2&\store2R&8\radd\store4R&16\radd\store\refmMQE' | gc)" = "0 1 " ] \
  && ok "fork inside map (nested scratch frames)" || no "fork in map"
# ⇉ pipeline over a hand-built quotation list [′d, ′i]: 3 cells = len + 2 addrs.
[ "$(printf '%s' ':d\dbl;:i\inc;5 3A 2&\store\refd&8\radd\store\refi&16\radd\store\pipe N E' | gc)" = "11" ] \
  && ok "pipeline: 5 threaded through [′d, ′i]" || no "pipeline"
[ "$(printf '%s' '5 1A 0&\store\pipe N E' | gc)" = "5" ] \
  && ok "pipeline over an empty quotation list is the identity" || no "empty pipeline"
tools/golfc -j examples/chain.golfj "$TMP/chain" 2>/dev/null
[ "$("$TMP/chain" 2>/dev/null)" = "$(printf '11\n2\n11')" ] && ok "golfc examples/chain.golfj" || no "chain.golfj"
[ "$(oracle chain)" = "$(printf '11\n2\n11')" ] \
  && ok "oracle: chain.golfj behaves identically" || no "oracle chain.golfj"
# @@ W3-VEC @@
echo "Implicit vectorization (M-VEC): the bare + - * ⌈ ⌊ dispatch on shape"
# Each of the five now compiles to [cmp qword [hook],0; je scalar; (a|b) <u heap
# base ? scalar : call [hook]; scalar]. The hook cells (0x4F0100 + 8*op byte) are
# BSS, and the prelude's last line installs ∔ ∸ ⨰ ⩌ ⩍ into them — so a program
# with the prelude vectorizes, and the compiler binary (which never runs one)
# keeps its cells zero and stays byte-for-byte scalar. Hence the fixpoint above.
[ "$(printf '%s' '4R3+QE'      | gc)" = "3 4 5 6 " ]   && ok "+ list,int  (broadcast via K)"     || no "vec + list,int"
[ "$(printf '%s' '10 4R-QE'    | gc)" = "10 9 8 7 " ]  && ok "- int,list  (broadcast via G, order kept)" || no "vec - int,list"
[ "$(printf '%s' '4R4R*SNE'    | gc)" = "14" ]         && ok "* list,list (dot product via Z)"   || no "vec * list,list"
[ "$(printf '%s' '4R4R+SNE'    | gc)" = "12" ]         && ok "+ list,list (elementwise via Z)"   || no "vec + list,list"
[ "$(printf '%s' '5R 2\max QE' | gc)" = "2 2 2 3 4 " ] && ok "⌈ list,int  (broadcast max)"       || no "vec max list,int"
[ "$(printf '%s' '5R 2\min QE' | gc)" = "0 1 2 2 2 " ] && ok "⌊ list,int  (broadcast min)"       || no "vec min list,int"
[ "$(printf '%s' '3 4+NE'      | gc)" = "7" ]          && ok "+ int,int   (unchanged)"           || no "vec + int,int"
[ "$(printf '%s' '0R3+LNE'     | gc)" = "0" ]          && ok "+ over the empty list"             || no "vec + empty"
# Filter safety. The template's (a|b) <u heap-base test is CONSERVATIVE, never
# authoritative: `<` yields -1, which looks like a huge address and does reach
# the hook — D then re-tests both operands exactly and applies the raw scalar
# add, so -1 + 1 is 0 and not a wild memory access.
[ "$(printf '%s' ':c3 4<1+;cNE' | gc)" = "0" ] \
  && ok "a -1 flag reaches the hook and falls back to the scalar op" || no "vec flag safety"
# Without the prelude nothing installs a hook, so the check falls straight
# through to the untouched v1 template.
[ "$(printf '%s' '4 3+48+)' | atom)" = "7" ] \
  && ok "no prelude: bare + is still exactly the scalar op" || no "vec scalar preservation"
# h x = ∑(x + ⍳2) = 2x+1: the dispatch happens inside a mapped word, so D/G/R/S
# all have to nest (each saves its own scratch frame).
[ "$(printf '%s' ':h2R+S;3R\refhMQE' | gc)" = "1 3 5 " ] \
  && ok "bare + broadcasting inside a mapped word (h x = 2x+1)" || no "vec inside map"
# Differential: boot/golfref.py emits the same polymorphic templates as golf2.
gref(){ cat <(python3 tools/codepage.py encode < lib/prelude.golfj) \
            <(python3 tools/codepage.py encode) | python3 boot/golfref.py > "$TMP/ovec" 2>/dev/null \
          && chmod +x "$TMP/ovec" && "$TMP/ovec" 2>/dev/null; }
[ "$(printf '%s' '4R3+QE 4R4R*SNE' | gref)" = "$(printf '%s' '4R3+QE 4R4R*SNE' | gc)" ] \
  && ok "oracle: the bare ops vectorize identically" || no "oracle vec"

# @@ W4-CELLS @@
echo "64-bit list cells (M4): negatives survive storage; N prints signed"
# N grew a sign check, so a negative prints as -n instead of its u64 image.
# Before W4A this printed 18446744073709551611.
[ "$(printf '%s' '0 5-NE' | gc)" = "-5" ] && ok "N prints a negative signed" || no "signed print"
# THE core proof of the widening: m x = x-2 maps ⍳5 to [-2 -1 0 1 2], and every
# one of those goes through a heap cell.  With 4-byte cells the two negatives
# came back as 4294967294 / 4294967295.
[ "$(printf '%s' ':m2\rsub;5R\refmMQE' | gc)" = "-2 -1 0 1 2 " ] \
  && ok "negative elements survive a list round trip (8-byte cells)" || no "negative elements"
# The parked-broadcast-scalar fix: K/G stash the scalar in s7, which used to be a
# 32-bit cell, so -3 came back as 4294967293 (and the last sum wrapped to 0).
[ "$(printf '%s' '0 3-4R+QE' | gc)" = "-3 -2 -1 0 " ] \
  && ok "a negative broadcast scalar keeps 64 bits through K/G" || no "broadcast scalar width"
# S's accumulator is a 64-bit scratch cell now, so a sum that crosses zero works.
[ "$(printf '%s' ':m2\rsub;5R\refmMSNE' | gc)" = "0" ] \
  && ok "sum crossing zero (-2-1+0+1+2)" || no "sum crossing zero"
# Regressions through the widened cells: M-VEC broadcast, an M-CHAIN fork, and a
# mapped word that itself loops (spill frames are 64 bytes now, 28 deep).
[ "$(printf '%s' '4R3+QE' | gc)" = "3 4 5 6 " ] \
  && ok "regression: M-VEC broadcast through widened cells" || no "widened vec broadcast"
[ "$(printf '%s' '5R\refS\refL\ref\sdv\fork NE' | gc)" = "2" ] \
  && ok "regression: fork mean through widened cells" || no "widened fork"
[ "$(printf '%s' ':g3RS;5R\refgMQE' | gc)" = "3 3 3 3 3 " ] \
  && ok "regression: nested HOF at 64-byte spill frames" || no "widened nested HOF"

# @@ W6-LIT @@
# W6A ------------------------------------------------------------------------
echo "Big literals (M4): a constant wider than 32 bits"
# `push imm32` SIGN-EXTENDS, so 0..2^31-1 was every constant a GOLF program could
# name: 4294967296 arrived as -4294967296 and 2147483648 as -2147483648.  The
# compiler's `W` word (self/golf2.golfj) now tests `v >> 31` and emits
# `mov rax, <imm64>; push rax` — 11 bytes instead of 5 — when the value needs it.
[ "$(printf '%s' '4294967296 N E'      | gc)" = "4294967296" ] \
  && ok "2^32 (the first value push imm32 cannot carry)" || no "big literal 2^32"
[ "$(printf '%s' '2147483648 N E'      | gc)" = "2147483648" ] \
  && ok "2^31 (fits 32 bits, but push imm32 would negate it)" || no "big literal 2^31"
[ "$(printf '%s' '2147483647 N E'      | gc)" = "2147483647" ] \
  && ok "2^31-1 (the largest literal that still fits imm32)" || no "boundary 2^31-1"
[ "$(printf '%s' '4294967295 1+N E'    | gc)" = "4294967296" ] \
  && ok "carrying across the 32-bit boundary at run time" || no "carry over 2^32"
[ "$(printf '%s' '9007199254740991 N E'| gc)" = "9007199254740991" ] \
  && ok "2^53-1 (well past anything 32 bits can hold)" || no "big literal 2^53"
[ "$(printf '%s' ':b4294967296;b N E'  | gc)" = "4294967296" ] \
  && ok "a big literal inside a user word" || no "big literal in a word"
[ "$(printf '%s' '4294967296 4294967296+N E' | gc)" = "8589934592" ] \
  && ok "two big literals through the polymorphic + (both re-test as ints)" || no "big literal arithmetic"
# The prelude is not involved: the emitter is the compiler's, so it works bare.
[ "$(printf '%s' '4294967296 32\shr48+)' | atom)" = "1" ] \
  && ok "no prelude: the high dword of 2^32 is 1" || no "bare big literal"
# The ENCODING itself, not just the value — a literal that fitted before must
# still compile to exactly the five bytes it always did, or every compiled
# program on the ladder would shift.  `)` follows each literal (6a 01 58 ...).
w6alit(){ printf '%s' "$1" | "$TMP/golf2" 2>/dev/null | od -An -tx1 -v | tr -d ' \n'; }
case "$(w6alit '5)')" in
  *68050000006a01*) ok "5 is still push imm32 (68 05 00 00 00)";;
  *)                no "small literal encoding changed";; esac
case "$(w6alit '2147483647)')" in
  *68ffffff7f6a01*) ok "2^31-1 is still push imm32 (68 ff ff ff 7f)";;
  *)                no "2^31-1 encoding";; esac
case "$(w6alit '2147483648)')" in
  *48b80000008000000000506a01*) ok "2^31 switches to mov rax,imm64; push rax";;
  *)                            no "2^31 encoding";; esac
case "$(w6alit '4294967296)')" in
  *48b80000000001000000506a01*) ok "2^32 as mov rax,imm64; push rax";;
  *)                            no "2^32 encoding";; esac
# Differential: the encodings are the whole point here, so boot/golfref.py has to
# agree byte for byte, not merely behave the same.
printf '%s' '4294967296 5 2147483648 1099511627775 0)' > "$TMP/w6alit.src"
"$TMP/golf2" < "$TMP/w6alit.src" > "$TMP/w6alit.g2" 2>/dev/null
python3 boot/golfref.py < "$TMP/w6alit.src" > "$TMP/w6alit.ref" 2>/dev/null
cmp -s "$TMP/w6alit.g2" "$TMP/w6alit.ref" \
  && ok "oracle: identical bytes for a program of mixed-width literals" || no "oracle big-literal bytes"
W6ABIG=$(printf '4294967296\n2147483648\n4294967296\n1099511627775\n86400\n43200000000000')
tools/golfc -j examples/bignum.golfj "$TMP/bignum" 2>/dev/null
[ "$("$TMP/bignum" 2>/dev/null)" = "$W6ABIG" ] && ok "golfc examples/bignum.golfj" || no "bignum.golfj"
[ "$(oracle bignum)" = "$W6ABIG" ] \
  && ok "oracle: bignum.golfj behaves identically" || no "oracle bignum.golfj"
# @@ W6-MEM @@
# W6B --------------------------------------------------------------- M-MEM ---
echo "Growable heap (M-MEM): ⌸ brk, the list heap is the kernel's, not a BSS hole"
# The atom on its own, no prelude: brk(0) reads the break, brk(a) moves it and
# reports the break in effect afterwards.
[ "$(printf '%s' '0 0\brk\rlt1\radd48+)' | atom)" = "0" ] \
  && ok "⌸ brk(0) returns a non-zero program break" || no "brk read"
[ "$(printf '%s' '0\brk 4096\radd\brk 0\brk\rsub1\radd48+)' | atom)" = "1" ] \
  && ok "⌸ brk(p+4096) moves the break and reports the new one" || no "brk grow"
# p_memsz shrank from 0x800000 to 0x200000, so the BSS ends at 0x600000 and the
# return stack starts there instead of at 0xC00000.  Everything above is heap.
[ "$(printf '%s' '0\brk 6291456\rlt1\radd48+)' | atom)" = "1" ] \
  && ok "the break starts above the shrunken BSS (0x600000)" || no "brk above bss"
# The prelude's init publishes what the kernel gave into the M-TAG bounds cells.
# The base is ASLR-shifted (observed anywhere from ~0x1C00000 to ~0x3B000000),
# so only its relation to the static image is assertable — never its value.
[ "$(printf '%s' '0 5177400@\rlt1\radd N E' | gc)" = "0" ] \
  && ok "heap span cell is non-zero (brk handed back the initial chunk)" || no "brk heap span"
[ "$(printf '%s' '5⍳ 5177396@\rsub 5177400@\rlt1\radd N E' | gc)" = "0" ] \
  && ok "a fresh list lands inside [base, base+span)" || no "list inside bounds"
# Nothing that is not a list may fall inside the moved window: the M-CHAIN thunk
# arena, a word address and a -1 flag all still classify as ints.
[ "$(printf '%s' '5⍳T N E' | gc)"      = "0" ] && ok "T: a brk-heap address is a list" || no "brk T list"
[ "$(printf '%s' '5046272 T N E' | gc)" = "1" ] \
  && ok "T: the 0x4D0000 thunk arena is still outside the heap" || no "brk T arena"
[ "$(printf '%s' ':d\dbl;\refd T N E' | gc)" = "1" ] \
  && ok "T: a word address is still outside the heap" || no "brk T word"
# The milestone itself.  The old static heap was 7,340,032 bytes between
# 0x500000 and the return stack, so a list of 917,504 cells or more walked off
# the end and segfaulted; 200000⍳ (1.6 MB) fitted even then, 2000000⍳ (16 MB)
# never could.  Both are one A call, so the break moves exactly once each.
[ "$(printf '%s' '200000⍳≢ṄE'  | gc)" = "200000" ]  \
  && ok "200000⍳ — a 1.6 MB list"  || no "200000 range"
[ "$(printf '%s' '2000000⍳≢ṄE' | gc)" = "2000000" ] \
  && ok "2000000⍳ — a 16 MB list, twice the whole old BSS" || no "2000000 range"
[ "$(printf '%s' '2000000⍳1999999⊇ṄE' | gc)" = "1999999" ] \
  && ok "the last cell of a 16 MB list is intact" || no "big index"
[ "$(printf '%s' '917504⍳≢ṄE'  | gc)" = "917504" ]  \
  && ok "917504⍳ — the exact size that overran the old static heap" || no "917504 range"
# A big map: a second list of the same size, so the heap grows a second time.
[ "$(printf '%s' ':d\dbl;1000000⍳\refdM 999999⊇ṄE' | gc)" = "1999998" ] \
  && ok "map over 1,000,000 elements (two 8 MB lists live at once)" || no "big map"
# Growth must keep the span covering lists allocated BEFORE it, or the older one
# would stop classifying as a list the moment the heap moved.
[ "$(printf '%s' '300000⍳→a300000⍳_←a 299999⊇ṄE' | gc)" = "299999" ] \
  && ok "an older list survives a heap growth" || no "span after growth"
[ "$(printf '%s' '300000⍳→a300000⍳_←a T N E' | gc)" = "0" ] \
  && ok "T still classifies an older list after the span grew" || no "T after growth"
[ "$(printf '%s' '200000⍳→a200000⍳_←a 3+ 199999⊇ṄE' | gc)" = "200002" ] \
  && ok "M-VEC broadcast over a big list across a growth" || no "big vec broadcast"
# The other side of the shrink: the return stack starts at the BSS top, so it
# moved from 0xC00000 to 0x600000 and now has 0x600000-0x4F1000 = 1.08 MB, i.e.
# ~138k frames, entirely to itself — where before it shared 7 MB with the heap
# and lost a frame for every 8 bytes allocated.  r recurses n+1 deep.
[ "$(printf '%s' ':r"[^]\dec r;50000 r N E' | gc)" = "0" ] \
  && ok "50,000-deep recursion on the relocated return stack" || no "return stack depth"
tools/golfc -j examples/bigheap.golfj "$TMP/big" 2>/dev/null
[ "$("$TMP/big" 2>/dev/null)" = "$(printf '1000000\n1999998\n999999')" ] \
  && ok "golfc examples/bigheap.golfj" || no "bigheap.golfj"
[ "$(oracle bigheap)" = "$(printf '1000000\n1999998\n999999')" ] \
  && ok "oracle: bigheap.golfj behaves identically" || no "oracle bigheap.golfj"
# W6B ----------------------------------------------------------------------
# @@ W7-DOCS @@
# W7A ------------------------------------------------------ doc assertions ---
# The prose is part of the build.  Every number quoted in ../README.md,
# DESIGN.md and REGISTRY.md is pulled back out with grep/sed here and compared
# against the artifact it describes, so a doc that drifts fails loudly instead
# of lying quietly.  The keys are distinctive phrases the docs were written to
# carry, and w7num/w7hex refuse a key that does not match EXACTLY ONE line — so
# deleting or duplicating a row is caught too, not just editing its number.
echo "Docs match reality (W7A): README/DESIGN/REGISTRY numbers vs the artifacts"
W7README="$EXP/../README.md"
w7num(){ # w7num <file> <unique key> -> that line's **bold** integer
  local n; n=$(grep -cF "$2" "$1" 2>/dev/null)
  [ "$n" = 1 ] || { printf 'KEY-MATCHED-%s-LINES' "${n:-0}"; return; }
  grep -F "$2" "$1" | grep -oE '\*\*[0-9]+\*\*' | head -1 | tr -d '*'
}
w7hex(){ # w7hex <file> <unique key> -> that line's **bold** hex constant
  local n; n=$(grep -cF "$2" "$1" 2>/dev/null)
  [ "$n" = 1 ] || { printf 'KEY-MATCHED-%s-LINES' "${n:-0}"; return; }
  grep -F "$2" "$1" | grep -oE '\*\*0x[0-9A-Fa-f]+\*\*' | head -1 | tr -d '*'
}
# The machine side of every comparison, computed once.
python3 - > "$TMP/w7a.facts" <<'PY'
import sys
sys.path.insert(0, "tools")
import mkblob2, codepage
alloc  = {b for b, *_ in mkblob2.ATOMS}
alloc |= {(x[0] if isinstance(x[0], int) else ord(x[0])) for x in codepage.LIB}
alloc |= {x[0] for x in codepage.COMPILER}
hi = [b for b in alloc if b >= 0x91]
print("atoms",  len(mkblob2.ATOMS))
print("blob",   len(mkblob2.build_blob2()))
print("memsz",  hex(mkblob2.MEMSZ))
print("rstack", hex(mkblob2.RSTACK_TOP))
print("rsdec",  mkblob2.RSTACK_TOP)
# The return stack runs from RSTACK_TOP down to the top of the 0x4F bank, 8
# bytes a frame; the docs quote it in thousands.
print("frames", (mkblob2.RSTACK_TOP - 0x4F1000) // 8 // 1000)
print("hiused", len(hi))
print("hifree", 111 - len(hi))
PY
w7fact(){ awk -v k="$1" '$1==k{print $2}' "$TMP/w7a.facts"; }
# Op bytes of a glyph program: encode drops the #-comments, and neither capstone
# holds a significant space, so stripping layout whitespace leaves the ops.
w7ops(){ python3 tools/codepage.py encode < "$1" | tr -d '[:space:]' | wc -c | tr -d ' '; }

W7ATOMS=$(w7fact atoms)
W7RA=$(sed -n 's/.*\*\*\([0-9][0-9]*\) operator atoms\*\*.*/\1/p' "$W7README" | head -1)
[ "$W7RA" = "$W7ATOMS" ] \
  && ok "README.md quotes $W7ATOMS operator atoms = len(mkblob2.ATOMS)" \
  || no "README.md atom count is '$W7RA', mkblob2.ATOMS has $W7ATOMS"
[ "$(w7num DESIGN.md 'operator atoms in')" = "$W7ATOMS" ] \
  && ok "DESIGN.md quotes $W7ATOMS operator atoms = len(mkblob2.ATOMS)" \
  || no "DESIGN.md atom count is '$(w7num DESIGN.md 'operator atoms in')', not $W7ATOMS"

# Self-referential: this suite's assertion total is the number of its own
# ok-call sites (one per assertion; the `case` blocks put theirs on the ok
# branch), which is what the final "Result:" line prints when nothing fails.
W7SITES=$(grep -oE 'ok +"' test/run2.sh | wc -l | tr -d ' ')
W7RT=$(sed -n 's/.*\*\*\([0-9][0-9]*\) assertions green\*\*.*/\1/p' "$W7README" | head -1)
[ "$W7RT" = "$W7SITES" ] \
  && ok "README.md quotes $W7SITES assertions = this suite's own total" \
  || no "README.md claims '$W7RT' assertions, run2.sh has $W7SITES"
[ "$(w7num DESIGN.md 'assertions in the run2 suite')" = "$W7SITES" ] \
  && ok "DESIGN.md quotes $W7SITES assertions = this suite's own total" \
  || no "DESIGN.md run2 count is '$(w7num DESIGN.md 'assertions in the run2 suite')', not $W7SITES"
# selfcheck.sh loops over its example list, so its total is a runtime fact: ask
# it.  It is a fraction of a second and writes nothing into the repo.
W7SC=$(bash test/selfcheck.sh 2>/dev/null | sed -n 's/^Result: \([0-9]*\) passed, \([0-9]*\) failed$/\1 \2/p')
[ "$W7SC" = "$(w7num DESIGN.md 'assertions in the selfcheck suite') 0" ] \
  && ok "DESIGN.md quotes test/selfcheck.sh's real total (${W7SC% *} passed, 0 failed)" \
  || no "DESIGN.md selfcheck count vs actual: '$(w7num DESIGN.md 'assertions in the selfcheck suite') 0' vs '$W7SC'"
# Same for the M-TOOL differential suite.  It is the slowest of the three (it
# compiles five GOLF programs and walks the ladder twice), which is why it is
# asked for its total rather than having it counted statically — and why this is
# the only place run2.sh pays for it.
W7GT=$(bash test/gtools.sh 2>/dev/null | sed -n 's/^Result: \([0-9]*\) passed, \([0-9]*\) failed$/\1 \2/p')
[ "$W7GT" = "$(w7num DESIGN.md 'assertions in the gtools differential suite') 0" ] \
  && ok "DESIGN.md quotes test/gtools.sh's real total (${W7GT% *} passed, 0 failed)" \
  || no "DESIGN.md gtools count vs actual: '$(w7num DESIGN.md 'assertions in the gtools differential suite') 0' vs '$W7GT'"

[ "$(w7num DESIGN.md 'the generated bootstrap seed')" = "$(wc -c < self/seed.golf)" ] \
  && ok "DESIGN.md's self/seed.golf size matches wc -c ($(wc -c < self/seed.golf) bytes)" \
  || no "DESIGN.md seed size '$(w7num DESIGN.md 'the generated bootstrap seed')' vs $(wc -c < self/seed.golf)"
[ "$(w7num DESIGN.md 'the generated v2 compiler')" = "$(wc -c < self/golf2.golf)" ] \
  && ok "DESIGN.md's self/golf2.golf size matches wc -c ($(wc -c < self/golf2.golf) bytes)" \
  || no "DESIGN.md golf2 size '$(w7num DESIGN.md 'the generated v2 compiler')' vs $(wc -c < self/golf2.golf)"
[ "$(w7num DESIGN.md 'the template blob itself')" = "$(w7fact blob)" ] \
  && ok "DESIGN.md's template-blob size matches build_blob2() ($(w7fact blob) bytes)" \
  || no "DESIGN.md blob size '$(w7num DESIGN.md 'the template blob itself')' vs $(w7fact blob)"

[ "$(w7num DESIGN.md 'the capstone, in op bytes')" = "$(w7ops examples/capstone.golfj)" ] \
  && ok "DESIGN.md's capstone size matches the encoded file ($(w7ops examples/capstone.golfj) op bytes)" \
  || no "DESIGN.md capstone '$(w7num DESIGN.md 'the capstone, in op bytes')' vs $(w7ops examples/capstone.golfj)"
[ "$(w7num DESIGN.md 'the legacy capstone, in op bytes')" = "$(w7ops examples/legacy_capstone.golfj)" ] \
  && ok "DESIGN.md's legacy-capstone size matches the encoded file ($(w7ops examples/legacy_capstone.golfj) op bytes)" \
  || no "DESIGN.md legacy capstone '$(w7num DESIGN.md 'the legacy capstone, in op bytes')' vs $(w7ops examples/legacy_capstone.golfj)"

# M-MEM's two numbers are one number: p_memsz and the return-stack top move
# together (mkblob2 derives RSTACK_TOP from MEMSZ), and REGISTRY.md §3 spells
# the top in both hex and decimal, so check the row's two columns against it.
[ "$(w7hex DESIGN.md 'the v2 p_memsz')" = "$(w7fact memsz)" ] \
  && ok "DESIGN.md's p_memsz matches mkblob2.MEMSZ ($(w7fact memsz))" \
  || no "DESIGN.md p_memsz '$(w7hex DESIGN.md 'the v2 p_memsz')' vs $(w7fact memsz)"
W7REG=$(awk -F'|' '/mkblob2.RSTACK_TOP/{gsub(/[ `]/,"",$2); gsub(/[ `]/,"",$3); print $2"/"$3; exit}' REGISTRY.md)
[ "$(w7hex DESIGN.md 'the return-stack top address')" = "$(w7fact rstack)" ] \
  && [ "$W7REG" = "$(w7fact rstack)/$(w7fact rsdec)" ] \
  && ok "DESIGN.md and REGISTRY.md §3 both give the return-stack top as $(w7fact rstack) / $(w7fact rsdec)" \
  || no "return-stack top: DESIGN '$(w7hex DESIGN.md 'the return-stack top address')', REGISTRY '$W7REG', real $(w7fact rstack)/$(w7fact rsdec)"
[ "$(w7num DESIGN.md 'clean return-stack frames')" = "$(w7fact frames)" ] \
  && ok "DESIGN.md's ~$(w7fact frames)k return-stack frames matches the measured span" \
  || no "DESIGN.md frame count '$(w7num DESIGN.md 'clean return-stack frames')' vs $(w7fact frames)"

# M-MEM deleted the fixed heap base and the 0xC00000 stack top: no memory-map
# row may resurrect either, and nothing in §1.2 may still be unshipped.
W7STALE=$(grep -cE '^\| `0x500000`|^\| `0xC00000`|shipping in wave' REGISTRY.md)
[ "$W7STALE" = "0" ] \
  && ok "REGISTRY.md has no fixed-heap-base row, no 0xC00000 row, no unshipped status" \
  || no "REGISTRY.md still carries $W7STALE stale row(s) (0x500000 / 0xC00000 / 'shipping in wave')"
[ "$(grep -F 'are now spent, leaving' REGISTRY.md | grep -oE '\*\*[0-9]+\*\*' | tr -d '*' | tr '\n' '/')" \
    = "$(w7fact hiused)/$(w7fact hifree)/" ] \
  && ok "REGISTRY.md §1: $(w7fact hiused) high op bytes spent, $(w7fact hifree) free — matches the tables" \
  || no "REGISTRY.md high-byte budget is stale (real: $(w7fact hiused) spent, $(w7fact hifree) free)"

# The README quotes programs, not just numbers.  Both halves are pinned: the
# bare spellings are the ones examples/capstone.golfj carries, the long ones are
# examples/legacy_capstone.golfj's — and then both are RUN, and must print what
# the README says they print.
W7PIN=0
for s in '4⍳4⍳*∑' '3→k“Hello“U←k+J'; do
  grep -qF "$s" "$W7README" && grep -qF "$s" examples/capstone.golfj || W7PIN=1
done
for s in '4⍳4⍳′*⊞∑' '3→k:f←k+;“Hello“U′f€J'; do
  grep -qF "$s" "$W7README" && grep -qF "$s" examples/legacy_capstone.golfj || W7PIN=1
done
[ "$W7PIN" = 0 ] \
  && ok "README.md's spellings are verbatim the ones capstone/legacy_capstone pin" \
  || no "a README spelling is not in the example that pins it"
W7DOCOUT=$(printf '%s' '5⍳′²€∑Ṅ␤4⍳4⍳*∑Ṅ␤4⍳3+⍕␤“Hello“U1+J␤3→k“Hello“U←k+J␤5⍳′∑′≢′÷⑂Ṅ␤100⍳∑Ṅ␤' | gc)
[ "$W7DOCOUT" = "$(printf '30\n14\n3 4 5 6 \nIfmmp\nKhoor\n2\n4950')" ] \
  && ok "every bare one-liner quoted in README.md prints what README.md claims" \
  || no "a README one-liner printed something else: $W7DOCOUT"
W7LEGOUT=$(printf '%s' '4⍳4⍳′*⊞∑Ṅ␤“Hello“U′⊕€J␤3→k:f←k+;“Hello“U′f€J␤' | gc)
[ "$W7LEGOUT" = "$(printf '14\nIfmmp\nKhoor')" ] \
  && ok "every long-form one-liner quoted in README.md still prints the same" \
  || no "a README long-form one-liner printed something else: $W7LEGOUT"
# W7A -------------------------------------------------------------------------

# Wave 8 (M-TOOL) anchors.  Unlike the waves above, several of these run in
# parallel, so they are spaced out: git merges two inserts cleanly only when the
# hunks do not share context lines.  Add tests directly under your own anchor and
# leave the blank lines around the others alone.

# @@ W8-SYS @@
echo "Raw syscalls (M-TOOL): ⎈ sys — a1 a2 a3 num ⎈ -> result"
# Before this op GOLF's entire I/O surface was `(` and `)`: one byte from fd 0,
# one byte to fd 1. ⎈ pops rax, rdx, rsi, rdi in that order, so a call reads
# left-to-right in argument order and unused arguments are simply pushed as 0.
# A “…“ literal pushes the address of its 4-byte length field, so its text
# starts at addr+4 and its length is `@` of the address — hence →s / ←s here
# rather than a hand-counted byte count.
[ "$(printf '%s' '“hello from sys“→s 1←s4\radd←s@1\sys_' | atom)" = "hello from sys" ] \
  && ok "⎈ write(1, buf, n) — the first syscall GOLF can spell" || no "sys write"
# The kernel's return value is pushed back unchanged: write returns the count.
[ "$(printf '%s' '“hello from sys“→s 1←s4\radd←s@1\sys N E' | gc)" = "hello from sys14" ] \
  && ok "⎈ pushes the kernel's return value (write -> 14)" || no "sys write count"
# ...and a NEGATIVE ERRNO on failure — the raw kernel convention, not libc's
# -1-plus-errno. close() of a never-opened fd is EBADF on every kernel, whatever
# RLIMIT_NOFILE happens to be, so -9 is stable.
[ "$(printf '%s' '999999 0 0 3\sys N E' | gc)" = "-9" ] \
  && ok "⎈ returns a negative errno (close of a bogus fd -> -EBADF)" || no "sys errno"
# read(0, buf, 4). The load segment is RWX, so the bytes of a “    “ literal are
# a perfectly legal scratch buffer. This one needs a stdin of its own: the
# helpers above hand theirs to the compiler, so it is already at EOF by the time
# the compiled program runs.
printf '%s' '“    “→s 0←s4\radd 4 0\sys N E ←s O E' \
  | python3 tools/codepage.py encode > "$TMP/sysrd.gb"
cat "$TMP/pre.gb" "$TMP/sysrd.gb" | "$TMP/golf2" > "$TMP/sysrd" 2>/dev/null && chmod +x "$TMP/sysrd"
[ "$(printf 'GOLF' | "$TMP/sysrd" 2>/dev/null)" = "$(printf '4\nGOLF')" ] \
  && ok "⎈ read(0, buf, 4) straight into a string literal's bytes" || no "sys read"
# exit(42): the one-argument shape, with 0 pushed for the two arguments the call
# does not use. This is what lets a GOLF tool fail a build.
printf '%s' '42 0 0 60\sys' | atom >/dev/null 2>&1
[ "$?" = 42 ] && ok "⎈ exit(42) — unused arguments are just 0" || no "sys exit"
# `syscall` clobbers rcx and r11 and nothing else GOLF depends on: no value is
# ever live in a register across ops, and rbp — the return-stack pointer — is
# untouched, so a word can syscall and still return to its caller.
[ "$(printf '%s' ':w“in a word“→s 1←s4\radd←s@1\sys_;w E 7 8+N E' | gc)" = "$(printf 'in a word\n15')" ] \
  && ok "⎈ inside a word: the return stack (rbp) survives the syscall" || no "sys in word"
# ⎈ is a pure template, so boot/golfref.py needed no edit — it builds its
# TEMPLATES from mkblob2.ATOMS. This is what proves the inheritance is real.
[ "$(printf '%s' '“hello from sys“→s 1←s4\radd←s@1\sys N E' | gref)" = "hello from sys14" ] \
  && ok "oracle: ⎈ auto-inherited from ATOMS, byte-identical behaviour" || no "oracle sys"

# @@ W8-ARGV @@
echo "argv (M-TOOL): STARTUP stashes the entry rsp at 0x4F0040, so argc/argv are reachable"
# The kernel enters the process with rsp pointing at argc (argv[i] at rsp+8+8*i),
# but GOLF uses rsp AS its data stack, so the very first push destroys it.
# STARTUP — tools/mkblob2.STARTUP2, the only code that runs before any push —
# now stashes it at 5177408 (0x4F0040, REGISTRY.md §3).  That cell holds a STACK
# address, far above 2^32 on Linux x86-64, so it and every argv[i] pointer it
# leads to must be read with the 64-bit ⊙ \fetch; the 32-bit @ would truncate.
# No prelude needed: the stash is in the program's own prologue.
[ "$(printf '%s' '5177408\fetch 2147483647\gt1+48+)' | atom)" = "0" ] \
  && ok "the entry rsp is above 2^31 (so @ would truncate it)" || no "entry rsp width"
# gc compiles to "$TMP/p" and runs it with no extra arguments, so argc is 1 and
# argv[0] is that absolute temp path — its first byte is '/' (47).
[ "$(printf '%s' '5177408\fetch\fetch N E' | gc)" = "1" ] \
  && ok "argc is 1 (5177408 ⊙ ⊙)" || no "argc"
[ "$(printf '%s' '5177408\fetch 8\radd\fetch?N E' | gc)" = "47" ] \
  && ok "argv[0] starts with '/' (5177408 ⊙ 8 ﹢ ⊙)" || no "argv[0] first byte"
# Walk argv[0] to its NUL.  The temp path's length is not fixed, but the harness
# always names the binary "p", so the byte before the NUL is.  The pointer stays
# on the data stack throughout: →x/←x is a 4-byte bank and would truncate it.
[ "$(printf '%s' '5177408\fetch 8\radd\fetch 0→n{"←n\radd?←n\inc→n 0\eq}←n\radd 2\rsub?)E' | gc)" = "p" ] \
  && ok "walking argv[0] to its NUL lands on the last byte" || no "argv[0] walk"
# Real arguments.  gc's exact pipeline, except that the compiled program is run
# with the helper's own arguments — gc cannot forward them, since every other
# case in this file wants a bare invocation.
garg(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/p" 2>/dev/null \
          && chmod +x "$TMP/p" && "$TMP/p" "$@"; }
[ "$(printf '%s' '5177408\fetch\fetch N E' | garg one two)" = "3" ] \
  && ok "argc counts the real arguments" || no "argc with arguments"
[ "$(printf '%s' '5177408\fetch 16\radd\fetch?)E' | garg one two)" = "o" ] \
  && ok "argv[1] at entry_rsp+16" || no "argv[1]"
[ "$(printf '%s' '5177408\fetch 24\radd\fetch?)E' | garg one two)" = "t" ] \
  && ok "argv[2] at entry_rsp+24" || no "argv[2]"
# A whole argument, the way a tool will read a file name: measure it, then emit
# it byte by byte.  n is a count and fits the 4-byte variable bank; the pointer
# does not, so it lives on the stack and is duplicated with " each iteration.
[ "$(printf '%s' '5177408\fetch 16\radd\fetch 0→n{"←n\radd?←n\inc→n 0\eq}←n 1\rsub→n 0→i{"←i\radd?)←i\inc→i ←i←n\eq}_E' | garg one two)" = "one" ] \
  && ok "argv[1] read out in full (measure, then emit)" || no "argv[1] string"
# The System V entry contract in one line: argv[argc] is NULL (envp follows it).
[ "$(printf '%s' '5177408\fetch"\fetch\inc 8\rmul\radd\fetch N E' | garg one two)" = "0" ] \
  && ok "argv[argc] is NULL (the argv array is terminated)" || no "argv NULL terminator"
# Oracle parity.  boot/golfref.py must emit the SAME startup stub: if it still
# emitted v1's, the cell would be BSS-zero and 5177408 ⊙ ⊙ would fault on a null
# pointer.  gref runs its binary as "$TMP/ovec" — again argc 1, argv[0] from '/'.
[ "$(printf '%s' '5177408\fetch\fetch N E 5177408\fetch 8\radd\fetch?N E' | gref)" = "$(printf '1\n47')" ] \
  && ok "oracle: golfref.py stashes the entry rsp too" || no "oracle argv"

# @@ W8-TOOLLIB @@
echo "Tool library lib/tio.golfj (M-TOOL): a die · b open · c read · d write · e slurp · f flush · g emit · h argv"
# gc compiles the prelude and nothing else, so the tool libraries need a helper
# of their own: prelude + tio + the case.  It also FORWARDS its arguments to the
# compiled program, which is the only way a NUL-terminated path gets in — a
# “…“ literal is a counted block, not a C string, so argv is what `b` is fed.
python3 tools/codepage.py encode < lib/tio.golfj > "$TMP/tio.gb"
tio(){ cat "$TMP/pre.gb" "$TMP/tio.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/tp" 2>/dev/null \
         && chmod +x "$TMP/tp" && "$TMP/tp" "$@"; }
printf 'GOLF tio\n' > "$TMP/tio-in"                    # 9 bytes, this harness's own file
# The library's whole point in one line, used twice below (a small file and a
# big one): open argv[1], slurp it, push every byte back out through g, flush.
tiocat='1 h 0 b e→n→p 0→i ←n 0\eq[{←p←i\radd?g ←i1\radd→i ←i←n\rlt1\radd}]f'
[ "$(printf '%s' '72g 73g f' | tio)" = "HI" ] \
  && ok "g emit + f flush (one write syscall, not two)" || no "emit/flush"
[ "$(printf '%s' '“abc“→s 1 ←s4\radd ←s@ d' | tio)" = "abc" ] \
  && ok "d write-all (fd buf n ->)" || no "write-all"
[ "$(printf '%s' '1 h 0 b e N E _' | tio "$TMP/tio-in")" = "9" ] \
  && ok "b open(argv[1]) + e slurp -> the file's length" || no "open/slurp length"
# The whole round trip: this is `cat`, and it is what the tools are made of.
[ "$(printf '%s' "$tiocat" | tio "$TMP/tio-in")" = "GOLF tio" ] \
  && ok "e slurp -> g emit round trip (cat)" || no "slurp/emit round trip"
# c reads ONCE, into whatever buffer it is given: a “    “ literal's own bytes
# do fine, the load segment being RWX.  4 of the 9 bytes, so got is 4, not 9.
[ "$(printf '%s' '1 h 0 b→v “    “→s ←v ←s4\radd 4 c N E ←s O E' | tio "$TMP/tio-in")" = "$(printf '4\nGOLF')" ] \
  && ok "c read(fd, buf, 4) -> a short read is a normal answer" || no "read once"
# An empty file: slurp's read loop is a DO-while, so EOF on the first read has
# to fall straight out with len 0, and a flush with nothing pending is a no-op.
: > "$TMP/tio-empty"
[ "$(printf '%s' '1 h 0 b e N E _ f' | tio "$TMP/tio-empty")" = "0" ] \
  && ok "e slurp of an empty file -> 0 (the guard case)" || no "slurp empty"
# Growth.  The buffer starts at 65536 bytes and doubles by allocating a fresh
# block and copying, so a 200003-byte file exercises the copy loop twice — and
# proves the copy is exact, since the bytes come back out through g.
python3 -c "
import random, sys
random.seed(7)                       # a fixed seed: the same file every run
sys.stdout.buffer.write(random.randbytes(200003))" > "$TMP/tio-big"
[ "$(printf '%s' '1 h 0 b e N E _' | tio "$TMP/tio-big")" = "200003" ] \
  && ok "e slurp grows past 65536 bytes (200003)" || no "slurp growth"
printf '%s' "$tiocat" | tio "$TMP/tio-big" > "$TMP/tio-big.out"
cmp -s "$TMP/tio-big" "$TMP/tio-big.out" \
  && ok "200003 bytes survive slurp + emit byte for byte" || no "slurp/emit large"
# The emitter auto-flushes at 8192, so 20000 bytes need three writes and no
# help from the caller beyond the final f.
printf '%s' '0→i{65g ←i1\radd→i ←i 20000\rlt1\radd}f' | tio > "$TMP/tio-flush.out"
[ "$(wc -c < "$TMP/tio-flush.out")" = "20000" ] \
  && ok "g auto-flushes when the 8192-byte buffer fills" || no "emit auto-flush"
# Slurping fd 0 needs a stdin of its own — the helper hands its own to the
# compiler — so this case builds the binary first and then feeds it, once from
# a file and once from a PIPE, where a short read is the rule and not the
# exception.  `build/gencode < self/golf2.golfj` is exactly this shape.
printf '%s' '0 e N E _' | python3 tools/codepage.py encode > "$TMP/tioslurp.gb"
cat "$TMP/pre.gb" "$TMP/tio.gb" "$TMP/tioslurp.gb" | "$TMP/golf2" > "$TMP/tps" 2>/dev/null && chmod +x "$TMP/tps"
[ "$("$TMP/tps" < "$TMP/tio-big" 2>/dev/null)" = "200003" ] \
  && ok "e slurp of fd 0 (a redirected file)" || no "slurp stdin"
[ "$(cat "$TMP/tio-big" | "$TMP/tps" 2>/dev/null)" = "200003" ] \
  && ok "e slurp of fd 0 (a pipe: every read comes up short)" || no "slurp pipe"
# Writing a file: open with w=1 (O_WRONLY|O_CREAT|O_TRUNC, 0644) and point the
# emitter at the fd by storing it in the library's cell (REGISTRY.md §3).
printf '%s' '2 h 1 b 5177520\store 79g 75g 10g f' | tio "$TMP/tio-in" "$TMP/tio-out" >/dev/null 2>&1
[ "$(cat "$TMP/tio-out" 2>/dev/null)" = "OK" ] \
  && ok "b open(w=1) creates a file the emitter writes into" || no "open for writing"
# argv, bounds-checked: h answers 0 past the end instead of reading envp.
[ "$(printf '%s' '9 h N E 1 h?N E' | tio one two)" = "$(printf '0\n111')" ] \
  && ok "h argv[i], and 0 for i >= argc" || no "argv helper"
# The error policy, end to end: a missing file is a message on fd 2 and status
# 1, not a 0 length that quietly produces an empty artifact.
printf '%s' '1 h 0 b _ “not reached“O' | python3 tools/codepage.py encode > "$TMP/tiodie.gb"
cat "$TMP/pre.gb" "$TMP/tio.gb" "$TMP/tiodie.gb" | "$TMP/golf2" > "$TMP/tpd" 2>/dev/null && chmod +x "$TMP/tpd"
tiomsg=$("$TMP/tpd" "$TMP/no-such-file-here" 2>&1 >/dev/null); tiost=$?
[ "$tiost" = 1 ] && [ "$tiomsg" = "tio: cannot open file for reading" ] \
  && ok "a die: open of a missing file -> fd 2 + exit 1" || no "die on open failure"
# X/Y discipline: d and e take a spill frame, so they nest inside a prelude
# looping word the way every scratch-using word must.
[ "$(printf '%s' ':x 65\radd"g;5R′xM S N E f' | tio)" = "$(printf '335\nABCDE')" ] \
  && ok "g inside a map (scratch survives the nesting)" || no "emit in map"
[ "$(printf '%s' ':y“ab“→s 1 ←s4\radd ←s@ d 7;3R′yM S N E' | tio)" = "$(printf 'ababab21')" ] \
  && ok "d inside a map (X/Y frame nests)" || no "write-all in map"

echo "Tool text library (lib/ttext.golfj): byte ranges, compare/find, decimal, hex"
# These words are NOT in the prelude, so the gc helper above cannot see them:
# gtools/build prepends lib/t*.golfj only to programs under gtools/.  Hence gtt,
# the same pipeline with lib/ttext.golfj spliced in between.  A "text buffer"
# here is a raw (addr, len) PAIR on the data stack — what read(2) hands back —
# so a “…“ literal is fed in as ←s 4﹢ (its bytes) plus ←s @ (its 4-byte length
# prefix).  Flags are zero-is-true, like `T` and like `[` itself; not-found and
# bad-digit are -1, which is why every check below prints with the signed Ṅ.
python3 tools/codepage.py encode < lib/ttext.golfj > "$TMP/ttext.gb"
gtt(){ cat "$TMP/pre.gb" "$TMP/ttext.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/p" 2>/dev/null \
         && chmod +x "$TMP/p" && "$TMP/p"; }
# i is-digit, j is-ASCII-letter.  195 is a UTF-8 lead byte: Python's isalpha()
# would call the character it starts a letter, j calls it not one (by design —
# see the divergence note in lib/ttext.golfj's header).
[ "$(printf '%s' '53 i N E 120 i N E 113 j N E 53 j N E 195 j N E' | gtt)" = "$(printf '0\n1\n0\n1\n1')" ] \
  && ok "i is-digit / j is-ASCII-letter (zero-is-true; 0x80+ is not a letter)" || no "i/j classify"
# k is the hex-digit value AND the is-hex-digit test: it is negative for a byte
# that is not one, so `k 0≺` is the flag in the same polarity as i and j.
[ "$(printf '%s' '102 k N E 65 k N E 103 k N E 102 k 0\slt N E 103 k 0\slt N E' | gtt)" = "$(printf '15\n10\n-1\n0\n-1')" ] \
  && ok "k hex-digit value, -1 when it is not one (and is-hex-digit is k 0≺)" || no "k hexval"
# l: a hex PAIR -> one byte.  This is every wave-3 tool's inner loop over
# data/blob.hex and data/codepage.tsv, so both cases and both failures matter.
[ "$(printf '%s' '“a7“→a ←a4\radd l N E “FF“→b ←b4\radd l N E “00“→c ←c4\radd l N E “z0“→d ←d4\radd l N E “0z“→e ←e4\radd l N E' | gtt)" \
   = "$(printf '167\n255\n0\n-1\n-1')" ] \
  && ok "l two hex digits -> a byte (either digit bad -> -1)" || no "l hex pair"
# m: copy n bytes.  The guarded n == 0 case must copy nothing at all.
[ "$(printf '%s' '“abcdef“→s “......“→d ←s4\radd ←d4\radd 3 m ←d O E ←s4\radd ←d4\radd 0 m ←d O E' | gtt)" \
   = "$(printf 'abc...\nabc...')" ] \
  && ok "m copy n bytes (and n == 0 copies none)" || no "m memcpy"
# n: (value, bytes consumed).  "99" with len 2 is a number at the very END of a
# buffer — no terminator to stop on, so only the length may stop it.  "0" is the
# value a "while v != 0" parser loses, and len 0 / a non-digit are the two ways
# a caller learns there was no number here at all.
[ "$(printf '%s' '“123x“→s ←s4\radd 4 n →u N E ←u N E' | gtt)" = "$(printf '123\n3')" ] \
  && ok "n parse decimal -> value + bytes consumed" || no "n decimal"
[ "$(printf '%s' '“99“→s ←s4\radd 2 n →u N E ←u N E “0“→t ←t4\radd 1 n →u N E ←u N E' | gtt)" \
   = "$(printf '99\n2\n0\n1')" ] \
  && ok "n at the very end of a buffer, and n of \"0\"" || no "n end/zero"
[ "$(printf '%s' '“x9“→s ←s4\radd 2 n →u N E ←u N E ←s4\radd 0 n →u N E ←u N E' | gtt)" \
   = "$(printf '0\n0\n0\n0')" ] \
  && ok "n on a non-digit and on an EMPTY range -> (0, 0)" || no "n empty"
# o: unsigned decimal INTO a buffer.  The prelude's Ṅ can do neither of these —
# it writes to fd 1, and it is signed, so it renders 2^64-1 as "-1".
[ "$(printf '%s' '“......“→b 0 ←b4\radd o N E ←b O E “......“→c 90210 ←c4\radd o N E ←c O E' | gtt)" \
   = "$(printf '1\n0.....\n5\n90210.')" ] \
  && ok "o format decimal into a buffer -> bytes written (0 -> \"0\")" || no "o format"
# The largest value these words support, both ways: 2^64-1 does not fit a GOLF
# literal, so it can only get onto the stack through n — and only o can print it.
[ "$(printf '%s' '“18446744073709551615“→s ←s4\radd ←s@ n →u “                    “→b ←b4\radd o →c ←b O E ←c N E ←u N E' | gtt)" \
   = "$(printf '18446744073709551615\n20\n20')" ] \
  && ok "n/o round-trip 18446744073709551615 (the largest value supported)" || no "n/o u64 max"
# p reads both ways: "starts with" and, at equal lengths, "these are equal".  A
# needle longer than the haystack is 1 WITHOUT reading past the end, which is
# what makes it safe to sweep to a buffer's last byte; an empty needle is 0.
[ "$(printf '%s' '“hello world“→s “hello“→t ““→e
←s4\radd 11 ←t4\radd ←t@ p N E ←s4\radd 11 ←s4\radd 5 p N E ←s4\radd 5 ←t4\radd 5 p N E
←s4\radd 3 ←t4\radd ←t@ p N E ←s4\radd 11 ←e4\radd ←e@ p N E ←s4\radd 0 ←e4\radd 0 p N E' | gtt)" \
   = "$(printf '0\n0\n0\n1\n0\n0')" ] \
  && ok "p starts-with / range-equal (short haystack 1, empty needle 0)" || no "p compare"
[ "$(printf '%s' '“hello world“→s “world“→t “hellp“→v ←s4\radd 11 ←t4\radd 5 p N E ←s4\radd 5 ←v4\radd 5 p N E' | gtt)" \
   = "$(printf '1\n1')" ] \
  && ok "p says no (and stops at the first differing byte)" || no "p mismatch"
# q: the byte finder.  0 is a legitimate answer, so absent must be -1, not 0.
[ "$(printf '%s' '“hello world“→s ←s4\radd 11 108 q N E ←s4\radd 11 100 q N E ←s4\radd 11 122 q N E ←s4\radd 0 104 q N E' | gtt)" \
   = "$(printf '2\n10\n-1\n-1')" ] \
  && ok "q find a byte (absent -1, EMPTY range -1)" || no "q find byte"
# r: the sequence finder, p in a sweep.  It must find a needle that is NOT at
# offset 0 — the bug that a stop flag of the wrong polarity hides perfectly.
[ "$(printf '%s' '“abcabd“→w “abd“→x “abc“→y ““→e
←w4\radd 6 ←x4\radd 3 r N E ←w4\radd 6 ←y4\radd 3 r N E
←w4\radd 6 “zz“→z ←z4\radd 2 r N E ←w4\radd 2 ←x4\radd 3 r N E ←w4\radd 6 ←e4\radd 0 r N E' | gtt)" \
   = "$(printf '3\n0\n-1\n-1\n0')" ] \
  && ok "r find a sequence (late hit, absent -1, over-long -1, empty 0)" || no "r find seq"
# Re-entrancy.  These words hold their state in the prelude's s0..s7 under an
# X/Y spill frame, so they may be called from inside a €map — and r calls p in
# its inner loop, which is the same property one level down.
[ "$(printf '%s' '“hello world“→s :z _ ←s4\radd 11 111 q ; 5R\refz M Q E :c _ ←s4\radd 11 “world“→t ←t4\radd 5 r ; 5R\refc M Q E 100R S N E' | gtt)" \
   = "$(printf '4 4 4 4 4 \n6 6 6 6 6 \n4950')" ] \
  && ok "ttext words nest inside €map (X/Y frame; prelude scratch survives)" || no "ttext re-entrancy"
# The thing the library exists for: one real record of data/blob.hex, decoded
# with these words alone.  "A7 07 58 5A 5E 5F 0F 05 50" is ⎈ \sys's own
# template — key 0xA7, seven body bytes — so the count l reports must agree with
# the length byte the record declares.
[ "$(printf '%s' '“A7 07 58 5A 5E 5F 0F 05 50“→s ←s@ 1\radd 3/→z ←s4\radd l N E ←s4\radd 3\radd l N E ←z 2\rsub N E' | gtt)" \
   = "$(printf '167\n7\n7')" ] \
  && ok "a real data/blob.hex record: key 167, 7 declared, 7 pairs decoded" || no "blob.hex record"
# The -1 marker survives a →x/←x round trip.  It did NOT while W8 was being
# built: the bank was four bytes per name and ←x zero-extended, so `q →x ←x 0≺`
# saw 4294967295, never took its not-found branch, and a loop bound derived from
# it ran about four billion times.  W8A/M3W widened the bank to eight bytes and
# made ←x a full 64-bit load, which fixed it at the source.  Kept as a
# REGRESSION test rather than deleted: every ttext word that reports "not found"
# does it with -1, and narrowing the bank again would break all of them at once,
# silently and far from the change.
[ "$(printf '%s' '“abc“→s ←s4\radd 3 122 q N E ←s4\radd 3 122 q →x ←x N E' | gtt)" \
   = "$(printf '%s\n%s' -1 -1)" ] \
  && ok "not-found -1 survives a →x/←x round trip (needs M3W's 64-bit bank)" || no "-1 through a variable"

echo "Tool library lib/tutf.golfj (M-TOOL): data/codepage.tsv as an in-memory table"
python3 tools/codepage.py encode < lib/tutf.golfj > "$TMP/tutf.gb" 2>/dev/null \
  && ok "encode lib/tutf.golfj" || no "encode lib/tutf.golfj"
# prelude + tutf + program.  The program source arrives on gt's stdin (the
# process substitution reads it), and the compiled binary is then handed the
# real data/codepage.tsv -- `t` takes a BUFFER, not a path, so the table library
# is testable with no file I/O and no dependency on lib/tio.golfj.
gt(){ cat "$TMP/pre.gb" "$TMP/tutf.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/tup" 2>/dev/null \
        && chmod +x "$TMP/tup" && "$TMP/tup" < data/codepage.tsv; }
# Every case first slurps stdin into a heap buffer and hands `t` (buf len); `t`
# leaves the record count, which the lookup cases drop with `_`.  `\gets` is
# `\get` + `s`, the longest-known-mnemonic-prefix rule doing exactly what the
# \sqr48 case below tests.
TL='5000A\setb\getb\setp{(\setc\getc 0\eq[\getc\getp,\getp\inc\setp]\getc 0\eq}\getb\getp\getb\rsub t'
CPY="import sys;sys.path.insert(0,'tools');import codepage as c"
[ "$(printf '%s' "$TL N E" | gt)" = "$(python3 -c "$CPY;print(len(c.all_rows()))")" ] \
  && ok "t parses every row of data/codepage.tsv" || no "t record count"
# A multi-byte glyph, matched on the RAW byte stream with no UTF-8 decoding:
# E2 8A 95 is ⊕, i.e. \inc = 0x81 = 129, three bytes consumed.
[ "$(printf '%s' "$TL _ 4A\setq 226\getq,138\getq1\radd,149\getq2\radd,\getq\getq3\radd v\setk\setj\getj N 32)\getk N E" | gt)" = "129 3" ] \
  && ok "v: glyph ⊕ -> 0x81, 3 bytes" || no "v multi-byte glyph"
# ...and the same word answers for the five glyphs that ARE ASCII (~ $ | = >).
# codepage.encode consults the glyph table BEFORE the ASCII passthrough, so a
# port must call v first even though today the two agree.
[ "$(printf '%s' "$TL _ 4A\setq 126\getq,\getq\getq1\radd v\setk\setj\getj N 32)\getk N E" | gt)" = "126 1" ] \
  && ok "v: ASCII glyph ~ -> 0x7E, 1 byte" || no "v ASCII glyph"
# The window is honoured: two thirds of ⊕ is not ⊕, so nothing may match.
[ "$(printf '%s' "$TL _ 4A\setq 226\getq,138\getq1\radd,\getq\getq2\radd v\setk_\getk N E" | gt)" = "0" ] \
  && ok "v: a glyph truncated by e does not match" || no "v window"
# LONGEST KNOWN MNEMONIC PREFIX, the rule the whole encoder hangs on: the alpha
# run "sqrp" is \sqr (0x83 = 131) and then the word p -- three letters, not a
# failure, exactly as \sqr48 is \sqr then 48.
[ "$(printf '%s' "$TL _ \strsqrp\str\setj\getj4\radd\getj4\radd\getj@\radd w\setk\setj\getj N 32)\getk N E" | gt)" = "131 3" ] \
  && ok "w: \\sqrp -> \\sqr 0x83, 3 letters (longest prefix)" || no "w longest prefix"
# An encode-only LIB row: \range and ⍳ both encode to the call byte of the
# letter word R, 0x52 = 82.
[ "$(printf '%s' "$TL _ \strrange\str\setj\getj4\radd\getj4\radd\getj@\radd w\setk\setj\getj N 32)\getk N E" | gt)" = "82 5" ] \
  && ok "w: \\range -> 0x52 (a letter-keyed LIB row still encodes)" || no "w encode-only row"
# ...but 0x52 must NOT decode back to ⍳.  That is the asymmetry the mode column
# exists for: a low byte could equally be a *user* word named R.
[ "$(printf '%s' "$TL _ 82 x\setk_\getk N 32)82 y\setk_\getk N E" | gt)" = "0 0" ] \
  && ok "x/y: 0x52 is E- and does not decode" || no "x/y encode-only row"
# ⎈ \sys 0xA7 = 167, the last M4 slot and wave 8's own op: >= 0x80, so ED, so it
# encodes from its mnemonic and decodes to both glyph (E2 8E 88) and mnemonic.
[ "$(printf '%s' "$TL _ \strsys\str\setj\getj4\radd\getj4\radd\getj@\radd w\setk\setj\getj N 32)\getk N E" | gt)" = "167 3" ] \
  && ok "w: \\sys -> 0xA7" || no "w sys"
[ "$(printf '%s' "$TL _ 167 x\setk\setj\getk N 0\setm\getk 0\eq[{32)\getj\getm\radd?N\getm\inc\setm\getm\getk\eq}]E 167 y\setk\setj 0\setm\getk 0\eq[{\getj\getm\radd?)\getm\inc\setm\getm\getk\eq}]E" | gt)" = "$(printf '3 226 142 136\nsys')" ] \
  && ok "x/y: 0xA7 decodes to ⎈ and to \\sys" || no "x/y sys"
# All 256 bytes at once, against the oracle: total glyph + mnemonic bytes over
# every byte codepage.decode would spell out.  Grows with the table on its own.
[ "$(printf '%s' "$TL _ 0\seti 0\setn{\geti x\setk_\getn\getk\radd\setn \geti y\setk_\getn\getk\radd\setn \geti\inc\seti\geti 256\eq}\getn N E" | gt)" \
  = "$(python3 -c "$CPY;print(sum(len(c.BYTE2GLYPH[b].encode())+len(c.BYTE2MNEM[b]) for b in range(256) if b>=128 and b in c.BYTE2GLYPH))")" ] \
  && ok "x/y agree with codepage.py over all 256 bytes" || no "x/y whole byte space"

# @@ W8-TOOLS @@


echo "Capstone: lists + higher-order + vectorization + strings + variables together"
CAPOUT=$(printf '30\n14\n5\nKhoor')
tools/golfc -j examples/capstone.golfj "$TMP/cap" 2>/dev/null
[ "$("$TMP/cap" 2>/dev/null)" = "$CAPOUT" ] && ok "golfc examples/capstone.golfj" || no "capstone.golfj"
[ "$(oracle capstone)" = "$CAPOUT" ] \
  && ok "oracle: capstone.golfj behaves identically" || no "oracle capstone.golfj"

# W7B ------------------------------------------------ legacy spellings -------
# W7B rewrote the capstone to let the bare polymorphic + and * do the looping.
# The forms it dropped are not deprecated — they are how a list meets any
# function that is NOT one of the five hooked operators — so the pre-M-VEC
# capstone is kept verbatim as examples/legacy_capstone.golfj and pinned here.
# The two files are the same program written two ways; the binding assertion is
# that they print the same bytes, not merely that each prints something.
echo "Legacy spellings (W7B): the explicit forms the capstone shrank away from"
tools/golfc -j examples/legacy_capstone.golfj "$TMP/lcap" 2>/dev/null
[ "$("$TMP/lcap" 2>/dev/null)" = "$CAPOUT" ] \
  && ok "golfc examples/legacy_capstone.golfj" || no "legacy_capstone.golfj"
[ "$("$TMP/lcap" 2>/dev/null)" = "$("$TMP/cap" 2>/dev/null)" ] \
  && ok "the shrunken capstone prints exactly what the explicit spellings did" || no "capstone vs legacy output"
[ "$(oracle legacy_capstone)" = "$CAPOUT" ] \
  && ok "oracle: legacy_capstone.golfj behaves identically" || no "oracle legacy_capstone.golfj"
# ⊞ zip-with a ′atom quotation, and broadcast hand-built from a variable, a
# closure word and ′f€ — line 2 and line 4 of the old capstone, on their own.
[ "$(printf '%s' '4R4R\ref*ZSNE'          | gc)" = "14" ] \
  && ok "legacy: ⊞ zip-with ′* still dots two lists"  || no "legacy zip"
[ "$(printf '%s' '3→k:f←k+;“Hello“U′fMJE' | gc)" = "Khoor" ] \
  && ok "legacy: closure + ′f€ still Caesar-shifts a string" || no "legacy closure map"
[ "$(printf '%s' '“Hello“U\ref\incMJE'    | gc)" = "Ifmmp" ] \
  && ok "legacy: ′⊕€ still maps an atom over a string" || no "legacy atom map string"
# And the shrink is real, measured on the code page rather than on the prose:
# encode drops every #-comment, and neither of these two programs contains a
# significant space (no space-separated literals, no space inside a “...“), so
# deleting the remaining layout whitespace leaves exactly the op bytes.
opbytes(){ python3 tools/codepage.py encode < "$1" | tr -d '[:space:]' | wc -c; }
W7BNEW=$(opbytes examples/capstone.golfj)
W7BOLD=$(opbytes examples/legacy_capstone.golfj)
[ "$W7BNEW" -lt "$W7BOLD" ] \
  && ok "capstone is $W7BNEW op bytes, down from $W7BOLD" || no "capstone did not shrink ($W7BNEW vs $W7BOLD)"
# W7B -------------------------------------------------------------------------

# @@ W8-VARS @@
# W8A ------------------------------------------------------------- M3W -------
echo "64-bit variable bank (M3W): →x / ←x round-trip a full 64-bit value"
# The bank at 0x4E0000 was 4 bytes per name and ←x was a `mov eax`, so a wide
# value came back truncated and zero-extended: 4294967296→x←x printed 0 and
# 0 5-→x←x printed 4294967291.  Stride 4 -> 8 plus a REX.W on both templates,
# in self/golf2.golfj AND mkblob2's v1-GOLF seed cases AND boot/golfref.py.
[ "$(printf '%s' '4294967296→x←xṄ␤' | gc)" = "4294967296" ] \
  && ok "2^32 survives →x/←x (was 0)"            || no "wide value through the bank"
[ "$(printf '%s' '0 5-→x←xṄ␤' | gc)" = "-5" ] \
  && ok "-5 survives →x/←x (was 4294967291)"     || no "negative through the bank"
[ "$(printf '%s' '9007199254740991→x←x1+Ṅ␤' | gc)" = "9007199254740992" ] \
  && ok "2^53-1 survives the bank and still increments" || no "2^53 through the bank"
# A list value is an address, and after M3W a tag bit anywhere above bit 31
# would survive it too — which is why NEXT_STEPS puts this before any tag work.
[ "$(printf '%s' '5⍳→a←aTṄ␤←a⍕␤' | gc)" = "$(printf '0\n0 1 2 3 4 ')" ] \
  && ok "a list address round-trips and still classifies as a list" || no "list through the bank"
# Two names must not overlap at the wider stride: 8*'a' and 8*'b' are 8 apart,
# so a full-width store to one may not touch the other.
[ "$(printf '%s' '4294967295→a4294967294→b←aṄ␤←bṄ␤' | gc)" = "$(printf '4294967295\n4294967294')" ] \
  && ok "adjacent names keep their own 8-byte cells"   || no "bank stride overlap"
[ "$(printf '%s' '7→a3→b←a←b+←a←b-*Ṅ10)' | gc)" = "40" ] \
  && ok "regression: (a+b)*(a-b) is still 40"    || no "M3 regression"
# The ENCODING, not just the value: →x is `pop rax; mov [bank+8*'x'], rax` and
# ←x is `mov rax,[bank+8*'x']; push rax`.  'x' is 120, so the cell is
# 0x4E0000+960 = 0x4E03C0 -> c0034e00 little-endian.
w8enc(){ printf '%s' "$1" | python3 tools/codepage.py encode | "$TMP/golf2" 2>/dev/null \
           | od -An -tx1 -v | tr -d ' \n'; }
case "$(w8enc '5→x←x)')" in
  *5848890425c0034e00*) ok "→x is pop rax; mov [0x4E03C0], rax (REX.W, stride 8)";;
  *)                    no "→x encoding";; esac
case "$(w8enc '5→x←x)')" in
  *488b0425c0034e0050*) ok "←x is mov rax,[0x4E03C0]; push rax (REX.W, stride 8)";;
  *)                    no "←x encoding";; esac
# Differential: the oracle transcribes the same two cases, so it must agree byte
# for byte and not merely behave the same.
printf '%s' '5→x←x 4294967296→y←y_)' | python3 tools/codepage.py encode > "$TMP/w8a.src"
"$TMP/golf2" < "$TMP/w8a.src" > "$TMP/w8a.g2" 2>/dev/null
python3 boot/golfref.py < "$TMP/w8a.src" > "$TMP/w8a.ref" 2>/dev/null
cmp -s "$TMP/w8a.g2" "$TMP/w8a.ref" \
  && ok "oracle: identical bytes for a program using → and ←" || no "oracle var-bank bytes"
# W8A --------------------------------------------------------------------------
# W8B ---------------------------------------------------------- M-CHAIN2 ------
echo "Chain definitions (M-CHAIN2): ⊚name f g h; is the train, without the ′s"
# ⊚ (0xB0) is a compiler prefix, not a template: it opens a definition whose body
# is a list of LINKS.  The link count decides the shape — 1 is a call, 2 are two
# calls, 3 are ′f ′g ′h ⑂, more are the fork then plain calls — so nothing is
# needed at run time that ⑂ did not already provide.
[ "$(printf '%s' '\chainm∑≢÷;5⍳mṄ␤' | gc)" = "2" ] \
  && ok "3 links: mean of ⍳5 = ÷(∑, ≢)"          || no "chain fork"
[ "$(printf '%s' '\chains∑;5⍳sṄ␤' | gc)" = "10" ] \
  && ok "1 link: a plain call"                   || no "chain 1 link"
[ "$(printf '%s' '\chaind∑\dbl;5⍳dṄ␤' | gc)" = "20" ] \
  && ok "2 links: ⊗(∑ x) — atop"                 || no "chain 2 links"
[ "$(printf '%s' '\chainq∑≢÷\dbl;5⍳qṄ␤' | gc)" = "4" ] \
  && ok "4 links: the fork, then the rest in turn" || no "chain 4 links"
[ "$(printf '%s' '\chainz;7zṄ␤' | gc)" = "7" ] \
  && ok "0 links: the identity"                  || no "chain 0 links"
# THE claim of the milestone: the sugar is not a new mechanism, it is the same
# bytes.  Compile both spellings of mean and require identical binaries.
printf '%s' '\chainm∑≢÷;5⍳mṄ␤'   | python3 tools/codepage.py encode > "$TMP/w8b.sugar"
printf '%s' ':m\ref∑\ref≢\ref\sdv\fork;5⍳mṄ␤' | python3 tools/codepage.py encode > "$TMP/w8b.expl"
cat "$TMP/pre.gb" "$TMP/w8b.sugar" > "$TMP/w8b.s.src"; cat "$TMP/pre.gb" "$TMP/w8b.expl" > "$TMP/w8b.e.src"
"$TMP/golf2" < "$TMP/w8b.s.src" > "$TMP/w8b.s.bin" 2>/dev/null
"$TMP/golf2" < "$TMP/w8b.e.src" > "$TMP/w8b.e.bin" 2>/dev/null
cmp -s "$TMP/w8b.s.bin" "$TMP/w8b.e.bin" \
  && ok "⊚m∑≢÷; compiles to exactly the bytes of :m′∑′≢′÷⑂;" || no "chain sugar bytes"
# A chain link may be an ATOM as well as a word — ÷ above is one, and ′ auto-
# wraps it in a thunk.  Here every link is an atom: ⊗ ⊕ then ∣ (mod).
[ "$(printf '%s' '\chainr\dbl\inc\smd;7rṄ␤' | gc)" = "6" ] \
  && ok "links may be atoms (⊗ ⊕ ∣ over 7 = 14 mod 8)" || no "chain atom links"
# A chain is an ordinary word: it can be ′-referenced, mapped, and called from
# another chain.  Means of [0,1] and [0,1,2,3] are 0 and 1.
[ "$(printf '%s' '\chainm∑≢÷;3⍶2&\store2⍳&8\radd\store4⍳&16\radd\store\refm€⍕␤' | gc)" = "0 1 " ] \
  && ok "a chain word maps like any other"       || no "chain in map"
# The explicit spelling is not deprecated and still works, and ′ — whose body
# became the shared word X — is unchanged for words and for atoms alike.
[ "$(printf '%s' '5⍳\ref∑\ref≢\ref\sdv\forkṄ␤' | gc)" = "2" ] \
  && ok "regression: the explicit ′∑′≢′÷⑂ fork"  || no "explicit fork"
[ "$(printf '%s' ':d\dbl;3\refd\exec48+)' | atom)" = "6" ] \
  && ok "regression: ′word through the shared X" || no "ref word via X"
[ "$(printf '%s' '3 4\ref+\exec48+)' | atom)" = "7" ] \
  && ok "regression: ′atom auto-wrapping through the shared X" || no "ref atom via X"
# Only tokens no earlier case claims become links, so a chain body is not a
# general body: the structural bytes keep their ordinary meanings and do not
# count as links.  Pinned on the BYTES, since the resulting word is nonsense to
# run — a literal is emitted where it stands, while links are deferred — but it
# must be exactly the nonsense the explicit spelling gives, or a future case
# reordering has changed the language silently.
printf '%s' '\chainc∑7≢÷;'   | python3 tools/codepage.py encode > "$TMP/w8b.dig1"
printf '%s' ':c7\ref∑\ref≢\ref\sdv\fork;' | python3 tools/codepage.py encode > "$TMP/w8b.dig2"
cat "$TMP/pre.gb" "$TMP/w8b.dig1" > "$TMP/w8b.d1.src"; cat "$TMP/pre.gb" "$TMP/w8b.dig2" > "$TMP/w8b.d2.src"
"$TMP/golf2" < "$TMP/w8b.d1.src" > "$TMP/w8b.d1.bin" 2>/dev/null
"$TMP/golf2" < "$TMP/w8b.d2.src" > "$TMP/w8b.d2.bin" 2>/dev/null
cmp -s "$TMP/w8b.d1.bin" "$TMP/w8b.d2.bin" \
  && ok "a digit in a chain body is a literal in place, and is not a link" || no "chain digit"
tools/golfc -j examples/chaindef.golfj "$TMP/chd" 2>/dev/null
[ "$("$TMP/chd" 2>/dev/null)" = "$(printf '2\n10\n20\n4')" ] \
  && ok "golfc examples/chaindef.golfj" || no "chaindef.golfj"
[ "$(oracle chaindef)" = "$(printf '2\n10\n20\n4')" ] \
  && ok "oracle: chaindef.golfj behaves identically" || no "oracle chaindef.golfj"
"$TMP/golf2" < <(cat "$TMP/pre.gb" <(python3 tools/codepage.py encode < examples/chaindef.golfj)) > "$TMP/chd.g2" 2>/dev/null
python3 boot/golfref.py < <(cat "$TMP/pre.gb" <(python3 tools/codepage.py encode < examples/chaindef.golfj)) > "$TMP/chd.ref" 2>/dev/null
cmp -s "$TMP/chd.g2" "$TMP/chd.ref" \
  && ok "oracle: identical bytes for a program of chain definitions" || no "oracle chain bytes"
# W8B --------------------------------------------------------------------------

echo "Resource registry (REGISTRY.md): op bytes, mnemonics and glyphs stay disjoint"
python3 tools/codepage.py check \
  && ok "codepage invariants (bytes/mnemonics/glyphs)" || no "codepage invariants (bytes/mnemonics/glyphs)"

echo
echo "v1 bootstrap seed: $(wc -c < self/seed.golf) bytes (self/seed.golf)"
echo "v2 compiler:       $(wc -c < self/golf2.golf) bytes (self/golf2.golf, from self/golf2.golfj)"
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
