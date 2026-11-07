#!/usr/bin/env bash
# Expanded GOLF (v2) test suite + bootstrap ladder.
#
#   ../SEEDS  --pins------->  v1c      (the frozen minimal compiler, a release binary)
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
EXP=$(pwd); SEED_ROOT=$(cd "$EXP/.." && pwd)
. "$EXP/tools/seed.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "Regenerate the generated compiler sources (self/seed.golf, self/golf2.golf)"
python3 tools/mkblob2.py 2>&1 | sed 's/^/  /'

echo "Bootstrap ladder"
ensure_seed v1c && ok "v1c (pinned release binary, ../SEEDS)" || { no "v1c unavailable"; exit 1; }
"$SEED" < self/seed.golf > "$TMP/seed" 2>/dev/null && chmod +x "$TMP/seed" \
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
"$TMP/golf2" < examples/v1/hello.golf > "$TMP/h" 2>/dev/null && chmod +x "$TMP/h"
[ "$("$TMP/h" 2>/dev/null)" = "Hello, world!" ] && ok "golf2 compiles v1 hello.golf" || no "golf2 hello"
"$TMP/golf2" < examples/v1/fizzbuzz.golf > "$TMP/fb" 2>/dev/null && chmod +x "$TMP/fb"
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
# The arena is BOUNDED, and the bound is enforced.  0x4D0000..0x4DFFFF is 65536
# bytes = EXACTLY 1680 thunks at 39 bytes each; the 1681st would start at
# 0x4E0017, which is inside the user variable bank at 0x4E0000 (REGISTRY.md §3).
# Until this check existed, a program that composed in a loop overwrote its own
# →x/←x cells with machine code and ran on to exit 0 — silent corruption of user
# data.  Nothing can be freed (a thunk's address may have escaped anywhere), so
# ∘ stops instead.  The canary below is a variable whose cell the overrun reaches.
arena(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" \
           > "$TMP/ar" 2>/dev/null; chmod +x "$TMP/ar"
         "$TMP/ar" >"$TMP/ar.out" 2>"$TMP/ar.err"; echo "$?"; }
compose_n(){ printf ':d\\dbl;:i\\inc;1234\\setv 0{\\refd\\refi\\comp_ 1\\radd"%s\\rlt1\\radd}_ \\getv N E' "$1"; }
[ "$(compose_n 1680 | arena)" = "0" ] && [ "$(cat "$TMP/ar.out")" = "1234" ] \
  && ok "1680 composes fit the arena exactly, and the canary is intact" || no "arena 1680"
[ "$(compose_n 1681 | arena)" = "1" ] \
  && ok "the 1681st compose exits 1 instead of writing into the variable bank" || no "arena 1681 status"
[ "$(cat "$TMP/ar.err")" = "GOLF: compose arena exhausted" ] \
  && ok "... and says so on fd 2, leaving fd 1 (the program's output) clean" || no "arena 1681 message"
[ ! -s "$TMP/ar.out" ] && ok "... with nothing written to fd 1" || no "arena 1681 stdout"
# Why the arena is not simply brk-grown, the way the list heap was at M-MEM:
# brk memory is R+W but NOT executable, and a thunk is code.  (A bare 0xC3 is a
# valid GOLF callee — ⍎ does `call rax` and `ret` pops that address right back —
# so this distinguishes "cannot execute" from "bad address".)
[ "$(printf '%s' '1\alloc\seth 195\geth, \geth?N E' | gc)" = "195" ] \
  && ok "a heap byte written through the allocator reads back" || no "heap rw"
[ "$(printf '%s' '1\alloc\seth 195\geth, \geth\exec' | arena)" != "0" ] \
  && ok "... but calling it dies: brk memory is not executable, so the arena cannot grow" \
  || no "heap nx"
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
# mapped word that itself loops (spill frames are 64 bytes now, 4096 deep since W10-C).
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
# The prelude's init publishes what the kernel gave into A's base/span cells.
# The base is ASLR-shifted (observed anywhere from ~0x1C00000 to ~0x3B000000),
# so only its relation to the static image is assertable — never its value.
# W9-2A/M-TAG2: a list VALUE is addr | 2^48, so the address is masked out with
# (v<<16)>>16 before it is compared against the window.
[ "$(printf '%s' '0 5177400@\rlt1\radd N E' | gc)" = "0" ] \
  && ok "heap span cell is non-zero (brk handed back the initial chunk)" || no "brk heap span"
[ "$(printf '%s' '5⍳16\shl16> 5177396@\rsub 5177400@\rlt1\radd N E' | gc)" = "0" ] \
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
# The return stack runs from RSTACK_TOP down to the top of the W9-2C guard page
# (RSTACK_FLOOR, one page above the 0x4F bank), 8 bytes a frame; the docs quote
# it in thousands.
print("frames", (mkblob2.RSTACK_TOP - mkblob2.RSTACK_FLOOR) // 8 // 1000)
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

und(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) > "$TMP/u.src"
       "$TMP/golf2" < "$TMP/u.src" > "$TMP/u.out" 2>"$TMP/u.err"; echo "$?"; }
echo "Per-call locals (M-FRAME): ⊡name … ; owns a frame, ⇒x / ⇐x reach its slots"
# The bug this fixes: the variable bank behind →x/←x is GLOBAL, one cell per
# name for the whole program, so a recursive word's frames overwrite each other
# and the answer is quietly wrong.  sum-1..n is the shortest thing that shows it.
[ "$(printf '%s' '\dlocs"0-[_0^]\lseta\lgeta1-s\lgeta+;10sN E' | gc)" = "55" ] \
  && ok "recursion through a local is correct at depth (sum 1..10 = 55)" || no "local recursion"
[ "$(printf '%s' ':g"0-[_0^]\setn\getn1-g\getn+;10gN E' | gc)" = "10" ] \
  && ok "... and the global bank still gives the old wrong answer (10)" || no "global recursion regression"
# Eight one-letter locals, a..h, each its own cell.  Pushed 1..8, so a=8 (popped first) and
# h=1 (popped last); a+h is 9 only if no two names share a slot.
[ "$(printf '%s' '\dlocf\lseta\lsetb\lsetc\lsetd\lsete\lsetf\lsetg\lseth\lgeta\lgeth+;1 2 3 4 5 6 7 8 fN E' | gc)" = "9" ] \
  && ok "all eight slots a..h are distinct" || no "eight slots"
# A frame belongs to the CALL, so locals nest through higher-order words.
[ "$(printf '%s' '\dlocd\lseta\lgeta\lgeta+;3R\refdMQE' | gc)" = "0 2 4 " ] \
  && ok "a ⊡ word works as a mapped function" || no "local in map"
# `^` is why ⊡ is a separate definition form: an early return has to release the
# frame, and a single-pass compiler cannot size one per definition (see
# tools/mkblob2.py's M-FRAME note).  Both exits of the same word:
[ "$(printf '%s' '\dlocc\lseta\lgeta0\slt1+[42^]\lgeta;0 5-cN E' | gc)" = "42" ] \
  && ok "^ inside a ⊡ word releases the frame and returns" || no "caret in frame word"
[ "$(printf '%s' '\dlocc\lseta\lgeta0\slt1+[42^]\lgeta;7cN E' | gc)" = "7" ] \
  && ok "... and the ordinary exit of that same word still works" || no "frame word normal exit"
# Opt-in is the whole design: a `:` word must be untouched, or 50,000-deep
# recursion (asserted above) would not still pass.  A ⊡ frame is a cell per
# local named (M-FRAME2), plus the return address.
[ "$(printf '%s' ':r"[^]\dec r;50000 r N E' | gc)" = "0" ] \
  && ok "a plain : word is unchanged — 50,000 deep still works" || no "opt-in regression"
# Unchecked, ⇒z is displacement 200 — a NEGATIVE disp8 (-56), landing in the
# frame of a word not yet called — and ⇒A wraps to 0 and silently aliases slot a.
[ "$(printf '%s' '\dlocf\lsetz;1fN' | und)" = "2" ] \
  && [ "$(cat "$TMP/u.err")" = "GOLF: local out of range z" ] \
  && ok "a slot name past h is refused, not silently wrapped" || no "lset range"
[ "$(printf '%s' '\dlocf\lgetA;1fN' | und)" = "2" ] \
  && [ "$(cat "$TMP/u.err")" = "GOLF: local out of range A" ] \
  && ok "... and one before a, which would have aliased slot a" || no "lget range"
tools/golfc -j examples/locals.golfj "$TMP/loc" 2>/dev/null
[ "$("$TMP/loc" 2>/dev/null)" = "$(printf '55\n10\n0 2 4 6 8 \nneg\n0\n7')" ] \
  && ok "golfc examples/locals.golfj" || no "locals.golfj"
[ "$(oracle locals)" = "$(printf '55\n10\n0 2 4 6 8 \nneg\n0\n7')" ] \
  && ok "oracle: locals.golfj behaves identically" || no "oracle locals.golfj"
"$TMP/golf2" < <(cat "$TMP/pre.gb" <(python3 tools/codepage.py encode < examples/locals.golfj)) > "$TMP/loc.g2" 2>/dev/null
python3 boot/golfref.py < <(cat "$TMP/pre.gb" <(python3 tools/codepage.py encode < examples/locals.golfj)) > "$TMP/loc.ref" 2>/dev/null
cmp -s "$TMP/loc.g2" "$TMP/loc.ref" \
  && ok "oracle: identical bytes for a program using locals" || no "oracle locals bytes"

echo "Diagnostics: an undefined word is reported, not compiled to a jump to zero"
# v1's `e` emitted `call rel32` with rel32 = dict[name] - (p+4) without ever
# looking at dict[name].  For a name that was never defined that cell is
# BSS-zero, so the call targeted a wild address: the COMPILE reported success
# and the binary died with SIGSEGV the moment the word was reached.  A word name
# is a single byte, so that was the symptom of every typo — and, since a word
# must be defined before use, of every attempt at mutual recursion.
[ "$(printf '%s' '5qN' | und)" = "2" ] \
  && ok "a call to an undefined word exits 2 instead of emitting the call" || no "undefined word status"
[ "$(cat "$TMP/u.err")" = "GOLF: undefined word q" ] \
  && ok "... naming the offending byte, on fd 2" || no "undefined word message"
[ ! -s "$TMP/u.out" ] \
  && ok "... and no partial binary reaches fd 1" || no "undefined word stdout"
# The forward reference is what mutual recursion needs.  M-DIAG made it exit 2
# naming b; since W10-A a one-byte name may be defined later, like a long one
# (M2), so this now compiles and runs — b's call site is patched by :b.
[ "$(printf '%s' ':a"0-[_0^]1-b;:b"0-[_1^]1-a;5aN' | und)" = "0" ] && [ -z "$(cat "$TMP/u.err")" ] \
  && chmod +x "$TMP/u.out" && [ "$("$TMP/u.out")" = "1" ] \
  && ok "mutual recursion between one-byte words compiles and runs (W10-A)" || no "mutual recursion"
# The check must not fire on anything legitimate: every word the prelude and the
# examples define is defined before use, and an ATOM has a template, so it never
# reaches the dictionary lookup at all.
[ "$(printf '%s' '100\range\sum N E' | und)" = "0" ] && [ -s "$TMP/u.out" ] \
  && ok "a valid program still compiles, exit 0" || no "valid program regression"
[ -z "$(cat "$TMP/u.err")" ] && ok "... with fd 2 silent" || no "valid program stderr"

# Gap-fix waves (W9): one anchor per agent task; each task adds its tests
# directly under its own anchor and nowhere else.  Keep them in order.
# @@ W9-1A-SIGNED @@
echo "W9-1A: ⌈ ⌊ (and ⩌ ⩍) are SIGNED; ⊔ ⊓ stay unsigned"
# Before W9-1A, ⌈ ⌊ compared unsigned (cmovb/cmova): max(-5,3) was -5.
[ "$(printf '%s' '0 5-3\max N E' | gc)" = "3" ]    && ok "⌈ signed: max(-5,3) = 3"   || no "signed max -5 3"
[ "$(printf '%s' '3 0 5-\max N E' | gc)" = "3" ]   && ok "⌈ signed: max(3,-5) = 3"   || no "signed max 3 -5"
[ "$(printf '%s' '0 5-3\min N E' | gc)" = "-5" ]   && ok "⌊ signed: min(-5,3) = -5"  || no "signed min -5 3"
[ "$(printf '%s' '3 0 5-\min N E' | gc)" = "-5" ]  && ok "⌊ signed: min(3,-5) = -5"  || no "signed min 3 -5"
[ "$(printf '%s' '0 5- 0 3-\max N E' | gc)" = "-3" ] && [ "$(printf '%s' '0 5- 0 3-\min N E' | gc)" = "-5" ] \
  && ok "⌈ ⌊ signed with both operands negative" || no "signed max/min both negative"
# The bare scalar template itself (no prelude, so no hook): cmovl / cmovg.
[ "$(printf '%s' '0 5-3\max 48+)' | atom)" = "3" ] && [ "$(printf '%s' '0 5-3\min 53+)' | atom)" = "0" ] \
  && ok "⌈ ⌊ scalar templates are signed without the prelude" || no "bare signed max/min"
[ "$(printf '%s' '0 5-3\vmax N E 0 5-3\vmin N E' | gc)" = "$(printf '3\n-5')" ] \
  && ok "⩌ ⩍ int,int signed" || no "vmax/vmin signed"
[ "$(printf '%s' '5R 2-0\max QE' | gc)" = "0 0 0 1 2 " ] && ok "⌈ list,int: [-2..2] ⌈ 0 = 0 0 0 1 2" || no "vec signed max list,int"
[ "$(printf '%s' '0 5R 2-\min QE' | gc)" = "-2 -1 0 0 0 " ] && ok "⌊ int,list: 0 ⌊ [-2..2]" || no "vec signed min int,list"
[ "$(printf '%s' '5R 2- 5R 3-\max QE 5R 2- 5R 3-\min QE' | gc)" = "$(printf -- '-2 -1 0 1 2 \n-3 -2 -1 0 1 ')" ] \
  && ok "⌈ ⌊ list,list elementwise with negatives" || no "vec signed max/min list,list"
[ "$(printf '%s' '5R 2-0\vmax QE 5R 2-0\vmin QE' | gc)" = "$(printf -- '0 0 0 1 2 \n-2 -1 0 0 0 ')" ] \
  && ok "⩌ ⩍ list,int elementwise signed" || no "vmax/vmin list signed"
# The extremes: d = b-a overflows here, but the compare is a ≻ a+d = a ≻ b, exact.
[ "$(printf '%s' '9223372036854775807 0 9223372036854775807- 1-\vmax N E 9223372036854775807 0 9223372036854775807- 1-\vmin N E' | gc)" \
    = "$(printf -- '9223372036854775807\n-9223372036854775808')" ] \
  && ok "⩌ ⩍ at INT64_MAX vs INT64_MIN" || no "vmax/vmin extremes"
[ "$(printf '%s' '6R 3-0 9-\ref\maxFNE' | gc)" = "2" ] && ok "fold ′⌈ over negatives (seed -9) = 2" || no "fold signed max"
# ⊔ ⊓ stay UNSIGNED — the prelude's pointer math depends on it: -5 is 2^64-5.
[ "$(printf '%s' '0 5-3\rmax N E 0 5-3\rmin N E' | gc)" = "$(printf -- '-5\n3')" ] \
  && ok "⊔ ⊓ still unsigned: rmax(-5,3) = -5, rmin(-5,3) = 3" || no "raw max/min unsigned"
[ "$(printf '%s' '0 5-3\max N E 5R 2-0\min QE' | gref)" = "$(printf '%s' '0 5-3\max N E 5R 2-0\min QE' | gc)" ] \
  && ok "oracle: signed ⌈ ⌊ identical in golfref" || no "oracle signed max/min"

# @@ W9-1B-STRINGS @@
echo "String literals are literal (W9-1B): verbatim UTF-8 between two “, one escape \\“"
[ "$(printf '%s' '“a\nb“O' | gc)" = 'a\nb' ] \
  && ok "“a\\nb“ prints a backslash-n, not a mnemonic error" || no "literal backslash in a string"
[ "$(printf '%s' '“say \“hi\““O' | gc)" = 'say “hi“' ] \
  && ok "\\“ inside a literal is the character “" || no "string escape \\“"
[ "$(printf '%s' '“héllo ⊕ 🗲“O' | gc)" = 'héllo ⊕ 🗲' ] \
  && ok "non-ASCII text and glyphs inside a literal stay their UTF-8 bytes" || no "UTF-8 in a string"
[ "$(printf '%s' '“a # b“O E 7N' | gc)" = "$(printf 'a # b\n7')" ] \
  && ok "# inside a literal is text, not a comment" || no "# in a string"
[ "$(printf '%s' '\strsqr “O“ ⊕\strO' | gc)" = 'sqr  ⊕' ] \
  && ok "\\str opens and closes too; either spelling closes either" || no "\\str delimiters"
printf '%s' '“Ď“O' | python3 tools/codepage.py encode > "$TMP/s8e.out" 2> "$TMP/s8e.err"
[ "$?" = 1 ] && grep -q 'cannot contain byte 0x8E' "$TMP/s8e.err" \
  && ok "a literal whose UTF-8 holds 0x8E (Ď = C4 8E) is an encode error" || no "0x8E in a string accepted"
printf '%s' '“héllo \“x\“ ⊕\\str 1N“#“O' > "$TMP/srt.src"
python3 tools/codepage.py encode < "$TMP/srt.src" > "$TMP/srt.gb"
python3 tools/codepage.py decode < "$TMP/srt.gb" | python3 tools/codepage.py encode | cmp -s - "$TMP/srt.gb" \
  && python3 tools/codepage.py decode -m < "$TMP/srt.gb" | python3 tools/codepage.py encode | cmp -s - "$TMP/srt.gb" \
  && [ "$(python3 tools/codepage.py decode < "$TMP/srt.gb")" = '“héllo \“x\“ ⊕\\str 1N“#“O' ] \
  && ok "decode renders a literal verbatim and round-trips it (glyph and -m form)" || no "string decode round trip"

# @@ W9-1C-REFDIAG @@
echo "Diagnostics: ′name of an undefined name is reported, not wrapped as an atom"
# `X` (the ′ case, and every chain link) read a name with no dictionary entry as
# an ATOM and wrapped its template in a thunk — so `′typo` built a thunk around a
# template that does not exist, the compile reported success, and the binary
# died with SIGILL.  X now checks the blob too and hands a byte that is neither
# to `e`, which is the undefined-word diagnostic already.
[ "$(printf '%s' '3⍳′q€⍕' | und)" = "2" ] \
  && ok "′ of an undefined name exits 2 instead of building a thunk" || no "ref undefined status"
[ "$(cat "$TMP/u.err")" = "GOLF: undefined word q" ] \
  && ok "... with the same message as a plain call, on fd 2" || no "ref undefined message"
[ ! -s "$TMP/u.out" ] && ok "... and no partial binary on fd 1" || no "ref undefined stdout"
[ "$(printf '%s' '⊚mq≢÷;5⍳mṄ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word q" ] \
  && ok "a chain link to an undefined name is reported the same way" || no "chain link undefined"
# Atoms and defined words keep compiling, to the bytes they did before.
[ "$(printf '%s' '3⍳′⊗€⍕' | gc)" = "0 2 4 " ] && ok "′⊗ still auto-wraps the atom"  || no "ref ⊗"
[ "$(printf '%s' '3⍳′²€⍕' | gc)" = "0 1 4 " ] && ok "′² still auto-wraps the atom"  || no "ref ²"
[ "$(printf '%s' '3 4\ref+\exec48+)' | atom)" = "7" ] && ok "′+ still auto-wraps (bare, no prelude)" || no "ref +"
[ "$(printf '%s' ':d2*;3⍳′d€⍕' | gc)" = "0 2 4 " ] && ok "′ of a defined word still pushes its body" || no "ref word"

# @@ W9-1D-REFERENCE @@
echo "Language reference (REFERENCE.md): generated tables, every op byte, tutorial"
# Section 3 of REFERENCE.md is codepage.py's own output, spliced between two
# marker lines; it must be the CURRENT output, or the reference has drifted.
python3 - > "$TMP/w9d.blk" <<'PY'
import sys
sys.path.insert(0, "tools")
import codepage
t = open("REFERENCE.md", encoding="utf-8").read()
a, z = t.find(codepage.REF_BEGIN), t.find(codepage.REF_END)
sys.stdout.write(t[a + len(codepage.REF_BEGIN) + 1:z] if 0 <= a < z else "NO MARKERS")
PY
python3 tools/codepage.py reference | cmp -s - "$TMP/w9d.blk" \
  && ok "REFERENCE.md's generated block = codepage.py reference" \
  || no "REFERENCE.md generated block is stale: python3 tools/codepage.py reference --update REFERENCE.md"
# Every allocated byte (atoms, compiler ops, library words) and every v1 core
# op is named in the file as `0xNN`, so nothing allocated goes undocumented.
w9dmiss=$(python3 - <<'PY'
import sys
sys.path.insert(0, "tools"); sys.path.insert(0, "boot")
import codepage, v1
t = open("REFERENCE.md", encoding="utf-8").read()
bs = {b for b, *_ in codepage.all_rows()} | {ord(k) for k in v1.TEMPLATES}
print(" ".join(f"0x{b:02X}" for b in sorted(bs) if f"`0x{b:02X}`" not in t))
PY
)
[ -z "$w9dmiss" ] && ok "every allocated op byte and v1 op appears in REFERENCE.md" \
  || no "REFERENCE.md does not mention: $w9dmiss"
# Ṅ prints SIGNED decimal (the code page used to say unsigned).
[ "$(printf '%s' '0 1-\num\nl' | gc)" = "-1" ] \
  && python3 tools/codepage.py table | grep -q 'Ṅ .*print signed decimal' \
  && ok "Ṅ prints signed decimal, and the code page says so" || no "Ṅ signed doc/behaviour"
# The tutorial: every ```golfj block between the TUTORIAL markers is followed by
# a ```text block of its exact stdout (trailing spaces ignored).  Compile each
# with the prelude and compare; one assertion covers them all.
rm -rf "$TMP/w9tut"; mkdir -p "$TMP/w9tut"
w9dn=$(python3 - "$TMP/w9tut" <<'PY'
import re, sys
t = open("REFERENCE.md", encoding="utf-8").read()
a, z = t.find("<!-- TUTORIAL BEGIN -->"), t.find("<!-- TUTORIAL END -->")
pairs = re.findall(r"```golfj\n(.*?)```\s*```text\n(.*?)```", t[a:z], re.S) if 0 <= a < z else []
for i, (src, out) in enumerate(pairs, 1):
    open(f"{sys.argv[1]}/{i}.golfj", "w", encoding="utf-8").write(src)
    open(f"{sys.argv[1]}/{i}.out", "w", encoding="utf-8").write(out)
print(len(pairs))
PY
)
w9dbad=""
for f in "$TMP"/w9tut/*.golfj; do
  [ -e "$f" ] || continue
  got=$(gc < "$f" | sed 's/[[:space:]]*$//')
  want=$(sed 's/[[:space:]]*$//' "${f%.golfj}.out")
  [ "$got" = "$want" ] || { w9dbad="$w9dbad $(basename "$f" .golfj)"; no "tutorial example $(basename "$f" .golfj) prints '$got', REFERENCE.md says '$want'"; }
done
[ "$w9dn" -ge 6 ] 2>/dev/null && [ "$w9dn" -le 10 ] && [ -z "$w9dbad" ] \
  && ok "all $w9dn REFERENCE.md tutorial examples compile and print their documented output" \
  || no "tutorial: $w9dn examples extracted (need 6-10), failing:$w9dbad"

# @@ W9-2A-TAG2 @@
echo "M-TAG2: a list value is addr | 2^48; T and the M-VEC filter test the tag, not a range"
# The regression the range test could not pass: the heap BASE, read out of A's
# cell as a plain integer, sat inside [base, base+span) and so was dispatched
# as a list.  It is an int now, and bare + is scalar on it.
[ "$(printf '%s' '5⍳_ 5177396@ 1+ 5177396@ 1\radd≡N E' | gc)" = "-1" ] \
  && ok "the heap base as an INTEGER: bare + is scalar addition" || no "tag2 base int +"
[ "$(printf '%s' '5⍳_ 5177396@ T N E' | gc)" = "1" ] \
  && ok "T: an integer equal to a heap address is an int" || no "tag2 base T"
[ "$(printf '%s' '5⍳16\shl16> T N E' | gc)" = "1" ] \
  && ok "T: a list's untagged address is an int" || no "tag2 raw addr T"
[ "$(printf '%s' '5⍳16\shl16>→a ←a 3* ←a 3\rmul≡N E' | gc)" = "-1" ] \
  && ok "bare * on an untagged heap address is scalar" || no "tag2 raw addr *"
[ "$(printf '%s' '5⍳48>N E' | gc)" = "1" ] \
  && ok "a list value carries the tag: v >> 48 == 1" || no "tag2 tag bit"
[ "$(printf '%s' '0 1-T N E' | gc)" = "1" ] && ok "T: -1 is still an int" || no "tag2 -1"
[ "$(printf '%s' '0 1 63\shl- T N E' | gc)" = "1" ] && ok "T: -2^63 is an int" || no "tag2 min int"
[ "$(printf '%s' '0 1000000000000000-T N E 0 1000000000000000- 7+N E' | gc)" = "$(printf '1\n-999999999999993')" ] \
  && ok "a large negative is an int, and bare + is scalar on it" || no "tag2 big negative"
[ "$(printf '%s' '1 48\shl1\rsub T N E 1 49\shl T N E' | gc)" = "$(printf '1\n1')" ] \
  && ok "T: 2^48-1 and 2^49 are ints (only [2^48, 2^49) is sacrificed)" || no "tag2 edges"
[ "$(printf '%s' '5⍳→x←x T N E ←x Q E ←x 10+Q E' | gc)" = "$(printf '0\n0 1 2 3 4 \n10 11 12 13 14 ')" ] \
  && ok "a list round-trips through →x/←x and still vectorizes" || no "tag2 var round trip"
# Lists of lists: R's result stored as an element stays a tagged list, so it
# indexes, measures and vectorizes like the outer one.
[ "$(printf '%s' '2A 1&\store 3⍳&8\radd\store 1 48\shl| "T N E "0 I T N E "0 I Q E 0 I 100+Q E' | gc)" = "$(printf '0\n0\n0 1 2 \n100 101 102 ')" ] \
  && ok "a list of lists stores and indexes; the inner element is a tagged list" || no "tag2 nested"
[ "$(printf '%s' ':s3⍳;3⍳\refs M "L N E 1 I"L N E ∑N E' | gc)" = "$(printf '3\n3\n3')" ] \
  && ok "map building a list per element (inner lists keep the tag)" || no "tag2 map of lists"
# A hand-built block from A is a raw address: every list word accepts it (the
# masking is idempotent), but it is an INT to T and the bare operators until it
# is tagged with 1 48≪|.
[ "$(printf '%s' '3A 2&\store 5&8\radd\store 6&16\radd\store "S N E "T N E 1 48\shl| 1+Q E' | gc)" = "$(printf '11\n1\n6 7 ')" ] \
  && ok "hand-built list: list words take it raw; tagging it makes it vectorize" || no "tag2 hand-built"

# @@ W9-2B-CHECKS @@
echo "Runtime checks (W9-2B): I bounds, ÷ ∣ divide by zero — message on fd 2, exit 1"
# Before W9-2B `3⍳9⊇Ṅ` printed whatever cell lay past the block (0) and exit 0,
# and `7 0÷` died of SIGFPE (status 136).  w92b runs a prelude program and
# prints its status; stdout and stderr land in $TMP/c.out / $TMP/c.err.
w92b(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/c" 2>/dev/null \
          && chmod +x "$TMP/c" && "$TMP/c" > "$TMP/c.out" 2> "$TMP/c.err"; echo "$?"; }
w92bdied(){ [ "$1" = 1 ] && [ "$(cat "$TMP/c.err")" = "GOLF: $2" ] && [ "$(cat "$TMP/c.out")" = "$3" ]; }
w92bdied "$(printf '%s' '7N E 3R 9 I N E' | w92b)" "index out of range" "7" \
  && ok "3⍳ then ⊇9: exit 1, message on fd 2, only the earlier 7 on fd 1" || no "index past the end"
w92bdied "$(printf '%s' '3R 3 I N E' | w92b)" "index out of range" "" \
  && ok "index == len is out of range" || no "index == len"
w92bdied "$(printf '%s' '3R 0 1- I N E' | w92b)" "index out of range" "" \
  && ok "a negative index is out of range (one unsigned compare)" || no "negative index"
w92bdied "$(printf '%s' '0R 0 I N E' | w92b)" "index out of range" "" \
  && ok "any index into the empty list is out of range" || no "empty-list index"
[ "$(printf '%s' '5R 0 I N E 5R 4 I N E 5R2*3 I N E' | gc)" = "$(printf '0\n4\n6')" ] \
  && ok "valid indexes unchanged (first, last, a computed list)" || no "valid index"
[ "$(printf '%s' '4R\ref\dblM S N E 3R 4R \ref\radd Z Q E 6R V Q E' | gc)" = "$(printf '12\n0 2 4 \n5 4 3 2 1 0 ')" ] \
  && ok "map / zip / reverse (I in their loops) unchanged" || no "loops over I"
w92bdied "$(printf '%s' '7 0\sdv N E' | w92b)" "divide by zero" "" \
  && ok "7 0÷: exit 1 with the message, not SIGFPE" || no "÷ by zero"
w92bdied "$(printf '%s' '5N E 7 0\smd N E' | w92b)" "divide by zero" "5" \
  && ok "7 0∣: exit 1 with the message, earlier output kept" || no "∣ by zero"
w92bdied "$(printf '%s' '7 0\ref\sdv\exec N E' | w92b)" "divide by zero" "" \
  && ok "′÷ (the auto-wrapped thunk) checks too" || no "′÷ by zero"
[ "$(printf '%s' '7 0\sdv' | atom 2>&1; echo "rc=$?")" = "$(printf 'GOLF: divide by zero\nrc=1')" ] \
  && ok "the bare ÷ template checks without the prelude" || no "bare ÷ by zero"
[ "$(printf '%s' '7 2\sdv N E 0 7-2\sdv N E 7 0 2-\sdv N E 0 7- 0 2-\sdv N E' | gc)" = "$(printf -- '3\n-3\n-3\n3')" ] \
  && ok "÷ signed, truncating, unchanged: 7/2 -7/2 7/-2 -7/-2 = 3 -3 -3 3" || no "÷ signs"
[ "$(printf '%s' '7 2\smd N E 0 7-2\smd N E 7 0 2-\smd N E 0 7- 0 2-\smd N E' | gc)" = "$(printf -- '1\n-1\n1\n-1')" ] \
  && ok "∣ signed, sign of the dividend, unchanged: 1 -1 1 -1" || no "∣ signs"
# INT64_MIN ÷ -1 is the other x86 #DE.  Defined, wrapping: ÷ is INT64_MIN, ∣ is 0.
[ "$(printf '%s' '1 63\shl 0 1-\sdv N E 1 63\shl 0 1-\smd N E 5 0 1-\sdv N E 5 0 1-\smd N E' | gc)" \
    = "$(printf -- '-9223372036854775808\n0\n-5\n0')" ] \
  && ok "INT64_MIN ÷ -1 = INT64_MIN and ∣ -1 = 0 (no trap); 5 ÷ -1 = -5" || no "INT64_MIN / -1"
[ "$(printf '%s' '5N E 7 0\sdv N E' | gref; echo "rc=$?")" = "$(printf '5\nrc=1')" ] \
  && [ "$(printf '%s' '7 0 2-\sdv N E 1 63\shl 0 1-\smd N E' | gref)" = "$(printf -- '-3\n0')" ] \
  && ok "oracle: golfref emits the same checked ÷ ∣" || no "oracle ÷ ∣"

# @@ W9-2C-GUARD @@
echo "Return-stack guard (W9-2C): the page below the return stack is PROT_NONE"
# STARTUP2 mprotects [0x4F1000, 0x4F2000), so a runaway recursion faults on the
# guard (SIGSEGV, 139) before it reaches the 0x4F bank, the variable bank or the
# code arena.  Before W9-2C a 200,000-deep plain recursion exited 0 having
# silently overwritten all three.  w9g compiles its argument and leaves the exit
# status in $w9grc and (bounded) stdout in $w9gout; it is called directly, not at
# the end of a pipe, so the two variables survive.  The braces send bash's own
# "Segmentation fault" notice to /dev/null with the program's stderr.
w9g(){ printf '%s' "$1" | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - \
         | "$TMP/golf2" > "$TMP/p" 2>/dev/null && chmod +x "$TMP/p"
       { "$TMP/p" > "$TMP/w9g.out"; } 2>/dev/null; w9grc=$?
       w9gout=$(head -c 64 "$TMP/w9g.out"); }
w9g ':r"[^]\dec r;200000 r N E'
[ "$w9grc" = 139 ] && [ -z "$w9gout" ] \
  && ok "200,000-deep plain : recursion dies with SIGSEGV (139) instead of exiting 0" \
  || no "200,000-deep recursion: rc $w9grc, output '$w9gout' (want 139, nothing)"
# Since M-FRAME2 (W9-4D) a ⊡ frame is one cell per local named, so the word
# names all eight one-letter locals to keep its 72-byte frame.
w9g '\dlocc\lseta\lgetb\lgetc\lgetd\lgete\lgetf\lgetg\lgeth_______\lgeta0\slt1+[0^]\lgeta1-c;20000cN E'
[ "$w9grc" = 139 ] && [ -z "$w9gout" ] \
  && ok "a ⊡ word (72-byte frames) recursing 20,000 deep dies the same way" \
  || no "20,000-deep ⊡ recursion: rc $w9grc, output '$w9gout' (want 139, nothing)"
# The canary: every level checks that →x still holds 12345 and prints B and exits
# if not.  Unguarded (the syscall NOPed out) this prints B — the return stack
# reaches the variable bank first; guarded the fault must come first.
w9g '12345→x:r"[^]←x12345≡[66)E]\dec r;200000 r N E'
[ "$w9grc" = 139 ] && [ -z "$w9gout" ] \
  && ok "... and the fault comes before a →x canary in the variable bank is overwritten" \
  || no "canary: rc $w9grc, output '$w9gout' (want 139, nothing)"
w9g '12345→x:r"[^]←x12345≡[66)E]\dec r;138000 r N←xN E'
[ "$w9grc" = 0 ] && [ "$w9gout" = "012345" ] \
  && ok "138,000 deep (the documented ≈138k) still runs clean, canary intact" \
  || no "138,000-deep recursion: rc $w9grc, output '$w9gout'"
# Every v2 binary carries the guard, the compilers included: golf2 (built by the
# seed, which embeds the same blob) and anything golf2 emits start with STARTUP2.
# The seed itself is built by the frozen v1c with v1's startup and has none.
W9GS=$(python3 -c 'import sys; sys.path.insert(0,"tools"); import mkblob2; print(mkblob2.STARTUP2.hex())')
[ "$(od -An -tx1 -j120 -N${#W9GS} "$TMP/golf2" | tr -d ' \n' | cut -c1-${#W9GS})" = "$W9GS" ] \
  && [ "$(od -An -tx1 -j120 -N${#W9GS} "$TMP/p" | tr -d ' \n' | cut -c1-${#W9GS})" = "$W9GS" ] \
  && ok "golf2 and the programs it emits both open with the guarded STARTUP2" \
  || no "STARTUP2 (with guard) not at offset 120 of golf2 / an emitted program"

# @@ W9-3A-NAMES @@
echo "Long names (M2): ‹name› wherever a one-byte name can stand, forward references"
# Ten long-named words, defined with all three headers and used as calls,
# quotations and chain links.  The digits after a name are a literal, not part
# of the name: the › is what ends it.
cat > "$TMP/m2ten.golfj" <<'EOF'
:‹square›²;
:‹cube›"‹square›*;
:‹inc›⊕;
:‹dec›⊖;
:‹double›⊗;
:‹half›⊘;
⊚‹mean›∑≢÷;
⊚‹sumsq›′‹square›€∑;
⊡‹hyp›⇒a⇒b⇐a‹square›⇐b‹square›+;
:‹ten›10;
5‹square›Ṅ␤3‹cube›Ṅ␤‹ten›‹inc›‹double›‹half›‹dec›Ṅ␤
5⍳‹mean›Ṅ␤4⍳‹sumsq›Ṅ␤3 4‹hyp›Ṅ␤
EOF
tools/golfc -j "$TMP/m2ten.golfj" "$TMP/m2ten" 2>/dev/null
[ "$("$TMP/m2ten" 2>/dev/null | tr '\n' ' ')" = "25 27 10 2 14 25 " ] \
  && ok "ten long-named words: :, ⊚ and ⊡ headers, calls, ′ inside a chain" || no "ten long names"
python3 tools/codepage.py encode < "$TMP/m2ten.golfj" | cat "$TMP/pre.gb" - > "$TMP/m2ten.src"
python3 boot/golfref.py < "$TMP/m2ten.src" > "$TMP/m2ten.ref" 2>/dev/null
cmp -s "$TMP/m2ten" "$TMP/m2ten.ref" \
  && ok "oracle: identical bytes for the long-name program" || no "oracle long-name bytes"
[ "$(printf '%s' ':\lnamesq\rname\sqr;7\lnamesq\rname N E' | gc)" = "49" ] \
  && ok "the ASCII spelling \\lname…\\rname is the same token" || no "lname/rname mnemonics"
# A long name's cell is 0x4E0000 + 8*(256+index) — past every one-byte name's —
# so ‹a› and a, ‹count› and c are four different variables.
[ "$(printf '%s' '1→a2→‹a›3→c4→‹count›←aṄ←‹a›Ṅ←cṄ←‹count›Ṅ' | gc)" = "1234" ] \
  && ok "long-named variables never collide with one-byte ones" || no "long variables"
[ "$(printf '%s' '0 7-→‹neg›←‹neg›Ṅ 4294967296→‹big›←‹big›Ṅ' | gc)" = "-74294967296" ] \
  && ok "... and are full 64-bit cells, like the bank they extend" || no "long variables 64-bit"
[ "$(printf '%s' ':‹twice›⊗;4⍳′‹twice›€⍕␤5′‹twice›⍎Ṅ' | gc)" = "$(printf '0 2 4 6 \n10')" ] \
  && ok "′‹name› is a quotation for € and ⍎" || no "quotation of a long name"
[ "$(printf '%s' '⊚‹avg›∑≢÷;6⍳‹avg›Ṅ:‹s›∑;:‹l›≢;⊚‹avg2›‹s›‹l›÷;8⍳‹avg2›Ṅ' | gc)" = "23" ] \
  && ok "a chain definition with a long name, and with long-named links" || no "chain with a long name"
# Mutual recursion: ‹even› calls ‹odd› before ‹odd› exists.  The call is emitted
# with a placeholder on ‹odd›'s pending list and patched by its definition.
# Zero is true, so 0 = yes.
[ "$(printf '%s' ':‹even›"[_0^]⊖‹odd›;:‹odd›"[_1^]⊖‹even›;10‹even›Ṅ7‹even›Ṅ7‹odd›Ṅ1000‹odd›Ṅ' | gc)" = "0101" ] \
  && ok "mutual recursion :‹even›…‹odd›…; :‹odd›…‹even›…; is correct" || no "mutual recursion"
[ "$(printf '%s' '3′‹later›⍎Ṅ:‹later›⊗;′‹later›_' | gc)" = "6" ] \
  && ok "′ of a long name defined further down (a jmp thunk, patched)" || no "forward quotation"
[ "$(printf '%s' ':‹ab›1;:‹abc›2;:‹a›3;‹abc›Ṅ‹ab›Ṅ‹a›Ṅ' | gc)" = "213" ] \
  && ok "‹ab› ‹abc› ‹a› are three names (no prefix collision)" || no "long-name prefixes"
[ "$(printf '%s' '5‹nope›Ṅ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word ‹nope›" ] \
  && [ ! -s "$TMP/u.out" ] \
  && ok "a long name never defined: GOLF: undefined word ‹nope›, exit 2, no binary" || no "undefined long name"
[ "$(printf '%s' ':‹f›‹g›;1Ṅ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word ‹g›" ] \
  && ok "... reported at end of input, even from inside a definition" || no "undefined long name in a body"
[ "$(printf '%s' '5qṄ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word q" ] \
  && ok "a one-byte name never defined: same message as before (at end of input since W10-A)" || no "one-byte undefined regression"
[ "$(printf '%s' '‹a b›' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: bad long name ‹a›" ] \
  && ok "a byte outside 0-9 A-Z a-z _ - is rejected" || no "bad long-name byte"
[ "$(printf '%s' '‹›' | und)" = "2" ] && [ "$(printf '%s' '‹abc' | und)" = "2" ] \
  && [ "$(printf '%s' '‹abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijk›' | und)" = "2" ] \
  && ok "an empty, unterminated or 61-byte long name is rejected" || no "empty/unterminated/long"
# The prelude's own long names (W9-4C on) share the 1024 (256 until W10-A): und
# compiles with the prelude, so the user program's first refused name is
# number 1025 - P.
w93p=$(grep -v '^ *#' lib/prelude.golfj | grep -oE '‹[0-9A-Za-z_-]+›' | sort -u | wc -l | tr -d ' ')
w93n=""; for k in $(seq 1 $((1025 - w93p))); do w93n="$w93n:‹w$k›;"; done
[ "$(printf '%s' "$w93n" | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: too many long names ‹w$((1025 - w93p))›" ] \
  && [ "$(printf '%s' "${w93n%:*}" | und)" = "0" ] \
  && ok "the 1025th long name is refused (1024 fit the table; $w93p of them are the prelude's)" || no "too many long names"
# The other half of the contract: a program without ‹ compiles to the bytes it
# always did.  Against the compiler logic of the commit before M2 (rebuilt with
# today's blob, so a template change elsewhere does not count) when this clone
# has that commit; against the oracle's untouched one-byte path when it does not.
W93BASE=102ab8c
w93ref=""
if git cat-file -e "$W93BASE^{commit}" 2>/dev/null \
   && git show "$W93BASE:expanded/self/golf2.golfj" > "$TMP/pre-m2.golfj" 2>/dev/null; then
  python3 - "$TMP/pre-m2.golfj" > "$TMP/pre-m2.golf" <<'PY'
import sys; sys.path.insert(0, "tools"); import mkblob2, codepage
enc = codepage.encode(open(sys.argv[1], encoding="utf-8").read())
sys.stdout.buffer.write(enc.replace(mkblob2.BLOB_MARKER, mkblob2.blob_escape()))
PY
  "$TMP/golf2" < "$TMP/pre-m2.golf" > "$TMP/pre-m2" 2>/dev/null && chmod +x "$TMP/pre-m2" && w93ref=pre-m2
fi
# Since W9-4C the prelude itself defines long-named words (‹readall› …), which
# a pre-M2 compiler cannot read, so this comparison feeds both compilers the
# prelude with every `:‹name›…;` definition cut out (the encoded bytes, walked
# so a `;` inside “…“ or after ' does not end one), and skips the examples that
# use ‹ themselves — the contract under test is "a program without ‹".
python3 - lib/prelude.golfj > "$TMP/pre-m1.gb" <<'PY'
import sys; sys.path.insert(0, "tools"); import mkblob2, codepage
b = codepage.encode(open(sys.argv[1], encoding="utf-8").read())
out, i, skip = bytearray(), 0, False
while i < len(b):
    c = b[i]
    if c == 0x3A and b[i+1:i+2] == bytes([mkblob2.LNAME_BYTE]): skip = True
    if c == 0x27: n = 2
    elif c == mkblob2.STR_BYTE: n = b.index(mkblob2.STR_BYTE, i + 1) + 1 - i
    else: n = 1
    if not skip: out += b[i:i+n]
    elif c == 0x3B: skip = False
    i += n
if mkblob2.LNAME_BYTE in out: sys.exit(1)
sys.stdout.buffer.write(out)
PY
cp "$TMP/pre-m1.gb" "$TMP/pre1.gb"   # W9-4B part 2 tests below use this name
w93bad=""; w93n=0; w93f=0
for f in examples/*.golfj examples/bitwise.g2 examples/v1/*.golf gtools/*.golfj; do
  case "$f" in *.golfj) grep -qF '‹' "$f" && continue;; esac
  case "$f" in
    *.golfj) { cat "$TMP/pre-m1.gb"
               case "$f" in gtools/*) for l in lib/t*.golfj; do python3 tools/codepage.py encode < "$l"; done;; esac
               python3 tools/codepage.py encode < "$f"; } > "$TMP/w93.src";;
    *.g2) cat "$TMP/pre-m1.gb" "$f" > "$TMP/w93.src";;
    *) cp "$f" "$TMP/w93.src";;
  esac
  "$TMP/golf2" < "$TMP/w93.src" > "$TMP/w93.new" 2>/dev/null
  if [ "$w93ref" = pre-m2 ]; then "$TMP/pre-m2" < "$TMP/w93.src" > "$TMP/w93.old" 2>/dev/null
  else python3 boot/golfref.py < "$TMP/w93.src" > "$TMP/w93.old" 2>/dev/null; fi
  # M-FRAME2 (W9-4D) deliberately changed what a ⊡ word compiles to (its frame
  # is sized to its locals), so a program using ⊡ is held to the same OUTPUT
  # as the pre-M2 build instead; every other program still to the same bytes.
  if grep -q '⊡\|\\dloc' "$f"; then
    chmod +x "$TMP/w93.new" "$TMP/w93.old"
    w93o=$("$TMP/w93.old" 2>&1 </dev/null); w93w=$("$TMP/w93.new" 2>&1 </dev/null)
    { [ -n "$w93o" ] && [ "$w93o" = "$w93w" ]; } || w93bad="$w93bad $f(output)"
    w93f=$((w93f+1))
  else cmp -s "$TMP/w93.new" "$TMP/w93.old" || w93bad="$w93bad $f"; fi
  w93n=$((w93n+1))
done
[ -z "$w93bad" ] && [ "$w93n" -gt 20 ] && [ -s "$TMP/pre-m1.gb" ] && [ "$w93f" -ge 1 ] \
  && ok "every existing example and gtools program compiles to the same bytes as before M2 (${w93ref:-oracle}, $w93n programs; the $w93f using ⊡ to the same output, M-FRAME2)" \
  || no "M2 changed the bytes of:$w93bad"

# @@ W9-3B-NESTED @@
echo "Nested lists (W9-3B): recursive ⍕, ≣ match, ⍤ depth, + - * ⌈ ⌊ to any depth"
# Before W9-3B `3⍳′⍳€⍕` printed three heap addresses and `+` stopped one level
# down.  `:s⍳′⍳€;4⍳′s€` is a depth-3 list [[],[[]],[[],[0]],[[],[0],[0,1]]].
[ "$(printf '%s' '5⍳⍕␤0⍳⍕␤' | gc)" = "$(printf '0 1 2 3 4 \n')" ] \
  && ok "⍕ of a flat list (and an empty one) prints exactly as before" || no "w93b flat show"
[ "$(printf '%s' '3⍳′⍳€⍕' | gc)" = "[] [0] [0 1] " ] \
  && ok "⍕ prints inner lists in brackets: 3⍳′⍳€ -> [] [0] [0 1]" || no "w93b nested show"
[ "$(printf '%s' ':s⍳′⍳€;4⍳′s€⍕' | gc)" = "[] [[]] [[] [0]] [[] [0] [0 1]] " ] \
  && ok "⍕ recurses to depth 3" || no "w93b depth-3 show"
[ "$(printf '%s' ':p"⍕␤;:s⍳′⍳€;3⍳′s€′p€⍕' | gc)" = "$(printf '\n[] \n[] [0] \n[] [[]] [[] [0]] ')" ] \
  && ok "⍕ called from inside a map leaves the map's scratch intact" || no "w93b show in map"
[ "$(printf '%s' '3⍳3⍳≣Ṅ␤3⍳2⍳≣Ṅ␤3 3≣Ṅ␤3 4≣Ṅ␤' | gc)" = "$(printf -- '-1\n0\n-1\n0')" ] \
  && ok "≣: equal/unequal flat lists and ints (-1 true, 0 false)" || no "w93b match flat"
[ "$(printf '%s' '3 3⍳≣Ṅ␤3⍳3≣Ṅ␤0⍳0≣Ṅ␤' | gc)" = "$(printf '0\n0\n0')" ] \
  && ok "≣: an int never matches a list" || no "w93b match int-list"
[ "$(printf '%s' '3⍳′⍳€3⍳′⍳€≣Ṅ␤3⍳′⍳€4⍳′⍳€≣Ṅ␤3⍳′⍳€3⍳≣Ṅ␤:s⍳′⍳€;4⍳′s€4⍳′s€≣Ṅ␤4⍳′s€4⍳′⍳€≣Ṅ␤' | gc)" = "$(printf -- '-1\n0\n0\n-1\n0')" ] \
  && ok "≣ recurses: equal nested lists match; length, shape or depth mismatches do not" || no "w93b match nested"
[ "$(printf '%s' '5⍤Ṅ␤0 7-⍤Ṅ␤3⍳⍤Ṅ␤0⍳⍤Ṅ␤3⍳′⍳€⍤Ṅ␤:s⍳′⍳€;4⍳′s€⍤Ṅ␤' | gc)" = "$(printf '0\n0\n1\n1\n2\n3')" ] \
  && ok "⍤: int 0, flat list 1, empty list 1, list of lists 2, depth 3" || no "w93b depth"
[ "$(printf '%s' '3⍳′⍳€ 10+⍕␤10 3⍳′⍳€-⍕␤3⍳′⍳€ 3*⍕␤' | gc)" = "$(printf '[] [10] [10 11] \n[] [10] [10 9] \n[] [0] [0 3] ')" ] \
  && ok "bare + - * broadcast a scalar into every depth (both sides)" || no "w93b deep scalar"
[ "$(printf '%s' ':s⍳′⍳€;4⍳′s€ 100+⍕' | gc)" = "[] [[]] [[] [100]] [[] [100] [100 101]] " ] \
  && ok "bare + broadcasts through three levels" || no "w93b deep scalar 3"
[ "$(printf '%s' '3⍳′⍳€"+⍕␤3⍳′⍳€"*⍕␤3⍳′⍳€ 3⍳+⍕␤' | gc)" = "$(printf '[] [0] [0 2] \n[] [0] [0 1] \n[] [1] [2 3] ')" ] \
  && ok "two nested lists combine elementwise; list+list of lists broadcasts per element" || no "w93b deep elementwise"
[ "$(printf '%s' '3⍳′⍳€ 0 5-⌊⍕␤3⍳′⍳€ 1⌈⍕␤3⍳′⍳€ 7∔⍕␤' | gc)" = "$(printf '[] [-5] [-5 -5] \n[] [1] [1 1] \n[] [7] [7 8] ')" ] \
  && ok "⌊ ⌈ stay signed at depth; ∔ called directly recurses too" || no "w93b deep min/max"

# @@ W9-3C-FREE @@
echo "M-MEM2 (W9-3C): ⌫ free — a size-classed free list in front of A's bump pointer"
# Every A block has a header cell [cap] in front of the address A returns; ⌫
# pushes a block on its class's list (heads at 0x4F00C0..0x4F00F8) and A pops
# the head of the matching class before bumping.  The program break (0⌸) is the
# witness: a loop that frees what it maps stays flat, the same loop without ⌫
# climbs by one 72-byte block per iteration (the break moves in 1 MB steps,
# so ~71 MB, not exactly 72).
[ "$(printf '%s' ':d\dbl;5R→l 0\brk→b 1000000→i{←l\refdM\free←i1-"→i0\eq}0\brk←b-N E ←l Q E' | gc)" = "$(printf '0\n0 1 2 3 4 ')" ] \
  && ok "1,000,000 × (map, ⌫): the program break does not move" || no "free loop keeps brk flat"
w93c=$(printf '%s' ':d\dbl;5R→l 0\brk→b 1000000→i{←l\refdM_←i1-"→i0\eq}0\brk←b-N E' | gc)
[ "$w93c" -ge 64000000 ] 2>/dev/null \
  && ok "the same loop without ⌫ grows the break ($w93c bytes)" || no "no-free loop: break grew '$w93c', want >= 64000000"
[ "$(printf '%s' '5R"→a\free 5R←a\eq N E 3A"→b\free 3A←b\eq N E' | gc)" = "$(printf -- '-1\n-1')" ] \
  && ok "a freed block is reused by the next same-size request (tagged list and raw A block)" || no "free reuse"
# Classes are powers of two (4 8 … 256 cells) so any request of the class fits:
# 5R takes 6 cells, 7R 8 — both class 8.  Above 256 cells one list, head-only fit.
[ "$(printf '%s' '5R→a←a\free 7R"←a\eq N E Q E 1000R→a←a\free 900R"←a\eq N E∑N E' | gc)" = "$(printf -- '-1\n0 1 2 3 4 5 6 \n-1\n404550')" ] \
  && ok "reuse within a size class (5⍳→7⍳, 1000⍳→900⍳), contents fresh" || no "class reuse"
[ "$(printf '%s' '5R→a←a\free 100R"←a\eq N E∑N E 5R←a\eq N E 1000R\free 2000R∑N E' | gc)" = "$(printf -- '0\n4950\n-1\n1999000')" ] \
  && ok "a different-size request bumps instead; the freed block waits for its own class" || no "different sizes"
[ "$(printf '%s' '5R→a 5R→b ←a\free←b\free 5R←b\eq N E 5R←a\eq N E 5R"←a\eq N E ←b\eq N E' | gc)" = "$(printf -- '-1\n-1\n0\n0')" ] \
  && ok "the free list is LIFO; once it is empty A bumps a fresh block" || no "free list LIFO"
[ "$(printf '%s' '5R"→a\free 5R\free 5R←a\eq N E' | gc)" = "-1" ] \
  && ok "a reused block can be freed again (A restores its header)" || no "free after reuse"
[ "$(printf '%s' ':s3R;4R\refsM"0 I\free"1 I\free\free 3R"Q E 3R Q E' | gc)" = "$(printf '0 1 2 \n0 1 2 ')" ] \
  && ok "freeing inner lists and the outer list of a list of lists" || no "nested free"
w93cf(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/c" 2>/dev/null \
           && chmod +x "$TMP/c" && "$TMP/c" > "$TMP/c.out" 2> "$TMP/c.err"; echo "$?"; }
w93cdied(){ [ "$1" = 1 ] && [ "$(cat "$TMP/c.err")" = "GOLF: $2" ] && [ "$(cat "$TMP/c.out")" = "$3" ]; }
w93cdied "$(printf '%s' '7N E 7\free 8N E' | w93cf)" "free of a non-heap value" "7" \
  && ok "⌫ of an int: exit 1, message on fd 2" || no "free of an int"
w93cdied "$(printf '%s' '“abc“\free' | w93cf)" "free of a non-heap value" "" \
  && ok "⌫ of a string literal (code segment) is refused too" || no "free of a string"
w93cdied "$(printf '%s' '5R"\free\free' | w93cf)" "double free" "" \
  && ok "⌫ twice on one block: exit 1, double free" || no "double free"
[ "$(printf '%s' ':d\dbl;5R→l 3→i{←l\refdM"Q E\free←i1-"→i0\eq}100R\refdM\free 9R∑N E' | gref)" \
    = "$(printf '%s' ':d\dbl;5R→l 3→i{←l\refdM"Q E\free←i1-"→i0\eq}100R\refdM\free 9R∑N E' | gc)" ] \
  && ok "oracle: golfref runs the same free list" || no "oracle free"

# @@ W9-4A-LISTWORDS1 @@
echo "List words (W9-4A): ⧺ cat, ↑ take, ↓ drop — new tagged lists, inputs untouched"
[ "$(printf '%s' '2⍳2⍳⧺⍕' | gc)" = "0 1 0 1 " ] && ok "⧺: 2⍳2⍳⧺ -> 0 1 0 1" || no "cat basic"
[ "$(printf '%s' '0⍳3⍳⧺⍕E 3⍳0⍳⧺⍕E 0⍳0⍳⧺≢N E 3⍳4⍳⧺≢N E' | gc)" = "$(printf '0 1 2 \n0 1 2 \n0\n7')" ] \
  && ok "⧺: empty on either side / both, result length via ≢" || no "cat empty/len"
[ "$(printf '%s' '“foo“⊃“bar“⊃⧺⊐E' | gc)" = "foobar" ] && ok "⧺ of two strings' code lists, printed by ⊐" || no "cat strings"
[ "$(printf '%s' '3⍳2⍳⧺T N E 3⍳2⍳⧺10+⍕' | gc)" = "$(printf '0\n10 11 12 10 11 ')" ] \
  && ok "⧺'s result is a tagged list (T, bare + vectorizes)" || no "cat tag"
[ "$(printf '%s' '5⍳0↑≢N E 5⍳5↑⍕E 5⍳9↑⍕E 5⍳2↑⍕E 0⍳3↑≢N E' | gc)" = "$(printf '0\n0 1 2 3 4 \n0 1 2 3 4 \n0 1 \n0')" ] \
  && ok "↑: n=0, n=len, n>len (whole list), 2, empty input" || no "take"
[ "$(printf '%s' '5⍳0 2-↑⍕E 5⍳0 9-↑⍕E 5⍳0 1 63≪-↑⍕E' | gc)" = "$(printf '3 4 \n0 1 2 3 4 \n0 1 2 3 4 ')" ] \
  && ok "↑: n<0 takes the last |n| (APL), clamped; -2^63 too" || no "take negative"
[ "$(printf '%s' '5⍳0↓⍕E 5⍳5↓≢N E 5⍳9↓≢N E 5⍳2↓⍕E 0⍳3↓≢N E' | gc)" = "$(printf '0 1 2 3 4 \n0\n0\n2 3 4 \n0')" ] \
  && ok "↓: n=0, n=len, n>len (empty), 2, empty input" || no "drop"
[ "$(printf '%s' '5⍳0 2-↓⍕E 5⍳0 9-↓≢N E 0⍳0 3-↓≢N E 5⍳0 1 63≪-↓≢N E' | gc)" = "$(printf '0 1 2 \n0\n0\n0')" ] \
  && ok "↓: n<0 drops the last |n| (APL), clamped" || no "drop negative"
[ "$(printf '%s' '5⍳2↑T N E 5⍳2↓T N E' | gc)" = "$(printf '0\n0')" ] && ok "↑/↓ results are tagged lists" || no "take/drop tag"
[ "$(printf '%s' '3⍳→a 2⍳→b ←a←b⧺_ ←a 1↑_ ←a 1↓_ ←a 0 1-↑_ ←a⍕E ←b⍕E' | gc)" = "$(printf '0 1 2 \n0 1 ')" ] \
  && ok "⧺/↑/↓ leave their inputs unchanged" || no "inputs unchanged"
[ "$(printf '%s' '2A 1&\store 3⍳&8\radd\store 1 48≪| 5⍳1↑⧺"≢N E"0⊇100+⍕E 1⊇N E' | gc)" = "$(printf '2\n100 101 102 \n0')" ] \
  && ok "⧺ carries a nested (tagged inner) list through unchanged" || no "cat nested"
tools/golfc -j examples/listwords.golfj "$TMP/lw" 2>/dev/null
LWOUT=$(printf '0 1 2 0 1 \n0 1 \n2 3 4 5 \n4 5 \n0 1 2 3 \n6\ngol is fun')
[ "$("$TMP/lw" 2>/dev/null)" = "$LWOUT" ] && ok "golfc examples/listwords.golfj" || no "listwords.golfj"
[ "$(oracle listwords)" = "$LWOUT" ] && ok "oracle: listwords.golfj behaves identically" || no "oracle listwords.golfj"

# @@ W9-4B-LISTWORDS2 @@
echo "List words (W9-4B): ⍋ sort (new list, signed, O(n log n)), ∊ member"
[ "$(printf '%s' '0⍳⍋≢N E 1⍳5+⍋⍕E 5⍳⍋⍕E 5⍳⌽⍋⍕E' | gc)" = "$(printf '0\n5 \n0 1 2 3 4 \n0 1 2 3 4 ')" ] \
  && ok "⍋: empty, one element, already sorted, reverse sorted" || no "sort basic"
[ "$(printf '%s' '6⍳⌽3- 4⍳⧺⍋⍕E 7⍳⌽7⍳⌽⧺0 5-+⍋⍕' | gc)" = "$(printf -- '-3 -2 -1 0 0 1 1 2 2 3 \n-5 -5 -4 -4 -3 -3 -2 -2 -1 -1 0 0 1 1 ')" ] \
  && ok "⍋: duplicates and negatives sort signed" || no "sort dup/neg"
[ "$(printf '%s' '1⍳1 63≪1-+ 1⍳0 1 63≪-+⧺ 1⍳0 1-+⧺ 1⍳5+⧺⍋⍕' | gc)" = "-9223372036854775808 -1 5 9223372036854775807 " ] \
  && ok "⍋: the full signed 64-bit range, -2^63 .. 2^63-1" || no "sort extremes"
[ "$(printf '%s' ':f7919*1000%500-;37⍳′f€⍋⍕' | gc)" = "$(python3 -c 'print(" ".join(str(x) for x in sorted(i*7919%1000-500 for i in range(37))), end=" ")')" ] \
  && ok "⍋: 37 scrambled values (odd length, runs of unequal width) match Python's sorted" || no "sort scrambled"
[ "$(printf '%s' '5⍳⌽→a ←a⍋_ ←a⍕E 5⍳⌽⍋T N E 3⍳⌽⍋10+⍕' | gc)" = "$(printf '4 3 2 1 0 \n0\n10 11 12 ')" ] \
  && ok "⍋ leaves its input unchanged and returns a tagged list" || no "sort input/tag"
[ "$(printf '%s' '3⍳′⍳€⌽′⍋€⍕' | gc)" = "[0 1] [0] [] " ] && ok "⍋ mapped over a list of lists" || no "sort in map"
W94T=$(date +%s%N)
W94B=$(printf '%s' '100000⍳"∑N E⌽"⍋"0⊇N E"99999⊇N E"∑N E≢N E 0⊇N E' | gc)
W94T=$(( ($(date +%s%N) - W94T) / 1000000 ))
[ "$W94B" = "$(printf '4999950000\n0\n99999\n4999950000\n100000\n99999')" ] && [ "$W94T" -lt 3000 ] \
  && ok "⍋ of 100,000 reversed elements: first/last right, ∑ kept, input intact, under 3 s" || no "sort 100k (${W94T} ms): $W94B"
[ "$(printf '%s' '5⍳3∊N 5⍳7∊N 5⍳0∊N 5⍳4∊N 0⍳0∊N 5⍳0 2-+0 2-∊N 5⍳0 2-+0 3-∊N 5⍳0 1-∊N' | gc)" = "01001011" ] \
  && ok "∊: hits (0) and misses (1), first/last element, negatives, empty list" || no "member"
[ "$(printf '%s' ':m→v 3⍳←v∊;5⍳′m€⍕E 3⍳′⍳€"1⊇∊N 3⍳′⍳€2⍳∊N' | gc)" = "$(printf '0 0 0 1 1 \n01')" ] \
  && ok "∊ inside a map; an inner list is found only as the same (tagged) list" || no "member map/nested"
echo "More list words (W9-4B part 2): ‹slice› ‹indexof› ‹unique› ‹flatten› (long-named prelude words)"
[ "$(printf '%s' '5⍳1 3‹slice›⍕E 5⍳0 5‹slice›⍕E 5⍳3 9‹slice›⍕E 5⍳2 0‹slice›≢N E 5⍳1 0 1-‹slice›≢N E' | gc)" \
    = "$(printf '1 2 3 \n0 1 2 3 4 \n3 4 \n0\n0')" ] \
  && ok "‹slice›: middle, whole, n clamped to what is left, n=0, n<0 -> empty" || no "slice basic"
[ "$(printf '%s' '5⍳5 1‹slice›≢N E 5⍳9 1‹slice›≢N E 5⍳0 1-1‹slice›⍕E 5⍳0 2-9‹slice›⍕E 5⍳0 9-2‹slice›⍕E 0⍳0 3‹slice›≢N E 0⍳0 1-3‹slice›≢N E' | gc)" \
    = "$(printf '0\n0\n4 \n3 4 \n0 1 \n0\n0')" ] \
  && ok "‹slice›: i=len / i>len empty; i<0 counts from the end, clamped to 0; empty input" || no "slice edges"
[ "$(printf '%s' '5⍳→a ←a1 2‹slice›T N E ←a⍕E 3⍳′⍳€1 2‹slice›⍕E' | gc)" = "$(printf '0\n0 1 2 3 4 \n[0] [0 1] ')" ] \
  && ok "‹slice›: tagged result, input untouched, inner lists carried" || no "slice tag/nested"
[ "$(printf '%s' '5⍳0‹indexof›N 5⍳4‹indexof›N 5⍳2‹indexof›N 5⍳7‹indexof›N 0⍳0‹indexof›N' | gc)" = "042-1-1" ] \
  && ok "‹indexof›: first, last, middle, absent -1, empty -1" || no "indexof basic"
[ "$(printf '%s' '3⍳3⍳⧺2‹indexof›N E 5⍳0 3-+0 1-‹indexof›N E 3⍳′⍳€"1⊇‹indexof›N E 3⍳′⍳€1⍳‹indexof›N E' | gc)" = "$(printf '2\n2\n1\n-1')" ] \
  && ok "‹indexof›: first of duplicates, negatives, an inner list only as the same tagged list" || no "indexof dup/neg/nested"
[ "$(printf '%s' '0⍳‹unique›≢N E 1⍳5+‹unique›⍕E 5⍳‹unique›⍕E 5⍳"⧺"⧺⌽‹unique›⍕E' | gc)" = "$(printf '0\n5 \n0 1 2 3 4 \n4 3 2 1 0 ')" ] \
  && ok "‹unique›: empty, one, all distinct, duplicates keep first-occurrence order" || no "unique basic"
[ "$(printf '%s' '7⍳⌽7⍳⧺0 3-+‹unique›⍕E 1⍳1 63≪+1⍳0 1-+⧺1⍳1 63≪+⧺0⍳⧺1⍳0 1-+⧺‹unique›⍕E' | gc)" \
    = "$(printf '3 2 1 0 -1 -2 -3 \n-9223372036854775808 -1 ')" ] \
  && ok "‹unique›: negatives and duplicates; -1, -2^63 and an empty tail" || no "unique neg/dup"
[ "$(printf '%s' ':h1024*;3000⍳′h€"⧺‹unique›"≢N E∑N E 5⍳→a ←a"⧺‹unique›T N E ←a⍕E' | gc)" = "$(printf '3000\n4606464000\n0\n0 1 2 3 4 ')" ] \
  && ok "‹unique›: multiples of 1024 (hash spread), tagged result, input untouched" || no "unique hash/tag"
W94U=$(date +%s)
W94UO=$(printf '%s' ':h7∣;10000⍳′h€10000⍳⌽⧺10000⍳⧺‹unique›"≢N E"0⊇N E"9999⊇N E∑N E' | gc)
W94U=$(( $(date +%s) - W94U ))
[ "$W94UO" = "$(printf '10000\n0\n7\n49995000')" ] && [ "$W94U" -lt 10 ] \
  && ok "‹unique› of 30,000 cells (10,000 distinct): first-seen order, compile+run ${W94U} s" || no "unique 10k (${W94U} s): $W94UO"
W94UB=$(printf '%s' '200000⍳"⧺‹unique›≢N' > "$TMP/u10k.golfj"; tools/golfc -j "$TMP/u10k.golfj" "$TMP/u10k" 2>/dev/null; \
        python3 -c 'import subprocess,sys,time; t=time.time(); r=subprocess.run([sys.argv[1]],capture_output=True); print(r.stdout.decode(), int((time.time()-t)*1000))' "$TMP/u10k")
[ "${W94UB% *}" = "200000" ] && [ "${W94UB#* }" -lt 1000 ] \
  && ok "‹unique› of 400,000 cells runs in ${W94UB#* } ms (hash set, not O(n²))" || no "unique 400k timing: $W94UB"
[ "$(printf '%s' '3⍳′⍳€‹flatten›⍕E :s⍳′⍳€;4⍳′s€‹flatten›⍕E 2⍳3⍳′⍳€⧺‹flatten›⍕E' | gc)" = "$(printf '0 0 1 \n0 0 0 1 \n0 1 0 0 1 ')" ] \
  && ok "‹flatten›: depth 2, depth 3, ints mixed with inner lists" || no "flatten nested"
[ "$(printf '%s' '0⍳‹flatten›≢N E :z_0⍳;5⍳‹flatten›⍕E 3⍳′z€‹flatten›≢N E 3⍳′⍳€‹flatten›⍤N E 5⍳→a ←a‹flatten›T N E ←a⍕E' | gc)" \
    = "$(printf '0\n0 1 2 3 4 \n0\n1\n0\n0 1 2 3 4 ')" ] \
  && ok "‹flatten›: empty, already flat (a copy), only empty inner lists, depth 1, tagged, input untouched" || no "flatten edges"
[ "$(printf '%s' ':‹wrap›→‹v›2A 1&\store←‹v›&8\radd\store 1 48≪|;5⍳200→i{‹wrap›←i1-"→i0\eq}"≢N E‹flatten›⍕E' | gc)" = "$(printf '1\n0 1 2 3 4 ')" ] \
  && ok "‹flatten› of a list nested 201 deep (no recursion, so no spill frames per level)" || no "flatten deep"
[ "$(printf '%s' ':s⍳′⍳€;4⍳′s€"‹flatten›_⍕E' | gc)" = "[] [[]] [[] [0]] [[] [0] [0 1]] " ] \
  && ok "‹flatten› leaves its nested input intact" || no "flatten input"
# The prelude's long names cost one-byte programs nothing: compiled after the
# full prelude and after the prelude with the four definitions cut out (pre1.gb,
# built by the M2 check above), a program differs only by the prelude's growth,
# and the tail of the binary — at least the program's own code — is identical.
# (A CALL into a prelude word is a rel32, so it moves by exactly that growth;
# these three programs make none.)
w94s=""
for u in "'H)'i)10)" ':s"*;7s48+)' '7 3≻1+48+)9²⊕"→q←q*10%48+)'; do
  python3 tools/codepage.py encode <<< "$u" > "$TMP/w94u.gb"
  cat "$TMP/pre.gb" "$TMP/w94u.gb" | "$TMP/golf2" > "$TMP/w94a" 2>/dev/null
  cat "$TMP/pre1.gb" "$TMP/w94u.gb" | "$TMP/golf2" > "$TMP/w94b" 2>/dev/null
  "$TMP/golf2" < /dev/null > "$TMP/w94e" 2>/dev/null
  "$TMP/golf2" < "$TMP/w94u.gb" > "$TMP/w94c" 2>/dev/null
  w94s="$w94s $(python3 -c 'import sys; a,b,c,e=(open(f,"rb").read() for f in sys.argv[1:5]); n=0
while n<min(len(a),len(b)) and a[-1-n]==b[-1-n]: n+=1
print(len(a)-len(b), int(n>=len(c)-len(e)>0))' "$TMP/w94a" "$TMP/w94b" "$TMP/w94c" "$TMP/w94e")"
done
w94d=$(cat "$TMP/pre.gb" | "$TMP/golf2" 2>/dev/null | wc -c); w94d1=$(cat "$TMP/pre1.gb" | "$TMP/golf2" 2>/dev/null | wc -c)
[ "$w94s" = " $((w94d-w94d1)) 1 $((w94d-w94d1)) 1 $((w94d-w94d1)) 1" ] \
  && ok "one-byte programs: only the prelude part of the binary changes (+$((w94d-w94d1)) bytes), the program's code is identical" \
  || no "long-named prelude words changed a one-byte program's code:$w94s (prelude +$((w94d-w94d1)))"
w94ct=$(python3 -c 'import subprocess,sys,time; t=time.time(); subprocess.run([sys.argv[1]],stdin=open(sys.argv[2],"rb"),stdout=subprocess.DEVNULL); print(int((time.time()-t)*1000))' "$TMP/golf2" "$TMP/pre.gb")
[ "$w94ct" -lt 1000 ] && ok "compiling the whole prelude (four long names included) takes ${w94ct} ms" || no "prelude compile time ${w94ct} ms"
W94P=':s⍳′⍳€;5⍳1 3‹slice›⍕E 5⍳"⧺‹unique›⍕E 5⍳3‹indexof›N E 4⍳′s€‹flatten›⍕E'
[ "$(printf '%s' "$W94P" | gref)" = "$(printf '%s' "$W94P" | gc)" ] \
  && ok "oracle: golfref runs the four long-named words identically" || no "oracle long-named list words"

# @@ W9-4C-INPUT @@
echo "Input words (W9-4C): ‹readall› ‹readline› ‹words› ‹num› ‹ints› ‹args› ‹getc›"
# gc cannot feed a program stdin (its stdin IS the source), so gin compiles the
# program given as $1 and runs it on gin's own stdin, with any further
# arguments as the program's argv.
gin(){ printf '%s' "$1" | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - | "$TMP/golf2" > "$TMP/pin" 2>/dev/null \
         && chmod +x "$TMP/pin" && shift && "$TMP/pin" "$@"; }
[ "$(printf '1 2 3' | gin '‹ints›∑Ṅ␤')" = "6" ] && ok "NEXT_STEPS's acceptance test: '1 2 3' on stdin sums to 6" || no "ints sum"
[ "$(printf '' | gin '‹readall›≢Ṅ ‹readall›T Ṅ ‹readline›Ṅ≢Ṅ ‹ints›≢Ṅ ‹getc›Ṅ')" = "00100-1" ] \
  && ok "empty stdin: ‹readall› an empty (tagged) list, ‹readline› EOF flag 1, ‹ints› empty, ‹getc› -1" || no "empty input"
[ "$(printf 'ab\n\ncd\nlast' | gin ':‹l›‹readline›"Ṅ[⊐]␤;‹l›‹l›‹l›‹l›‹l›‹l›')" = "$(printf '0ab\n0\n0cd\n0last\n1\n1')" ] \
  && ok "‹readline› line by line: an empty line, a last line without '\\n', then EOF (and EOF again)" || no "readline lines"
[ "$(printf 'x 1\ny 2\n' | gin '‹readline›_⊐␤‹getc›Ṅ␤‹readall›⊐')" = "$(printf 'x 1\n121\n 2')" ] \
  && ok "‹readline›, ‹getc› and ‹readall› share one buffer and interleave" || no "shared buffer"
[ "$(printf 'hello\nworld\n' | gin '‹readall›⊐')" = "$(printf 'hello\nworld')" ] && ok "‹readall› echoed with ⊐ (cat)" || no "readall cat"
[ "$(printf '  foo bar\t\tbaz  ' | gin '‹readall›‹words›"≢Ṅ⍕ “   “⊃‹words›≢Ṅ 0⍳‹words›≢Ṅ')" = "3[102 111 111] [98 97 114] [98 97 122] 00" ] \
  && ok "‹words›: runs of spaces/tabs, leading/trailing blanks, no empty words; blank and empty input" || no "words"
[ "$(printf ' a\n\n b\r\nc\x0bd\x0ce' | gin '‹readall›‹words›′≢€⍕')" = "1 1 1 1 1 " ] \
  && ok "‹words› splits on all of 9-13 and 32" || no "words whitespace set"
[ "$(printf '' | gin '“-42“⊃‹num›Ṅ␤“+9x“⊃‹num›Ṅ␤“ 007“⊃‹num›Ṅ␤“abc“⊃‹num›Ṅ␤“-“⊃‹num›Ṅ␤0⍳‹num›Ṅ␤“-9223372036854775808“⊃‹num›Ṅ')" \
     = "$(printf -- '-42\n9\n7\n0\n0\n0\n-9223372036854775808')" ] \
  && ok "‹num›: signs, leading blanks, stops at a non-digit, garbage and empty give 0, -2^63" || no "num"
[ "$(printf -- ' -5\n+7 10\t\t x 3 -0 12abc' | gin '‹ints›⍕')" = "-5 7 10 0 3 0 12 " ] \
  && ok "‹ints›: negative numbers parse; a non-number word counts as 0" || no "ints negative"
[ "$(printf '' | gin '‹args›"≢Ṅ⍕' one 'a b' '')" = "3[111 110 101] [97 32 98] [] " ] \
  && [ "$(printf '' | gin '‹args›≢Ṅ')" = "0" ] \
  && ok "‹args› sees argv[1..] (a space inside one, an empty one); none gives an empty list" || no "args"
python3 -c 'import sys; sys.stdout.write("".join("%d\n" % (i*7919 % 100003 - 50000) for i in range(200000)))' > "$TMP/big.in"
W94C=$(gin '‹readall›"≢Ṅ␤∑Ṅ␤' < "$TMP/big.in")
[ "$W94C" = "$(python3 -c 'd=open("'"$TMP/big.in"'","rb").read(); print(len(d)); print(sum(d))')" ] && [ "$(wc -c < "$TMP/big.in")" -gt 1000000 ] \
  && ok "a $(wc -c < "$TMP/big.in")-byte input is read fully (length and byte sum)" || no "1 MB readall: $W94C"
[ "$(gin '‹ints›"≢Ṅ␤∑Ṅ' < "$TMP/big.in")" = "$(python3 -c 'v=[i*7919 % 100003 - 50000 for i in range(200000)]; print(len(v)); print(sum(v))')" ] \
  && ok "‹ints› of that input: 200000 numbers, sum matches Python" || no "1 MB ints"
tools/golfc -j examples/input.golfj "$TMP/input" 2>/dev/null </dev/null
[ "$(printf 'a list\n3 -4 10\n' | "$TMP/input" x y 2>/dev/null)" = "$(printf 'a list\n9\nx\ny')" ] \
  && ok "golfc examples/input.golfj (first line, sum of the rest, the arguments)" || no "input.golfj"
[ "$(printf 'a list\n3 -4 10\n' | oracle input)" = "$(printf 'a list\n9')" ] \
  && ok "oracle: input.golfj behaves identically (no arguments)" || no "oracle input.golfj"

# @@ W9-4D-FRAMES @@
echo "Sized frames (M-FRAME2, W9-4D): a ⊡ word reserves one cell per local it names"
# ⊡ emits `sub rbp, imm32` and every `^` an `add rbp, imm32`, each immediate left
# holding the previous site; `;` walks that list and writes 8*k into each, k the
# number of distinct locals (a..h or ‹long›) named in the definition.
w94dbin(){ printf '%s' "$1" | python3 tools/codepage.py encode | "$TMP/golf2" > "$TMP/w94d.bin" 2>/dev/null; }
w94dhas(){ python3 -c 'import sys; d=open(sys.argv[1],"rb").read(); print(d.count(bytes.fromhex(sys.argv[2])))' "$TMP/w94d.bin" "$1"; }
w94dbin '⊡t⇒a⇒‹b›⇐a⇐‹b›+"[^]1+;'
[ "$(w94dhas 4881ed10000000)" = 1 ] && [ "$(w94dhas 4881c510000000)" = 2 ] \
  && [ "$(w94dhas 4883ed40)" = 0 ] \
  && ok "two locals: sub rbp,16 once, add rbp,16 at the ^ and at ; (no 64-byte slab)" \
  || no "two-local frame bytes: sub×$(w94dhas 4881ed10000000) add×$(w94dhas 4881c510000000)"
w94dbin '⊡z"[^]1-;'
[ "$(w94dhas 4881ed00000000)" = 1 ] && [ "$(w94dhas 4881c500000000)" = 2 ] \
  && ok "zero locals: the frame is 0 cells (k = 0 is allowed)" || no "zero-local frame bytes"
# Measured, not just read off the bytes: 24-byte frames (two locals + the return
# address) go 40,000 deep; the same word naming eight locals has 72-byte frames,
# which hit the W9-2C guard page long before that (≈15k).
w9g '⊡c"⇒a⇒‹d›⇐a[0^]⇐a1-c⇐‹d›+;40000cN E'
[ "$w9grc" = 0 ] && [ "$w9gout" = "800020000" ] \
  && ok "a two-local ⊡ word recurses 40,000 deep (24-byte frames)" \
  || no "two-local depth: rc $w9grc, output '$w9gout'"
w9g '⊡c"⇒a⇒‹d›⇐b⇐c⇐e⇐f⇐g⇐h______⇐a[0^]⇐a1-c⇐‹d›+;40000cN E'
[ "$w9grc" = 139 ] && [ -z "$w9gout" ] \
  && ok "... the same word naming eight locals hits the guard page (72-byte frames)" \
  || no "eight-local depth: rc $w9grc, output '$w9gout' (want 139)"
w9g '⊡‹z›"[^]1-‹z›;100000‹z›N E'
[ "$w9grc" = 0 ] && [ "$w9gout" = "0" ] \
  && ok "a zero-local ⊡ word recurses 100,000 deep, like a : word" || no "zero-local depth: rc $w9grc"
[ "$(printf '%s' '⊡‹sum›"[_0^]⇒‹acc›⇐‹acc›1-‹sum›⇐‹acc›+;30000‹sum›N E' | gc)" = "450015000" ] \
  && ok "one long-named local: ‹sum› of 1..30000 = n(n+1)/2 at depth" || no "long local recursion"
[ "$(printf '%s' '⊡‹m›⇒a⇒‹x›⇒b⇐a⇐‹x›-⇐b*⇐a+;2 7 3‹m›N E' | gc)" = "-5" ] \
  && ok "long and one-letter locals mixed in one word" || no "mixed locals"
# Sixteen distinct slots, one-letter and long interleaved: pushed 1..16, so the
# first popped (a) is 16 and the last (‹i16›) is 1, and ‹i9› (9th) is 8.
[ "$(printf '%s' '⊡f⇒a⇒‹i2›⇒b⇒‹i4›⇒c⇒‹i6›⇒d⇒‹i8›⇒‹i9›⇒e⇒‹i11›⇒f⇒‹i13›⇒g⇒‹i15›⇒‹i16›⇐a10000*⇐‹i9›100*+⇐‹i16›+;1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16fN E' | gc)" = "160801" ] \
  && ok "sixteen mixed locals get sixteen distinct slots" || no "sixteen locals"
# Every level leaves through an early ^ — the base case's and one after the
# recursive call — so a ^ that released the wrong amount would drift rbp by
# 20,000 frames.  Then two frame sizes (one and two cells) calling each other.
[ "$(printf '%s' '⊡‹t›"⇒‹n›⇒a⇐‹n›[0^]⇐‹n›1-‹t›⇐a+0[^]9;20000‹t›N E' | gc)" = "200010000" ] \
  && ok "early ^ exits restore rbp in a sized frame, 20,000 deep" || no "early-exit recursion"
[ "$(printf '%s' '⊡‹ev›⇒‹n›⇐‹n›[1^]⇐‹n›1-‹od›;⊡‹od›⇒‹n›⇐a_⇐‹n›[0^]⇐‹n›1-‹ev›0[^]7;30000‹ev›N 30001‹ev›N E' | gc)" = "10" ] \
  && ok "two frame sizes, mutually recursive through early ^, 30,000 deep" || no "mutual sized frames"
[ "$(printf '%s' '⊡f⇒‹a1›⇒‹a2›⇒‹a3›⇒‹a4›⇒‹a5›⇒‹a6›⇒‹a7›⇒‹a8›⇒‹a9›⇒‹a10›⇒‹a11›⇒‹a12›⇒‹a13›⇒‹a14›⇒‹a15›⇒‹a16›⇒‹a17›;' | und)" = "2" ] \
  && [ "$(cat "$TMP/u.err")" = "GOLF: too many locals ‹a17›" ] && [ ! -s "$TMP/u.out" ] \
  && ok "a 17th local is refused (16 keep every slot a disp8), exit 2" || no "too many locals"
[ "$(printf '%s' ':g⇐‹x›;' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: local out of range ‹x›" ] \
  && ok "a long local outside a ⊡ word is refused (there is no frame to hold it)" || no "long local outside ⊡"
w94dsrc='⊡‹t›"⇒‹n›⇒a⇐‹n›[0^]⇐‹n›1-‹t›⇐a+0[^]9;⊡‹m›⇒a⇒‹x›⇒b⇐a⇐‹x›-⇐b*⇐a+;⊡‹z›1+;50‹t›N 2 7 3‹m›N 4‹z›N'
cat "$TMP/pre.gb" <(printf '%s' "$w94dsrc" | python3 tools/codepage.py encode) > "$TMP/w94d.src"
"$TMP/golf2" < "$TMP/w94d.src" > "$TMP/w94d.g2" 2>/dev/null
python3 boot/golfref.py < "$TMP/w94d.src" > "$TMP/w94d.ref" 2>/dev/null
cmp -s "$TMP/w94d.g2" "$TMP/w94d.ref" \
  && ok "oracle: identical bytes for sized frames (long, mixed, zero locals, ^)" || no "oracle sized-frame bytes"

# W10 — the remaining-limits round: one anchor per task.
# @@ W10-A-NAMES @@
echo "W10-A: forward references for one-byte names; 1024 long names"
# Mutual recursion between one-byte words: a = "is even", b = "is odd", zero is
# true.  (The spelling with ≡ compiles too; ≡ is non-zero on EQUAL, so there the
# `[` fires for n ≠ 0 and both calls return at once — 0, by its own logic.)
[ "$(printf '%s' ':a"0-[_0^]1-b; :b"0-[_1^]1-a; 5aṄ 6aṄ 7bṄ' | gc)" = "100" ] \
  && [ "$(printf '%s' ':a"0≡[_0^]1-b;:b"0≡[_1^]1-a;5aṄ' | gc)" = "0" ] \
  && ok ":a…b; :b…a; mutual recursion between one-byte words" || no "one-byte mutual recursion"
[ "$(printf '%s' '3′d⍎Ṅ 4⍳′d€⍕ :d⊗;' | gc)" = "60 2 4 6 " ] \
  && ok "′x of a one-byte word defined further down (a jmp thunk, patched)" || no "one-byte forward quotation"
[ "$(printf '%s' '⊚mq≢÷; :q∑; 5⍳mṄ' | gc)" = "2" ] \
  && ok "a chain link to a one-byte word defined later" || no "one-byte forward chain link"
# Redefinition keeps its meaning: a call after the first :d binds to it, a call
# before any :d binds to the first, a call after the second to the second.
[ "$(printf '%s' ':f d; :d1; :g d; :d2; :h d; fṄgṄhṄ' | gc)" = "112" ] \
  && ok "forward calls bind to the FIRST definition; a redefinition rebinds only later calls" || no "one-byte redefinition"
# Templates dispatch before words: an atom byte never goes forward, even if a
# word of that byte is defined later.
[ "$(printf '%s' '3⊗Ṅ :⊗99; 3⊗Ṅ' | gc)" = "66" ] \
  && ok "an atom byte is still its template, never a forward call" || no "template before forward"
[ "$(printf '%s' ':‹a›b;5‹a›Ṅ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word b" ] \
  && [ ! -s "$TMP/u.out" ] \
  && ok "a one-byte name never defined: GOLF: undefined word b at end of input, exit 2, no binary" || no "one-byte undefined at end"
[ "$(printf '%s' '′q_ 1Ṅ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word q" ] \
  && ok "... and ′q of one never defined, the same" || no "one-byte undefined quotation at end"
# The oracle agrees byte for byte on forward one-byte calls, ′ and chains.
W10AP=':a"0≡[_0^]1-b; :b"0≡[_1^]1-a; 7aṄ 3′d⍎Ṅ ⊚mq≢÷; :q∑; 5⍳mṄ :d⊗;'
cat "$TMP/pre.gb" <(printf '%s' "$W10AP" | python3 tools/codepage.py encode) > "$TMP/w10a.src"
"$TMP/golf2" < "$TMP/w10a.src" > "$TMP/w10a.g2" 2>/dev/null
python3 boot/golfref.py < "$TMP/w10a.src" > "$TMP/w10a.ref" 2>/dev/null
[ -s "$TMP/w10a.g2" ] && cmp -s "$TMP/w10a.g2" "$TMP/w10a.ref" \
  && ok "oracle: identical bytes for one-byte forward references" || no "oracle one-byte forward bytes"
# 1024 long names: every one a word AND a variable (cells 0x4E0800..0x4E27F8),
# two of them called forward, so the table, the heads and the bank all reach
# their ends.  P are the prelude's, so the program adds 1024 - P.
w10n=$((1024 - w93p)); w10s=""
for k in $(seq 1 $w10n); do w10s="$w10s:‹v$k›$k→‹v$k›;"; done
w10s="‹v$w10n›‹v1›$w10s‹v$((w10n-1))›←‹v1›Ṅ←‹v$((w10n-1))›Ṅ←‹v$w10n›Ṅ"
w10s="${w10s/:‹v$w10n›/:‹z›;:‹v$w10n›}"
[ "$(printf '%s' "$w10s" | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: too many long names ‹z›" ] \
  && ok "1024 long names fill the table: one more (‹z›) is refused" || no "1024 cap: $(cat "$TMP/u.err")"
w10s="${w10s/:‹z›;/}"
[ "$(printf '%s' "$w10s" | und)" = "0" ] && chmod +x "$TMP/u.out" && [ "$("$TMP/u.out")" = "1$((w10n-1))$w10n" ] \
  && ok "$w10n user long names (+ $w93p prelude) as words and variables, the 1024th's cell (0x4E27F8) included" || no "1024 long names run"

# @@ W10-B-V1DIV @@
echo "v1's / % (W10-B): unsigned as ever, but a zero divisor is a clean error, not SIGFPE"
# Before W10-B `7 0/` and `7 0%` died of SIGFPE (status 136): they are v1's
# frozen `xor edx,edx; div rcx` templates.  The v2 blob now OVERRIDES them with
# the W9-2B zero check in front of v1's own tail (tools/mkblob2.py _udivchk).
w92bdied "$(printf '%s' '7 0/N E' | w92b)" "divide by zero" "" \
  && ok "7 0/: exit 1 with the message on fd 2, not SIGFPE" || no "/ by zero"
w92bdied "$(printf '%s' '5N E 7 0%N E' | w92b)" "divide by zero" "5" \
  && ok "7 0%: exit 1 with the message, earlier output kept" || no "% by zero"
w92bdied "$(printf '%s' '7 0\ref/\exec N E' | w92b)" "divide by zero" "" \
  && ok "′/ (the auto-wrapped thunk) checks too" || no "′/ by zero"
[ "$(printf '%s' '7 0%' | atom 2>&1; echo "rc=$?")" = "$(printf 'GOLF: divide by zero\nrc=1')" ] \
  && ok "the bare % template checks without the prelude" || no "bare % by zero"
[ "$(printf '%s' '7 2/N E 7 2%N E 0 1- 2/N E 0 1- 10%N E 0 1- 0 2-/N E 0 7- 2%N E' | gc)" \
    = "$(printf '3\n1\n9223372036854775807\n5\n1\n1')" ] \
  && ok "/ % still UNSIGNED for nonzero divisors (u64 max /2, %10, -1/-2 = 1)" || no "/ % unsigned"
printf '%s' '100 7/N E 100 7%N E 0 1- 3/N E 0 1- 0 2-%N E 1 0/N E' | python3 tools/codepage.py encode \
  | cat "$TMP/pre.gb" - > "$TMP/w10b.src"
"$TMP/golf2" < "$TMP/w10b.src" > "$TMP/w10b.g2" 2>/dev/null
python3 boot/golfref.py < "$TMP/w10b.src" > "$TMP/w10b.ref" 2>/dev/null
cmp -s "$TMP/w10b.g2" "$TMP/w10b.ref" \
  && ok "oracle: identical bytes for checked / %" || no "oracle / % bytes"
chmod +x "$TMP/w10b.ref"
[ "$("$TMP/w10b.ref" 2>&1; echo "rc=$?")" \
    = "$(printf '14\n2\n6148914691236517205\n1\nGOLF: divide by zero\nrc=1')" ] \
  && ok "oracle: the same results and the same clean exit" || no "oracle / % run"

# @@ W10-C-SPILL @@
echo "Spill stack (W10-C): 4096 frames at 0x440000, overflow checked in X"
# X/Y's frames moved from 0x4F0900 (28 frames) to 0x440000..0x47FFFF (4096), so
# nested-list recursion and nested higher-order words go hundreds deep; past the
# end X writes `GOLF: spill stack exhausted` to fd 2 and exits 1.  `w10cn D K`
# pushes K⍳ nested D deep (W10CW defines ‹wrap›: x -> a one-element list [x]).
W10CW=':‹wrap›→‹v›2A 1&\store←‹v›&8\radd\store 1 48≪|;'
w10cn(){ printf '%s⍳%s→i{‹wrap›←i1-"→i0\\eq}' "$2" "$1"; }
[ "$( { printf '%s' "$W10CW"; w10cn 200 3; printf '⍕E'; } | gc)" = "$(printf '[%.0s' $(seq 200))0 1 2$(printf ']%.0s' $(seq 200)) " ] \
  && ok "⍕ of a list nested 200 deep" || no "⍕ 200 deep"
[ "$( { printf '%s' "$W10CW"; w10cn 100 3; printf '"+⍕E'; } | gc)" = "$(printf '[%.0s' $(seq 100))0 2 4$(printf ']%.0s' $(seq 100)) " ] \
  && ok "+ of a list nested 100 deep with itself" || no "+ 100 deep"
[ "$( { printf '%s' "$W10CW"; w10cn 200 3; printf '""≣N E⍤N E'; w10cn 200 3; w10cn 200 4; printf '≣N E'; } | gc)" \
    = "$(printf -- '-1\n201\n0')" ] \
  && ok "≣ and ⍤ at depth 200 (a list matches itself, not one differing at the core)" || no "≣/⍤ 200 deep"
[ "$( { printf '%s' "$W10CW"; w10cn 3000 3; printf '⍤N E'; w10cn 1500 3; printf '"+⍤N E'; } | gc)" = "$(printf '3001\n1501')" ] \
  && ok "⍤ at depth 3000 and + at depth 1500 (thousands of frames)" || no "⍤ 3000 / + 1500 deep"
w10cerr=$( { printf '%s' "$W10CW"; w10cn 100000 3; printf '⍤N E'; } | cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/p" 2>/dev/null \
           && chmod +x "$TMP/p" && { "$TMP/p" > "$TMP/w10c.out" 2>&1; echo "rc=$?"; } 2>/dev/null)
[ "$w10cerr" = "rc=1" ] && [ "$(cat "$TMP/w10c.out")" = "GOLF: spill stack exhausted" ] \
  && ok "⍤ of a 100,000-deep nesting: 'GOLF: spill stack exhausted', exit 1" \
  || no "spill exhaustion: $w10cerr, '$(head -c 80 "$TMP/w10c.out")'"
grep -q "^| \`0x440000\`–\`0x47FFFF\` | 4456448–4718591 | .*4096 frames" REGISTRY.md \
  && [ "$(grep -o '4456448\\radd' lib/prelude.golfj | wc -l)" = 2 ] && grep -q '"262144\\rlt\[' lib/prelude.golfj \
  && ok "REGISTRY §3 and prelude X/Y agree on the spill region and its 4096-frame bound" || no "spill region docs/prelude"

echo "Resource registry (REGISTRY.md): op bytes, mnemonics and glyphs stay disjoint"
python3 tools/codepage.py check \
  && ok "codepage invariants (bytes/mnemonics/glyphs)" || no "codepage invariants (bytes/mnemonics/glyphs)"

echo
echo "v1 bootstrap seed: $(wc -c < self/seed.golf) bytes (self/seed.golf)"
echo "v2 compiler:       $(wc -c < self/golf2.golf) bytes (self/golf2.golf, from self/golf2.golfj)"
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
