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
printf '\f' >> "$TMP/pre.gb"   # + the form feed golfc puts after it: lines count from the program (W11-3B)
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
# program on the ladder would shift.  `)` follows each literal (since W11-1C its
# template opens with the flush-hook load, 48 8b 04 25 ...; it was 6a 01 58).
w6alit(){ printf '%s' "$1" | "$TMP/golf2" 2>/dev/null | od -An -tx1 -v | tr -d ' \n'; }
case "$(w6alit '5)')" in
  *6805000000488b0425*) ok "5 is still push imm32 (68 05 00 00 00)";;
  *)                no "small literal encoding changed";; esac
case "$(w6alit '2147483647)')" in
  *68ffffff7f488b0425*) ok "2^31-1 is still push imm32 (68 ff ff ff 7f)";;
  *)                no "2^31-1 encoding";; esac
case "$(w6alit '2147483648)')" in
  *48b8000000800000000050488b0425*) ok "2^31 switches to mov rax,imm64; push rax";;
  *)                            no "2^31 encoding";; esac
case "$(w6alit '4294967296)')" in
  *48b8000000000100000050488b0425*) ok "2^32 as mov rax,imm64; push rax";;
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
# W9-2A/M-TAG2: a list VALUE is addr | 0x7FFF<<48 (W11-1A; 2^48 before), so the address is masked out with
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
# looping word the way every scratch-using word must.  (W11-1C: N E buffer in
# the prelude's output buffer, apart from tio's, so ‹flush› puts the sum out
# ahead of what f writes.)
[ "$(printf '%s' ':x 65\radd"g;5R′xM S N E‹flush› f' | tio)" = "$(printf '335\nABCDE')" ] \
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
# Since W12-Z3 a ⊡ word takes ⇒z (its table gives it a slot), so the fixed-slot
# case is a : word's.
[ "$(printf '%s' ':f\lsetz;1fN' | und)" = "2" ] \
  && [ "$(cat "$TMP/u.err")" = "GOLF: local out of range z at line 1" ] \
  && ok "a slot name past h is refused outside ⊡, not silently wrapped" || no "lset range"
[ "$(printf '%s' '\dlocf\lgetA;1fN' | und)" = "2" ] \
  && [ "$(cat "$TMP/u.err")" = "GOLF: local out of range A at line 1" ] \
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
[ "$(cat "$TMP/u.err")" = "GOLF: undefined word q at line 1" ] \
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
# W11-1A: the top int is 0x7FFF<<48 - 1 now — [0x7FFF<<48, 2^63) is the list tag's band.
[ "$(printf '%s' '9223090561878065151 1 63\shl\vmax N E 9223090561878065151 1 63\shl\vmin N E' | gc)" \
    = "$(printf -- '9223090561878065151\n-9223372036854775808')" ] \
  && ok "⩌ ⩍ at the largest int (0x7FFF<<48 - 1) vs INT64_MIN" || no "vmax/vmin extremes"
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
[ "$(cat "$TMP/u.err")" = "GOLF: undefined word q at line 1" ] \
  && ok "... with the same message as a plain call, on fd 2" || no "ref undefined message"
[ ! -s "$TMP/u.out" ] && ok "... and no partial binary on fd 1" || no "ref undefined stdout"
[ "$(printf '%s' '⊚mq≢÷;5⍳mṄ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word q at line 1" ] \
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
echo "M-TAG2: a list value is addr | 0x7FFF<<48; T and the M-VEC filter test the tag, not a range"
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
[ "$(printf '%s' '5⍳48>N E' | gc)" = "32767" ] \
  && ok "a list value carries the tag: v >> 48 == 0x7FFF" || no "tag2 tag bits"
[ "$(printf '%s' '0 1-T N E' | gc)" = "1" ] && ok "T: -1 is still an int" || no "tag2 -1"
[ "$(printf '%s' '0 1 63\shl- T N E' | gc)" = "1" ] && ok "T: -2^63 is an int" || no "tag2 min int"
[ "$(printf '%s' '0 1000000000000000-T N E 0 1000000000000000- 7+N E' | gc)" = "$(printf '1\n-999999999999993')" ] \
  && ok "a large negative is an int, and bare + is scalar on it" || no "tag2 big negative"
[ "$(printf '%s' '1 48\shl T N E 32767 48\shl1\rsub T N E 1 63\shl1\rsub T N E' | gc)" = "$(printf '1\n1\n0')" ] \
  && ok "T: 2^48 and 0x7FFF<<48 - 1 are ints; 2^63-1 is in the sacrificed band" || no "tag2 edges"
[ "$(printf '%s' '5⍳→x←x T N E ←x Q E ←x 10+Q E' | gc)" = "$(printf '0\n0 1 2 3 4 \n10 11 12 13 14 ')" ] \
  && ok "a list round-trips through →x/←x and still vectorizes" || no "tag2 var round trip"
# Lists of lists: R's result stored as an element stays a tagged list, so it
# indexes, measures and vectorizes like the outer one.
[ "$(printf '%s' '2A 1&\store 3⍳&8\radd\store 32767 48\shl| "T N E "0 I T N E "0 I Q E 0 I 100+Q E' | gc)" = "$(printf '0\n0\n0 1 2 \n100 101 102 ')" ] \
  && ok "a list of lists stores and indexes; the inner element is a tagged list" || no "tag2 nested"
[ "$(printf '%s' ':s3⍳;3⍳\refs M "L N E 1 I"L N E ∑N E' | gc)" = "$(printf '3\n3\n3')" ] \
  && ok "map building a list per element (inner lists keep the tag)" || no "tag2 map of lists"
# A hand-built block from A is a raw address: every list word accepts it (the
# masking is idempotent), but it is an INT to T and the bare operators until it
# is tagged with 32767 48≪|.
[ "$(printf '%s' '3A 2&\store 5&8\radd\store 6&16\radd\store "S N E "T N E 32767 48\shl| 1+Q E' | gc)" = "$(printf '11\n1\n6 7 ')" ] \
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
[ "$(printf '%s' '5‹nope›Ṅ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word ‹nope› at line 1" ] \
  && [ ! -s "$TMP/u.out" ] \
  && ok "a long name never defined: GOLF: undefined word ‹nope›, exit 2, no binary" || no "undefined long name"
[ "$(printf '%s' ':‹f›‹g›;1Ṅ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word ‹g› at line 1" ] \
  && ok "... reported at end of input, even from inside a definition" || no "undefined long name in a body"
[ "$(printf '%s' '5qṄ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word q at line 1" ] \
  && ok "a one-byte name never defined: same message as before (at end of input since W10-A)" || no "one-byte undefined regression"
[ "$(printf '%s' '‹a b›' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: bad long name ‹a› at line 1" ] \
  && ok "a byte outside 0-9 A-Z a-z _ - is rejected" || no "bad long-name byte"
[ "$(printf '%s' '‹›' | und)" = "2" ] && [ "$(printf '%s' '‹abc' | und)" = "2" ] \
  && [ "$(printf '%s' '‹abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijk›' | und)" = "2" ] \
  && ok "an empty, unterminated or 61-byte long name is rejected" || no "empty/unterminated/long"
# The prelude's own long names (W9-4C on) share the 1024 (256 until W10-A): und
# compiles with the prelude, so the user program's first refused name is
# number 1025 - P.
w93p=$(grep -v '^ *#' lib/prelude.golfj | grep -oE '‹[0-9A-Za-z_-]+›' | sort -u | wc -l | tr -d ' ')
w93n=""; for k in $(seq 1 $((1025 - w93p))); do w93n="$w93n:‹w$k›;"; done
[ "$(printf '%s' "$w93n" | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: too many long names ‹w$((1025 - w93p))› at line 1" ] \
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
# Since W11-0 one-byte words call a long name too (I, ∘ and ⌫ raise their
# errors through ‹throw›): such a call outside a definition is cut as well,
# which leaves those failure paths without their exit — harmless, as both
# compilers get the same cut prelude and nothing here takes a failure path.
# Since W11-1C the printers N E O J Q emit through ‹_1c_put› (the output
# buffer): that call is cut to a raw `)` instead, so the cut prelude still
# prints, unbuffered, exactly what it used to.
# Since W11-2D the list words enter through ‹_2d_chk› (the mask plus the
# use-after-free check) and their loops index through ‹_2d_ix›: those calls
# are cut to the bare mask `16\shl16>` and to `I`, what they replaced.
python3 - lib/prelude.golfj > "$TMP/pre-m1.gb" <<'PY'
import sys; sys.path.insert(0, "tools"); import mkblob2, codepage
b = codepage.encode(open(sys.argv[1], encoding="utf-8").read())
out, i, skip = bytearray(), 0, False
while i < len(b):
    c = b[i]
    if c == 0x3A and b[i+1:i+2] == bytes([mkblob2.LNAME_BYTE]): skip = True
    if c == mkblob2.LNAME_BYTE and not skip:
        j = b.index(mkblob2.RNAME_BYTE, i) + 1
        if b[i+1:j-1] == b"_1c_put": out += b")"   # W11-1C: the raw byte write
        if b[i+1:j-1] == b"_2d_chk": out += codepage.encode("16\\shl16>")   # W11-2D: the bare mask
        if b[i+1:j-1] == b"_2d_ix": out += b"I"   # W11-2D: the loops' index is I
        i = j; continue
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
  # W11-1E: the pre-M2 logic leaves v1's fixed p_filesz (0x10000) in the header;
  # today's compilers write the image's size there, so the old output gets the same.
  if [ "$w93ref" = pre-m2 ]; then "$TMP/pre-m2" < "$TMP/w93.src" > "$TMP/w93.old" 2>/dev/null
    python3 -c 'import sys; f=sys.argv[1]; b=bytearray(open(f,"rb").read()); b[96:104]=len(b).to_bytes(8,"little"); open(f,"wb").write(b)' "$TMP/w93.old"
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
[ "$(printf '%s' '2A 1&\store 3⍳&8\radd\store 32767 48≪| 5⍳1↑⧺"≢N E"0⊇100+⍕E 1⊇N E' | gc)" = "$(printf '2\n100 101 102 \n0')" ] \
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
[ "$(printf '%s' '1⍳32767 48≪1\rsub+ 1⍳0 1 63≪-+⧺ 1⍳0 1-+⧺ 1⍳5+⧺⍋⍕' | gc)" = "-9223372036854775808 -1 5 9223090561878065151 " ] \
  && ok "⍋: the full signed int range, -2^63 .. 0x7FFF<<48 - 1 (W11-1A)" || no "sort extremes"
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
[ "$(printf '%s' ':‹wrap›→‹v›2A 1&\store←‹v›&8\radd\store 32767 48≪|;5⍳200→i{‹wrap›←i1-"→i0\eq}"≢N E‹flatten›⍕E' | gc)" = "$(printf '1\n0 1 2 3 4 ')" ] \
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
  && [ "$(cat "$TMP/u.err")" = "GOLF: too many locals ‹a17› at line 1" ] && [ ! -s "$TMP/u.out" ] \
  && ok "a 17th local is refused (16 keep every slot a disp8), exit 2" || no "too many locals"
[ "$(printf '%s' ':g⇐‹x›;' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: local out of range ‹x› at line 1" ] \
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
[ "$(printf '%s' ':‹a›b;5‹a›Ṅ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word b at line 1" ] \
  && [ ! -s "$TMP/u.out" ] \
  && ok "a one-byte name never defined: GOLF: undefined word b at end of input, exit 2, no binary" || no "one-byte undefined at end"
[ "$(printf '%s' '′q_ 1Ṅ' | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: undefined word q at line 1" ] \
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
# their ends.  P are the prelude's, so the program adds 1024 - P.  (About 66 KB
# with the prelude: past the old 64 KB image, inside W11-1E's 192 KB cap.)
w10n=$((1024 - w93p)); w10s=""
for k in $(seq 1 $w10n); do w10s="$w10s:‹v$k›$k→‹v$k›;"; done
w10s="‹v$w10n›‹v1›$w10s‹v$((w10n-1))›←‹v1›Ṅ←‹v$((w10n-1))›Ṅ←‹v$w10n›Ṅ"
w10s="${w10s/:‹v$w10n›/:‹z›;:‹v$w10n›}"
[ "$(printf '%s' "$w10s" | und)" = "2" ] && [ "$(cat "$TMP/u.err")" = "GOLF: too many long names ‹z› at line 1" ] \
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
W10CW=':‹wrap›→‹v›2A 1&\store←‹v›&8\radd\store 32767 48≪|;'
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

# W11 — round 3 (Python/Rust gaps): one marker per task.  A task adds its tests
# directly under its own marker, never below the next one.
# === W11-0 ===
echo "W11-0: ‹throw›, the runtime's one error exit (msg code list -> 'GOLF: msg' on fd 2, exit 1)"
# The stub every prelude error but X's goes through (index, compose arena, the
# two ⌫ guards); W11-3A makes it catchable.  stdout stays empty, stderr is
# exactly the line, and the routed errors read as they always did.
w110(){ printf '%s' "$1" | gc > "$TMP/w110.out" 2> "$TMP/w110.err"; echo "rc=$? $(wc -c < "$TMP/w110.out") $(cat "$TMP/w110.err")"; }
[ "$(w110 '7Ṅ“boom“U‹throw›8Ṅ')" = "rc=1 1 GOLF: boom" ] && [ "$(w110 '0⍳‹throw›')" = "rc=1 0 GOLF: " ] \
  && [ "$(w110 '3⍳9⊇')" = "rc=1 0 GOLF: index out of range" ] && [ "$(w110 '3⍳"⌫⌫')" = "rc=1 0 GOLF: double free" ] \
  && [ "$(w110 '5⌫')" = "rc=1 0 GOLF: free of a non-heap value" ] \
  && [ "$(w110 '0→i{′⊕′⊖∘_←i1+"→i1700\rlt1+}')" = "rc=1 0 GOLF: compose arena exhausted" ] \
  && ok "‹throw›: user message, empty message, and the four routed errors unchanged" || no "‹throw› stub / routed errors"

# === W11-1A ===
echo "W11-1A: the list tag is 0x7FFF<<48; [2^48, 2^49) are ordinary integers again"
# Through W10 a list was addr | 2^48, so 2^48+1 was dispatched as a list by the
# bare + and segfaulted, and big sums of squares printed garbage.
[ "$(printf '%s' '16777216 16777216* 1+Ṅ' | gc)" = "281474976710657" ] \
  && ok "2^24*2^24 + 1 is scalar arithmetic (281474976710657)" || no "w111a 2^48+1"
[ "$(printf '%s' '100000⍳"*∑Ṅ' | gc)" = "333328333350000" ] \
  && ok "sum of squares below 100000 passes through [2^48, 2^49)" || no "w111a sum of squares"
[ "$(printf '%s' '1 48\shl"T Ṅ␤1\rsub T Ṅ␤1 48\shl 2⍳+⍕␤1 49\shl 1\rsub 1+Ṅ' | gc)" \
    = "$(printf '1\n1\n281474976710656 281474976710657 \n562949953421312')" ] \
  && ok "2^48 boundary: 2^48 and 2^48-1 are ints, 2^48 broadcasts as a scalar, 2^49-1 + 1" || no "w111a 2^48 boundary"
[ "$(printf '%s' '0 5-"T Ṅ␤3+Ṅ␤0 1 48\shl-"T Ṅ␤1-Ṅ␤0 5-3⍳*⍕' | gc)" \
    = "$(printf '1\n-2\n1\n-281474976710657\n0 -5 -10 ')" ] \
  && ok "negatives (top bits 0xFFFF) stay ints, scalar and broadcast" || no "w111a negatives"
[ "$(printf '%s' '32766 48\shl"T Ṅ␤1+Ṅ␤3⍳48>Ṅ' | gc)" = "$(printf '1\n9222809086901354497\n32767')" ] \
  && ok "0x7FFE<<48 is an int; a list's top 16 bits are 0x7FFF" || no "w111a band edge"

# === W11-1B ===
echo "W11-1B: file I/O — ‹open› ‹create› ‹close› ‹fread› ‹fwrite› ‹readfile› ‹writefile›"
# w111b compiles the program and runs it INSIDE a fresh temp dir, so relative
# paths like “x.txt“ land there; it prints `rc=<status> <stdout>|<stderr>`.
mkdir -p "$TMP/w111b/d"
w111b(){ printf '%s' "$1" | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - | "$TMP/golf2" > "$TMP/w111b/p" 2>/dev/null \
          && chmod +x "$TMP/w111b/p" && (cd "$TMP/w111b" && ./p > p.out 2> p.err; echo "rc=$? $(cat p.out)|$(cat p.err)"); }
[ "$(w111b '“hello, file“⊃“w.txt“⊃‹writefile›“w.txt“⊃‹readfile›"⊐␤≢Ṅ')" = "rc=0 hello, file
11|" ] && [ "$(cat "$TMP/w111b/w.txt")" = "hello, file" ] \
  && ok "‹writefile› then ‹readfile›: the file holds the bytes and reads back" || no "writefile/readfile round trip"
[ "$(w111b '7Ṅ“x.txt“⊃‹readfile›⊐')" = "rc=1 7|GOLF: cannot open x.txt (ENOENT)" ] \
  && ok "missing file: GOLF: cannot open x.txt (ENOENT), exit 1" || no "missing file message"
[ "$(w111b '“d“⊃‹readfile›')" = "rc=1 |GOLF: cannot read d (EISDIR)" ] \
  && [ "$(w111b '“d“⊃‹create›')" = "rc=1 |GOLF: cannot create d (EISDIR)" ] \
  && [ "$(w111b '“w.txt/q“⊃‹open›')" = "rc=1 |GOLF: cannot open w.txt/q (ENOTDIR)" ] \
  && [ "$(w111b '0⍳“no/f“⊃‹writefile›')" = "rc=1 |GOLF: cannot create no/f (ENOENT)" ] \
  && ok "errors name the verb and path: EISDIR on read and create, ENOTDIR, ENOENT on create" || no "path error messages"
[ "$(w111b '99‹close›')" = "rc=1 |GOLF: cannot close fd 99 (EBADF)" ] \
  && [ "$(w111b '99 4‹fread›')" = "rc=1 |GOLF: cannot read fd 99 (EBADF)" ] \
  && [ "$(w111b '“ab“⊃99‹fwrite›')" = "rc=1 |GOLF: cannot write fd 99 (EBADF)" ] \
  && ok "fd words name the fd: close, fread, fwrite on fd 99 (EBADF)" || no "fd error messages"
[ "$(w111b '1‹_1b_ename›⊐ 13‹_1b_ename›⊐ 17‹_1b_ename›⊐ 21‹_1b_ename›⊐ 20‹_1b_ename›⊐ 99‹_1b_ename›⊐')" = "rc=0 EPERMEACCESEEXISTEISDIRENOTDIRerrno 99|" ] \
  && ok "errno names: EPERM EACCES EEXIST EISDIR ENOTDIR, and the 'errno N' fallback" || no "errno names"
[ "$(w111b '5179712⊙Ṅ')" = "rc=0 0|" ] && grep -q '"5179712\\store‹_1b_ename›' lib/prelude.golfj \
  && ok "the errno goes in the 1B cell 5179712 before the throw (0 until a failure)" || no "errno cell"
[ "$(w111b '“w.txt“⊃‹open›"4‹fread›⊐␤"4‹fread›⊐␤"4‹fread›⊐␤"4‹fread›≢Ṅ"0‹fread›≢Ṅ‹close›')" = "rc=0 hell
o, f
ile
00|" ] && ok "‹fread›: chunks of n bytes, a short last one, then empty at EOF" || no "fread chunks"
[ "$(w111b '“w.txt“⊃‹create›"“ab“⊃&‹fwrite›"“cd“⊃&‹fwrite›‹close›“w.txt“⊃‹readfile›⊐ 0⍳“z.txt“⊃‹writefile›“z.txt“⊃‹readfile›"≢Ṅ T Ṅ')" = "rc=0 abcd00|" ] \
  && [ -e "$TMP/w111b/z.txt" ] && [ ! -s "$TMP/w111b/z.txt" ] \
  && ok "‹create› truncates and ‹fwrite›s append; an empty file reads back as an empty tagged list" || no "create/fwrite/empty"
[ "$(w111b ':‹m›255$;300000⍳′‹m›€“b.txt“⊃‹writefile›“b.txt“⊃‹readfile›"≢Ṅ␤∑Ṅ')" = "rc=0 300000
38246416|" ] && [ "$(wc -c < "$TMP/w111b/b.txt")" = 300000 ] \
  && ok "a 300000-byte file (past the 64 KB first block) round-trips byte for byte" || no "big file"
[ "$(w111b '7Ṅ“ab“⊃1‹fwrite›8Ṅ')" = "rc=0 7ab8|" ] \
  && ok "‹fwrite› to fd 1 drains the 1C buffer first: buffered and direct bytes stay in order" || no "fwrite/buffer order"

# === W11-1C ===
echo "W11-1C: buffered output — Ṅ ⍕ ␤ 🗲 ⊐ through an 8 KB buffer, ‹flush›, flush at every exit"
# Byte-identical output for the big case, then the write count (strace when it
# is installed; the counts are exact: ceil(bytes / 8192) writes, and none for a
# program that prints nothing).
printf '%s' '1000000⍳⍕' | gc > "$TMP/w111c.out"; cp "$TMP/p" "$TMP/w111c.big"
python3 -c "import sys; sys.stdout.write(' '.join(map(str, range(10**6))) + ' ')" > "$TMP/w111c.exp"
cmp -s "$TMP/w111c.out" "$TMP/w111c.exp" \
  && ok "1000000⍳⍕ prints the same 6,888,890 bytes" || no "1000000⍳⍕ output"
printf '%s' ':a_65; 20000⍳′a€⊐' | gc > "$TMP/w111c.20k"
[ "$(wc -c < "$TMP/w111c.20k")" = 20000 ] && [ "$(tr -d A < "$TMP/w111c.20k" | wc -c)" = 0 ] \
  && ok "⊐ of 20000 bytes crosses the 8192-byte buffer twice, nothing lost" || no "buffer wrap"
cp "$TMP/p" "$TMP/w111c.wrap"
if command -v strace >/dev/null 2>&1; then
  w111cw(){ strace -f -e trace=write -o "$TMP/w111c.st" "$@" > /dev/null 2>&1; grep -c '^[0-9]* *write(' "$TMP/w111c.st"; }
  printf '%s' '1 2+_' | gc > /dev/null; cp "$TMP/p" "$TMP/w111c.none"
  [ "$(w111cw "$TMP/w111c.big")" = 841 ] && [ "$(w111cw "$TMP/w111c.wrap")" = 3 ] \
    && [ "$(w111cw "$TMP/w111c.none")" = 0 ] \
    && ok "write(2) calls (strace): 1000000⍳⍕ 841 (was 6,888,890), 20000 bytes 3, no output 0" \
    || no "write counts: $(w111cw "$TMP/w111c.big") $(w111cw "$TMP/w111c.wrap") $(w111cw "$TMP/w111c.none")"
  # ‹readline› flushes before it reads, so a prompt is out before the program blocks.
  printf '%s' '“> “🗲‹readline›_⊐' | gc > /dev/null; cp "$TMP/p" "$TMP/w111c.rl"
  echo hi | strace -e trace=read,write -o "$TMP/w111c.st" "$TMP/w111c.rl" > /dev/null 2>&1
  grep -E '^(read\(0|write\(1)' "$TMP/w111c.st" | head -1 | grep -q '^write(1, "> "' \
    && ok "‹readline› flushes a pending prompt before its first read(2)" || no "prompt before read"
else ok "write counts: strace not installed, skipped"; ok "prompt before read: strace not installed, skipped"; fi
# Every exit flushes: falling off the end, `.` with a status, the ÷ / % divide
# guards, ‹throw› (index error) — and the message lands AFTER the output.
w111c(){ printf '%s' "$1" | gc > "$TMP/w111c.o" 2>&1; echo "rc=$? $(cat "$TMP/w111c.o")"; }
[ "$(w111c '42Ṅ␤')" = "rc=0 42" ] && [ "$(w111c '42Ṅ3.99Ṅ')" = "rc=3 42" ] \
  && [ "$(w111c '7Ṅ␤3⍳9⊇')" = "$(printf 'rc=1 7\nGOLF: index out of range')" ] \
  && [ "$(w111c '7Ṅ␤“boom“⊃‹throw›')" = "$(printf 'rc=1 7\nGOLF: boom')" ] \
  && [ "$(w111c '7Ṅ␤5 0÷')" = "$(printf 'rc=1 7\nGOLF: divide by zero')" ] \
  && [ "$(w111c '7Ṅ␤5 0%')" = "$(printf 'rc=1 7\nGOLF: divide by zero')" ] \
  && ok "flush on exit, on ‘.’, and before ‹throw›/divide-by-zero messages (output first)" || no "exit flush: $(w111c '7Ṅ␤3⍳9⊇')"
[ "$( { printf '%s7Ṅ␤' "$W10CW"; w10cn 100000 3; printf '⍤N E'; } | gc 2>&1)" = "$(printf '7\nGOLF: spill stack exhausted')" ] \
  && ok "X's spill-stack error flushes too: the 7 printed before it comes first" || no "spill error flush order"
# `)` and `(` stay raw (one write/read per byte) but flush the buffer first, so
# mixing them with the printers keeps program order; ⎈ does not, hence ‹flush›.
[ "$(printf '%s' '65)66Ṅ67)“d“🗲69)' | gc)" = "A66CdE" ] \
  && ok "raw ‘)’ between buffered printers keeps program order (it flushes first)" || no "mixed ) order"
[ "$(printf '%s' '5Ṅ1“b“4+1 1⎈_' | gc)" = "b5" ] && [ "$(printf '%s' '5Ṅ‹flush›1“b“4+1 1⎈_' | gc)" = "5b" ] \
  && ok "raw ⎈ write overtakes the buffer unless the program calls ‹flush›" || no "‹flush› + ⎈"
[ "$(printf '%s' '2 5179784⊛5Ṅ' | gc 2>&1 >/dev/null)" = "5" ] \
  && ok "the buffer's fd cell (0x4F0988) redirects the printers (fd 2)" || no "buffer fd cell"
# The flush hook is BSS, filled only by the prelude: a bare program (the compiler
# itself) never calls it — and the oracle compiles the same exit/flush path.
[ "$(printf '%s' '72)73)10)' | atom)" = "HI" ] && [ "$(printf '%s' '5⍳⍕␤7Ṅ' | gref)" = "$(printf '0 1 2 3 4 \n7')" ] \
  && ok "no prelude: ‘)’ is still a raw write; golfref.py flushes at exit too" || no "bare ) / oracle flush"

# === W11-1D ===
echo "W11-1D: text words ‹fmt› ‹hex› ‹parsehex› ‹split› ‹trim› ‹startswith› ‹joinwith› ‹pad›"
# Code lists in, code lists out; every list result is a new list.  124) prints
# `|` so padding and trimming show their edges.
[ "$(printf '%s' '“a, b,c“⊃44‹split›′‹trim›€"≢Ṅ␤"0⊇⊐␤"1⊇⊐␤2⊇⊐␤255‹hex›⊐' | gc)" = "$(printf '3\na\nb\nc\nff')" ] \
  && ok "the done-when pair: “a, b,c“⊃44‹split›′‹trim›€ gives a b c; 255‹hex›⊐ prints ff" || no "w11-1d done-when"
[ "$(printf '%s' '0‹fmt›⊐␤123‹fmt›⊐␤0 45-‹fmt›⊐␤0 1-‹fmt›⊐␤1 63≪‹fmt›⊐␤1 63≪⊖‹fmt›⊐␤10‹fmt›"≢Ṅ⍕' | gc)" \
   = "$(printf '0\n123\n-45\n-1\n-9223372036854775808\n9223372036854775807\n249 48 ')" ] \
  && ok "‹fmt›: 0, positive, negative, -1, INT64_MIN, INT64_MAX; a real code list" || no "w11-1d fmt"
[ "$(printf '%s' '0‹hex›⊐␤3054‹hex›⊐␤0 1-‹hex›⊐␤1 63≪‹hex›⊐␤15‹hex›⊐16‹hex›⊐' | gc)" \
   = "$(printf '0\nbee\nffffffffffffffff\n8000000000000000\nf10')" ] \
  && ok "‹hex›: lowercase, no prefix, negatives as unsigned two's complement" || no "w11-1d hex"
[ "$(printf '%s' '“ff“⊃‹parsehex›Ṅ␤“  -1A“⊃‹parsehex›Ṅ␤“+deadBEEFx9“⊃‹parsehex›Ṅ␤“zz“⊃‹parsehex›Ṅ␤0⍳‹parsehex›Ṅ␤“0x1f“⊃‹parsehex›Ṅ␤“ffffffffffffffff“⊃‹parsehex›Ṅ' | gc)" \
   = "$(printf '255\n-26\n3735928559\n0\n0\n0\n-1')" ] \
  && ok "‹parsehex›: case-blind digits, whitespace and sign, stops at a non-hex byte, bad/empty -> 0, wraps" || no "w11-1d parsehex"
[ "$(printf '%s' '1 63≪"‹hex›‹parsehex›≡Ṅ 0 1-"‹hex›‹parsehex›≡Ṅ 48879"‹hex›‹parsehex›≡Ṅ 0 77-"‹fmt›‹num›≡Ṅ' | gc)" = "-1-1-1-1" ] \
  && ok "‹hex›‹parsehex› and ‹fmt›‹num› round-trip (INT64_MIN, -1, 0xbeef, -77)" || no "w11-1d round trip"
[ "$(printf '%s' '0⍳44‹split›"≢Ṅ0⊇≢Ṅ␤“,a,,b,“⊃44‹split›"≢Ṅ′≢€⍕␤“abc“⊃44‹split›"≢Ṅ0⊇⊐␤“k=v“⊃61‹split›⍕' | gc)" \
   = "$(printf '10\n50 1 0 1 0 \n1abc\n[107] [118] ')" ] \
  && ok "‹split›: empty fields kept (Python str.split), the empty list is one empty field, no sep is one field" || no "w11-1d split"
[ "$(printf '%s' '2⍳9+“ hi  there “⊃⧺2⍳12+⧺‹trim›"≢Ṅ124)⊐124)␤“   “⊃‹trim›≢Ṅ0⍳‹trim›≢Ṅ“x“⊃‹trim›⊐“ab“⊃‹trim›⊐' | gc)" \
   = "$(printf '9|hi  there|\n00xab')" ] \
  && ok "‹trim›: tabs/newlines/CR/spaces both ends, inner kept; all-blank and empty give empty" || no "w11-1d trim"
[ "$(printf '%s' '“abc“⊃“ab“⊃‹startswith›Ṅ“abc“⊃“abc“⊃‹startswith›Ṅ“abc“⊃0⍳‹startswith›Ṅ“ab“⊃“abc“⊃‹startswith›Ṅ“abc“⊃“b“⊃‹startswith›Ṅ0⍳0⍳‹startswith›Ṅ0⍳“a“⊃‹startswith›Ṅ“abc“⊃“ab“⊃‹startswith›[124)]' | gc)" = "0001101|" ] \
  && ok "‹startswith›: 0 on a prefix (zero-is-true like ∊), the empty prefix always, longer prefix 1" || no "w11-1d startswith"
[ "$(printf '%s' '“x,y,z“⊃44‹split›“ - “⊃‹joinwith›⊐␤“a b“⊃32‹split›44‹joinwith›⊐␤0⍳44‹joinwith›≢Ṅ␤“a“⊃32‹split›“--“⊃‹joinwith›⊐␤“,,“⊃44‹split›44‹joinwith›⊐␤3⍳′‹fmt›€0⍳‹joinwith›⊐' | gc)" \
   = "$(printf 'x - y - z\na,b\n0\na\n,,\n012')" ] \
  && ok "‹joinwith›: list or int sep, empty list of lists, one element, inverse of ‹split›" || no "w11-1d joinwith"
[ "$(printf '%s' '42‹fmt›5‹pad›⊐124)␤“abcdef“⊃3‹pad›⊐124)␤0⍳2‹pad›⍕124)“ab“⊃0 3-‹pad›⊐124)' | gc)" = "$(printf '   42|\nabcdef|\n32 32 |ab|')" ] \
  && ok "‹pad›: left-pads with spaces, never truncates, negative width is a copy" || no "w11-1d pad"
# The input is never written, and the words nest inside a map (X/Y frames).
[ "$(printf '%s' '“ a “⊃"‹trim›_"⊐124)"32‹split›_"5‹pad›_"0⍳‹startswith›_⊐124)3⍳′‹fmt›€⍕' | gc)" = "$(printf ' a | a |[48] [49] [50] ')" ] \
  && ok "the text words leave their input unchanged and nest inside €" || no "w11-1d purity/nesting"
# The Python oracle compiles the prelude to the same behaviour.
w111d='“ x,ff , -1A“⊃44‹split›′‹trim›€"′‹parsehex›€⍕"124‹joinwith›⊐0 255-‹fmt›⊐1 63≪‹hex›⊐'
[ "$(printf '%s' "$w111d" | gref)" = "$(printf '%s' "$w111d" | gc)" ] && [ "$(printf '%s' "$w111d" | gc)" = "0 255 -26 x|ff|-1A-2558000000000000000" ] \
  && ok "oracle: boot/golfref.py runs the text words identically" || no "w11-1d oracle"
# REFERENCE.md's Text examples print what the doc says.
w111dbad=""
while IFS= read -r w111dl; do
  w111dp=${w111dl%%  ->*}; w111dp=${w111dp%"${w111dp##*[! ]}"}; w111dw=${w111dl##*->  }
  [ "$(printf '%s' "$w111dp" | gc)" = "$w111dw" ] || w111dbad="$w111dbad [$w111dp]"
done < <(sed -n '/^### Text$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w111dbad" ] && [ "$(sed -n '/^### Text$/,/^### /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 8 ] \
  && ok "REFERENCE.md's Text examples print what they say" || no "REFERENCE Text examples:$w111dbad"

# === W11-1E ===
echo "W11-1E: the program-size cap is 192 KB (196608 bytes), checked; p_filesz is the image's size"
# Until W11-1E every program was one PT_LOAD with v1's fixed 64 KB p_filesz and
# nothing checked it: a bigger one compiled and then crashed.  Now p_filesz is
# the file's true size and both compilers refuse an image past 0x430000 (the
# W11-1C output buffer, the lowest runtime region; REGISTRY §3).
w11e(){ cat "$TMP/pre.gb" - > "$TMP/e.src"; "$1" < "$TMP/e.src" > "$TMP/e.out" 2>"$TMP/e.err"; echo "$?"; }
w11efsz(){ python3 -c 'import sys; b=open(sys.argv[1],"rb").read(); print(int.from_bytes(b[96:104],"little"), len(b))' "$1"; }
# P(a,b) = `0 0`, a x ⊕ (u bytes each: 4 until W12-O1 put its not-a-number
# check in front, 26 since), b x `&_` (5 bytes), `Ṅ`: gcd(u,5) = 1, so any size
# from P(0,0) up is reachable and the test lands on the cap exactly.
w11eprog(){ python3 -c 'import sys; a,b=int(sys.argv[1]),int(sys.argv[2]); sys.stdout.write("0 0"+"⊕"*a+"&_"*b+"Ṅ")' "$1" "$2" | python3 tools/codepage.py encode; }
[ "$(w11eprog 0 0 | w11e "$TMP/golf2")" = 0 ] && w11e0=$(stat -c%s "$TMP/e.out") || w11e0=0
w11eu=$(python3 -c 'import sys; sys.path.insert(0,"tools"); import mkblob2; print(len(mkblob2.OVERRIDES[0x81]))')
w11ed=$((196608 - w11e0)); w11eb=0; while [ $(((w11ed - 5*w11eb) % w11eu)) -ne 0 ]; do w11eb=$((w11eb+1)); done
w11ea=$(((w11ed - 5*w11eb) / w11eu))
w11eprog "$w11ea" "$w11eb" > "$TMP/e.cap.g2"
[ "$(w11e "$TMP/golf2" < "$TMP/e.cap.g2")" = 0 ] && [ "$(w11efsz "$TMP/e.out")" = "196608 196608" ] \
  && chmod +x "$TMP/e.out" && [ "$("$TMP/e.out")" = "$w11ea" ] \
  && ok "a program of exactly 196608 bytes (image up to 0x430000) compiles, p_filesz = 196608, runs and prints $w11ea" \
  || no "program at the cap ($w11e0 base, $(cat "$TMP/e.err"))"
cp "$TMP/e.out" "$TMP/e.cap.bin"
python3 boot/golfref.py < "$TMP/e.src" > "$TMP/e.cap.ref" 2>/dev/null
cmp -s "$TMP/e.cap.bin" "$TMP/e.cap.ref" && ok "oracle: golfref emits the same 196608 bytes" || no "oracle at the cap"
[ "$(w11e "$TMP/seed" < "$TMP/e.cap.g2")" = 0 ] && cmp -s "$TMP/e.out" "$TMP/e.cap.bin" \
  && ok "... and so does seed" || no "seed at the cap"
w11eprog $((w11ea + 1)) "$w11eb" > "$TMP/e.over.g2"
[ "$(w11e "$TMP/golf2" < "$TMP/e.over.g2")" = 2 ] && [ "$(cat "$TMP/e.err")" = "GOLF: program too large" ] && [ ! -s "$TMP/e.out" ] \
  && ok "$w11eu bytes (one ⊕) over the cap: GOLF: program too large on fd 2, exit 2, nothing on fd 1" || no "over the cap: $(cat "$TMP/e.err")"
[ "$(w11e "$TMP/seed" < "$TMP/e.over.g2")" = 2 ] && [ ! -s "$TMP/e.out" ] && [ ! -s "$TMP/e.err" ] \
  && ok "... seed exits 2 silently, as for an undefined word" || no "seed over the cap"
[ "$(python3 boot/golfref.py < "$TMP/e.src" 2>"$TMP/e.err" > "$TMP/e.out"; echo $?)" = 2 ] && [ "$(cat "$TMP/e.err")" = "GOLF: program too large" ] \
  && ok "... and golfref says the same" || no "golfref over the cap"
# Far over (a 1 MB program): refused while compiling, before the buffer can
# reach the compiler's own state.
[ "$(w11eprog 262144 0 | w11e "$TMP/golf2")" = 2 ] && [ "$(cat "$TMP/e.err")" = "GOLF: program too large" ] && [ ! -s "$TMP/e.out" ] \
  && ok "a 1 MB program is refused the same way" || no "far over the cap"
# Between the old 64 KB and the new cap, with real work in it: one word of
# 2000 store/load/increment statements, then the list heap and the printers.
w11es=""; for k in $(seq 1 2000); do w11es="$w11es$k→‹x›←‹x›⊕→‹x›"; done
w11es=":‹f›0$w11es←‹x›⊕;‹f›Ṅ 100⍳"'"*∑Ṅ'
[ "$(printf '%s' "$w11es" | python3 tools/codepage.py encode | w11e "$TMP/golf2")" = 0 ] && chmod +x "$TMP/e.out" \
  && [ "$(stat -c%s "$TMP/e.out")" -gt 65536 ] && [ "$("$TMP/e.out")" = "2002328350" ] \
  && ok "a $(stat -c%s "$TMP/e.out")-byte program (> 64 KB) runs: the list heap and the output buffer above the image still work" \
  || no "program past 64 KB: $(cat "$TMP/e.err")"
w11efsz "$TMP/golf2" | { read -r f n; [ "$f" = "$n" ] && [ "$n" -lt 65536 ]; } \
  && ok "golf2's own p_filesz is its size, under the 64 KB its data base (0x410000) needs" || no "golf2 p_filesz"

# === W11-2A ===
echo "W11-2A: ⎘“path“ includes a file (fd-0 swap, nested, include-once, . then lib/)"
# Every include test runs in its own directory: paths resolve against the
# compiler's cwd, then lib/.  w112a <compiler> compiles prelude + stdin there,
# leaving $TMP/inc/p (binary), $TMP/inc/err and the exit status on stdout.
mkdir -p "$TMP/inc/lib" "$TMP/inc/sub"
w112enc(){ python3 tools/codepage.py encode; }
w112a(){ cat "$TMP/pre.gb" <(w112enc) > "$TMP/inc/src"; (cd "$TMP/inc" && "$1" < src > p 2>err; echo $?); }
w112run(){ chmod +x "$TMP/inc/p" && "$TMP/inc/p"; }
printf '%s' ':‹sq›"*;'                 | w112enc > "$TMP/inc/sq.g2"
printf '%s' '⎘“sq.g2“:‹cube›"‹sq›*;'   | w112enc > "$TMP/inc/lib/cube.g2"
printf '%s' '12'                        > "$TMP/inc/twelve.g2"
printf '%s' '# a comment with no newline at the end' > "$TMP/inc/c.g2"
[ "$(printf '%s' '⎘“sq.g2“5‹sq›Ṅ' | w112a "$TMP/golf2")" = 0 ] && [ "$(w112run)" = 25 ] \
  && ok "a program uses a word defined in an included file" || no "include a word: $(cat "$TMP/inc/err")"
cp "$TMP/inc/p" "$TMP/inc/p.one"
printf '%s' ':‹sq›"*;5‹sq›Ṅ' | w112a "$TMP/golf2" > /dev/null
cmp -s "$TMP/inc/p" "$TMP/inc/p.one" && ok "... and compiles to exactly the bytes of the same source written in place" || no "include is not textual"
[ "$(printf '%s' '⎘“sq.g2“⎘“sq.g2“5‹sq›Ṅ⎘“sq.g2“' | w112a "$TMP/golf2")" = 0 ] && cmp -s "$TMP/inc/p" "$TMP/inc/p.one" \
  && ok "a file included three times compiles once (include-once; same bytes as one include)" || no "double include"
[ "$(printf '%s' '⎘“cube.g2“⎘“sq.g2“3‹cube›Ṅ␤4‹sq›Ṅ' | w112a "$TMP/golf2")" = 0 ] && [ "$(w112run)" = "$(printf '27\n16')" ] \
  && ok "nested: lib/cube.g2 (found through lib/) includes sq.g2, which is then not included again" || no "nested include: $(cat "$TMP/inc/err")"
[ "$(printf '%s' '⎘“nope.g2“1Ṅ' | w112a "$TMP/golf2")" = 2 ] && [ "$(cat "$TMP/inc/err")" = "GOLF: cannot include nope.g2 at line 1" ] && [ ! -s "$TMP/inc/p" ] \
  && ok "a missing file: GOLF: cannot include nope.g2 on fd 2, exit 2, nothing on fd 1" || no "missing include: $(cat "$TMP/inc/err")"
[ "$(printf '%s' '⎘“nope.g2“1Ṅ' | w112a "$TMP/seed")" = 2 ] && [ ! -s "$TMP/inc/err" ] && [ ! -s "$TMP/inc/p" ] \
  && ok "... the seed exits 2 silently, as for every compile error" || no "seed missing include"
[ "$(printf '%s' '⎘“twelve.g2“3+Ṅ⎘“c.g2“7Ṅ' | w112a "$TMP/golf2")" = 0 ] && [ "$(w112run)" = "157" ] \
  && ok "a file's end ends its last token: 12 then 3, and a final comment does not eat the includer" || no "token boundary at end of include"
printf '%s' ':‹sq›0;' | w112enc > "$TMP/inc/lib/sq.g2"
[ "$(printf '%s' '⎘“sq.g2“5‹sq›Ṅ' | w112a "$TMP/golf2")" = 0 ] && [ "$(w112run)" = 25 ] \
  && ok "search order: the path as written (cwd) before lib/" || no "search order"
printf '%s' '⎘“sub/me.g2“:‹me›9;' | w112enc > "$TMP/inc/sub/me.g2"
[ "$(printf '%s' '⎘“sub/me.g2“‹me›Ṅ' | w112a "$TMP/golf2")" = 0 ] && [ "$(w112run)" = 9 ] \
  && ok "a file that includes itself is compiled once; a path with a directory works" || no "self include"
for k in 1 2 3 4 5 6 7 8 9; do printf '%s' "⎘“d$((k + 1)).g2“" | w112enc > "$TMP/inc/d$k.g2"; done
printf '%s' '7)' > "$TMP/inc/d8.g2"
[ "$(printf '%s' '⎘“d1.g2“8)' | w112a "$TMP/golf2")" = 0 ] && [ "$(w112run)" = "$(printf '\007\010')" ] \
  && ok "includes nest 8 deep" || no "8-deep include: $(cat "$TMP/inc/err")"
printf '%s' '⎘“d9.g2“' | w112enc > "$TMP/inc/d8.g2"; : > "$TMP/inc/d10.g2"
[ "$(printf '%s' '⎘“d1.g2“' | w112a "$TMP/golf2")" = 2 ] && [ "$(cat "$TMP/inc/err")" = "GOLF: includes nested too deeply d9.g2 at d8.g2 line 1" ] && [ ! -s "$TMP/inc/p" ] \
  && ok "a 9th level: GOLF: includes nested too deeply d9.g2, exit 2" || no "9-deep include: $(cat "$TMP/inc/err")"
w112many=""; for k in $(seq 1 61); do : > "$TMP/inc/e$k.g2"; w112many="$w112many⎘“e$k.g2“"; done
[ "$(printf '%s' "${w112many%⎘“e61.g2“}1Ṅ" | w112a "$TMP/golf2")" = 0 ] && [ "$(w112run)" = 1 ] \
  && [ "$(printf '%s' "${w112many}" | w112a "$TMP/golf2")" = 2 ] && [ "$(cat "$TMP/inc/err")" = "GOLF: too many includes e61.g2 at line 1" ] \
  && ok "60 distinct files may be included; the 61st: GOLF: too many includes e61.g2" || no "include table bound: $(cat "$TMP/inc/err")"
w112long=$(printf 'x%.0s' $(seq 1 251))
[ "$(printf '%s' "⎘“$w112long“" | w112a "$TMP/golf2")" = 2 ] && [ "$(cat "$TMP/inc/err")" = "GOLF: cannot include ${w112long%x} at line 1" ] \
  && [ "$(printf '%s' '⎘5' | w112a "$TMP/golf2")" = 2 ] && [ "$(cat "$TMP/inc/err")" = "GOLF: cannot include  at line 1" ] \
  && [ "$(printf '%s' '⎘“sq.g2' | w112a "$TMP/golf2")" = 2 ] && [ "$(cat "$TMP/inc/err")" = "GOLF: cannot include sq.g2 at line 1" ] \
  && ok "a path over 250 bytes, ⎘ without “, an unclosed path: GOLF: cannot include …, exit 2" || no "bad include syntax: $(cat "$TMP/inc/err")"
w112p='⎘“cube.g2“⎘“twelve.g2“‹cube›Ṅ⎘“d1.g2“'
printf '%s' '7)' > "$TMP/inc/d8.g2"
[ "$(printf '%s' "$w112p" | w112a "$TMP/golf2")" = 0 ] && cp "$TMP/inc/p" "$TMP/inc/p.g2" \
  && [ "$(printf '%s' "$w112p" | w112a "$TMP/seed")" = 0 ] && cmp -s "$TMP/inc/p" "$TMP/inc/p.g2" \
  && (cd "$TMP/inc" && python3 "$EXP/boot/golfref.py" < src > p.ref 2>/dev/null) && cmp -s "$TMP/inc/p.ref" "$TMP/inc/p.g2" \
  && [ "$("$TMP/inc/p.g2")" = "$(printf '1728\007')" ] \
  && ok "seed, golf2 and boot/golfref.py emit the same bytes for nested and repeated includes" || no "include parity (seed/golf2/golfref)"
[ "$(printf '%s' '⎘“nope.g2“' | w112a "$TMP/golf2")" = 2 ] && (cd "$TMP/inc" && python3 "$EXP/boot/golfref.py" < src > p.ref 2>err.ref; [ $? = 2 ]) \
  && [ "$(cat "$TMP/inc/err.ref")" = "GOLF: cannot include nope.g2 at line 1" ] \
  && ok "golfref: the same missing-file message and status" || no "golfref missing include"
[ "$(printf '%s' '\import\strx.g2\str ⎘“y“' | w112enc | od -An -tx1 | tr -d ' \n')" = "b68e782e67328e20b68e798e" ] \
  && [ "$(printf '\266\216a#b\216' | python3 tools/codepage.py decode)" = "⎘“a#b“" ] \
  && ok "⎘ and \\import encode to 0xB6; the encoder leaves the path (a “…“ literal) alone; decode shows ⎘" || no "⎘ encode/decode"
# tools/golfc: an included .golfj is glyph source, so golfc encodes it on the
# way (recursively, one copy per real file); a .g2 include is read raw.
mkdir -p "$TMP/incj/lib"
printf '%s\n' '# squares: glyph source, a comment and a \mnemonic' ':‹sq›"\rmul;' > "$TMP/incj/lib/sqj.golfj"
printf '%s\n' '⎘“sqj.golfj“' ':‹quad›‹sq›‹sq›;   # x^4' > "$TMP/incj/util.golfj"
printf '%s\n' '⎘“util.golfj“⎘“sqj.golfj“⎘“lib/sqj.golfj“⎘“raw.g2“' '3‹quad›Ṅ␤5‹sq›Ṅ␤‹r›Ṅ' > "$TMP/incj/main.golfj"
printf '%s' ':‹r›6;' | w112enc > "$TMP/incj/raw.g2"
printf '%s' '⎘“gone.golfj“1Ṅ' > "$TMP/incj/bad.golfj"
(cd "$TMP/incj" && "$EXP/tools/golfc" -j main.golfj m >/dev/null 2>&1) && [ "$("$TMP/incj/m")" = "$(printf '81\n25\n6')" ] \
  && ok "golfc -j: nested .golfj includes (via lib/) are encoded, a .g2 one read raw, the same file once" || no "golfc -j with .golfj includes"
[ "$(cd "$TMP/incj" && "$EXP/tools/golfc" -j bad.golfj b 2>&1 >/dev/null; echo "rc=$?")" = "$(printf 'GOLF: cannot include gone.golfj at line 1\nrc=2')" ] \
  && ok "golfc -j: a missing .golfj include is reported under its own name, exit 2" || no "golfc missing .golfj include"
# REFERENCE.md's Modules example, cut out of the doc and run as it says.
mkdir -p "$TMP/incr/lib"
sed -n '/^### Modules$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' > "$TMP/incr/ex"
sed -n '/^# lib\/geom.golfj$/,/^$/p' "$TMP/incr/ex" > "$TMP/incr/lib/geom.golfj"
sed -n '/^# main.golfj/,/^```$/p' "$TMP/incr/ex" | grep -v '^```$' > "$TMP/incr/main.golfj"
(cd "$TMP/incr" && "$EXP/tools/golfc" -j main.golfj main >/dev/null 2>&1) && [ "$("$TMP/incr/main")" = 25 ] \
  && grep -q 'prints 25' "$TMP/incr/main.golfj" && grep -q '‹hyp2›' "$TMP/incr/lib/geom.golfj" \
  && ok "REFERENCE.md's Modules example builds with golfc -j and prints 25" || no "REFERENCE Modules example"

# === W11-2B ===
echo "W11-2B: dict and set — ‹hash› ‹dict› ‹put› ‹get› ‹has› ‹del› ‹keys› ‹vals› ‹set› ‹add›"
# A compact (insertion-ordered) open-addressing dict, keys compared with ≣.
# d is changed in place, so `"…‹put›` leaves the same d twice; the tests keep
# one copy with `"` and let the extras pile up.
[ "$(printf '%s' '‹dict›"1 10‹put›_"2 20‹put›_"1 11‹put›_"1‹get›Ṅ32)"2‹get›Ṅ␤"‹keys›⍕␤"‹vals›⍕␤"3‹has›Ṅ"1‹has›Ṅ␤‹keys›≢Ṅ' | gc)" \
   = "$(printf '11 20\n1 2 \n11 20 \n10\n2')" ] \
  && ok "put / get / overwrite in place / has (zero-is-true) / keys / vals" || no "w11-2b basics"
# ‹hash› is FNV-1a 64 over an int's 8 bytes (low first), or over a list's
# elements with inner lists hashed first; Python computes the same numbers.
w112bh=$(python3 -c '
M=2**64; B=0xcbf29ce484222325
def f(h,x):
  for i in range(8): h=((h^((x>>(8*i))&255))*0x100000001b3)%M
  return h
def H(v):
  if isinstance(v,int): return f(B,v%M)
  h=B
  for e in v: h=f(h,H(e) if isinstance(e,list) else e%M)
  return h
s=lambda v: v-M if v>=2**63 else v
print(" ".join(str(s(H(v))) for v in [5,0,-1,[],[0,1,2],[[],[0],[0,1]],[97,98]]))')
[ "$(printf '%s' '5‹hash›Ṅ32)0‹hash›Ṅ32)0 1-‹hash›Ṅ32)0⍳‹hash›Ṅ32)3⍳‹hash›Ṅ32)3⍳′⍳€‹hash›Ṅ32)“ab“⊃‹hash›Ṅ' | gc)" = "$w112bh" ] \
  && ok "‹hash›: FNV-1a 64 of ints, flat and nested lists matches Python" || no "w11-2b hash: $w112bh"
[ "$(printf '%s' '3⍳′⍳€‹hash›3⍳′⍳€‹hash›≡Ṅ“ab“⊃‹hash›“ab“⊃‹hash›≡Ṅ3⍳‹hash›4⍳‹hash›≡Ṅ' | gc)" = "-1-10" ] \
  && ok "‹hash›: ≣-equal (distinct) lists hash equal; different lists differ" || no "w11-2b hash eq"
# Delete, reinsert (goes to the end), delete of a missing key, and churn: 100k
# put+del of distinct keys only ever compacts, so the table stays at cap 8.
[ "$(printf '%s' '‹dict›"5 1‹put›_"6 2‹put›_"7 3‹put›_"6‹del›_"‹keys›⍕"‹vals›⍕"6‹has›Ṅ"9‹del›_"6 4‹put›_"‹keys›⍕‹vals›⍕' | gc)" = "5 7 1 3 15 7 6 1 3 4 " ] \
  && ok "‹del›: removes, a reinserted key goes last, deleting a missing key is a no-op" || no "w11-2b del"
[ "$(printf '%s' '‹dict›→‹d›0→‹i›{←‹d›←‹i›←‹i›‹put›_←‹d›←‹i›‹del›_←‹i›⊕"→‹i›100000≡}←‹d›1⊇Ṅ32)←‹d›‹keys›≢Ṅ32)←‹d›42 1‹put›42‹get›Ṅ' | gc)" = "8 0 1" ] \
  && ok "100k put+del: tombstones are compacted away, the table never grows" || no "w11-2b churn"
# Growth: 1000 keys double the table to 2048 (load <= 1/2), keep insertion
# order and every value.
[ "$(printf '%s' '‹dict›→‹d›0→‹i›{←‹d›←‹i›←‹i›²‹put›_←‹i›⊕"→‹i›1000≡}←‹d›1⊇Ṅ32)←‹d›‹keys›1000⍳≣Ṅ32)←‹d›‹vals›1000⍳"*≣Ṅ32)←‹d›999‹get›Ṅ' | gc)" = "2048 -1 -1 998001" ] \
  && ok "growth: 1000 keys, cap 2048, keys in insertion order, values intact" || no "w11-2b growth"
# List keys: code lists made separately find each other; nested keys; [5] and
# 5 are different keys though they hash alike; the empty list is a key.
[ "$(printf '%s' '‹dict›"“ab“⊃1‹put›_"3⍳′⍳€2‹put›_"5 3‹put›_"5 1⍳+4‹put›_"0⍳5‹put›_"“ab“⊃‹get›Ṅ"3⍳′⍳€‹get›Ṅ"5‹get›Ṅ"1⍳5+‹get›Ṅ"0⍳‹get›Ṅ"2⍳′⍳€‹has›Ṅ"“abc“⊃‹has›Ṅ‹keys›⍕' | gc)" = "1234511[97 98] [[] [0] [0 1]] 5 [5] [] " ] \
  && ok "list keys: ≣ equality, nested lists, [5] vs 5, the empty list" || no "w11-2b list keys"
# Sets on top: ‹add› twice is one member; ‹has› ‹del› ‹keys› work on sets.
[ "$(printf '%s' '‹set›"4‹add›_"2‹add›_"4‹add›_"“x“⊃‹add›_"‹keys›⍕"2‹has›Ṅ"3‹has›Ṅ"2‹del›_"2‹has›Ṅ"‹keys›≢Ṅ‹vals›⍕' | gc)" = "4 2 [120] 01120 0 " ] \
  && ok "sets: ‹set› ‹add› (idempotent), ‹has› ‹del› ‹keys› on a set" || no "w11-2b sets"
w112be(){ printf '%s' "$1" | gc > "$TMP/w112b.out" 2> "$TMP/w112b.err"; echo "rc=$? $(cat "$TMP/w112b.out") $(cat "$TMP/w112b.err")"; }
[ "$(w112be '7Ṅ‹dict›"1 1‹put›_"2‹get›Ṅ')" = "rc=1 7 GOLF: key not found" ] && [ "$(w112be '‹dict›"1 1‹put›_"1‹del›_1‹get›')" = "rc=1  GOLF: key not found" ] \
  && ok "‹get› of a missing (or deleted) key throws: GOLF: key not found, exit 1" || no "w11-2b missing key"
# The done-when pair.  Word count over stdin (two of this repo's docs) matches
# sort | uniq -c once both are sorted the same way.
w112bwc=':‹bump›→‹k›←‹d›←‹k›1←‹d›←‹k›‹has›[_←‹d›←‹k›‹get›⊕]‹put›;:‹show›→‹k›←‹d›←‹k›‹get›Ṅ“ “🗲←‹k›⊐␤0;‹dict›→‹d›‹readall›‹words›′‹bump›€_←‹d›‹keys›′‹show›€_'
printf '%s' "$w112bwc" | gc > /dev/null; cp "$TMP/p" "$TMP/w112bwc"
cat REFERENCE.md DESIGN.md > "$TMP/w112b.in"
"$TMP/w112bwc" < "$TMP/w112b.in" | LC_ALL=C sort > "$TMP/w112b.got"
tr -s ' \t\n\r\v\f' '\n' < "$TMP/w112b.in" | grep -v '^$' | LC_ALL=C sort | uniq -c | awk '{print $1, $2}' | LC_ALL=C sort > "$TMP/w112b.want"
[ -s "$TMP/w112b.want" ] && cmp -s "$TMP/w112b.got" "$TMP/w112b.want" \
  && ok "word count of stdin ($(wc -l < "$TMP/w112b.want") distinct words) matches sort | uniq -c" || no "w11-2b word count"
[ "$("$TMP/w112bwc" < "$TMP/w112b.in" | head -1 | cut -d' ' -f2-)" = "$(tr -s ' \t\n\r\v\f' '\n' < "$TMP/w112b.in" | grep -v '^$' | head -1)" ] \
  && ok "... keys come out in order of first appearance" || no "w11-2b word count order"
# 100,000 int inserts then 100,000 lookups (sum of the values 3i): well under
# 1 s (about 0.05 s here; the bound is generous for slow machines).
printf '%s' '‹dict›→‹d›0→‹i›{←‹d›←‹i›←‹i›3*‹put›_←‹i›⊕"→‹i›100000≡}0→‹s›0→‹i›{←‹s›←‹d›←‹i›‹get›+→‹s›←‹i›⊕"→‹i›100000≡}←‹s›Ṅ32)←‹d›‹keys›≢Ṅ' | gc > /dev/null
cp "$TMP/p" "$TMP/w112bt"; w112bt0=$(date +%s%N); w112bto=$("$TMP/w112bt"); w112bt1=$(date +%s%N)
w112bms=$(( (w112bt1 - w112bt0) / 1000000 ))
[ "$w112bto" = "14999850000 100000" ] && [ "$w112bms" -lt 1000 ] \
  && ok "100k int inserts + 100k lookups: right sum, ${w112bms} ms (< 1000)" || no "w11-2b 100k ($w112bto, ${w112bms} ms)"
# The Python oracle compiles the prelude to the same behaviour.
w112bo='‹dict›"“ab“⊃1‹put›_"3⍳′⍳€2‹put›_"7 3‹put›_"7‹del›_"9 4‹put›_"“ab“⊃‹get›Ṅ"3⍳′⍳€‹get›Ṅ‹keys›⍕7‹hash›Ṅ'
[ "$(printf '%s' "$w112bo" | gref)" = "$(printf '%s' "$w112bo" | gc)" ] && [ "$(printf '%s' "$w112bo" | gc)" = "12[97 98] [[] [0] [0 1]] 9 5465015992139406178" ] \
  && ok "oracle: boot/golfref.py runs the dict words identically" || no "w11-2b oracle"
# REFERENCE.md's "Dicts and sets" examples print (stdout + stderr) what they
# say, trailing spaces aside.
w112bbad=""
while IFS= read -r w112bl; do
  w112bp=${w112bl%%  ->*}; w112bp=${w112bp%"${w112bp##*[! ]}"}; w112bw=${w112bl##*->  }
  w112bg=$(printf '%s' "$w112bp" | gc 2>&1); w112bg=${w112bg%"${w112bg##*[! ]}"}
  [ "$w112bg" = "$w112bw" ] || w112bbad="$w112bbad [$w112bp]"
done < <(sed -n '/^### Dicts and sets$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w112bbad" ] && [ "$(sed -n '/^### Dicts and sets$/,/^### /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 8 ] \
  && ok "REFERENCE.md's Dicts and sets examples print what they say" || no "REFERENCE Dicts examples:$w112bbad"

# === W11-2C ===
echo "W11-2C: ⊸ bind, closures by value (x ′f ⊸ -> ′g; g pushes the captured x, calls f)"
# The done-when line: the VALUE of n is captured when ⊸ runs, so k still adds 10
# after n becomes 99.  (GAPS §2.2's `:f←k+;` reads k at call time instead.)
[ "$(printf '%s' '10→n ←n′+⊸→k 99→n 3⍳←k€⍕' | gc)" = "10 11 12 " ] \
  && ok "10→n ←n′+⊸→k 99→n 3⍳←k€⍕ prints 10 11 12 (value captured, not the variable)" || no "w11-2c capture"
[ "$(printf '%s' '10→k :f←k+; 3⍳′f€⍕ 99→k 3⍳′f€⍕' | gc)" = "10 11 12 99 100 101 " ] \
  && ok "... while a word reading ←k follows the global (the contrast)" || no "w11-2c global contrast"
# x sits ABOVE the element when f runs, so ′- binds the right operand.
[ "$(printf '%s' '3⍳5′-⊸€⍕ 4⍳2′⊇⊸⍎Ṅ' | gc)" = "-5 -4 -3 2" ] \
  && ok "partial application of a binary word: e-5 per element; ′⊇ bound to an index" || no "w11-2c partial"
# A captured LIST: the tagged 64-bit value goes into the thunk whole.
[ "$(printf '%s' '3⍳′⧺⊸→c 2⍳←c⍎⍕ 0⍳←c⍎⍕ 3⍳10+′+⊸→a 3⍳←a⍎⍕ 0⍳′⧺⊸→p 2⍳←p⍎⍕' | gc)" = "0 1 0 1 2 0 1 2 10 12 14 0 1 " ] \
  && ok "binding a list: ⧺ appends the captured list (also the empty one); + adds it elementwise" || no "w11-2c list"
[ "$(printf '%s' '5 1 63≪′+⊸⍎Ṅ 0 1-′⊕⊸⍎Ṅ 7 0 1-′+⊸⍎Ṅ' | gc)" = "-922337203685477580306" ] \
  && ok "the full 64 bits are captured (INT64_MIN, -1)" || no "w11-2c 64-bit"
# Composes with ∘ on either side, binds a composed quotation, binds a bound one.
w112cc=':d⊗;3⍳10′+⊸′d∘€⍕ 3⍳′d10′+⊸∘€⍕ 5′⊗′⊕∘⊸⍎Ṅ 3 4′+⊸⊸⍎Ṅ'
[ "$(printf '%s' "$w112cc" | gc)" = "20 22 24 10 12 14 117" ] \
  && ok "bind composes with ∘ (either side), binds a composed quotation, and binds a bound one" || no "w11-2c compose"
[ "$(printf '%s' "$w112cc" | gref)" = "20 22 24 10 12 14 117" ] \
  && ok "oracle: boot/golfref.py runs ⊸ identically" || no "w11-2c oracle"
# ⊸ inside a map: a fresh thunk per element (X/Y frames nest), each its own x.
[ "$(printf '%s' ':b′⍳⊸;3⍳′b€′⍎€⍕' | gc)" = "[] [0] [0 1] " ] \
  && ok "⊸ inside €: one thunk per element, each with its own x" || no "w11-2c in map"
# A thunk is 38 bytes in ∘'s arena (∘'s is 39), on the same bump pointer.
[ "$(printf '%s' '1′⊕⊸1′⊕⊸\rsub\negṄ ′⊕′⊕∘1′⊕⊸\rsub\negṄ' | gc)" = "3839" ] \
  && ok "a bind thunk is 38 bytes, on the compose arena's bump pointer" || no "w11-2c thunk size"
# The arena bound holds for ⊸ alone and for any mix of ⊸ and ∘.  1724 binds
# (65512 bytes) fit, the 1725th would start past 65498; 851 ∘+⊸ pairs (77 bytes
# each) end at 65527 and the 852nd ∘ would cross.  The canary v is a variable
# the overrun would reach (the bank starts right after the arena).
w112c(){ printf '1234→v 0→i{%s←i1+"→i%s\\rlt1+}%s←vṄ' "$1" "$2" "${3-}" | arena; }
w112cb='0→i{1′⊕⊸_←i1+"→i698\rlt1+}'
[ "$(w112c '1′⊕⊸_' 1724)" = 0 ] && [ "$(cat "$TMP/ar.out")" = 1234 ] \
  && [ "$(w112c '1′⊕⊸_' 1725)" = 1 ] && [ "$(cat "$TMP/ar.err")" = "GOLF: compose arena exhausted" ] && [ ! -s "$TMP/ar.out" ] \
  && ok "1724 binds fit the arena, the 1725th says compose arena exhausted (exit 1, stdout clean)" || no "w11-2c bind arena"
[ "$(w112c '′⊕′⊖∘_1′⊕⊸_' 851)" = 0 ] && [ "$(cat "$TMP/ar.out")" = 1234 ] \
  && [ "$(w112c '′⊕′⊖∘_1′⊕⊸_' 852)" = 1 ] && [ "$(cat "$TMP/ar.err")" = "GOLF: compose arena exhausted" ] && [ ! -s "$TMP/ar.out" ] \
  && ok "mixing ∘ and ⊸: 851 pairs fit with the canary intact, the next ∘ is diagnosed" || no "w11-2c mixed arena"
[ "$(w112c '′⊕′⊖∘_' 1000 "$w112cb")" = 0 ] && [ "$(cat "$TMP/ar.out")" = 1234 ] \
  && [ "$(w112c '′⊕′⊖∘_' 1000 "${w112cb/698/699}")" = 1 ] && [ "$(cat "$TMP/ar.err")" = "GOLF: compose arena exhausted" ] \
  && ok "1000 composes then 698 binds fit; the 699th bind is diagnosed" || no "w11-2c compose-then-bind arena"
# REFERENCE.md's Closures examples print what the doc says.
w112cbad=""
while IFS= read -r w112cl; do
  w112cp=${w112cl%%  ->*}; w112cp=${w112cp%"${w112cp##*[! ]}"}; w112cw=${w112cl##*->  }
  [ "$(printf '%s' "$w112cp" | gc | sed 's/ *$//')" = "$w112cw" ] || w112cbad="$w112cbad [$w112cp]"
done < <(sed -n '/^### Closures$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w112cbad" ] && [ "$(sed -n '/^### Closures$/,/^### /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 5 ] \
  && ok "REFERENCE.md's Closures examples print what they say" || no "REFERENCE Closures examples:$w112cbad"

# === W11-2D ===
echo "W11-2D: use after free — ⌫ poisons the length cell, list words check it; ‹heapstats›"
# ⌫ writes -559038737 into a freed block's length cell (the free-list link
# moved to payload cell 1) and A writes 0 over it on reuse.  Every list word
# enters through ‹_2d_chk› (I clamps a negative length), so a freed list that
# reaches one dies with `GOLF: use after free`, exit 1, stdout flushed first.
[ "$(w110 '7Ṅ5⍳"⌫∑Ṅ')" = "rc=1 1 GOLF: use after free" ] \
  && ok "a freed list passed to ∑: GOLF: use after free, exit 1 (earlier output kept)" || no "uaf sum: $(w110 '7Ṅ5⍳"⌫∑Ṅ')"
w112dbad=""
for w in '≢Ṅ' '⍕' "′⊕€_" '0′+⇤_' '∏_' '2⊇_' '0⊇_' '⌽_' "′⊕⌿_" '⊐' '9⍳⧺_' '9⍳&⧺__' '2↑_' '2↓_' '⍋_' '3∊_' '9⍳≣_' '⍤_' \
         '1+_' '1-_' '2*_' '9⍳+_' '1&-__' '9⍳&*__' "9⍳′+⊞_" '‹words›_' '1 2‹slice›_' '3‹indexof›_' '‹unique›_' '‹flatten›_'; do
  r=$(w110 "5⍳\"⌫$w")
  [ "$r" = "rc=1 0 GOLF: use after free" ] || w112dbad="$w112dbad [$w: $r]"
done
[ -z "$w112dbad" ] && ok "≢ ⍕ € ⇤ ∏ ⊇ ⌽ ⌿ ⊐ ⧺ ↑ ↓ ⍋ ∊ ≣ ⍤ ⊞, bare + - * (D, either side) and the W9 long words all refuse a freed list" \
  || no "uaf entry points:$w112dbad"
[ "$(w110 '3⍳′⍳€"2⊇⌫⍕')" = "rc=1 7 GOLF: use after free" ] \
  && ok "a freed INNER list is caught when ⍕ recurses into it" || no "uaf nested: $(w110 '3⍳′⍳€"2⊇⌫⍕')"
[ "$(w110 '3⍳"⌫⌫')" = "rc=1 0 GOLF: double free" ] && [ "$(w110 '3A"⌫⌫')" = "rc=1 0 GOLF: double free" ] \
  && [ "$(w110 '3⍳9⊇')" = "rc=1 0 GOLF: index out of range" ] && [ "$(w110 '3⍳0 1-⊇')" = "rc=1 0 GOLF: index out of range" ] \
  && ok "double free (list and raw block) and index out of range on a live list are unchanged" || no "uaf: other messages"
[ "$(printf '%s' '5⍳"⌫ 5⍳"≢Ṅ␤"∑Ṅ␤ 3A"⌫ 3A\fetch Ṅ␤ 5⍳"→a⌫ 5⍳_ ←a∑Ṅ' | gc)" = "$(printf '5\n10\n0\n10')" ] \
  && ok "a reused block is live again (A clears the poison, raw blocks too); a stale copy of it is NOT caught" || no "uaf reuse"
[ "$(printf '%s' '‹heapstats›→b→n 5⍳ ‹heapstats›←b-Ṅ␤←n-Ṅ␤ ⌫ 1000⍳"⌫ ‹heapstats›←b-Ṅ␤←n-Ṅ␤' | gc)" = "$(printf '72\n1\n0\n0')" ] \
  && ok "‹heapstats› -> blocks bytes: 5⍳ adds one 72-byte block ((8+1)*8), ⌫ takes it back, a class-7 block too" || no "heapstats basic"
[ "$(printf '%s' ':d⊗;5⍳→l ‹heapstats›→b→n 100000→i{←l′d€"∑_⌫←i1-"→i0≡}‹heapstats›←b-Ṅ␤←n-Ṅ␤ 100→i{←l′d€_←i1-"→i0≡}‹heapstats›←b-Ṅ␤←n-Ṅ' | gc)" \
    = "$(printf '0\n0\n7200\n100')" ] \
  && ok "100,000 × (map, ∑, ⌫): live blocks stay flat; the same loop without ⌫ adds a block per pass" || no "heapstats flat loop"
[ "$(printf '%s' '5⍳"⌫∑Ṅ' | gref; echo " $?")" = " 1" ] \
  && [ "$(printf '%s' ':d⊗;5⍳→l 50→i{←l′d€⌫←i1-"→i0≡}‹heapstats›Ṅ␤Ṅ␤3A"⌫3A\fetch Ṅ' | gref)" \
       = "$(printf '%s' ':d⊗;5⍳→l 50→i{←l′d€⌫←i1-"→i0≡}‹heapstats›Ṅ␤Ṅ␤3A"⌫3A\fetch Ṅ' | gc)" ] \
  && ok "oracle: golfref runs the poison, the reuse and ‹heapstats› the same" || no "uaf oracle"
# REFERENCE.md's Memory examples print what the doc says.
w112dbad=""
while IFS= read -r w112dl; do
  w112dp=${w112dl%%  ->*}; w112dp=${w112dp%"${w112dp##*[! ]}"}; w112dw=${w112dl##*->  }
  [ "$(printf '%s' "$w112dp" | gc)" = "$w112dw" ] || w112dbad="$w112dbad [$w112dp]"
done < <(sed -n '/^### Memory$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w112dbad" ] && [ "$(sed -n '/^### Memory$/,/^### /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 4 ] \
  && [ "$(w110 '5⍳"⌫∑Ṅ')" = "rc=1 0 GOLF: use after free" ] \
  && ok "REFERENCE.md's Memory examples print what they say" || no "REFERENCE Memory examples:$w112dbad"

# === W11-3A ===
echo "W11-3A: ‹catch› / ‹throw› — a caught error is its message (a code list), 0 on success"
# ‹catch› arms a handler record (a spill-stack frame: sp bp from ⊷, the old
# chain head) and runs f; ‹throw› with one armed unlinks it and ⊶s back, so
# ‹catch› returns with the message on the stack as it was at the call.
w113(){ printf '%s' "$1" | gc 2>&1; echo " rc=$?"; }
[ "$(printf '%s' '1 2⊷→b→s 3 4 5 ←s←b⊶ ṄṄ ⊷_⊷_\rsubṄ' | gc)" = "218" ] \
  && ok "⊷ ⊶: a saved sp/bp pair drops what was pushed since; ⊷'s sp is rsp before the atom (8 apart)" || no "⊷ ⊶ atoms"
[ "$(w113 ':‹bad›3⍳9⊇;1 2′‹bad›‹catch›⊐␤Ṅ␤Ṅ␤5180160⊙Ṅ5177392@Ṅ')" = "$(printf 'index out of range\n2\n1\n00 rc=0')" ] \
  && ok "′‹bad›‹catch›: the index error comes back as its message, the program goes on (chain and spill stack empty after)" \
  || no "catch index error: $(w113 ':‹bad›3⍳9⊇;1 2′‹bad›‹catch›⊐␤Ṅ␤Ṅ␤5180160⊙Ṅ5177392@Ṅ')"
[ "$(w113 ':‹ok›5 6;1′‹ok›‹catch›ṄṄṄṄ5180160⊙Ṅ5177392@Ṅ')" = "065100 rc=0" ] \
  && ok "success: 0 above f's results, the handler unlinked" || no "catch success"
[ "$(w113 ':‹f›1 2 3“no“⊃‹throw›;7′‹f›‹catch›⊐Ṅ⊷_ ′‹f›‹catch›_ ⊷_\rsubṄ')" = "no78 rc=0" ] \
  && ok "error path: what f pushed is discarded, the depth at ‹catch› restored" || no "catch depth"
[ "$(w113 '7Ṅ“mine“⊃′‹throw›‹catch›⊐8Ṅ')" = "7mine8 rc=0" ] && [ "$(w113 '7Ṅ“mine“⊃‹throw›8Ṅ')" = "$(printf '7GOLF: mine\n rc=1')" ] \
  && ok "a program's own ‹throw›: caught, or (none armed) GOLF: mine, exit 1, earlier output first" || no "user throw"
[ "$(w113 ':‹in›“inner“⊃‹throw›;:‹out›′‹in›‹catch›⊐“outer“⊃‹throw›;′‹out›‹catch›⊐5180160⊙Ṅ')" = "innerouter0 rc=0" ] \
  && ok "nesting: the inner ‹catch› handles, the outer stays armed for the next throw" || no "catch nesting"
[ "$(w113 ':‹g›‹throw›;:‹h›“again“⊃′‹g›‹catch›‹throw›;′‹h›‹catch›⊐ ′‹h›‹catch›_ ‹h›9Ṅ')" = "$(printf 'againGOLF: again\n rc=1')" ] \
  && ok "rethrow from a handler reaches the outer ‹catch›; with none left it prints and exits 1" || no "rethrow"
# Unwinding: € (spill frames), ⇤, ⊡ frames, nested ⍕ — afterwards a deep op
# works and the spill offset is back to 0.
W113D='5177392@Ṅ␤3000⍳′⍳€′∑€∑Ṅ'
[ "$(w113 ":‹f›\"7≡1+[“seven“⊃‹throw›]⊗;:‹g›10⍳′‹f›€;′‹g›‹catch›⊐␤$W113D")" = "$(printf 'seven\n0\n4495501000 rc=0')" ] \
  && ok "a throw from inside € (map) unwinds its spill frame; a deep map/sum still works" || no "throw in map"
[ "$(w113 ":‹f›\"5≡1+[“five“⊃‹throw›]+;:‹g›10⍳0′‹f›⇤;′‹g›‹catch›⊐␤$W113D")" = "$(printf 'five\n0\n4495501000 rc=0')" ] \
  && ok "a throw from inside ⇤ (fold)" || no "throw in fold"
[ "$(w113 ":‹r›\"0≡[1-1⍳+′‹r›€^]_“deep“⊃‹throw›;3000′‹r›‹catch›⊐␤$W113D")" = "$(printf 'deep\n0\n4495501000 rc=0')" ] \
  && ok "a throw 3000 nested maps deep" || no "throw deep in maps"
[ "$(w113 ":‹p›3⍳′⍳€\"2⊇⌫⍕;′‹p›‹catch›␤⊐␤$W113D")" = "$(printf '[] [0] \nuse after free\n0\n4495501000 rc=0')" ] \
  && ok "a throw from inside a nested ⍕ (output before it kept)" || no "throw in nested print"
[ "$(w113 '⊡‹d›⇒a⇒b ⇐a⇐b+ 3⍳9⊇;⊡‹e›⇒a 1 2‹d› ⇐a;⊡‹m›⇒a⇒b 5′‹e›‹catch›⊐ ⇐a⇐bṄṄ 4⍳′⍳€⍕;8 9‹m›')" = "index out of range89[] [0] [0 1] [0 1 2]  rc=0" ] \
  && ok "a throw out of nested ⊡ words drops their frames; the catcher's own locals are intact" || no "throw through ⊡"
[ "$(w113 ':‹s›“e“⊃‹throw›;:‹t›′‹s›‹catch›_;10⍳′‹t›€⍕')" = "0 1 2 3 4 5 6 7 8 9  rc=0" ] \
  && ok "‹catch› inside a mapped word: the map's own scratch survives each caught throw" || no "catch inside map"
[ "$(w113 ":‹r›1⍳′‹r›€;′‹r›‹catch›⊐␤$W113D")" = "$(printf 'spill stack exhausted\n0\n4495501000 rc=0')" ] \
  && [ "$(w113 ':‹r›1⍳′‹r›€;‹r›')" = "$(printf 'GOLF: spill stack exhausted\n rc=1')" ] \
  && ok "spill stack exhausted: catchable (unwound before its message is built); uncaught unchanged" || no "catch spill exhaustion"
[ "$(w113 ':‹z›7 0/;1 2′‹z›‹catch›⊐ṄṄ:‹y›7 0÷;′‹y›‹catch›_:‹x›7 0∣;′‹x›‹catch›_:‹w›7 0%;′‹w›‹catch›⊐')" = "divide by zero21divide by zero rc=0" ] \
  && [ "$(w113 '5Ṅ7 0÷')" = "$(printf '5GOLF: divide by zero\n rc=1')" ] && [ "$(w113 '5Ṅ7 0%')" = "$(printf '5GOLF: divide by zero\n rc=1')" ] \
  && ok "/ % ÷ ∣ by zero: catchable through the 0x4F0B10 hook; uncaught unchanged" || no "catch divide by zero"
[ "$(w113 ':‹r›"0≡[1-1⍳+′‹r›€^]_7 0÷;3000′‹r›‹catch›⊐')" = "divide by zero rc=0" ] \
  && ok "a divide by zero 3000 maps deep is caught (unwound before its message is built)" || no "deep div0"
w113o=':‹in›“inner“⊃‹throw›;:‹out›′‹in›‹catch›⊐“outer“⊃‹throw›;′‹out›‹catch›⊐:‹bad›3⍳9⊇;1 2′‹bad›‹catch›⊐ṄṄ:‹r›1⍳′‹r›€;′‹r›‹catch›⊐:‹z›7 0÷;′‹z›‹catch›⊐'
[ "$(printf '%s' "$w113o" | gref)" = "$(printf '%s' "$w113o" | gc)" ] && [ "$(printf '%s' "$w113o" | gc)" = "innerouterindex out of range21spill stack exhausteddivide by zero" ] \
  && ok "oracle: golfref compiles ⊷ ⊶ and runs ‹catch› / ‹throw› the same" || no "catch oracle"
# REFERENCE.md's Errors examples print what the doc says (stderr merged).
w113bad=""
while IFS= read -r w113l; do
  w113p=${w113l%%  ->*}; w113p=${w113p%"${w113p##*[! ]}"}; w113w=${w113l##*->  }
  [ "$(printf '%s' "$w113p" | gc 2>&1 | sed 's/ *$//')" = "$w113w" ] || w113bad="$w113bad [$w113p]"
done < <(sed -n '/^### Errors$/,/^## /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w113bad" ] && [ "$(sed -n '/^### Errors$/,/^## /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 8 ] \
  && ok "REFERENCE.md's Errors examples print what they say" || no "REFERENCE Errors examples:$w113bad"

# === W11-3B ===
echo "W11-3B: compile errors say where (line, file); golf2 -g / golfc -g write a symbol map"
# golf2 counts newlines as it reads (‹read>), per file, and a form feed between
# tokens restarts the count — pre.gb ends with one, as golfc's input does, so
# these lines are the program's own.  w113b <compiler> runs prelude + stdin in
# $TMP/inc (w112a's directory, with its sq.g2), leaving "rc message".
w113b(){ cat "$TMP/pre.gb" <(w112enc) > "$TMP/inc/src"; (cd "$TMP/inc" && $1 < src > p 2>err; echo "$? $(cat err)"); }
[ "$(printf '1Ṅ\n\n5qṄ\n' | w113b "$TMP/golf2")" = "2 GOLF: undefined word q at line 3" ] && [ ! -s "$TMP/inc/p" ] \
  && ok "an undefined word on line 3: GOLF: undefined word q at line 3, exit 2, no binary" || no "undefined line: $(cat "$TMP/inc/err")"
[ "$(printf ':‹a›b;\n\n:‹c›b;\n5‹a›Ṅ' | w113b "$TMP/golf2")" = "2 GOLF: undefined word b at line 1" ] \
  && [ "$(printf '\n\n:f‹g›;\n‹g›\n' | w113b "$TMP/golf2")" = "2 GOLF: undefined word ‹g› at line 3" ] \
  && [ "$(printf '\n\n3⍳′q€⍕' | w113b "$TMP/golf2")" = "2 GOLF: undefined word q at line 3" ] \
  && [ "$(printf '\n⊚m\nq≢÷;5⍳mṄ' | w113b "$TMP/golf2")" = "2 GOLF: undefined word q at line 3" ] \
  && ok "a forward reference never defined is reported at its FIRST use (call, ‹long›, ′, chain link)" || no "first-use line: $(cat "$TMP/inc/err")"
[ "$(printf '\n\n‹a b›' | w113b "$TMP/golf2")" = "2 GOLF: bad long name ‹a› at line 3" ] \
  && [ "$(printf '\n:g⇐‹x›;' | w113b "$TMP/golf2")" = "2 GOLF: local out of range ‹x› at line 2" ] \
  && [ "$(printf '1\n⎘“sq.g2“\n\n⎘“nope.g2“' | w113b "$TMP/golf2")" = "2 GOLF: cannot include nope.g2 at line 4" ] \
  && ok "immediate errors carry the line too (bad long name, local out of range, cannot include)" || no "immediate error lines: $(cat "$TMP/inc/err")"
[ "$(printf '“a\nb“ # c\n`3 x\ny\n\n\nq' | w113b "$TMP/golf2")" = "2 GOLF: undefined word q at line 7" ] \
  && ok "newlines inside a string, a comment's end and a raw blob all count" || no "newline counting: $(cat "$TMP/inc/err")"
w113bp=$(python3 tools/codepage.py encode < lib/prelude.golfj | tr -cd '\n' | wc -c | tr -d ' ')
[ "$(python3 tools/codepage.py encode < lib/prelude.golfj | cat - <(printf '5qN') | "$TMP/golf2" 2>&1 >/dev/null)" \
    = "GOLF: undefined word q at line $((w113bp + 1))" ] \
  && [ "$(printf '1\n2\n\f3\nq' | w113b "$TMP/golf2")" = "2 GOLF: undefined word q at line 2" ] \
  && ok "without the form feed the prelude's $w113bp lines count; a form feed between tokens restarts at line 1" || no "form feed reset"
# Includes: each file has its own count, saved and restored per level; inside
# one the message names it as its ⎘ wrote it.
printf '# a comment\n⎘“sq.g2“\n\n:‹cube›"‹sq›*;\n‹oops›\n' | w112enc > "$TMP/inc/w113cube.g2"
printf '\n\n:‹bad›⇒z;\n' | w112enc > "$TMP/inc/w113loc.g2"
[ "$(printf '1\n⎘“w113cube.g2“\n3‹cube›Ṅ\n' | w113b "$TMP/golf2")" = "2 GOLF: undefined word ‹oops› at w113cube.g2 line 5" ] \
  && [ "$(printf '1\n⎘“sq.g2“\n⎘“w113loc.g2“' | w113b "$TMP/golf2")" = "2 GOLF: local out of range z at w113loc.g2 line 3" ] \
  && ok "an error inside an included file: … at w113cube.g2 line 5 (its own line, its own name)" || no "include error names the file: $(cat "$TMP/inc/err")"
printf '%s' '⎘“d9.g2“' | w112enc > "$TMP/inc/d8.g2"     # W11-2A's chain, 9 deep again
[ "$(printf '1\n⎘“w113cube.g2“\n\n:‹oops›;\n\n\n‹z›' | w113b "$TMP/golf2")" = "2 GOLF: undefined word ‹z› at line 7" ] \
  && [ "$(printf '%s' '⎘“d1.g2“' | w113b "$TMP/golf2")" = "2 GOLF: includes nested too deeply d9.g2 at d8.g2 line 1" ] \
  && ok "the includer's count resumes after a (nested) include; a 9th level is reported inside d8.g2" || no "count across includes: $(cat "$TMP/inc/err")"
w113bbad=""
for w113bs in '1\n⎘“w113cube.g2“\n3‹cube›Ṅ\n' '1\n⎘“sq.g2“\n⎘“w113loc.g2“' '1\n⎘“w113cube.g2“\n\n:‹oops›;\n\n\n‹z›' \
              '1\n⎘“sq.g2“\n\n⎘“nope.g2“' '\n\n‹a b›' '\n‹abc' '\n:f⇒a⇒z;' '1Ṅ\n\n5qṄ\n' '1\n2\n\f3\nq' '⎘“d1.g2“'; do
  w113bg=$(printf "$w113bs" | w113b "$TMP/golf2")
  w113br=$(printf "$w113bs" | w113b "python3 $EXP/boot/golfref.py")
  [ "$w113bg" = "$w113br" ] || w113bbad="$w113bbad [$w113bs: $w113bg | $w113br]"
done
[ -z "$w113bbad" ] && ok "boot/golfref.py reports the same message, place and status for each" || no "golfref positions:$w113bbad"
# golfc: a .golfj program and a .golfj include, through the prelude.
mkdir -p "$TMP/w113/lib"
printf '# helpers\n\n:‹sq›"*;\n‹nope›\n' > "$TMP/w113/lib/h.golfj"
printf '1Ṅ\n⎘“h.golfj“\n5‹sq›Ṅ\n' > "$TMP/w113/a.golfj"
printf '1Ṅ\n\n5qṄ\n' > "$TMP/w113/b.golfj"
[ "$(cd "$TMP/w113" && "$EXP/tools/golfc" -j b.golfj b 2>&1; echo "rc=$?")" = "$(printf 'GOLF: undefined word q at line 3\nrc=2')" ] \
  && [ "$(cd "$TMP/w113" && "$EXP/tools/golfc" -j a.golfj a 2>&1; echo "rc=$?")" = "$(printf 'GOLF: undefined word ‹nope› at h.golfj line 4\nrc=2')" ] \
  && ok "golfc -j: the line is the user's file's (prelude not counted); an included .golfj is named, not its temp copy" || no "golfc lines"
# -g: the map.  golf2 -g writes `name 0xaddr` lines to fd 2 after a good
# compile, the binary unchanged; golfc -g turns that into OUT.map, glyphs and all.
printf ':‹sq›"*;\n:f‹sq›;\n5fṄ\n' > "$TMP/w113/c.golfj"
(cd "$TMP/w113" && "$EXP/tools/golfc" -j -g c.golfj c && "$EXP/tools/golfc" -j c.golfj c2) >/dev/null 2>&1
[ "$("$TMP/w113/c")" = 25 ] && cmp -s "$TMP/w113/c" "$TMP/w113/c2" \
  && ok "golfc -g: the binary is byte-identical with and without -g" || no "golfc -g binary"
cat "$TMP/pre.gb" <(w112enc < "$TMP/w113/c.golfj") > "$TMP/w113/c.src"
"$TMP/golf2" -g < "$TMP/w113/c.src" > "$TMP/w113/g.bin" 2> "$TMP/w113/g.map"
"$TMP/seed" -g < "$TMP/w113/c.src" > "$TMP/w113/s.bin" 2>/dev/null
cmp -s "$TMP/w113/g.bin" "$TMP/w113/c" && cmp -s "$TMP/w113/s.bin" "$TMP/w113/c" \
  && [ "$(grep -c . "$TMP/w113/g.map")" = "$(grep -c . "$TMP/w113/c.map")" ] \
  && ok "golf2 -g: the same binary as golf2 and the seed, the map on fd 2 ($(grep -c . "$TMP/w113/c.map") words)" || no "golf2 -g"
python3 - "$TMP/w113/c" "$TMP/w113/c.map" "$EXP/boot" <<'PY' && ok "every c.map address is a word body in c (the prologue is there), f's call lands on ‹sq›, ⌫ is a glyph" || no "map vs binary"
import re, sys
sys.path.insert(0, sys.argv[3]); import v1
img = open(sys.argv[1], "rb").read()
words = {}
for ln in open(sys.argv[2], encoding="utf-8"):
    m = re.fullmatch(r"(\S+) 0x([0-9a-f]+)\n", ln)
    assert m, ln
    words[m.group(1)] = int(m.group(2), 16) - 0x400000
pro = bytes(v1.PROLOGUE)
assert all(img[a:a + len(pro)] == pro for a in words.values()), "a body without the prologue"
f = words["f"] + len(pro)                       # f's body: prologue, then call ‹sq›
assert img[f] == 0xE8
assert f + 5 + int.from_bytes(img[f + 1:f + 5], "little", signed=True) == words["‹sq›"]
assert "⌫" in words and "‹throw›" in words and "A" in words
PY
printf '%s' ':‹sq›"*;3‹sq›48+)' > "$TMP/w113/d.g2.src"; w112enc < "$TMP/w113/d.g2.src" > "$TMP/w113/d.g2"
w113bd=$(python3 -c 'import sys; sys.path.insert(0, "tools"); import mkblob2; print("%x" % (0x400000 + 120 + len(mkblob2.STARTUP2) + 5))')
(cd "$TMP/w113" && "$EXP/tools/golfc" -n -g d.g2 d) && [ "$(cat "$TMP/w113/d.map")" = "‹sq› 0x$w113bd" ] && [ "$("$TMP/w113/d")" = 9 ] \
  && ok "golfc -n -g, no prelude: one word, ‹sq› 0x$w113bd (header, startup stub, the jmp over the body)" || no "golfc -n -g: $(cat "$TMP/w113/d.map")"
[ "$(printf '%s' '5qṄ' | w113b "$TMP/golf2 -g")" = "2 GOLF: undefined word q at line 1" ] \
  && ok "a failed compile with -g writes the diagnostic only, no map" || no "-g on error"
# REFERENCE.md's Compile errors example says what golf2 says.
w113bex=$(sed -n '/^### Compile errors$/,/^### /p' REFERENCE.md | grep -m1 -B1 'stderr: GOLF: undefined word q at line 2' | sed 's/ *#.*//')
[ "$(printf '%s' "$w113bex" | w113b "$TMP/golf2")" = "2 GOLF: undefined word q at line 2" ] && grep -q '^### Debugging$' REFERENCE.md \
  && ok "REFERENCE.md's Compile errors example is what golf2 reports; ### Debugging documents -g" || no "REFERENCE compile errors example"

# === W11-3C ===
echo "W11-3C: checked arithmetic — ‹cadd› ‹csub› ‹cmul› throw 'integer overflow'; the bare ops still wrap"
# The literal 9223372036854775807 is fine in a USER program (golf2 reads 64-bit
# literals); INT64_MIN is spelled `1 63\shl`.  The bare - on INT64_MAX would
# list-dispatch (top 16 bits 0x7FFF), so negatives are built with \neg.
[ "$(w110 '7Ṅ9223372036854775807 1‹cadd›Ṅ')" = "rc=1 1 GOLF: integer overflow" ] \
  && [ "$(w110 '9223372036854775807 1‹cadd›Ṅ')" = "rc=1 0 GOLF: integer overflow" ] \
  && ok "INT64_MAX 1 ‹cadd›: GOLF: integer overflow, exit 1 (earlier output flushed)" || no "cadd MAX+1: $(w110 '9223372036854775807 1‹cadd›Ṅ')"
w113cbad=""
for w in '9223372036854775807 1‹cadd›' '1 63\shl 1\neg‹cadd›' '1 63\shl"‹cadd›' '9223372036854775807"‹cadd›' \
         '1 63\shl 1‹csub›' '9223372036854775807 1\neg‹csub›' '0 1 63\shl‹csub›' '1\neg 9223372036854775807‹csub›\neg 2‹csub›' \
         '1\neg 1 63\shl‹cmul›' '1 63\shl 1\neg‹cmul›' '9223372036854775807 2‹cmul›' '3037000500"‹cmul›' \
         '3037000500"\neg‹cmul›' '1 32\shl"‹cmul›' '1 62\shl 2‹cmul›' '1 62\shl\neg 2\neg‹cmul›' '1 63\shl"‹cmul›'; do
  r=$(w110 "$w")
  [ "$r" = "rc=1 0 GOLF: integer overflow" ] || w113cbad="$w113cbad [$w: $r]"
done
[ -z "$w113cbad" ] && ok "boundary overflows: MAX+1, MIN-1, MIN+MIN, MAX+MAX, MIN-1 (sub), MAX-(-1), 0-MIN, -1×MIN, MIN×-1, MAX×2, 3037000500², 2^32², 2^62×2" \
  || no "checked boundary overflows:$w113cbad"
[ "$(printf '%s' '9223372036854775807 0‹cadd›Ṅ␤1 63\shl 1‹cadd›Ṅ␤9223372036854775807 1\neg‹cadd›Ṅ␤9223372036854775807"\neg‹cadd›Ṅ␤1 63\shl 1\neg‹csub›Ṅ␤9223372036854775807 1‹csub›Ṅ␤1\neg 9223372036854775807‹csub›Ṅ␤0 9223372036854775807‹csub›Ṅ␤0 1 63\shl‹cmul›Ṅ␤1 63\shl 0‹cmul›Ṅ␤1 63\shl 1‹cmul›Ṅ␤1\neg 9223372036854775807‹cmul›Ṅ␤3037000499"‹cmul›Ṅ␤3037000499"\neg‹cmul›Ṅ␤1 62\shl\neg 2‹cmul›Ṅ␤4611686018427387903 2‹cmul›Ṅ' | gc)" \
    = "$(printf '9223372036854775807\n-9223372036854775807\n9223372036854775806\n0\n-9223372036854775807\n9223372036854775806\n-9223372036854775808\n-9223372036854775807\n0\n0\n-9223372036854775808\n-9223372036854775807\n9223372030926249001\n-9223372030926249001\n-9223372036854775808\n9223372036854775806')" ] \
  && ok "boundary non-overflows: MAX+0, MIN+1, MIN-(-1), -1-MAX = MIN, 0×MIN, MIN×1, 3037000499², -2^62×2 = MIN" || no "checked boundary non-overflows"
# Differential against Python over 20 values × 20 values × 3 ops: every pair that
# fits gives Python's exact result (and the same as the bare op, where the bare
# op can be used: neither operand in the 0x7FFF list band); every pair that does
# not fit dies with the message.  The programs are encoded once, in one Python.
python3 - "$TMP" <<'PYEOF'
import sys; sys.path.insert(0, "tools"); import codepage
T = sys.argv[1]; M = 1 << 63
V = [0, 1, -1, 2, -2, 7, -1000, 65536, 3037000499, -3037000499, 3037000500, -3037000500,
     1 << 32, (1 << 32) - 1, 1 << 62, -(1 << 62), M - 1, -M, -M + 1, (32767 << 48) + 5]
def lit(v):
    return "1 63\\shl" if v == -M else (f"{-v}\\neg" if v < 0 else str(v))
band = lambda v: (v & ((1 << 64) - 1)) >> 48 == 0x7FFF
ops = [("‹cadd›", "+", lambda a, b: a + b), ("‹csub›", "-", lambda a, b: a - b), ("‹cmul›", "*", lambda a, b: a * b)]
n = 0
for k, (word, bare, f) in enumerate(ops):
    src, want = [], []
    for a in V:
        for b in V:
            r = f(a, b)
            if -M <= r < M:
                src.append(f"{lit(a)} {lit(b)}{word}Ṅ␤"); want.append(str(r))
                if not band(a) and not band(b):
                    src.append(f"{lit(a)} {lit(b)}{bare}Ṅ␤"); want.append(str(r))
            else:
                n += 1
                open(f"{T}/w113c.ov{n}.g2", "wb").write(codepage.encode(f"{lit(a)} {lit(b)}{word}Ṅ"))
    open(f"{T}/w113c.ok{k}.g2", "wb").write(codepage.encode("".join(src)))
    open(f"{T}/w113c.ok{k}.want", "w").write("\n".join(want) + "\n")
open(f"{T}/w113c.nov", "w").write(str(n))
PYEOF
w113cbad=""
for k in 0 1 2; do
  cat "$TMP/pre.gb" "$TMP/w113c.ok$k.g2" | "$TMP/golf2" > "$TMP/p" 2>/dev/null && chmod +x "$TMP/p" && "$TMP/p" > "$TMP/w113c.got" 2>&1
  cmp -s "$TMP/w113c.got" "$TMP/w113c.ok$k.want" || w113cbad="$w113cbad [op $k: $(diff "$TMP/w113c.got" "$TMP/w113c.ok$k.want" | head -3 | tr '\n' ' ')]"
done
w113cn=$(cat "$TMP/w113c.nov")
for i in $(seq 1 "$w113cn"); do
  cat "$TMP/pre.gb" "$TMP/w113c.ov$i.g2" | "$TMP/golf2" > "$TMP/p" 2>/dev/null && chmod +x "$TMP/p" && "$TMP/p" > "$TMP/w113c.out" 2> "$TMP/w113c.err"
  r="rc=$? $(wc -c < "$TMP/w113c.out") $(cat "$TMP/w113c.err")"
  [ "$r" = "rc=1 0 GOLF: integer overflow" ] || w113cbad="$w113cbad [ov$i: $r]"
done
[ -z "$w113cbad" ] && [ "$w113cn" -gt 100 ] \
  && ok "differential vs Python, 20×20 values × 3 ops: every fitting result exact (= the bare op where usable), all $w113cn overflows throw" \
  || no "checked differential:$w113cbad"
[ "$(printf '%s' '3 4‹cadd›Ṅ␤3 4‹csub›Ṅ␤3037000499"‹cmul›Ṅ␤1\neg 1 63\shl‹cmul›Ṅ' | gref; echo " $?")" = "$(printf '7\n-1\n9223372030926249001\n 1')" ] \
  && ok "oracle: golfref runs ‹cadd› ‹csub› ‹cmul› and the overflow exit the same" || no "checked oracle"
# REFERENCE.md's Checked arithmetic examples print what the doc says.
w113cbad=""
while IFS= read -r w113cl; do
  w113cp=${w113cl%%  ->*}; w113cp=${w113cp%"${w113cp##*[! ]}"}; w113cw=${w113cl##*->  }
  [ "$(printf '%s' "$w113cp" | gc 2>&1)" = "$w113cw" ] || w113cbad="$w113cbad [$w113cp]"
done < <(sed -n '/^### Checked arithmetic$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w113cbad" ] && [ "$(sed -n '/^### Checked arithmetic$/,/^### /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 4 ] \
  && ok "REFERENCE.md's Checked arithmetic examples print what they say" || no "REFERENCE Checked arithmetic examples:$w113cbad"

# === W11-3 integration ===
echo "W11-3 integration: ‹catch› across 3A/3C (overflow caught) and 2A (catch in a program with ⎘)"
[ "$(w110 ':‹f›9223372036854775807 1‹cadd›;′‹f›‹catch›⊐“|“⊃⊐5Ṅ')" = "rc=0 18 " ] && [ "$(cat "$TMP/w110.out")" = "integer overflow|5" ] \
  && ok "′‹f›‹catch› around INT64_MAX 1 ‹cadd› returns 'integer overflow' and the program continues" \
  || no "caught overflow: $(w110 ':‹f›9223372036854775807 1‹cadd›;′‹f›‹catch›⊐“|“⊃⊐5Ṅ')"
printf '%s' ':‹boom›3⍳9⊇;:‹safe›′‹boom›‹catch›;' | w112enc > "$TMP/inc/w113i.g2"
[ "$(printf '%s' '⎘“w113i.g2“′‹boom›‹catch›⊐7Ṅ‹safe›⊐8Ṅ' | w112a "$TMP/golf2")" = 0 ] \
  && [ "$(w112run 2>&1; echo " $?")" = "index out of range7index out of range8 0" ] \
  && ok "‹catch› works in a program that ⎘-includes a file (around an included word, and inside one)" \
  || no "catch with include: $(cat "$TMP/inc/err") $(w112run 2>&1)"

# === W11-4A ===

echo "W11-4A: ⊜ records (constructor, accessors, setters over a plain list); vendor/ as the third include place"
# w114a <compiler> compiles prelude + stdin in $TMP/inc (W11-2A's directory),
# leaving "rc message" and the binary in $TMP/inc/p; w112run runs it.
w114a(){ cat "$TMP/pre.gb" <(w112enc) > "$TMP/inc/src"; (cd "$TMP/inc" && $1 < src > p 2>err; echo "$? $(cat err)"); }
[ "$(printf '%s' '⊜‹point›‹x›‹y›; 3 4‹point›‹point-y›Ṅ' | gc)" = 4 ] \
  && ok "⊜‹point›‹x›‹y›; 3 4‹point›‹point-y›Ṅ prints 4" || no "record accessor"
[ "$(printf '%s' '⊜‹point›‹x›‹y›; 3 4‹point›"‹point-x›Ṅ␤9‹set-point-x›"⍕␤"‹point-x›Ṅ␤"≢Ṅ␤‹point-y›Ṅ' | gc)" = "$(printf '3\n9 4 \n9\n2\n4')" ] \
  && ok "‹set-point-x› stores in place and leaves the record; ⍕ prints its fields; ≢ is the field count" || no "record setter / ⍕"
[ "$(printf '%s' '⊜p a ‹b›
  c ;:‹q›"‹p-c›\\‹p-a›-;1 2 3p"‹q›Ṅ␤"7‹set-p-b›‹p-b›Ṅ␤⍕' | gc)" = "$(printf '2\n7\n1 7 3 ')" ] \
  && ok "one-byte record and field names, whitespace and a newline between fields, mixed with ‹long› ones" || no "one-byte record names"
[ "$(printf '%s' ':‹len2›"‹v-x›²\\‹v-y›²+;⊚‹both›‹v-x›‹v-y›+;⊜‹v›‹x›‹y›;3 4‹v›"‹len2›Ṅ␤‹both›Ṅ␤2⍳′‹mk›€′‹v-y›€⍕:‹mk›"‹v›;' | gc)" = "$(printf '25\n7\n0 1 ')" ] \
  && ok "the words are ordinary: called and chained before the ⊜ (forward references), quoted with ′" || no "record words as names"
[ "$(printf '1Ṅ\n⊜‹point›‹x›‹y›; 3 4‹point›‹point-z›Ṅ' | w114a "$TMP/golf2")" = "2 GOLF: undefined word ‹point-z› at line 2" ] && [ ! -s "$TMP/inc/p" ] \
  && ok "a wrong field: GOLF: undefined word ‹point-z› at line 2, exit 2, no binary" || no "wrong field: $(cat "$TMP/inc/err")"
w114bad=""
for w114c in '⊜‹point›;|2 GOLF: record without fields ‹point› at line 1' \
             '\n⊜‹point›‹x› ‹y›|2 GOLF: record without ; ‹point› at line 2' \
             '⊜p‹x›(;|2 GOLF: bad record field ( at line 1' \
             '⊜(xy;|2 GOLF: bad record name ( at line 1' \
             "⊜‹$(printf 'a%.0s' $(seq 1 55))›‹x›;|2 GOLF: bad long name ‹set-$(printf 'a%.0s' $(seq 1 55))-› at line 1"; do
  w114g=$(printf "${w114c%%|*}" | w114a "$TMP/golf2")
  [ "$w114g" = "${w114c#*|}" ] && [ ! -s "$TMP/inc/p" ] || w114bad="$w114bad [$w114g]"
  w114s=$(printf "${w114c%%|*}" | w114a "$TMP/seed")
  [ "$w114s" = "2 " ] && [ ! -s "$TMP/inc/p" ] || w114bad="$w114bad [seed: $w114s]"
  w114r=$(printf "${w114c%%|*}" | w114a "python3 $EXP/boot/golfref.py")
  [ "$w114r" = "${w114c#*|}" ] || w114bad="$w114bad [golfref: $w114r]"
done
[ -z "$w114bad" ] \
  && ok "malformed ⊜ (no fields, no ;, bad field, bad name, a 61-byte invented name): golf2 and golfref say so with the line, exit 2; the seed exits 2" \
  || no "malformed ⊜:$w114bad"
w114many=$(python3 -c 'print("⊜‹r›" + "".join("‹f%d›" % k for k in range(256)) + ";" + " ".join(str(k) for k in range(100, 356)) + "‹r›\"‹r-f255›Ṅ␤\"‹r-f0›Ṅ␤≢Ṅ")')
[ "$(printf '%s' "$w114many" | gc)" = "$(printf '355\n100\n256')" ] \
  && [ "$(printf '%s' "${w114many/;/‹f256›;}" | w114a "$TMP/golf2")" = "2 GOLF: too many record fields ‹r› at line 1" ] \
  && ok "256 fields (512 invented names) work; a 257th: GOLF: too many record fields ‹r›" || no "record field bound: $(cat "$TMP/inc/err")"
[ "$(printf '%s' '⊜‹p›‹x›;5‹p›"⌫‹p-x›' | gc 2>&1)" = "GOLF: use after free" ] \
  && [ "$(printf '%s' '⊜‹p›‹x›‹y›;3⍳9‹set-p-y›⍕␤1⍳‹p-y›' | gc 2>&1)" = "$(printf '0 9 2 \nGOLF: index out of range')" ] \
  && ok "accessors and setters go through ⊇: use after free and index out of range still apply" || no "record checks"
printf '%s' '⊜‹p›‹x›‹y›;' | w112enc > "$TMP/w114.rec.g2"
printf '%s' ':‹p›2⍳\\&16≪16>16﹢⊛\\&16≪16>8﹢⊛;:‹p-x›0⊇;:‹set-p-x›&0⊇_&16≪16>8﹢⊛;:‹p-y›1⊇;:‹set-p-y›&1⊇_&16≪16>16﹢⊛;' | w112enc > "$TMP/w114.hand.g2"
cat "$TMP/pre.gb" "$TMP/w114.rec.g2" | "$TMP/golf2" > "$TMP/w114.rec" 2>/dev/null
cat "$TMP/pre.gb" "$TMP/w114.hand.g2" | "$TMP/golf2" > "$TMP/w114.hand" 2>/dev/null
cmp -s "$TMP/w114.rec" "$TMP/w114.hand" && [ -s "$TMP/w114.rec" ] \
  && ok "⊜‹p›‹x›‹y›; compiles to exactly the bytes of its five definitions written out (REFERENCE.md, Records)" || no "record expansion is not textual"
# Includes: a record declared in an included file; vendor/ searched after the
# path as written and lib/.
mkdir -p "$TMP/inc/vendor/pkg"
printf '%s' '⊜‹pt›‹x›‹y›;:‹norm2›"‹pt-x›²\\‹pt-y›²+;' | w112enc > "$TMP/inc/vendor/pkg/pt.g2"
printf '%s' ':‹who›1;' | w112enc > "$TMP/inc/vendor/who.g2"
printf '%s' ':‹who›2;' | w112enc > "$TMP/inc/lib/who.g2"
printf '%s' ':‹vend›3;' | w112enc > "$TMP/inc/vendor/vend.g2"
[ "$(printf '%s' '⎘“pkg/pt.g2“3 4‹pt›"‹norm2›Ṅ␤5‹set-pt-x›‹norm2›Ṅ' | w114a "$TMP/golf2")" = "0 " ] && [ "$(w112run)" = "$(printf '25\n41')" ] \
  && ok "a record declared in an included file (found in vendor/) works in the includer" || no "record in include: $(cat "$TMP/inc/err")"
[ "$(printf '%s' '⎘“who.g2“⎘“vend.g2“‹who›Ṅ‹vend›Ṅ' | w114a "$TMP/golf2")" = "0 " ] && [ "$(w112run)" = 23 ] \
  && [ "$(printf '%s' '⎘“nope.g2“' | w114a "$TMP/golf2")" = "2 GOLF: cannot include nope.g2 at line 1" ] \
  && ok "search order: as written, lib/, then vendor/; in none of them: GOLF: cannot include nope.g2" || no "vendor search order: $(cat "$TMP/inc/err")"
w114p='⎘“pkg/pt.g2“⎘“vend.g2“⊜q a ‹b›;3 4‹pt›‹norm2›Ṅ‹vend›Ṅ7 8q9‹set-q-b›"‹q-a›+⍕'
[ "$(printf '%s' "$w114p" | w114a "$TMP/golf2")" = "0 " ] && cp "$TMP/inc/p" "$TMP/inc/p.g2" \
  && [ "$(printf '%s' "$w114p" | w114a "$TMP/seed")" = "0 " ] && cmp -s "$TMP/inc/p" "$TMP/inc/p.g2" \
  && (cd "$TMP/inc" && python3 "$EXP/boot/golfref.py" < src > p.ref 2>/dev/null) && cmp -s "$TMP/inc/p.ref" "$TMP/inc/p.g2" \
  && [ "$(chmod +x "$TMP/inc/p.g2"; "$TMP/inc/p.g2")" = "25314 16 " ] \
  && ok "seed, golf2 and boot/golfref.py emit the same bytes for records and a vendor/ include" || no "record parity (seed/golf2/golfref)"
[ "$(printf '%s' '\rec\lnamep\rname xy;' | w112enc | od -An -tx1 | tr -d ' \n')" = "b7b470b52078793b" ] \
  && [ "$(printf '\267\264p\265xy;' | python3 tools/codepage.py decode)" = "⊜‹p›xy;" ] \
  && ok "⊜ and \\rec encode to 0xB7; decode shows ⊜" || no "⊜ encode/decode"
# tools/golfc: a .golfj package in vendor/ is encoded on the way, like lib/'s.
mkdir -p "$TMP/w114g/vendor"
printf '%s\n' '# a package' '⊜‹pt›‹x›‹y›;' ':‹sum›"‹pt-x›\\‹pt-y›+;' > "$TMP/w114g/vendor/geo.golfj"
printf '%s\n' '⎘“geo.golfj“' '3 4‹pt›‹sum›Ṅ' > "$TMP/w114g/main.golfj"
(cd "$TMP/w114g" && "$EXP/tools/golfc" -j main.golfj m >/dev/null 2>&1) && [ "$("$TMP/w114g/m")" = 7 ] \
  && ok "golfc -j: a .golfj include found in vendor/ is encoded and compiled (a record inside)" || no "golfc vendor .golfj"
# REFERENCE.md's Records examples print what the doc says.
w114bad=""
while IFS= read -r w114l; do
  w114q=${w114l%%  ->*}; w114q=${w114q%"${w114q##*[! ]}"}; w114w=${w114l##*->  }
  [ "$(printf '%s' "$w114q" | gc 2>&1)" = "$w114w" ] || w114bad="$w114bad [$w114q]"
done < <(sed -n '/^### Records$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w114bad" ] && [ "$(sed -n '/^### Records$/,/^### /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 5 ] \
  && ok "REFERENCE.md's Records examples print what they say" || no "REFERENCE Records examples:$w114bad"

# === W11-4B ===
echo "W11-4B: ‹assert› ‹expect›, exit status 1 after a failure, tools/golftest"
# w114b PROG -> "rc=N" ; stdout+stderr in $TMP/w114b.out
w114b(){ printf '%s' "$1" | gc > "$TMP/w114b.out" 2>&1; echo "rc=$?"; }
[ "$(w114b '1 1≡“a“⊃‹assert›3⍳3⍳“b“⊃‹expect›3⍳′⍳€3⍳′⍳€“c“⊃‹expect›7 7“d“⊃‹expect›')" = "rc=0" ] && [ ! -s "$TMP/w114b.out" ] \
  && ok "passing ‹assert›/‹expect› (ints, lists, nested lists) print nothing and exit 0" || no "passing checks: $(cat "$TMP/w114b.out")"
[ "$(w114b '1 2≡“one is two“⊃‹assert›“after“⊃⊐␤')" = "rc=1" ] && [ "$(cat "$TMP/w114b.out")" = "$(printf 'FAIL: one is two\nafter')" ] \
  && ok "a failing ‹assert› prints FAIL: <msg>, the program carries on, and the end-of-program exit becomes 1" || no "failing assert: $(cat "$TMP/w114b.out")"
[ "$(w114b '0“z“⊃‹assert›1“o“⊃‹assert›2“t“⊃‹assert›5180416⊙Ṅ')" = "rc=1" ] && [ "$(cat "$TMP/w114b.out")" = "$(printf 'FAIL: z\nFAIL: o\nFAIL: t\n3')" ] \
  && ok "‹assert› passes only on -1: 0, 1 (zero-is-true true) and 2 fail; the failure count cell 5180416 counts them" || no "assert convention: $(cat "$TMP/w114b.out")"
[ "$(w114b '3⍳⌽3⍳“r“⊃‹expect›6 7“s“⊃‹expect›0⍳1⍳“e“⊃‹expect›2⍳′⍳€0⍳“n“⊃‹expect›')" = "rc=1" ] \
  && [ "$(cat "$TMP/w114b.out")" = "$(printf 'FAIL: r: expected [0 1 2] got [2 1 0]\nFAIL: s: expected 7 got 6\nFAIL: e: expected [0] got []\nFAIL: n: expected [] got [[] [0]]')" ] \
  && ok "a failing ‹expect› prints expected/got (ints by Ṅ, lists in brackets via ⍕, empty and nested)" || no "failing expect: $(cat "$TMP/w114b.out")"
[ "$(w114b '0“x“⊃‹assert›0.')" = "rc=1" ] && [ "$(w114b '0“x“⊃‹assert›3.')" = "rc=3" ] && [ "$(w114b '1 1≡“x“⊃‹assert›0.')" = "rc=0" ] \
  && ok "after a failure '0.' exits 1, '3.' keeps 3; with no failure '0.' still exits 0" || no "explicit exit after failure"
[ "$(w114b '0“x“⊃‹assert›65)66)␤(Ṅ“y“⊃⊐')" = "rc=1" ] && [ "$(cat "$TMP/w114b.out")" = "$(printf 'FAIL: x\nAB\n0y')" ] \
  && ok "raw ) and ( after a failure still just flush (the exit hook leaves them alone)" || no "raw io after failure: $(cat "$TMP/w114b.out")"
[ "$(w114b ':‹t›0“in“⊃‹assert›“boom“⊃‹throw›;′‹t›‹catch›⊐␤5180416⊙Ṅ')" = "rc=1" ] && [ "$(cat "$TMP/w114b.out")" = "$(printf 'FAIL: in\nboom\n1')" ] \
  && ok "a failure inside a caught ‹catch› still counts and still makes the exit 1" || no "assert in catch: $(cat "$TMP/w114b.out")"
# REFERENCE.md's Testing examples print what the doc says (and exit 1 exactly when they print FAIL:).
w114bbad=""
while IFS= read -r w114bl; do
  w114bp=${w114bl%%  ->*}; w114bp=${w114bp%"${w114bp##*[! ]}"}; w114bw=${w114bl##*->  }
  w114brc=$(w114b "$w114bp"); w114bexp=rc=0; case "$w114bw" in FAIL:*) w114bexp=rc=1;; esac
  [ "$(cat "$TMP/w114b.out")" = "$w114bw" ] && [ "$w114brc" = "$w114bexp" ] || w114bbad="$w114bbad [$w114bp]"
done < <(sed -n '/^### Testing$/,/^## /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w114bbad" ] && [ "$(sed -n '/^### Testing$/,/^## /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 6 ] \
  && ok "REFERENCE.md's Testing examples print what they say" || no "REFERENCE Testing examples:$w114bbad"
# tools/golftest on the shipped passing example and the failing fixture.
w114bgt(){ tools/golftest "$@" > "$TMP/w114b.gt" 2>&1; echo "rc=$?"; }
[ "$(w114bgt examples/tests)" = "rc=0" ] && [ "$(cat "$TMP/w114b.gt")" = "$(printf 'PASS examples/tests/lists_test.golfj\n1 passed, 0 failed')" ] \
  && ok "golftest examples/tests: PASS examples/tests/lists_test.golfj, exit 0" || no "golftest pass: $(cat "$TMP/w114b.gt")"
[ "$(w114bgt test/fixtures/golftest/fail_test.golfj examples/tests)" = "rc=1" ] \
  && [ "$(cat "$TMP/w114b.gt")" = "$(printf 'FAIL test/fixtures/golftest/fail_test.golfj (exit 1)\n  FAIL: one is two\n  FAIL: reverse is identity: expected [0 1 2] got [2 1 0]\n  FAIL: six: expected 7 got 6\nPASS examples/tests/lists_test.golfj\n1 passed, 1 failed')" ] \
  && ok "golftest on the failing fixture: FAIL (exit 1) with its FAIL lines, then the summary; exits 1" || no "golftest fail: $(cat "$TMP/w114b.gt")"
mkdir -p "$TMP/w114b/sub"
printf '1Ṅ\n5qṄ\n' > "$TMP/w114b/sub/bad_test.golfj"
printf '“FAIL: by hand“⊃⊐␤‹flush›0 0 0 60⎈' > "$TMP/w114b/raw_test.golfj"
printf '3⍳9⊇' > "$TMP/w114b/err_test.golfj"
printf '0“never run“⊃‹assert›' > "$TMP/w114b/helper.golfj"
[ "$(w114bgt "$TMP/w114b")" = "rc=1" ] \
  && [ "$(sed "s#$TMP/##" "$TMP/w114b.gt")" = "$(printf 'FAIL w114b/err_test.golfj (exit 1)\n  GOLF: index out of range\nFAIL w114b/raw_test.golfj (exit 0)\n  FAIL: by hand\nFAIL w114b/sub/bad_test.golfj (compile error)\n  GOLF: undefined word q at line 2\n0 passed, 3 failed')" ] \
  && ok "golftest DIR recurses, takes only *_test.golfj; runtime error, FAIL: with exit 0 and compile error all fail" || no "golftest cases: $(cat "$TMP/w114b.gt")"
mkdir -p "$TMP/w114b/none"
[ "$(w114bgt "$TMP/w114b/none")" = "rc=1" ] && grep -q 'no \*_test.golfj found' "$TMP/w114b.gt" \
  && ok "golftest with no test files: 'no *_test.golfj found', exit 1" || no "golftest none: $(cat "$TMP/w114b.gt")"

# === W11-4C ===
echo "W11-4C: ‹stack› prints the data stack non-destructively; tools/golfi is a replay REPL"
[ "$(printf '%s' '‹stack›1 2 3⍳‹stack›⍕‹stack›Ṅ‹stack›' | gc)" = "$(printf '<0>\n<3> 1 2 [0 1 2]\n0 1 2 <2> 1 2\n2<1> 1')" ] \
  && ok "‹stack›: <depth> then bottom to top, a list via ⍕'s bracketed form, and the stack is left as it was" || no "w11-4c stack basic"
[ "$(printf '%s' '0 1 63\shl 5\neg 3⍳′⍳€0⍳‹stack›' | gc)" = "<5> 0 -9223372036854775808 -5 [[] [0] [0 1]] []" ] \
  && ok "‹stack›: zero, INT64_MIN, negatives, nested and empty lists" || no "w11-4c stack values"
# Inside a word the data stack is the same (return addresses live on the rbp
# stack); inside € the mapped element sits on top of the caller's values; a ⊡
# word's locals frame is not on it either.
[ "$(printf '%s' ':‹s›9‹stack›_;1 2‹s›‹stack›1 2⍳′‹stack›€_⊡‹g›⇒‹a›7‹stack›_;‹g›‹stack›' | gc)" \
    = "$(printf '<3> 1 2 9\n<2> 1 2\n<4> 1 2 1 0\n<4> 1 2 1 1\n<3> 1 2 7\n<2> 1 2')" ] \
  && ok "‹stack› inside a : word, inside €, inside a ⊡ word: the one data stack" || no "w11-4c stack in words"
[ "$(printf '%s' '5 6′‹stack›‹catch›‹stack›' | gc)" = "$(printf '<2> 5 6\n<3> 5 6 0')" ] \
  && ok "‹stack› under ‹catch›" || no "w11-4c stack catch"
w114c='1 2 3⍳3⍳′⍳€‹stack›:‹s›‹stack›;4 ‹s›'
[ "$(printf '%s' "$w114c" | gref)" = "$(printf '%s' "$w114c" | gc)" ] && [ "$(printf '%s' "$w114c" | gc | head -1)" = "<4> 1 2 [0 1 2] [[] [0] [0 1]]" ] \
  && ok "oracle: golfref runs ‹stack› identically" || no "w11-4c stack oracle"
# tools/golfi: a scripted session.  A word defined on line 1 is used two lines
# later; the stack shows after each entry; an undefined word (compile error)
# and an index error (runtime) are reported and dropped, and the session goes
# on as if they never happened; a definition spans two lines; stdin is
# /dev/null (‹readall› gets nothing, no hang); :show :reset :quit.
w114cin=':‹sq›"*;
3 4
‹sq›+
oops
3⍳9⊇
2 3⍳
‹sq›
“sq: “🗲∑Ṅ
:f
1+;
f
‹readall›≢_
:show
:reset
‹stack›
:quit
7'
w114cwant='<0>
<2> 3 4
<1> 19
GOLF: undefined word o
(not kept)
GOLF: index out of range
(not kept)
<3> 19 2 [0 1 2]
<3> 19 2 [0 1 4]
sq: 5
<2> 19 2
<2> 19 2
<2> 19 3
<2> 19 3
:‹sq›"*;
3 4
‹sq›+
2 3⍳
‹sq›
“sq: “🗲∑Ṅ
:f
1+;
f
‹readall›≢_
session cleared
<0>
<0>'
w114cgot=$(printf '%s\n' "$w114cin" | timeout 60 tools/golfi 2>&1)
[ "$w114cgot" = "$w114cwant" ] && ok "golfi: scripted session (define, use 2 lines later, stack each entry, errors dropped, multi-line def, :show :reset :quit)" \
  || no "w11-4c golfi session: $(diff <(printf '%s\n' "$w114cwant") <(printf '%s\n' "$w114cgot") | head -8 | tr '\n' '|')"
# An entry left open at end of input is not run; an error inside a two-line
# entry names its line; -t times every entry.
[ "$(printf ':g\nzz;\n1[2\n' | tools/golfi 2>&1)" = "$(printf 'GOLF: undefined word z at line 2 of this entry\n(not kept)\nincomplete entry at end of input\n(not kept)')" ] \
  && ok "golfi: an error's line within a multi-line entry; an unfinished entry at EOF is dropped" || no "w11-4c golfi open/line"
w114ct=$(printf '1\n2\n' | tools/golfi -t | grep -c '^([0-9.]* s)$')
[ "$w114ct" = 2 ] && ok "golfi -t: one timing line per entry" || no "w11-4c golfi -t ($w114ct)"
# REFERENCE.md's REPL examples print what the doc says.
w114cbad=""
while IFS= read -r w114cl; do
  w114cp=${w114cl%%  ->*}; w114cp=${w114cp%"${w114cp##*[! ]}"}; w114cw=${w114cl##*->  }
  [ "$(printf '%s' "$w114cp" | gc 2>&1)" = "$w114cw" ] || w114cbad="$w114cbad [$w114cp]"
done < <(sed -n '/^### REPL$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w114cbad" ] && [ "$(sed -n '/^### REPL$/,/^### /p' REFERENCE.md | grep -c -- '  ->  ')" -ge 3 ] \
  && ok "REFERENCE.md's REPL examples print what they say" || no "REFERENCE REPL examples:$w114cbad"

# === W11-4D ===
echo "W11-4D: tools/golfgdb — gdb by word name (golf-break, golf-bt, golf-stack, golf-where)"
# REFERENCE.md's Debugging walkthrough: its program block (`# deb.golfj`) is
# compiled with golfc -g, its `(gdb) ` lines are the commands, and its golf-*
# output lines (golf:, #N, data stack, [k]) must come out of gdb -batch in the
# same order — with addresses masked, since they move with the prelude.
mkdir -p "$TMP/w114d"
sed -n '/^### Debugging$/,/^## /p' REFERENCE.md | awk -v d="$TMP/w114d" '
  /^```/ { if (inb) { inb = 0; f = "" } else { inb = 1; first = 1 } next }
  inb && first { first = 0; if ($0 == "# deb.golfj") f = d "/deb.golfj"; else if ($0 ~ /tools\/golfgdb/) f = d "/session" }
  inb && f != "" { print > f }'
grep '^(gdb) ' "$TMP/w114d/session" | sed 's/^(gdb) //' | grep -v '^continue$' > "$TMP/w114d/cmds"
w114dm(){ grep -E '^(golf:|#[0-9]|data stack|  \[)' | sed 's/0x[0-9a-f]*/0x…/g'; }
w114dg=$(cd "$TMP/w114d" && "$EXP/tools/golfc" -j -g deb.golfj deb 2>&1 && "$EXP/tools/golfgdb" --emit deb.gdb deb 2>&1)
"$EXP/tools/golfgdb" "$TMP/w114d/nomap" > /dev/null 2> "$TMP/w114d/nomap.err"; w114drc=$?
[ -z "$w114dg" ] && [ "$("$TMP/w114d/deb")" = 72 ] \
  && grep -q 'GOLF_WORDS = \[.*‹inner›' "$TMP/w114d/deb.gdb" \
  && [ "$(grep -c 'super().__init__("golf-\(break\|bt\|stack\|where\|words\)"' "$TMP/w114d/deb.gdb")" = 5 ] \
  && [ "$w114drc" = 1 ] && grep -q 'no .*nomap.map (compile with' "$TMP/w114d/nomap.err" \
  && ok "golfgdb --emit writes a gdb script holding the map and golf-break/bt/stack/where/words; no .map -> a clear error" \
  || no "golfgdb --emit: $w114dg $(cat "$TMP/w114d/nomap.err")"
if command -v gdb >/dev/null 2>&1 && [ "$(gdb -nx -batch -ex 'python print(4*4)' 2>/dev/null)" = 16 ]; then
  w114dgot=$(cd "$TMP/w114d" && "$EXP/tools/golfgdb" --batch-script cmds ./deb 2>&1)
  [ -s "$TMP/w114d/cmds" ] && [ "$(echo "$w114dgot" | w114dm)" = "$(w114dm < "$TMP/w114d/session")" ] \
    && [ "$(echo "$w114dgot" | grep -E '^#[0-9]' | sed 's/.* in //; s/+.*//' | tr '\n' ' ')" = "‹inner› ‹mid› ‹outer› (top level) " ] \
    && echo "$w114dgot" | grep -qx '  \[0\] 6' \
    && ok "gdb -batch: golf-break inner stops in ‹inner›; golf-bt ‹inner› ‹mid› ‹outer› (top level); golf-stack shows the 6 (= REFERENCE walkthrough)" \
    || no "golfgdb walkthrough: $w114dgot"
  # Stopped on the word's FIRST byte (inside the prologue, the return address
  # still on rsp) with plain `break *ADDR`; the caller is a ⊡ word whose local
  # shares the return stack; a list argument; the named break in a ⊡ word.
  printf ':‹inner›"*;\n⊡‹g›⇒a⇐a⇐a+‹inner›;\n:‹f›∑‹g›;\n5⍳‹f›Ṅ\n' > "$TMP/w114d/u.golfj"
  (cd "$TMP/w114d" && "$EXP/tools/golfc" -j -g u.golfj u) > /dev/null 2>&1
  printf '%s\n' 'golf-break f' run golf-stack delete "break *$(sed -n 's/^‹inner› //p' "$TMP/w114d/u.map")" continue \
    golf-bt golf-stack stepi stepi golf-where golf-bt golf-stack > "$TMP/w114d/ucmds"
  w114du=$(cd "$TMP/w114d" && "$EXP/tools/golfgdb" --batch-script ucmds ./u 2>&1)
  [ "$(echo "$w114du" | w114dm | tr '\n' '|')" = "golf: 0x… in ‹f›+7|data stack: depth 1|  [0] list @0x… len 5 [0 1 2 3 4]|golf: 0x… in ‹inner›+0|#0  0x… in ‹inner›+0|#1  0x… in ‹g›+77|#2  0x… in ‹f›+17|#3  0x… in (top level)|data stack: depth 1|  [0] 20|golf: 0x… in ‹inner›+4|golf: 0x… in ‹inner›+7|golf: 0x… in ‹inner›+7|#0  0x… in ‹inner›+7|#1  0x… in ‹g›+77|#2  0x… in ‹f›+17|#3  0x… in (top level)|data stack: depth 1|  [0] 20|" ] \
    && ok "inside a prologue (break *ADDR, stepi) golf-bt / golf-stack stay right; a ⊡ caller's local is skipped; a list shows its elements" \
    || no "golfgdb prologue/locals: $w114du"
  printf '%s\n' 'golf-break nosuch' > "$TMP/w114d/bad"; printf '%s\n' 'golf-break ‹inner›' run continue > "$TMP/w114d/cont"
  w114db=$(cd "$TMP/w114d" && "$EXP/tools/golfgdb" --batch-script bad ./deb 2>&1)
  w114dc=$(cd "$TMP/w114d" && "$EXP/tools/golfgdb" --batch-script cont ./deb 2>&1)
  echo "$w114db" | grep -q 'golf-break: no word nosuch in the map' \
    && echo "$w114dc" | grep -q '^72\[Inferior 1 (process [0-9]*) exited normally\]$' \
    && ok "golf-break ‹inner› (bracketed) then continue: the program finishes and prints 72; an unknown name is an error" \
    || no "golfgdb continue/unknown: $w114db | $w114dc"
else
  ok "golfgdb walkthrough: gdb (with Python) not installed, skipped"
  ok "golfgdb prologue/locals: gdb (with Python) not installed, skipped"
  ok "golfgdb continue/unknown name: gdb (with Python) not installed, skipped"
fi

# === W11-4E ===
echo "W11-4E: tools/golfdeps — golf.deps pins packages (name git-url tag sha256), fetched into vendor/"
# The package is a local git repo made here (no network): mathx.golfj defines
# ‹pkgcube›.  Each project is its own directory holding golf.deps + vendor/.
w114e="$TMP/deps"; w114gd="$EXP/tools/golfdeps"; w114n=11
w114z=0000000000000000000000000000000000000000000000000000000000000000
w114bad=1111111111111111111111111111111111111111111111111111111111111111
# w114 DIR ARGS... — run golfdeps in DIR; stdout+stderr to $w114e/out, status on stdout
w114(){ w114d=$1; shift; (cd "$w114d" && "$w114gd" "$@" > "$w114e/out" 2>&1; echo $?); }
mkdir -p "$w114e/src/sub" "$w114e/p1" "$w114e/p2" "$w114e/p3"
printf '%s\n' '# mathx: a test package' ':‹pkgcube›""**;' > "$w114e/src/mathx.golfj"
printf 'not golf\n' > "$w114e/src/sub/notes.txt"
if command -v git >/dev/null 2>&1 && (cd "$w114e/src" && git init -q && git add . \
     && git -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm pkg \
     && git -c tag.gpgsign=false tag v1.0) >/dev/null 2>&1; then
  w114h=$("$w114gd" hash "$w114e/src")
  # The definition, computed independently: sha256 over "<sha256> <path>\n", paths sorted, .git/ left out.
  w114py=$(python3 -c '
import hashlib, os, sys
r = sys.argv[1]; fs = []
for d, ds, ns in os.walk(r):
    if d == r and ".git" in ds: ds.remove(".git")
    fs += [os.path.relpath(os.path.join(d, n), r) for n in ns]
print(hashlib.sha256(b"".join(b"%s %s\n" % (hashlib.sha256(open(os.path.join(r, f), "rb").read()).hexdigest().encode(), f.encode())
      for f in sorted(fs, key=os.fsencode))).hexdigest())' "$w114e/src")
  echo "mathx  $w114e/src  v1.0  $w114z   # not pinned yet" > "$w114e/p1/golf.deps"
  [ "$(w114 "$w114e/p1" fetch)" = 1 ] && grep -q "has no sha256 pin yet" "$w114e/out" && grep -q "got  $w114h" "$w114e/out" \
    && [ ! -e "$w114e/p1/vendor/mathx" ] && [ -z "$(ls -A "$w114e/p1/vendor")" ] \
    && ok "an all-zero pin is refused (exit 1, nothing in vendor/), printing the hash the tag has" || no "zero pin: $(cat "$w114e/out")"
  [ -n "$w114h" ] && [ "$w114h" = "$w114py" ] \
    && ok "golfdeps hash = sha256 of sorted '<sha256> <path>' lines, .git/ excluded (as REFERENCE.md defines it)" || no "package hash '$w114h' vs '$w114py'"
  printf '# mathx, pinned\nmathx file://%s v1.0 %s  # the test package\n' "$w114e/src" "$w114h" > "$w114e/p1/golf.deps"
  [ "$(w114 "$w114e" fetch -f p1/golf.deps)" = 0 ] && grep -q "fetched into vendor/mathx" "$w114e/out" \
    && cmp -s "$w114e/src/mathx.golfj" "$w114e/p1/vendor/mathx/mathx.golfj" && [ ! -e "$w114e/p1/vendor/mathx/.git" ] \
    && [ "$(ls -A "$w114e/p1/vendor")" = mathx ] && [ ! -e "$w114e/vendor" ] \
    && ok "fetch clones the tag into vendor/mathx/ next to the manifest (-f), without .git/ or leftovers" || no "fetch: $(cat "$w114e/out")"
  printf '%s\n' '⎘“vendor/mathx/mathx.golfj“' '3‹pkgcube›Ṅ' > "$w114e/p1/main.golfj"
  (cd "$w114e/p1" && "$EXP/tools/golfc" -j main.golfj main > /dev/null 2>&1) && [ "$("$w114e/p1/main")" = 27 ] \
    && ok "a program includes the fetched package (⎘“vendor/mathx/mathx.golfj“) and uses its word: 27" || no "use a package"
  [ "$(w114 "$w114e/p1" fetch)" = 0 ] && [ "$(cat "$w114e/out")" = "golfdeps: mathx v1.0: up to date" ] \
    && [ "$(w114 "$w114e/p1" verify)" = 0 ] && [ "$(w114 "$w114e/p1" list)" = 0 ] && [ "$(cat "$w114e/out")" = "mathx v1.0 ok" ] \
    && ok "fetch again is a no-op (up to date); verify exits 0; list says 'mathx v1.0 ok'" || no "re-fetch: $(cat "$w114e/out")"
  printf 'tampered\n' >> "$w114e/p1/vendor/mathx/sub/notes.txt"
  [ "$(w114 "$w114e/p1" verify)" = 1 ] && grep -q "vendor/mathx does not match its sha256 pin" "$w114e/out" \
    && [ "$(w114 "$w114e/p1" list)" = 0 ] && [ "$(cat "$w114e/out")" = "mathx v1.0 modified" ] \
    && [ "$(w114 "$w114e/p1" fetch)" = 0 ] && [ "$(w114 "$w114e/p1" verify)" = 0 ] \
    && cmp -s "$w114e/src/sub/notes.txt" "$w114e/p1/vendor/mathx/sub/notes.txt" \
    && ok "verify catches a tampered vendor file (exit 1, list: modified); fetch restores it" || no "tamper: $(cat "$w114e/out")"
  cp -R "$w114e/p1/vendor" "$w114e/p2/"
  printf 'mathx %s v1.0 %s\n' "$w114e/src" "$w114bad" > "$w114e/p2/golf.deps"
  [ "$(w114 "$w114e/p2" fetch)" = 1 ] && grep -q "does not match the sha256 pinned in golf.deps; refusing it" "$w114e/out" \
    && grep -q "want $w114bad" "$w114e/out" && grep -q "got  $w114h" "$w114e/out" \
    && [ ! -e "$w114e/p2/vendor/mathx" ] && [ -z "$(ls -A "$w114e/p2/vendor")" ] \
    && ok "a wrong hash is refused: exit 1, want/got printed, vendor/mathx (even an old copy) removed" || no "wrong hash: $(cat "$w114e/out")"
  printf 'mathx %s v9.9 %s\n' "$w114e/src" "$w114h" > "$w114e/p3/golf.deps"
  [ "$(w114 "$w114e/p3" fetch)" = 1 ] && grep -q "mathx: cannot clone tag v9.9" "$w114e/out" && [ -z "$(ls -A "$w114e/p3/vendor")" ] \
    && [ "$(w114 "$w114e/p3" verify)" = 1 ] && grep -q "mathx v9.9: missing from vendor/" "$w114e/out" \
    && ok "a tag that does not exist: cannot clone, exit 1, nothing left; verify: missing, exit 1" || no "bad tag: $(cat "$w114e/out")"
  w114m=""
  for w114l in "mathx $w114e/src v1.0" "../up $w114e/src v1.0 $w114h" ".hid $w114e/src v1.0 $w114h" "m x v1.0 ABC" \
               "m x v1.0 $w114h|m y v1.0 $w114h"; do
    printf '# header\n\n%s\n' "$w114l" | tr '|' '\n' > "$w114e/p3/bad.deps"
    [ "$(w114 "$w114e/p3" list -f bad.deps)" = 2 ] && grep -q "^golfdeps: bad.deps line [34]: " "$w114e/out" || w114m="$w114m [$w114l]"
  done
  [ -z "$w114m" ] && [ "$(w114 "$w114e/p3" fetch -f none.deps)" = 2 ] && [ "$(w114 "$w114e/p3" frob)" = 2 ] \
    && ok "manifest errors exit 2 naming the line: 3 fields, ../ or . names, a short hash, a name twice; no manifest" || no "manifest errors:$w114m"
  sed -n '/^### Packages$/,/^### /p' REFERENCE.md | awk '/^```$/{n++; next} n==1' > "$w114e/p3/golf.deps"
  [ "$(w114 "$w114e/p3" list)" = 0 ] && [ "$(cat "$w114e/out")" = "$(printf 'mathx v1.2 missing\ntextx v0.3 missing')" ] \
    && ok "REFERENCE.md's golf.deps example parses (golfdeps list: two packages, missing)" || no "REFERENCE golf.deps example: $(cat "$w114e/out")"
  # The bare ⎘“<name>/<file>“ form goes through W11-4A's vendor/ search path
  # (merged in wave 4), so it must pass: no skip branch.
  sed -n '/^### Packages$/,/^### /p' REFERENCE.md | awk '/^```$/{n++; next} n==5' > "$w114e/p1/bare.golfj"
  (cd "$w114e/p1" && "$EXP/tools/golfc" -j bare.golfj bare > /dev/null 2>&1) && [ "$("$w114e/p1/bare")" = 27 ] \
    && grep -q '^⎘“mathx/mathx.golfj“' "$w114e/p1/bare.golfj" \
    && ok "REFERENCE.md's ⎘“mathx/mathx.golfj“ example finds the package through vendor/ and prints 27" || no "bare package include"
else
  for k in $(seq 1 "$w114n"); do ok "golfdeps: git not available, skipped"; done
fi

# === W11-4 integration ===
echo "W11-4 integration: one program over ⎘ + ⊜ + dict + ⊸ + ‹catch› + ‹fmt› + files + ‹expect›; golfi with records"
w114x="$TMP/w114x"; rm -rf "$w114x"; mkdir -p "$w114x"
cat > "$w114x/geom.golfj" <<'GOLF'
⊜‹point›‹x›‹y›;
:‹norm2›"‹point-x›²&‹point-y›²+;
GOLF
cat > "$w114x/main_test.golfj" <<'GOLF'
⎘“geom.golfj“
⎘“geom.golfj“
3 4‹point›→p
←p‹norm2›→n
←n 25“norm2 via record“⊃‹expect›
←p 9‹set-point-x›‹point-x› 9“setter“⊃‹expect›
‹dict›“norm“⊃←n‹put›→d
←d“norm“⊃‹get› 25“dict get“⊃‹expect›
3⍳10′+⊸€→l
←l∑ 33“bound add“⊃‹expect›
:‹bad›←l9⊇;
′‹bad›‹catch›→e
←e“index out of range“⊃“caught“⊃‹expect›
←n‹fmt›“n.txt“⊃‹writefile›
“n.txt“⊃‹readfile›→r
←r“25“⊃“file round trip“⊃‹expect›
“caught: “⊃⊐←e⊐␤
“norm2 = “⊃⊐←r⊐␤
←l⍕␤
GOLF
sed 's/←l∑ 33/←l∑ 34/' "$w114x/main_test.golfj" > "$w114x/bad_test.golfj"
(cd "$w114x" && "$EXP/tools/golfc" -j main_test.golfj main > /dev/null 2>&1 && ./main > out 2>&1; echo $? > rc)
[ "$(cat "$w114x/rc")" = 0 ] && [ "$(cat "$w114x/out")" = "$(printf 'caught: index out of range\nnorm2 = 25\n10 11 12 ')" ] \
  && [ "$(cat "$w114x/n.txt")" = 25 ] \
  && ok "one program: ⎘ (twice, once), ⊜ record + setter, dict, ⊸, caught index error, ‹fmt› → ‹writefile›/‹readfile›, every ‹expect› passes" \
  || no "W11 smoke program: rc=$(cat "$w114x/rc") $(cat "$w114x/out")"
(cd "$w114x" && "$EXP/tools/golftest" . > gt 2>&1; echo $? > rc)
[ "$(cat "$w114x/rc")" = 1 ] && grep -q '^PASS ./main_test.golfj$\|^PASS main_test.golfj$' "$w114x/gt" \
  && grep -q '^  FAIL: bound add: expected 34 got 33$' "$w114x/gt" && grep -q '^1 passed, 1 failed$' "$w114x/gt" \
  && ok "golftest on it: the program PASSes, the one-check variant FAILs with expected/got, exit 1" \
  || no "golftest smoke: $(cat "$w114x/gt")"
[ "$(printf '%s\n' '⊜‹point›‹x›‹y›;' '3 4‹point›' '"‹point-y›' | (cd "$w114x" && "$EXP/tools/golfi" 2>&1) | tail -3)" = "$(printf '<0>\n<1> [3 4]\n<2> [3 4] 4')" ] \
  && ok "golfi keeps a ⊜ record across lines (constructor and accessor in later entries)" || no "golfi records"

# === W12-0 ===
echo "W12-0: € ⇤ ⌿ ⊞ call their function with the caller's stack underneath (the A1 contract)"
w120bad=""; w120n=0
while IFS= read -r w120l; do
  w120p=${w120l%%  ->*}; w120p=${w120p%"${w120p##*[! ]}"}; w120w=${w120l##*->  }
  w120n=$((w120n+1))
  [ "$(printf '%s' "$w120p" | gc | sed 's/ *$//')" = "$w120w" ] || w120bad="$w120bad [$w120p]"
  [ "$(printf '%s' "$w120p" | gref | sed 's/ *$//')" = "$w120w" ] || w120bad="$w120bad oracle[$w120p]"
done < <(sed -n '/^### Threading state through/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w120bad" ] && [ "$w120n" -ge 6 ] \
  && ok "REFERENCE.md's threading examples (running sum/max, counter, ⌿ ⇤ ⊞) print what they say, golf2 and oracle" \
  || no "REFERENCE threading examples:$w120bad"
w120reg=$(sed -n '/^### 1.4 W12 assignments/,/^## 2\./p' REGISTRY.md | grep -cE '\| (reserved|shipped) \|$')
[ "$w120reg" -ge 13 ] && ok "REGISTRY.md §1.4 reserves the W12 bytes ($w120reg rows)" || no "W12 byte reservations: $w120reg"

# === W12-P1 ===
echo "W12-P1: ‹ints› scans the stdin buffer directly; ‹readbytes›; ‹words› ‹num› ‹readall› rewritten"
# w12p1m FILE: the REFERENCE "Input" semantics of ‹ints› in Python (words split
# on 9-13 and 32, one optional sign, digits up to a non-digit, mod 2^64), printed
# the way ⍕ prints a flat list.
w12p1m(){ python3 - "$1" <<'PY'
import sys
out = []
for w in open(sys.argv[1], "rb").read().split():
    i, neg, acc = 0, w[:1] == b"-", 0
    if w[:1] in (b"-", b"+"): i = 1
    while i < len(w) and 48 <= w[i] <= 57: acc = acc * 10 + w[i] - 48; i += 1
    v = (-acc if neg else acc) % 2**64
    out.append(v - 2**64 if v >= 2**63 else v)
sys.stdout.write("".join("%d " % v for v in out))
PY
}
# the oracle on stdin: golfref compiles prelude + $1, the binary reads our stdin
w12p1o(){ printf '%s' "$1" | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - | python3 boot/golfref.py > "$TMP/w12p1o" 2>/dev/null \
            && chmod +x "$TMP/w12p1o" && "$TMP/w12p1o"; }
[ "$(printf '' | gin '‹ints›"≢Ṅ⍕')" = "0" ] && [ "$(printf ' \t\n\r\n  \x0b\x0c ' | gin '‹ints›≢Ṅ')" = "0" ] \
  && ok "‹ints›: empty input and whitespace-only input give the empty list" || no "ints empty/blank"
[ "$(printf -- '-1 +2 -30 +0 -0 7 +12 -9x' | gin '‹ints›⍕')" = "-1 2 -30 0 0 7 12 -9 " ] \
  && ok "‹ints›: '-' negates, '+' is skipped, -0 is 0" || no "ints signs"
[ "$(printf -- '12ab x -7z +x - + 5-3 -+5 +-5 --1 1x2' | gin '‹ints›⍕')" = "12 0 -7 0 0 0 5 0 0 0 1 " ] \
  && ok "‹ints›: a word like 12ab is 12, x is 0; a lone sign, a second sign or a later '-' ends the number" || no "ints words"
[ "$(printf '1\r\n-2\r\n\r\n3\r\n' | gin '‹ints›⍕')" = "1 -2 3 " ] && [ "$(printf '4\t5\x0b6\x0c7' | gin '‹ints›⍕')" = "4 5 6 7 " ] \
  && ok "‹ints›: CRLF lines, and tab, \\v, \\f between numbers" || no "ints CRLF"
[ "$(printf '99999999999999999999 9223372036854775808 18446744073709551616 18446744073709551617 -18446744073709551615' | gin '‹ints›⍕')" \
     = "7766279631452241919 -9223372036854775808 0 1 1 " ] \
  && [ "$(printf '9223372036854775807 -9223372036854775808' | gin '‹ints›→l←l0⊇Ṅ␤←l1⊇Ṅ')" = "$(printf '9223372036854775807\n-9223372036854775808')" ] \
  && ok "‹ints›: overflow wraps mod 2^64 (INT64 max and min exactly, 2^64 is 0)" || no "ints wraparound"
# Numbers, signs and non-number words straddling every 8192-byte refill: token
# k starts j bytes before the boundary 8192k (j = 0..8), so its sign, its
# digits or its tail land in the next read.
python3 - > "$TMP/w12p1b.in" <<'PY'
import sys
toks = [b"-1234567", b"+987654", b"12ab34", b"x9", b"7", b"-", b"31415926535"]
out = bytearray(); k = 1
for j in range(9):
    for t in toks:
        pad = 8192 * k - j - len(out)
        out += b" " * max(pad, 1) + t; k += 1
out += b"\n"
sys.stdout.buffer.write(bytes(out))
PY
[ "$(wc -c < "$TMP/w12p1b.in")" -gt 500000 ] && [ "$(gin '‹ints›⍕' < "$TMP/w12p1b.in")" = "$(w12p1m "$TMP/w12p1b.in")" ] \
  && [ "$(gin '‹readall›‹words›′‹num›€⍕' < "$TMP/w12p1b.in")" = "$(w12p1m "$TMP/w12p1b.in")" ] \
  && ok "‹ints› (and ‹readall›‹words›′‹num›€) on tokens split across the 8 KB buffer boundary, 63 placements, match Python" \
  || no "ints across the buffer boundary"
python3 -c 'import random; r=random.Random(5); a=[b"0",b"1",b"9",b"-",b"+",b" ",b"\n",b"\r",b"\t",b"x",b"\x00",b"\xff",b"/",b":"]; open("'"$TMP"'/w12p1r.in","wb").write(b"".join(r.choice(a) for _ in range(60000)))'
[ "$(gin '‹ints›⍕' < "$TMP/w12p1r.in")" = "$(w12p1m "$TMP/w12p1r.in")" ] \
  && [ "$(gin '‹readall›‹words›′‹num›€⍕' < "$TMP/w12p1r.in")" = "$(w12p1m "$TMP/w12p1r.in")" ] \
  && ok "60 KB of random digits, signs, blanks, NUL and 0xFF: ‹ints› and the ‹words›/‹num› pipeline match Python" || no "ints random bytes"
[ "$(printf '12 34\n' | gin '‹getc›Ṅ␤‹ints›⍕')" = "$(printf '49\n2 34 ')" ] \
  && [ "$(printf 'n 2\n5 6\n' | gin '‹readline›_⊐␤‹ints›⍕‹getc›Ṅ')" = "$(printf 'n 2\n5 6 -1')" ] \
  && ok "‹ints› picks up where ‹getc› / ‹readline› left the shared buffer, and leaves it at end of input" || no "ints after getc"
# ‹ints› keeps ONE growing list: after it, the live heap holds that list and
# the 8 KB buffer, not a code list (8 bytes/byte) or 200000 small lists.
[ "$(gin '‹heapstats›→b_‹ints›≢Ṅ␤‹heapstats›←b-3145728<Ṅ_' < "$TMP/big.in")" = "$(printf '200000\n-1')" ] \
  && ok "‹ints› of 200000 numbers grows the live heap by under 3 MB (one doubled result list and the buffer)" || no "ints heap growth"
[ "$(printf '1 -2 x 3\r\n+4' | w12p1o '‹ints›⍕')" = "1 -2 0 3 4 " ] && [ "$(printf 'ab\ncd' | w12p1o '‹readbytes›"🗲⊃≢Ṅ')" = "$(printf 'ab\ncd5')" ] \
  && ok "oracle: ‹ints› and ‹readbytes› behave identically" || no "oracle ints/readbytes"
[ "$(printf 'hello\nworld\n' | gin '‹readbytes›🗲')" = "$(printf 'hello\nworld')" ] && [ "$(printf '' | gin '‹readbytes›"@Ṅ⊃≢Ṅ')" = "00" ] \
  && [ "$(printf 'ab cd' | gin '‹getc›Ṅ‹readbytes›"🗲⊃≢Ṅ‹getc›Ṅ')" = "97b cd4-1" ] \
  && ok "‹readbytes›: 🗲 prints it, ⊃ makes a code list, empty input is length 0; it takes the rest after ‹getc›, then end of input" \
  || no "readbytes basics"
python3 -c 'open("'"$TMP"'/w12p1y.in","wb").write(bytes(range(256))*300)'
gin '‹readbytes›🗲' < "$TMP/w12p1y.in" > "$TMP/w12p1y.out"; gin '‹readall›⊐' < "$TMP/w12p1y.in" > "$TMP/w12p1z.out"
cmp -s "$TMP/w12p1y.in" "$TMP/w12p1y.out" && cmp -s "$TMP/w12p1y.in" "$TMP/w12p1z.out" \
  && [ "$(gin '‹readbytes›⊃"≢Ṅ␤∑Ṅ' < "$TMP/big.in")" = "$(python3 -c 'd=open("'"$TMP"'/big.in","rb").read(); print(len(d)); print(sum(d))')" ] \
  && ok "‹readbytes›🗲 and ‹readall›⊐ copy 76800 bytes of every value 0-255 exactly; ‹readbytes›⊃ of the 1 MB input: length and byte sum" \
  || no "readbytes binary / big"
[ "$(printf 'abc' | gin '‹heapstats›_→n‹readbytes›⌫‹heapstats›_←n-Ṅ')" = "0" ] \
  && ok "‹readbytes› is an ordinary A block: ⌫ gives it back" || no "readbytes free"
# === W12-O1 ===
echo "W12-O1: ± ⊕ ⊖ ² ⊗ ⊘ on a list throw 'not a number' (catchable); on ints, and in bare programs, unchanged"
# The six templates test TOS's top byte (0x7F) and, only then, call the hook
# cell 5180864 the prelude fills with ‹_12o1_nan› (exact: tagged AND in the
# list heap).  w110 (W11-0, above) prints rc, the stdout byte count and stderr.
w12o1bad=""
for w12o1a in '±' '⊕' '⊖' '²' '⊗' '⊘'; do
  [ "$(w110 "7Ṅ5⍳$w12o1a⍕")" = "rc=1 1 GOLF: not a number" ] || w12o1bad="$w12o1bad [$w12o1a: $(w110 "7Ṅ5⍳$w12o1a⍕")]"
  [ "$(w110 "0⍳$w12o1a")" = "rc=1 0 GOLF: not a number" ] || w12o1bad="$w12o1bad [empty $w12o1a]"
  [ "$(printf '%s' ":‹f›3⍳$w12o1a;1 2′‹f›‹catch›⊐␤Ṅ␤Ṅ" | gc)" = "$(printf 'not a number\n2\n1')" ] || w12o1bad="$w12o1bad [catch $w12o1a]"
  [ "$(printf '%s' "7Ṅ5⍳$w12o1a⍕" | gref; echo " rc=$?")" = "7 rc=1" ] || w12o1bad="$w12o1bad [oracle $w12o1a]"
done
[ -z "$w12o1bad" ] && ok "each of ± ⊕ ⊖ ² ⊗ ⊘ on a list (empty too): GOLF: not a number on fd 2, exit 1, earlier output flushed; ′f‹catch› gets the message with the stack restored; the oracle agrees" \
  || no "W12-O1 atoms on lists:$w12o1bad"
[ "$(printf '%s' '2⍳′⍳€′⊕€⍕' | gc 2>&1)" = "GOLF: not a number" ] && [ "$(printf '%s' '3⍳"⌫⊖' | gc 2>&1)" = "GOLF: not a number" ] \
  && [ "$(printf '%s' '3⍳′⊕€⍕␤3⍳′²€⍕␤3⍳′±€⍕' | gc)" = "$(printf '1 2 3 \n0 1 4 \n0 -1 -2 ')" ] \
  && ok "an inner list (′⊕€ over a list of lists) and a freed list throw too; ′⊕ ′² ′± over a list of ints map as before" || no "W12-O1 inner/freed/map"
# Ints, edge values included: INT64_MAX and every int in [0x7F<<56, 2^63)
# reach the hook (top byte 0x7F) and must come back untouched, as must the old
# M-TAG band [2^48, 2^49), INT64_MIN, -1 and a tag-band int pointing below the
# heap.  Expected values from Python's 64-bit wrap; ⊘ is a LOGICAL shift.
python3 - "$TMP" <<'PYEOF'
import sys
T = sys.argv[1]
vals = [("9223372036854775807", 2**63 - 1), ("9223372036854775806", 2**63 - 2), ("1 63≪", -2**63),
        ("281474976710661", 2**48 + 5), ("562949953421311", 2**49 - 1), ("32767 48≪ 4096|", (32767 << 48) | 4096),
        ("35747322042253312", 0x7F << 48), ("1 63≪±⊖", 2**63 - 1), ("0", 0), ("7", 7), ("1\\neg", -1)]
ops = {"±": lambda v: -v, "⊕": lambda v: v + 1, "⊖": lambda v: v - 1, "²": lambda v: v * v,
       "⊗": lambda v: v * 2, "⊘": lambda v: (v % 2**64) >> 1}
# The raw spellings of the same six, for the bare (no-prelude) program, which cannot print.
raw = {"±": "~1﹢", "⊕": " 1﹢", "⊖": " 1﹣", "²": "\"﹡", "⊗": "\"﹢", "⊘": " 1>"}
s = lambda v: (v + 2**63) % 2**64 - 2**63
prog, want, bare = [], [], []
for src, v in vals:
    for g, f in ops.items():
        prog.append(f"{src}{g}Ṅ␤"); want.append(str(s(f(v))))
        bare.append(f"{src}{g} {src}{raw[g]}≡1+[89)]")
open(f"{T}/o1.prog", "w", encoding="utf-8").write("".join(prog))
open(f"{T}/o1.want", "w").write("\n".join(want) + "\n")
open(f"{T}/o1.bare", "w", encoding="utf-8").write("".join(bare))
open(f"{T}/o1.n", "w").write(str(len(bare)))
PYEOF
[ "$(gc < "$TMP/o1.prog")" = "$(cat "$TMP/o1.want")" ] && [ "$(gref < "$TMP/o1.prog")" = "$(cat "$TMP/o1.want")" ] \
  && ok "on $(cat "$TMP/o1.n") int cases (INT64_MAX/MIN, MAX-1, the old [2^48,2^49) band, 0x7F<<48, a tag-band int below the heap, -1 0 7) the six give Python's 64-bit result, golf2 and oracle" \
  || no "W12-O1 ints: $(diff <(gc < "$TMP/o1.prog") "$TMP/o1.want" | head -5 | tr '\n' ' ')"
w12o1y=$(printf '%*s' "$(cat "$TMP/o1.n")" '' | tr ' ' Y)
mkdir -p "$TMP/o1"; cp "$TMP/o1.bare" "$TMP/o1/b.golfj"
(cd "$TMP/o1" && "$EXP/tools/golfc" -n -j b.golfj b > /dev/null 2>&1 && ./b > b.out 2>&1; echo $? > b.rc)
[ "$(cat "$TMP/o1/b.out")" = "$w12o1y" ] && [ "$(cat "$TMP/o1/b.rc")" = 0 ] \
  && [ "$(cd "$TMP/o1" && "$EXP/tools/golfc" -j b.golfj p > /dev/null 2>&1 && ./p)" = "$w12o1y" ] \
  && ok "golfc -n (no prelude, the hook cell stays 0): each atom equals its raw spelling on all $(cat "$TMP/o1.n") cases; with the prelude too" \
  || no "W12-O1 bare: $(cat "$TMP/o1/b.out") rc=$(cat "$TMP/o1/b.rc")"
w12o1t=$(python3 -c 'import sys; sys.path.insert(0,"tools"); import mkblob2 as m
print(all(m.OVERRIDES[b][:7] == [0x80,0x7C,0x24,0x07,0x7F,0x75,15] and m.OVERRIDES[b][22:] == m._ATOM_TPL[b] for b in m.NUMCHK_BYTES),
      m.NAN_HOOK == 5180864, all(b not in m.OVERRIDES for b in (0x7E,0x24,0x7C,0x3D,0x3E,0xA2,0xA3,0x91,0x92,0x93)))')
[ "$w12o1t" = "True True True" ] && grep -q '^:‹_12o1_init›\\ref‹_12o1_nan›5180864\\store;$' lib/prelude.golfj \
  && ok "templates: cmp byte [rsp+7],0x7F; jne over the 15-byte hook call; then the atom byte for byte; hook cell 5180864 (slot O1); ~ \$ | = > ≪ ≫ and the raw atoms stay unchecked" \
  || no "W12-O1 template shape: $w12o1t"
w12o1bad=""; w12o1n=0
while IFS= read -r w12o1l; do
  w12o1p=${w12o1l%%  ->*}; w12o1p=${w12o1p%"${w12o1p##*[! ]}"}; w12o1w=${w12o1l##*->  }; w12o1n=$((w12o1n+1))
  [ "$(printf '%s' "$w12o1p" | gc 2>&1 | sed 's/ *$//')" = "$w12o1w" ] || w12o1bad="$w12o1bad [$w12o1p]"
done < <(sed -n '/^The unary arithmetic atoms/,/^### Atoms$/p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w12o1bad" ] && [ "$w12o1n" -ge 4 ] && ok "REFERENCE.md §2's atoms-on-lists examples print what they say" || no "REFERENCE W12-O1 examples:$w12o1bad"
# === W12-Z3 ===
echo "W12-Z3: one-letter locals a–z inside a ⊡ word (M-FRAME2's slot table, still ≤ 16)"
# Inside ⊡ any lowercase letter takes the next slot at its first appearance,
# exactly as a..h and ‹long› names did; outside ⊡ only M-FRAME's fixed a..h
# slots exist, so ⇒q there is refused as before.
w12z3e(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) > "$TMP/z3.src"
          "$TMP/golf2" < "$TMP/z3.src" > /dev/null 2>"$TMP/z3.err"; w12z3g=$?
          python3 boot/golfref.py < "$TMP/z3.src" > /dev/null 2>"$TMP/z3.rerr"; w12z3r=$?
          echo "$w12z3g $w12z3r $(cat "$TMP/z3.err") | $(cat "$TMP/z3.rerr")"; }
w12z3p='⊡‹t›⇒r⇐r[0^]⇐r⇒s⇐s2*⇒a⇐a⇒‹acc›⇐r1-‹t›⇒z⇐z⇐‹acc›+⇐s-;20000‹t›Ṅ'
[ "$(printf '%s' "$w12z3p" | gc)" = "200010000" ] && [ "$(printf '%s' "$w12z3p" | gref)" = "200010000" ] \
  && ok "⇒r ⇒s ⇒z mixed with a and ‹acc›, 20,000 deep: each call keeps its own (golf2 and the oracle)" \
  || no "i–z locals in recursion: $(printf '%s' "$w12z3p" | gc)"
w94dbin "${w12z3p%%;*};"
[ "$(w94dhas 4881ed28000000)" = 1 ] && [ "$(w94dhas 4881c528000000)" = 2 ] \
  && ok "five locals r s a ‹acc› z: sub rbp,40 once, add rbp,40 at the ^ and at ;" \
  || no "i–z frame size: sub×$(w94dhas 4881ed28000000) add×$(w94dhas 4881c528000000)"
w94dbin '⊡f⇒z⇒a⇐a⇐z-;'
[ "$(w94dhas 5848894500)" = 1 ] && [ "$(w94dhas 5848894508)" = 1 ] && [ "$(printf '%s' '⊡f⇒z⇒a⇐a⇐z-;5 3fṄ' | gc)" = "2" ] \
  && ok "slots go by first appearance, not by letter: ⇒z is [rbp+0], ⇒a [rbp+8]" || no "z/a slot order"
w12z3k='⇒k⇒l⇒m⇒n⇒o⇒p⇒q⇒r⇒s⇒t⇒u⇒v⇒w⇒x⇒y⇒z'
[ "$(printf '%s' "⊡f$w12z3k⇐k⇐z-⇐q+;1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16fṄ" | gc)" = "25" ] \
  && ok "all 16 slots as one-letter locals k…z (⇐k⇐z-⇐q+ = 16-1+10)" || no "16 one-letter locals"
[ "$(printf '%s' "⊡f$w12z3k⇐k⇒j;" | w12z3e)" = "2 2 GOLF: too many locals j at line 1 | GOLF: too many locals j at line 1" ] \
  && ok "the 17th distinct one-letter name is GOLF: too many locals j, exit 2 (both)" || no "17th one-letter local: $(printf '%s' "⊡f$w12z3k⇐k⇒j;" | w12z3e)"
[ "$(printf '%s' "⊡f⇒a⇒b⇒c⇒d⇒e⇒f⇒g⇒h⇒i⇒‹v1›⇒‹v2›⇒‹v3›⇒‹v4›⇒‹v5›⇒‹v6›⇒‹v7›⇒‹v8›;" | w12z3e)" = "2 2 GOLF: too many locals ‹v8› at line 1 | GOLF: too many locals ‹v8› at line 1" ] \
  && ok "the cap counts one-letter and long names together: a…i + 7 long = 16, the 8th long is the 17th" || no "mixed 17th local"
[ "$(printf '%s' ':g⇒q;' | w12z3e)" = "2 2 GOLF: local out of range q at line 1 | GOLF: local out of range q at line 1" ] \
  && [ "$(printf '%s' ':g1⇐z;' | w12z3e)" = "2 2 GOLF: local out of range z at line 1 | GOLF: local out of range z at line 1" ] \
  && [ "$(printf '%s' '5⇒i' | w12z3e)" = "2 2 GOLF: local out of range i at line 1 | GOLF: local out of range i at line 1" ] \
  && ok "outside a ⊡ word ⇒q / ⇐z / top-level ⇒i are still local out of range (both)" || no "i–z outside ⊡: $(printf '%s' ':g⇒q;' | w12z3e)"
[ "$(printf '%s' '⊡f⇒A;' | w12z3e)" = "2 2 GOLF: local out of range A at line 1 | GOLF: local out of range A at line 1" ] \
  && [ "$(printf '%s' '⊡f⇒{;' | w12z3e)" = "2 2 GOLF: local out of range { at line 1 | GOLF: local out of range { at line 1" ] \
  && ok "inside ⊡ a one-letter local must still be lowercase: ⇒A and ⇒{ (just past z) are refused" || no "non-lowercase local in ⊡"
w94dbin '⊡f⇒h⇒a⇐h⇐a-;'
[ "$(w94dhas 5848894500)" = 1 ] && [ "$(w94dhas 5848894508)" = 1 ] && [ "$(w94dhas 4881ed10000000)" = 1 ] \
  && [ "$(printf '%s' '⊡f⇒h⇒a⇐h⇐a-;5 3fṄ' | gc)" = "-2" ] \
  && [ "$(printf '%s' ':g⇒a⇒h;' | w12z3e)" = "0 0  | " ] \
  && ok "a–h unchanged: same slots and frame inside ⊡, and outside ⊡ ⇒a…⇒h still compile" || no "a–h behaviour"
# === W12-P2 ===
echo "W12-P2: dicts that hash once — ‹getor› ‹bump› ‹upd›, the int-key probe, growth"
# One ‹_2b_find› per call.  An int key has its own hash (8 consecutive ints
# share a group of index slots) and is compared raw with ≡; a list key keeps
# ‹hash› and ≣.  ‹hash›'s own values are pinned by the W11-2B block above.
w12p2a='‹dict›"1 10‹put›_"1 0‹getor›Ṅ32)"2 7‹getor›Ṅ32)"“ab“⊃5‹put›_"“ab“⊃0‹getor›Ṅ32)"3⍳′⍳€9‹getor›Ṅ32)"1‹del›_"1 8‹getor›Ṅ32)‹keys›≢Ṅ'
[ "$(printf '%s' "$w12p2a" | gc)" = "10 7 5 9 8 1" ] \
  && ok "‹getor›: present / missing int keys, a list key, a missing nested key, after ‹del›; nothing is inserted" || no "w12-p2 getor"
w12p2b='‹dict›"5‹bump›_"5‹bump›_"6‹bump›_"5‹get›Ṅ32)"6‹get›Ṅ32)"5‹del›_"5‹bump›_"5‹get›Ṅ32)"‹keys›⍕"‹vals›⍕'
[ "$(printf '%s' "$w12p2b" | gc)" = "2 1 1 6 5 1 1 " ] \
  && ok "‹bump›: a missing key starts at 1, a present one counts up; after ‹del› it restarts at 1 and goes last" || no "w12-p2 bump"
[ "$(printf '%s' '‹dict›"“ab“⊃‹bump›_"“ab“⊃‹bump›_"3⍳′⍳€‹bump›_"3⍳′⍳€‹bump›_"3⍳′⍳€‹bump›_"1⍳5+‹bump›_"5‹bump›_"0⍳‹bump›_"“ab“⊃‹get›Ṅ"3⍳′⍳€‹get›Ṅ"1⍳5+‹get›Ṅ"5‹get›Ṅ"0⍳‹get›Ṅ‹keys›⍕' | gc)" = "23111[97 98] [[] [0] [0 1]] [5] 5 [] " ] \
  && ok "‹bump› on list keys: code lists made apart, a nested key, [5] vs 5, the empty list" || no "w12-p2 bump list keys"
# Int keys of every shape: negative, >= 2^62, and 0 after a ‹del› (the deleted
# entry's key becomes the tagged null, so the raw ≡ can never match it).
[ "$(printf '%s' '‹dict›"0 1-‹bump›_"0 1-‹bump›_"1 62≪‹bump›_"0‹bump›_"0‹del›_"0 1-‹get›Ṅ"1 62≪‹get›Ṅ"0‹has›Ṅ"0 4‹getor›Ṅ‹keys›≢Ṅ' | gc)" = "21142" ] \
  && ok "int keys: -1, 2^62, and a deleted 0 is not found by the int probe" || no "w12-p2 int keys"
w12p2u='‹dict›"4′⊕‹upd›_"4′⊕‹upd›_"4‹get›Ṅ32)"9′⊗‹upd›_"9‹has›Ṅ"9‹get›Ṅ32)"3⍳′⍳€′⊕‹upd›_"3⍳′⍳€′⊕‹upd›_"3⍳′⍳€‹get›Ṅ32)"4‹del›_"4′⊕‹upd›_"‹keys›⍕‹vals›⍕'
[ "$(printf '%s' "$w12p2u" | gc)" = "2 00 2 9 [[] [0] [0 1]] 4 0 2 1 " ] \
  && ok "‹upd›: a missing key gets 0 first, then f; present keys, a nested list key, after ‹del›" || no "w12-p2 upd"
# f runs with the caller's stack under v, and may use the dict itself: bump
# another key (the entry stays put: written in place), grow the table past
# several doublings (the entry moved: a second probe stores it), or delete
# k (stored again).  An f that throws leaves k at 0 and unwinds to ‹catch›.
[ "$(printf '%s' ':f&+;‹dict›→d 7←d 3′f‹upd›_←d 3′f‹upd›_←d 3‹get›ṄṄ' | gc)" = "147" ] \
  && [ "$(printf '%s' ':g←d 1‹bump›_10+;‹dict›→d ←d 2′g‹upd›_←d 2′g‹upd›_←d‹keys›⍕←d‹vals›⍕' | gc)" = "2 1 20 2 " ] \
  && ok "‹upd› threads the caller's stack to f; f may ‹bump› the same dict" || no "w12-p2 upd threading"
w12p2g=':h0→i{←d←i1000+‹bump›_←i⊕"→i100≡}5+;‹dict›→d ←d 7′h‹upd›_←d 7‹get›Ṅ32)←d‹keys›≢Ṅ32)←d1⊇Ṅ32)←d‹keys›0⊇Ṅ'
[ "$(printf '%s' "$w12p2g" | gc)" = "5 101 256 7" ] \
  && [ "$(printf '%s' ':q←d 7‹del›_1+;‹dict›→d ←d 7 5‹put›_←d 7′q‹upd›_←d 7‹get›Ṅ←d‹keys›≢Ṅ' | gc)" = "61" ] \
  && [ "$(printf '%s' ':t“boom“⊃‹throw›;:u←d 3′t‹upd›;‹dict›→d ′u‹catch›⊐32)←d 3‹get›Ṅ' | gc)" = "boom 0" ] \
  && ok "‹upd›: f that grows the table (8 -> 256) or deletes k still lands; a throwing f is caught" || no "w12-p2 upd reentry"
# Growth: 100,000 keys on a power-of-two stride (the shape a plain
# multiplicative hash piles up on), bumped twice each: cap 8 doubles to
# 65536, then quadruples to 262144; keys stay in order.
w12p2s='‹dict›→‹d›0→‹i›{←‹d›←‹i›65536*‹bump›_←‹i›⊕"→‹i›100000≡}0→‹i›{←‹d›←‹i›65536*‹bump›_←‹i›⊕"→‹i›100000≡}←‹d›‹vals›∑Ṅ32)←‹d›‹keys›≢Ṅ32)←‹d›‹keys›100000⍳65536*≣Ṅ32)←‹d›1⊇Ṅ'
printf '%s' "$w12p2s" | gc > /dev/null; cp "$TMP/p" "$TMP/w12p2s"
w12p2t0=$(date +%s%N); w12p2so=$("$TMP/w12p2s"); w12p2t1=$(date +%s%N); w12p2ms=$(( (w12p2t1 - w12p2t0) / 1000000 ))
[ "$w12p2so" = "200000 100000 -1 262144" ] && [ "$w12p2ms" -lt 1000 ] \
  && ok "growth: 100k stride-65536 keys bumped twice, cap 262144, order and counts intact, ${w12p2ms} ms (< 1000)" || no "w12-p2 growth ($w12p2so, ${w12p2ms} ms)"
# A million ‹bump›s (500,000 distinct keys): about 0.1 s here, the bound is
# generous for slow machines.
printf '%s' ':f2/←d\\‹bump›_0;‹dict›→d 1000000⍳′f€_ ←d‹keys›≢Ṅ32)←d‹vals›∑Ṅ' | gc > /dev/null; cp "$TMP/p" "$TMP/w12p2m"
w12p2t0=$(date +%s%N); w12p2mo=$("$TMP/w12p2m"); w12p2t1=$(date +%s%N); w12p2ms=$(( (w12p2t1 - w12p2t0) / 1000000 ))
[ "$w12p2mo" = "500000 1000000" ] && [ "$w12p2ms" -lt 1000 ] \
  && ok "1M ‹bump› (500k distinct): right counts, ${w12p2ms} ms (< 1000)" || no "w12-p2 1M bump ($w12p2mo, ${w12p2ms} ms)"
# The word count again, with ‹bump›: the same output as W11-2B's.
printf '%s' ':‹tally›←‹d›\\‹bump›;:‹show›→‹k›←‹d›←‹k›‹get›Ṅ“ “🗲←‹k›⊐␤0;‹dict›→‹d›‹readall›‹words›′‹tally›€_←‹d›‹keys›′‹show›€_' | gc > /dev/null
"$TMP/p" < "$TMP/w112b.in" > "$TMP/w12p2wc.got"
[ -s "$TMP/w12p2wc.got" ] && cmp -s "$TMP/w12p2wc.got" <("$TMP/w112bwc" < "$TMP/w112b.in") \
  && ok "word count with ‹bump› prints exactly what the W11-2B has/get/put version does" || no "w12-p2 word count"
# The oracle runs the new words identically.
w12p2bad=""
for w12p2p in "$w12p2a" "$w12p2b" "$w12p2u" "$w12p2g"; do
  [ "$(printf '%s' "$w12p2p" | gref)" = "$(printf '%s' "$w12p2p" | gc)" ] || w12p2bad="$w12p2bad [$w12p2p]"
done
[ -z "$w12p2bad" ] && ok "oracle: boot/golfref.py runs ‹getor› ‹bump› ‹upd› (and a grow inside f) identically" || no "w12-p2 oracle:$w12p2bad"
# REFERENCE.md's examples of the three words print what they say, golf2 and
# oracle (the W11-2B block checks the whole section on golf2 too).
w12p2bad=""; w12p2n=0
while IFS= read -r w12p2l; do
  w12p2p=${w12p2l%%  ->*}; w12p2p=${w12p2p%"${w12p2p##*[! ]}"}; w12p2w=${w12p2l##*->  }
  w12p2n=$((w12p2n+1))
  [ "$(printf '%s' "$w12p2p" | gc | sed 's/ *$//')" = "$w12p2w" ] || w12p2bad="$w12p2bad [$w12p2p]"
  [ "$(printf '%s' "$w12p2p" | gref | sed 's/ *$//')" = "$w12p2w" ] || w12p2bad="$w12p2bad oracle[$w12p2p]"
done < <(sed -n '/^### Dicts and sets$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ' | grep -- '‹getor›\|‹bump›\|‹upd›')
[ -z "$w12p2bad" ] && [ "$w12p2n" -ge 6 ] \
  && ok "REFERENCE.md's ‹getor› ‹bump› ‹upd› examples ($w12p2n) print what they say, golf2 and oracle" || no "REFERENCE W12-P2 examples:$w12p2bad"

# === W12-Z4 ===
echo "W12-Z4: ⍈ store-at, the growable vector (⍆ ⍅ ‹vec› ‹last› ‹first›) and the deque (‹deque› ‹pushf› ‹popf›)"
# ⍈ is ⊇'s twin; a vector is a list whose spare capacity (A's header cell)
# ⍆ fills before it doubles into a new block; a deque is a ring in one block
# tagged 0x7FFD.  w110 (W11-0, above) prints rc, the stdout byte count and stderr.
[ "$(printf '%s' '5⍳2 9⍈⍕␤5⍳"2 9⍈≡Ṅ␤5⍳→l ←l4 0 9-⍈_ ←l∑Ṅ␤3⍳′⍳€1 5⍳⍈⍕␤5⍳0 7⍈4 8⍈⍕' | gc)" \
    = "$(printf '0 1 9 3 4 \n-1\n-3\n[] [0 1 2 3 4] [0 1] \n7 1 2 3 8 ')" ] \
  && ok "⍈ stores in place and leaves the same l (≡ -1), negative values and list values too" || no "⍈ basics: $(printf '%s' '5⍳2 9⍈⍕' | gc)"
w12z4bad=""
for w12z4a in '5⍳5 9⍈' '5⍳0 1-9⍈' '0⍳0 9⍈' '5⍳9 1 63≪|9⍈' '‹vec›‹last›' '‹vec›‹first›' '‹deque›‹first›' '‹deque›‹last›'; do
  [ "$(w110 "$w12z4a")" = "rc=1 0 GOLF: index out of range" ] || w12z4bad="$w12z4bad [$w12z4a: $(w110 "$w12z4a")]"
done
[ "$(w110 '7Ṅ‹vec›⍅')" = "rc=1 1 GOLF: pop from empty" ] || w12z4bad="$w12z4bad [vec pop]"
[ "$(w110 '‹vec›1⍆⍅_⍅')" = "rc=1 0 GOLF: pop from empty" ] || w12z4bad="$w12z4bad [vec pop 2]"
[ "$(w110 '‹deque›⍅')" = "rc=1 0 GOLF: pop from empty" ] || w12z4bad="$w12z4bad [deque pop]"
[ "$(w110 '‹deque›1‹pushf›‹popf›_‹popf›')" = "rc=1 0 GOLF: pop from empty" ] || w12z4bad="$w12z4bad [deque popf]"
[ "$(w110 '5⍳1‹pushf›')" = "rc=1 0 GOLF: not a deque" ] && [ "$(w110 '‹vec›‹popf›')" = "rc=1 0 GOLF: not a deque" ] || w12z4bad="$w12z4bad [not a deque]"
[ -z "$w12z4bad" ] && ok "errors through ‹throw›: index out of range (⍈ past the end, negative, on empty; ‹first›/‹last› of an empty vector or deque), pop from empty (both ends), not a deque; earlier output flushed" \
  || no "W12-Z4 errors:$w12z4bad"
w12z4bad=""
for w12z4a in '0 9⍈' '1⍆' '⍅' '‹first›' '‹last›'; do
  [ "$(w110 "5⍳\"⌫$w12z4a")" = "rc=1 0 GOLF: use after free" ] || w12z4bad="$w12z4bad [list $w12z4a]"
  [ "$(w110 "300⍳\"⌫$w12z4a")" = "rc=1 0 GOLF: use after free" ] || w12z4bad="$w12z4bad [class-7 list $w12z4a]"
done
for w12z4a in '1⍆' '⍅' '1‹pushf›' '‹popf›' '‹first›' '‹last›' '≢'; do
  [ "$(w110 "‹deque›1⍆\"⌫$w12z4a")" = "rc=1 0 GOLF: use after free" ] || w12z4bad="$w12z4bad [deque $w12z4a]"
done
[ "$(w110 '‹vec›→v←v1⍆2⍆3⍆_←v≢Ṅ←v4⍆_←v≢')" = "rc=1 1 GOLF: use after free" ] && [ "$(w110 '‹vec›→v←v1⍆2⍆3⍆4⍆_←v≢')" = "rc=1 0 GOLF: use after free" ] || w12z4bad="$w12z4bad [stale after growth]"
[ "$(w110 '‹vec›→v←v1⍆2⍆3⍆4⍆_ ←v⌫')" = "rc=1 0 GOLF: double free" ] || w12z4bad="$w12z4bad [stale ⌫]"
[ -z "$w12z4bad" ] && ok "use after free: ⍈ ⍆ ⍅ ‹first› ‹last› on a freed list (small and class 7), every deque word on a freed deque, and the value a growth left behind (⌫ of it: double free)" \
  || no "W12-Z4 use after free:$w12z4bad"
[ "$(printf '%s' ':‹f›‹vec›⍅;1 2′‹f›‹catch›⊐␤Ṅ␤Ṅ␤:‹g›5⍳7 0⍈;′‹g›‹catch›⊐␤:‹h›‹deque›‹popf›;′‹h›‹catch›⊐' | gc)" \
    = "$(printf 'pop from empty\n2\n1\nindex out of range\npop from empty')" ] \
  && ok "′f‹catch› gets pop from empty / index out of range, with the caller's stack restored" || no "W12-Z4 catch"
# Capacity: ‹vec› is A(1) = class 4, (4+1)*8 = 40 bytes; each growth doubles
# the block (past 256 cells class 7 gives exactly the request) and gives the
# old one back, so the live block count stays +1 and the bytes are (cap+1)*8.
python3 - "$TMP" <<'PYEOF'
import sys
T = sys.argv[1]
marks = [0, 3, 4, 7, 8, 15, 16, 100, 255, 256, 511, 512, 1023, 1024, 5000]
prog = [":‹p›←‹v›\\\\⍆→‹v›0;‹heapstats›→b→n‹vec›→‹v›"]
want, done, model = [], 0, []
for m in marks:
    if m > done:
        prog.append(f"{m - done}⍳\"′‹p›€⌫⌫")
        model += range(m - done)
        done = m
    prog.append("‹heapstats›←b-Ṅ“ “🗲←n-Ṅ“ “🗲←‹v›≢Ṅ“ “🗲←‹v›∑Ṅ␤")
    cap = 4
    while m + 1 > cap:
        cap *= 2
    want.append(f"{(cap + 1) * 8} 1 {m} {sum(model)}")
prog.append("←‹v›⌫‹heapstats›←b-Ṅ“ “🗲←n-Ṅ␤")
want.append("0 0")
open(f"{T}/z4cap.prog", "w", encoding="utf-8").write("".join(prog))
open(f"{T}/z4cap.want", "w").write("\n".join(want) + "\n")
PYEOF
[ "$(gc < "$TMP/z4cap.prog")" = "$(cat "$TMP/z4cap.want")" ] \
  && ok "‹heapstats› through 11 doublings (3 → 8191 elements): one live block of (cap+1)*8 bytes, ≢ and ∑ right at every step; ⌫ of the grown vector gives back exactly that block" \
  || no "W12-Z4 capacity: $(diff <(gc < "$TMP/z4cap.prog") "$TMP/z4cap.want" | head -4 | tr '\n' ' ')"
[ "$(printf '%s' '5⍳→l ←l7⍆_ ←l≢Ṅ␤←l8⍆_ ←l"≢Ṅ⍕␤←l9⍆≡Ṅ␤3‹vecn›→v‹heapstats›_→n←v1⍆2⍆3⍆_‹heapstats›_←n-Ṅ' | gc)" \
    = "$(printf '6\n70 1 2 3 4 7 8 \n0\n0')" ] \
  && ok "⍆ on a ⍳ list appends in place into its spare room (5⍳ holds 7, so the 8th push moves it: ≡ 0); 3‹vecn› takes 3 pushes without a growth" || no "W12-Z4 in-place / vecn"
# Random workloads against a Python model, through golf2 AND the oracle: a
# vector (⍆ ⍅ ⍈ ⊇ ‹first› ‹last› ≢ ∑) and a deque (both ends, peeks, ≢),
# with push-heavy and pop-heavy phases so the deque's ring wraps and doubles
# several times.
python3 - "$TMP" <<'PYEOF'
import random, sys
from collections import deque
T = sys.argv[1]
r = random.Random(1204)
p, w, v = ["‹vec›→v"], [], []
for step in range(900):
    bias = 0.8 if (step // 150) % 2 == 0 else 0.3
    x = r.randrange(0, 10**6)
    op = r.random()
    if op < bias or not v:
        p.append(f"←v{x}⍆→v"); v.append(x)
    else:
        k = r.randrange(6)
        if k == 0:
            p.append("←v⍅Ṅ␤_"); w.append(v.pop())
        elif k == 1:
            i = r.randrange(len(v)); p.append(f"←v{i} {x}⍈_"); v[i] = x
        elif k == 2:
            i = r.randrange(len(v)); p.append(f"←v{i}⊇Ṅ␤"); w.append(v[i])
        elif k == 3:
            p.append("←v‹first›Ṅ␤←v‹last›Ṅ␤"); w += [v[0], v[-1]]
        else:
            p.append("←v≢Ṅ␤←v∑Ṅ␤"); w += [len(v), sum(v)]
open(f"{T}/z4vec.prog", "w", encoding="utf-8").write("".join(p))
open(f"{T}/z4vec.want", "w").write("".join(f"{a}\n" for a in w))
p, w, d = ["‹deque›→d"], [], deque()
for step in range(1500):
    bias = 0.75 if (step // 250) % 2 == 0 else 0.35
    x = r.randrange(0, 10**6)
    if r.random() < bias or not d:
        if r.random() < 0.5:
            p.append(f"←d{x}⍆→d"); d.append(x)
        else:
            p.append(f"←d{x}‹pushf›→d"); d.appendleft(x)
    else:
        k = r.randrange(5)
        if k == 0:
            p.append("←d⍅Ṅ␤_"); w.append(d.pop())
        elif k == 1:
            p.append("←d‹popf›Ṅ␤_"); w.append(d.popleft())
        elif k == 2:
            p.append("←d‹first›Ṅ␤"); w.append(d[0])
        elif k == 3:
            p.append("←d‹last›Ṅ␤"); w.append(d[-1])
        else:
            p.append("←d≢Ṅ␤"); w.append(len(d))
p.append("←d≢Ṅ␤")
w.append(len(d))
open(f"{T}/z4deq.prog", "w", encoding="utf-8").write("".join(p))
open(f"{T}/z4deq.want", "w").write("".join(f"{a}\n" for a in w))
PYEOF
[ "$(gc < "$TMP/z4vec.prog")" = "$(cat "$TMP/z4vec.want")" ] && [ "$(gref < "$TMP/z4vec.prog")" = "$(cat "$TMP/z4vec.want")" ] \
  && ok "900 random vector ops (⍆ ⍅ ⍈ ⊇ ‹first› ‹last› ≢ ∑) match a Python list, golf2 and oracle" \
  || no "W12-Z4 vector model: $(diff <(gc < "$TMP/z4vec.prog") "$TMP/z4vec.want" | head -4 | tr '\n' ' ')"
[ "$(gc < "$TMP/z4deq.prog")" = "$(cat "$TMP/z4deq.want")" ] && [ "$(gref < "$TMP/z4deq.prog")" = "$(cat "$TMP/z4deq.want")" ] \
  && ok "1500 random deque ops at both ends (wrapping, growing) match collections.deque, golf2 and oracle" \
  || no "W12-Z4 deque model: $(diff <(gc < "$TMP/z4deq.prog") "$TMP/z4deq.want" | head -4 | tr '\n' ' ')"
[ "$(printf '%s' '‹heapstats›→b→n‹deque›→d 1000→i{←d←i‹pushf›→d←i⊖"→i0≡}‹heapstats›←b-Ṅ“ “🗲←n-Ṅ“ “🗲←d≢Ṅ“ “🗲←d‹first›Ṅ“ “🗲←d‹last›Ṅ␤←d⌫‹heapstats›←b-Ṅ“ “🗲←n-Ṅ␤‹deque›"T Ṅ"16≪16>"⊙Ṅ8﹢⊙Ṅ' | gc)" \
    = "$(printf '8200 1 1000 1 1000\n0 0\n100')" ] \
  && ok "a deque grown to 1000 by ‹pushf› is one live block (cap 1024: 8200 bytes) and ⌫ gives it back; T calls a deque an int; a new one is [n=0, h=0, …]" \
  || no "W12-Z4 deque heap: $(printf '%s' '‹heapstats›→b→n‹deque›→d 1000→i{←d←i‹pushf›→d←i⊖"→i0≡}‹heapstats›←b-Ṅ“ “🗲←n-Ṅ' | gc)"
[ "$(printf '%s' '⍈⍆⍅\putat\push\pop' | python3 tools/codepage.py encode | od -An -tx1 | tr -d ' \n')" = "d5d6d7d5d6d7" ] \
  && grep -qE '^\| `0xD5` \| `\\putat` \| `⍈` .*\| Z4 \| shipped \|$' REGISTRY.md \
  && grep -qE '^\| `0xD6` \| `\\push` \| `⍆` .*\| Z4 \| shipped \|$' REGISTRY.md \
  && grep -qE '^\| `0xD7` \| `\\pop` \| `⍅` .*\| Z4 \| shipped \|$' REGISTRY.md \
  && ok "⍈ ⍆ ⍅ and \\putat \\push \\pop encode to 0xD5–0xD7; REGISTRY §1.4 marks the three shipped" || no "W12-Z4 codepage / registry rows"
# The three LeetCode rewrites (bench/leetcode/golf) use the new words and no
# raw-memory stack any more; small inputs, answers from the Python solutions.
w12z4bad=""
mkdir -p "$TMP/z4lc"
for w12z4a in parens islands slidemax; do
  "$EXP/tools/golfc" -j "$EXP/bench/leetcode/golf/$w12z4a.golfj" "$TMP/z4lc/$w12z4a" > /dev/null 2>&1 || w12z4bad="$w12z4bad [compile $w12z4a]"
done
grep -q '⊛' bench/leetcode/golf/parens.golfj bench/leetcode/golf/islands.golfj bench/leetcode/golf/slidemax.golfj && w12z4bad="$w12z4bad [raw ⊛ left]"
grep -q '⍆' bench/leetcode/golf/parens.golfj && grep -q '⍈' bench/leetcode/golf/islands.golfj && grep -q '⊟' bench/leetcode/golf/slidemax.golfj || w12z4bad="$w12z4bad [new words missing]"
for w12z4a in '([]{})' '([)]' '((' '())' '}' '{[()()]}'; do
  [ "$(printf '%s\n' "$w12z4a" | "$TMP/z4lc/parens")" = "$(printf '%s\n' "$w12z4a" | python3 bench/leetcode/py/parens.py)" ] || w12z4bad="$w12z4bad [parens $w12z4a]"
done
for w12z4a in '11000 11000 00100 00011' '1 0 1' '111 101 111' '0000 0000' '10101 01010 10101'; do
  [ "$(printf '%s\n' $w12z4a | "$TMP/z4lc/islands")" = "$(printf '%s\n' $w12z4a | python3 bench/leetcode/py/islands.py)" ] || w12z4bad="$w12z4bad [islands $w12z4a]"
done
for w12z4a in '3 1 3 -1 -3 5 3 6 7' '1 4 2 9' '2 9 8 7 6 5' '4 1 2 3 4 5 6' '3 5 5 5 5'; do
  [ "$(printf '%s\n' "$w12z4a" | "$TMP/z4lc/slidemax" | sed 's/ *$//')" = "$(printf '%s\n' "$w12z4a" | python3 bench/leetcode/py/slidemax.py)" ] || w12z4bad="$w12z4bad [slidemax $w12z4a]"
done
[ -z "$w12z4bad" ] && ok "LeetCode parens (⍆ ⍅), islands (⍈ ⊇ ⍆ ⍅) and slidemax (deque, since W12-A5 one ⊟) lost their raw stacks and still answer like the Python solutions" \
  || no "W12-Z4 LeetCode rewrites:$w12z4bad"
w12z4bad=""; w12z4n=0
while IFS= read -r w12z4l; do
  w12z4p=${w12z4l%%  ->*}; w12z4p=${w12z4p%"${w12z4p##*[! ]}"}; w12z4w=${w12z4l##*->  }; w12z4n=$((w12z4n+1))
  [ "$(printf '%s' "$w12z4p" | gc 2>&1 | sed 's/ *$//')" = "$w12z4w" ] || w12z4bad="$w12z4bad [$w12z4p]"
  case "$w12z4w" in GOLF:*) ;; *) [ "$(printf '%s' "$w12z4p" | gref | sed 's/ *$//')" = "$w12z4w" ] || w12z4bad="$w12z4bad oracle[$w12z4p]";; esac
done < <(sed -n '/^### Vectors and deques$/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w12z4bad" ] && [ "$w12z4n" -ge 8 ] && ok "REFERENCE.md's Vectors and deques examples print what they say (golf2; the oracle too, but for the stderr ones)" \
  || no "REFERENCE W12-Z4 examples:$w12z4bad"

# === W12-P3 ===
echo "W12-P3: tight loops in ⍳ ∑ ∏ ⌽ € ⇤ ⌿ ⊞ and the elementwise + - * ⌈ ⌊"
# ⍳ ∑ ∏ run a one-at-a-time head loop until the rest is a multiple of four,
# then a four-wide body, so every length 0..9 takes a different split; the
# other words walk one pointer against an end.  Checked against Python.
w12p3a=""
for n in 0 1 2 3 4 5 6 7 8 9; do
  w12p3p=":f2∣;$n⍳⍕␤$n⍳∑Ṅ␤$n⍳1+∏Ṅ␤$n⍳⌽⍕␤$n⍳′²€⍕␤$n⍳7′+⇤Ṅ␤$n⍳′f⌿⍕␤$n⍳$n 2+⍳′*⊞⍕␤$n⍳\"+⍕␤$n⍳3-⍕␤10 $n⍳-⍕␤$n⍳4⍳+⍕␤$n⍳2⌈⍕␤$n⍳0 2-⌊⍕"
  w12p3w=$(python3 - "$n" <<'PY'
import sys, math
n = int(sys.argv[1]); l = list(range(n)); j = lambda v: " ".join(map(str, v))
print("\n".join([j(l), str(sum(l)), str(math.factorial(n)), j(l[::-1]), j(x*x for x in l),
                 str(7 + sum(l)), j(x for x in l if x % 2 == 0), j(x*x for x in l), j(2*x for x in l),
                 j(x-3 for x in l), j(10-x for x in l), j(2*x for x in l[:4]), j(max(x, 2) for x in l),
                 j(min(x, -2) for x in l)]))
PY
)
  [ "$(printf '%s' "$w12p3p" | gc | sed 's/ *$//')" = "$w12p3w" ] || w12p3a="$w12p3a $n"
done
[ -z "$w12p3a" ] && ok "lengths 0..9: ⍳ ∑ ∏ ⌽ € ⇤ ⌿ ⊞ and list+list, list-scalar, scalar-list, ⌈ ⌊ match Python" \
  || no "W12-P3 lengths:$w12p3a"
# Nesting: a map inside a map inside a map, ∑ of each inner list, and the
# elementwise ops on a list that mixes ints and lists (each int element takes
# the inline op, each list element recurses).
w12p3n=':m′²€;:s⍳′⍳€;:n′m€;:u′∑€;4⍳′⍳€′m€⍕␤4⍳′s€′n€⍕␤4⍳′s€′u€⍕␤4⍳′s€′u€′∑€⍕'
[ "$(printf '%s' "$w12p3n" | gc | sed 's/ *$//')" = "$(printf '[] [0] [0 1] [0 1 4]\n[] [[]] [[] [0]] [[] [0] [0 1]]\n[] [0] [0 0] [0 0 1]\n0 0 0 1')" ] \
  && [ "$(printf '%s' "$w12p3n" | gref)" = "$(printf '%s' "$w12p3n" | gc)" ] \
  && ok "map inside map inside map, ∑ inside two maps (golf2 and the oracle)" || no "W12-P3 nesting: $(printf '%s' "$w12p3n" | gc)"
w12p3m='3⍳2⍳′⍳€⧺"10+⍕␤"10\\-⍕␤""+⍕␤"∑⍕␤""*⍕␤"3⌈⍕␤"1⌊⍕␤∏⍕'
[ "$(printf '%s' "$w12p3m" | gc | sed 's/ *$//')" = "$(printf '10 11 12 [] [10]\n10 9 8 [] [10]\n0 2 4 [] [0]\n\n0 1 4 [] [0]\n3 3 3 [] [3]\n0 1 1 [] [0]\n')" ] \
  && ok "0 1 2 [] [0] with + - * ⌈ ⌊ ∑ ∏: ints inline, lists recurse, ∑ through a list accumulator" || no "W12-P3 mixed: $(printf '%s' "$w12p3m" | gc)"
# A throw from inside the user's function mid-loop is caught; the spill
# stack is back to 0 and the same word works again (its loop cells are
# re-initialised on entry).  Then a use-after-free met mid-loop inside the
# elementwise recursion and inside ∑'s accumulator +.
[ "$(w113 ':t"2≡1+[“two“⊃‹throw›];:g5⍳′t€;′g‹catch›⊐␤7⍳′²€⍕␤:h9⍳′g€;′h‹catch›⊐␤3⍳′⍳€′∑€⍕␤5177392@Ṅ')" \
    = "$(printf 'two\n0 1 4 9 16 25 36 \ntwo\n0 0 1 \n0 rc=0')" ] \
  && [ "$(w113 ':t"2≡1+[“two“⊃‹throw›]+;:g5⍳0′t⇤;′g‹catch›⊐␤7⍳0′+⇤Ṅ␤5177392@Ṅ')" = "$(printf 'two\n21\n0 rc=0')" ] \
  && [ "$(w113 ':t"2≡1+[“two“⊃‹throw›]2∣;:g5⍳′t⌿;′g‹catch›⊐␤:f2∣;7⍳′f⌿⍕␤5177392@Ṅ')" = "$(printf 'two\n0 2 4 6 \n0 rc=0')" ] \
  && [ "$(w113 ':t"2≡1+[“two“⊃‹throw›]+;:g5⍳5⍳′t⊞;′g‹catch›⊐␤7⍳5⍳′+⊞⍕␤5177392@Ṅ')" = "$(printf 'two\n0 2 4 6 8 \n0 rc=0')" ] \
  && ok "a throw from € (also nested in €), ⇤, ⌿, ⊞ mid-loop is caught, then the word runs again; spill stack back to 0" \
  || no "W12-P3 throw mid-loop"
[ "$(w113 ':g9⍳′⍳€"4⊇⌫"+;′g‹catch›⊐␤9⍳′⍳€"+⍕␤:h9⍳′⍳€"4⊇⌫∑;′h‹catch›⊐␤5⍳∑Ṅ␤5177392@Ṅ')" \
    = "$(printf 'use after free\n[] [0] [0 2] [0 2 4] [0 2 4 6] [0 2 4 6 8] [0 2 4 6 8 10] [0 2 4 6 8 10 12] [0 2 4 6 8 10 12 14] \nuse after free\n10\n0 rc=0')" ] \
  && ok "use after free met mid-loop inside + and inside ∑'s accumulator: caught, then + and ∑ work again" || no "W12-P3 uaf mid-loop"
# ⍳ ∑ ∏ ⌽ take no spill frame and never touch s0..s7: their state is the
# data stack plus slot P3's cells (REGISTRY §3.2), which nothing they call
# re-enters.  The elementwise path takes one frame per nesting level (it was
# two, D and Z/K/G), so + now goes 3000 deep, and past the 4096 frames it
# still stops with the W10-C message, catchable as W11-3A made it.
[ "$(printf '%s' '12345 5177440⊛ 9⍳∑_ 9⍳1+∏_ 9⍳⌽_ 9⍳"+_ 5177440⊙Ṅ' | gc)" = "12345" ] \
  && [ "$(sed -n '/^:[RSPV]/,/;$/p' lib/prelude.golfj | grep -oE '51[0-9]{5}' | sort -u | tr '\n' ' ')" = "5180800 5180808 5180816 " ] \
  && ok "⍳ ∑ ∏ ⌽ leave s0..s7 alone and name only P3's cells 5180800 5180808 5180816" || no "W12-P3 cells"
[ "$( { printf '%s' "$W10CW"; w10cn 3000 3; printf '"+⍤N E'; } | gc)" = "3001" ] \
  && ok "+ of a list nested 3000 deep with itself (one spill frame per level)" || no "W12-P3 + 3000 deep"
w12p3x=$( { printf '%s' "$W10CW"; w10cn 100000 3; printf '"+⍤N E'; } | cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/p" 2>/dev/null \
           && chmod +x "$TMP/p" && { "$TMP/p" > "$TMP/w12p3.out" 2>&1; echo "rc=$?"; } 2>/dev/null)
[ "$w12p3x" = "rc=1" ] && [ "$(cat "$TMP/w12p3.out")" = "GOLF: spill stack exhausted" ] \
  && [ "$( { printf '%s:‹d›"+⍤;' "$W10CW"; w10cn 100000 3; printf '′‹d›‹catch›⊐␤5⍳"+⍕'; } | gc)" = "$(printf 'spill stack exhausted\n0 2 4 6 8 ')" ] \
  && ok "+ 100,000 deep: GOLF: spill stack exhausted, exit 1; under ‹catch› the message, then + works" || no "W12-P3 + spill exhaustion: $w12p3x"

# === W12-A2 ===
echo "W12-A2: ⍀ inclusive scan and ⍁ seedless reduce"
# REFERENCE.md's examples for ⍀ ⍁ ⍸ (A2 and A3 share the section), on golf2
# and, for those that print on stdout, the oracle.
w12a2bad=""; w12a2n=0
while IFS= read -r w12a2l; do
  w12a2p=${w12a2l%%  ->*}; w12a2p=${w12a2p%"${w12a2p##*[! ]}"}; w12a2w=${w12a2l##*->  }
  w12a2n=$((w12a2n+1))
  [ "$(printf '%s' "$w12a2p" | gc 2>&1 | sed 's/ *$//')" = "$w12a2w" ] || w12a2bad="$w12a2bad [$w12a2p]"
  case "$w12a2w" in GOLF:*) ;; *) [ "$(printf '%s' "$w12a2p" | gref | sed 's/ *$//')" = "$w12a2w" ] || w12a2bad="$w12a2bad oracle[$w12a2p]";; esac
done < <(sed -n '/^### Scan, reduce and each-indexed/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w12a2bad" ] && [ "$w12a2n" -ge 15 ] \
  && ok "REFERENCE.md's ⍀ ⍁ ⍸ examples ($w12a2n) print what they say, golf2 and oracle" || no "W12-A2 REFERENCE examples:$w12a2bad"
# Every length 0..9 (and 100000), scan of + and of ⌈ over a shuffled list,
# reduce of + and ⌊, checked against Python.
w12a2a=""
for n in 0 1 2 3 4 5 6 7 8 9; do
  w12a2p=":g7*11∣3-;$n⍳′g€\"′+⍀⍕␤\"′⌈⍀⍕␤\"≢0≡[\"′+⍁Ṅ␤\"′⌊⍁Ṅ]␤_"
  w12a2w=$(python3 - "$n" <<'PY'
import sys, itertools
n = int(sys.argv[1]); l = [(x*7) % 11 - 3 for x in range(n)]; j = lambda v: " ".join(map(str, v))
out = [j(itertools.accumulate(l)), j(itertools.accumulate(l, max))]
if n: out += [str(sum(l)), str(min(l))]
print("\n".join(out + [""]))
PY
)
  [ "$(printf '%s' "$w12a2p" | gc | sed 's/ *$//')" = "$w12a2w" ] || w12a2a="$w12a2a $n"
done
[ -z "$w12a2a" ] && [ "$(printf '%s' '100000⍳"′+⍀"≢Ṅ␤99999⊇Ṅ␤"′+⍁Ṅ␤∑Ṅ' | gc)" = "$(printf '100000\n4999950000\n4999950000\n4999950000')" ] \
  && ok "lengths 0..9 and 100000: ⍀ (+, ⌈) and ⍁ (+, ⌊) match Python's accumulate / sum / min" || no "W12-A2 lengths:$w12a2a"
# A scan inside a scan's function inside a reduce's, a reduce inside a
# reduce's, and the input is never written; the result is a new tagged list,
# the empty one too.
[ "$(printf '%s' ':a⍳′+⍀∑;:b⍳′a€′+⍀∑+;:r⍳1+′*⍁+;6⍳′b⍀⍕␤4⍳1+′r⍁Ṅ␤5⍳"′+⍀_⍕␤5⍳′+⍀48>Ṅ␤0⍳′+⍀48>Ṅ␤3⍳′⍳€′⧺⍁⍤Ṅ' | gc)" \
    = "$(printf '0 0 0 1 7 28 \n33\n0 1 2 3 4 \n32767\n32767\n1')" ] \
  && [ "$(printf '%s' ':a⍳′+⍀∑;:b⍳′a€′+⍀∑+;6⍳′b⍀⍕' | gref)" = "0 0 0 1 7 28 " ] \
  && ok "⍀ inside ⍀ inside € inside ⍀, ⍁ inside ⍁ (and the oracle); input unchanged; results tagged" || no "W12-A2 nesting: $(printf '%s' ':a⍳′+⍀∑;:b⍳′a€′+⍀∑+;6⍳′b⍀⍕' | gc)"
# A throw from f mid-scan / mid-reduce is caught, the word runs again and the
# spill stack is back to 0; empty reduce is catchable; errors exit 1 with the
# output so far flushed.
[ "$(w113 ':t"2≡1+[“two“⊃‹throw›]+;:g5⍳′t⍀;′g‹catch›⊐␤7⍳′+⍀⍕␤:h5⍳′t⍁;′h‹catch›⊐␤7⍳′+⍁Ṅ␤:e0⍳′+⍁;′e‹catch›⊐␤:k3⍳′g€;′k‹catch›⊐␤5177392@Ṅ')" \
    = "$(printf 'two\n0 1 3 6 10 15 21 \ntwo\n21\nempty reduce\ntwo\n0 rc=0')" ] \
  && [ "$(w110 '7Ṅ0⍳′+⍁')" = "rc=1 1 GOLF: empty reduce" ] && [ "$(w110 '5⍳"⌫′+⍀')" = "rc=1 0 GOLF: use after free" ] \
  && [ "$(w110 '5⍳"⌫′+⍁')" = "rc=1 0 GOLF: use after free" ] \
  && ok "a throw mid-⍀ / mid-⍁ (also under €) is caught and the word works again; empty reduce, use after free" || no "W12-A2 errors: $(w110 '7Ṅ0⍳′+⍁')"
[ "$(sed -n '/^# === W12-A2 scan and reduce ===/,$p' lib/prelude.golfj | sed '1!{/^# === /,$d}' | grep -v '^#' | grep -oE '51[0-9]{5}' | sort -u | tr '\n' ' ')" = "5177440 5177448 5177456 5177464 5177472 " ] \
  && ok "⍀ ⍁ keep their state in s0..s4 under one spill frame (A2's slot 5180992… stays free)" || no "W12-A2 cells"

# === W12-A3 ===
echo "W12-A3: ⍸ each-indexed (f gets x i)"
w12a3a=""
for n in 0 1 2 3 4 5 6 7 8 9; do
  w12a3w=$(python3 -c "import sys; n=int(sys.argv[1]); print(' '.join(str((x+5)*i-(x+5)) for i,x in enumerate(range(n))))" "$n")
  [ "$(printf '%s' ":f&*\\\\-;$n⍳5+′f⍸⍕" | gc | sed 's/ *$//')" = "$w12a3w" ] || w12a3a="$w12a3a $n"
done
[ -z "$w12a3a" ] && [ "$(printf '%s' ':f\\_;100000⍳′f⍸"99999⊇Ṅ∑Ṅ' | gc)" = "999994999950000" ] \
  && ok "lengths 0..9 and 100000: ⍸ calls f with x i, i from 0 (f = x*i - x)" || no "W12-A3 lengths:$w12a3a"
# ⍸ inside €, € inside ⍸, ⍸ inside ⍸ (and the oracle); threading; tagged.
w12a3n=':h′+⍸;:m⍳′²€∑+;:q⍳′+⍸∑+;3⍳′⍳€′h€⍕␤4⍳′m⍸⍕␤5⍳′q⍸⍕␤5⍳′+⍸48>Ṅ␤0⍳′+⍸"48>Ṅ≢Ṅ'
[ "$(printf '%s' "$w12a3n" | gc | sed 's/ *$//')" = "$(printf '[] [0] [0 2]\n0 1 3 8\n0 1 4 9 16\n32767\n327670')" ] \
  && [ "$(printf '%s' "$w12a3n" | gref)" = "$(printf '%s' "$w12a3n" | gc)" ] \
  && ok "⍸ inside €, € inside ⍸, ⍸ inside ⍸ (golf2 and the oracle); results tagged, empty too" || no "W12-A3 nesting: $(printf '%s' "$w12a3n" | gc)"
[ "$(w113 ':t"2≡1+[“two“⊃‹throw›]+;:k5⍳′t⍸;′k‹catch›⊐␤4⍳′+⍸⍕␤:j3⍳′k€;′j‹catch›⊐␤5177392@Ṅ')" = "$(printf 'two\n0 2 4 6 \ntwo\n0 rc=0')" ] \
  && [ "$(w110 '5⍳"⌫′+⍸')" = "rc=1 0 GOLF: use after free" ] \
  && ok "a throw mid-⍸ (also under €) is caught and ⍸ works again; use after free" || no "W12-A3 errors"
[ "$(sed -n '/^# === W12-A3 each-indexed ===/,$p' lib/prelude.golfj | sed '1!{/^# === /,$d}' | grep -v '^#' | grep -oE '51[0-9]{5}' | sort -u | tr '\n' ' ')" = "5177440 5177448 5177456 5177464 5177472 5177488 " ] \
  && ok "⍸ keeps its state in s0..s4 and s6 under one spill frame (A3's slot 5181056… stays free)" || no "W12-A3 cells"
# === W12-A4 ===
echo "W12-A4: ⍒ sort by key and ‹grade› (the sorting permutation)"
# ⍒ is € for the keys, then ‹grade› of them, then a gather in place; ‹grade›
# is ⍋'s merge sort on indices, comparing K[a] >s K[b].  Checked against
# Python's sorted (stable) and the oracle.
w12a4p=':f7919*1000%;:g10%;:h500-;37⍳′f€"′g⍒⍕␤′h€"‹grade›⍕␤′±⍒⍕␤:q7%3-;12⍳′q⍒⍕'
w12a4w=$(python3 -c '
l=[i*7919%1000 for i in range(37)]; m=[x-500 for x in l]; j=lambda v:" ".join(map(str,v))
print(j(sorted(l,key=lambda x:x%10))); print(j(sorted(range(37),key=lambda i:m[i])))
print(j(sorted(m,key=lambda x:-x))); print(j(sorted(range(12),key=lambda i:i%7-3)))')
[ "$(printf '%s' "$w12a4p" | gc | sed 's/ *$//')" = "$w12a4w" ] \
  && [ "$(printf '%s' "$w12a4p" | gref)" = "$(printf '%s' "$w12a4p" | gc)" ] \
  && ok "⍒ is stable (keys with duplicates), descending by ′±, negative keys; ‹grade› gives the sorting permutation: Python's sorted, and the oracle agrees" \
  || no "W12-A4 basics: $(printf '%s' "$w12a4p" | gc | head -2 | tr '\n' '|')"
[ "$(printf '%s' '0⍳′±⍒≢Ṅ0⍳‹grade›≢Ṅ␤1⍳5+′±⍒⍕1⍳5+‹grade›⍕␤5⍳′±⍒TṄ5⍳‹grade›TṄ0⍳′±⍒TṄ0⍳‹grade›TṄ␤5⍳→a ←a′±⍒_ ←a‹grade›_ ←a⍕' | gc)" \
    = "$(printf '00\n5 0 \n0000\n0 1 2 3 4 ')" ] \
  && ok "⍒ and ‹grade› on empty and one-element lists; tagged results (T 0); the input is never written" || no "W12-A4 edges"
[ "$(printf '%s' ':k←t\\⊇;1⍳32767 48≪1\rsub+ 1⍳1 63≪+⧺ 1⍳0 1-+⧺ 1⍳5+⧺→t 4⍳′k⍒⍕␤←t‹grade›⍕␤←t′±⍒⍕' | gc)" \
    = "$(printf '1 2 3 0 \n1 2 3 0 \n-9223372036854775808 9223090561878065151 5 -1 ')" ] \
  && ok "keys over the full signed range -2^63 .. 0x7FFF<<48 - 1 compare signed, as ⍋ (± of -2^63 is itself)" || no "W12-A4 extremes"
# The A1 contract: k is called once per element, in order, with the caller's
# stack under x.  A counter below the list ends at 5; a printing key prints
# each element once.  k may run ⍒ itself (nested frames).
[ "$(printf '%s' ':k\\⊕\\±;0 5⍳′k⍒⍕Ṅ␤:p"Ṅ;5⍳⌽′p⍒⍕␤:i±;:m′i⍒0⊇;3⍳1+′⍳€⌽"′m⍒⍕␤⍕␤:n5⍳′±⍒≢;3⍳′n⍒⍕' | gc)" \
    = "$(printf '4 3 2 1 0 5\n432100 1 2 3 4 \n[0] [0 1] [0 1 2] \n[0 1 2] [0 1] [0] \n0 1 2 ')" ] \
  && ok "k is called exactly n times, in order, with the caller's stack under x (A1); ⍒ nested inside k" || no "W12-A4 threading"
[ "$(w113 ':k“bad“⊃‹throw›;:f5⍳′k⍒;1 2′f‹catch›⊐␤Ṅ␤Ṅ␤:j"3-[“three“⊃‹throw›];:g9⍳′j⍒;′g‹catch›⊐␤5⍳′±⍒⍕␤5177392@Ṅ')" \
    = "$(printf 'bad\n2\n1\nthree\n4 3 2 1 0 \n0 rc=0')" ] \
  && ok "a throw inside k (first call, and mid-way) is caught with the caller's stack restored; ⍒ works again; spill stack back to 0" || no "W12-A4 catch"
w12a4bad=""
for w12a4a in '5⍳"⌫′±⍒' '5⍳"⌫‹grade›' '300⍳"⌫′±⍒' '300⍳"⌫‹grade›'; do
  [ "$(w110 "$w12a4a")" = "rc=1 0 GOLF: use after free" ] || w12a4bad="$w12a4bad [$w12a4a: $(w110 "$w12a4a")]"
done
[ -z "$w12a4bad" ] && ok "⍒ and ‹grade› on a freed list (small and class 7): use after free" || no "W12-A4 use after free:$w12a4bad"
[ "$(printf '%s' '1000⍳→l ‹heapstats›→b→n ←l′±⍒⌫ ←l‹grade›⌫ :k5⍳"′±⍒⌫⌫;←l′k⍒⌫ ‹heapstats›←b-Ṅ“ “🗲←n-Ṅ' | gc)" = "0 0" ] \
  && ok "⍒ and ‹grade› give their scratch blocks (keys, the other merge buffer) back: ‹heapstats› unchanged" || no "W12-A4 heap"
# 1M elements, 1000 distinct keys (so stability matters everywhere): output
# against Python, and the cost against ⍋ on the same list (reported, not
# asserted: the machine is shared).
printf '%s' ':f7919*1000003%;:k1000%±;1000000⍳′f€′k⍒⍕' > "$TMP/a4big.golfj"
printf '%s' ':f7919*1000003%;1000000⍳′f€⍋_' > "$TMP/a4sort.golfj"
printf '%s' ':f7919*1000003%;:k;1000000⍳′f€′k⍒_' > "$TMP/a4ks.golfj"
for w12a4f in a4big a4sort a4ks; do python3 tools/codepage.py encode < "$TMP/$w12a4f.golfj" | cat "$TMP/pre.gb" - | "$TMP/golf2" > "$TMP/$w12a4f" 2>/dev/null; chmod +x "$TMP/$w12a4f"; done
w12a4t0=$(date +%s%N); "$TMP/a4sort"; w12a4t1=$(date +%s%N); "$TMP/a4ks"; w12a4t2=$(date +%s%N)
[ "$("$TMP/a4big" | md5sum)" = "$(python3 -c '
l=[i*7919%1000003 for i in range(1000000)]
print(" ".join(map(str,sorted(l,key=lambda x:-(x%1000)))),end=" ")' | md5sum)" ] \
  && ok "1M elements by a key with 1000 values match Python's sorted; ⍋ $(( (w12a4t1-w12a4t0)/1000000 )) ns/element, ⍒ $(( (w12a4t2-w12a4t1)/1000000 )) ns/element" \
  || no "W12-A4 1M"
# === W12-A7 ===
echo "W12-A7: ⋄ — if-else c[a⋄b] and the top-tested while {c⋄body} (compiler syntax)"
# Zero is true, as for [ and }: c[a⋄b] runs a when c is 0, b otherwise;
# {c⋄body} computes c before every pass and runs body while c is 0.  Both are
# the jumps [ ] { } already emit (one more jmp each), so no run-time machinery.
w12a7b(){ [ "$(printf '%s' "$1" | gc)" = "$2" ] && [ "$(printf '%s' "$1" | gref)" = "$2" ]; }
w12a7b '0[1Ṅ⋄2Ṅ]5[1Ṅ⋄2Ṅ]' "12" \
  && ok "0[1Ṅ⋄2Ṅ] prints 1, 5[1Ṅ⋄2Ṅ] prints 2 (golf2 and the oracle)" || no "if-else basic: $(printf '%s' '0[1Ṅ⋄2Ṅ]5[1Ṅ⋄2Ṅ]' | gc)"
w12a7b ':s"[_“zero“⋄0≺1+[“neg“⋄“pos“]]🗲;0s 7s 0 3-s' "zeroposneg" \
  && ok "nested if-else in a word: zero / pos / neg" || no "nested if-else"
w12a7b '0→i{←i5<1+⋄←iṄ←i1+→i}␤0→j{1⋄99Ṅ}←jṄ␤{1}7Ṅ' "$(printf '01234\n0\n7')" \
  && ok "{←i5<1+⋄…} runs 5 passes; {1⋄99Ṅ} runs none; a plain { } is unchanged" || no "while basic"
w12a7b '0→i{←i6<1+⋄←i[0Ṅ⋄←i2%[“e“🗲⋄“o“🗲]]←i1+→i}␤0→i{←i2<1+⋄0→k{←k3<1+⋄←i←k+Ṅ←k1+→k}←i1+→i}' "$(printf '0oeoeo\n012123')" \
  && ok "if-else nested in a while, and a while nested in a while" || no "while nesting"
w12a7b '0→i{←i3<1+"[_0⋄_1]⋄←iṄ←i1+→i}␤0[{1⋄}7Ṅ⋄8Ṅ]␤1[{1}9Ṅ⋄{1⋄}8Ṅ]' "$(printf '012\n7\n8')" \
  && ok "a whole [a⋄b] inside a while's condition; a while inside each branch of an if-else" || no "mixed nesting"
w12a7b ':g0{"10<1+⋄"7-[^⋄1+]}99;gṄ' "7" \
  && ok "^ from inside a while's body returns from the word" || no "^ in while"
w12a7d=$(python3 -c 'print("0[" * 40 + "7Ṅ" + "⋄9Ṅ]" * 40 + "␤" + "1[" + "0[" * 39 + "7Ṅ" + "⋄9Ṅ]" * 40)')
w12a7b "$w12a7d" "$(printf '7\n9')" && ok "if-else nested 40 deep" || no "40-deep if-else"
w12a7b '“a⋄b“🗲 # ⋄ in a comment
' "a⋄b" && ok "⋄ inside “…“ and in a comment is left alone" || no "⋄ in string/comment"
w94dbin '0[1⋄2]'
[ "$(w94dhas 6800000000584885c00f850a0000006801000000e9050000006802000000)" = 1 ] \
  && ok "0[1⋄2] is push 0; pop/test/jnz +10; push 1; jmp +5; push 2" || no "if-else bytes"
w94dbin '{0⋄}'
[ "$(w94dhas 6800000000584885c00f8505000000e9ecffffff)" = 1 ] \
  && ok "{0⋄} is push 0; pop/test/jnz +5 (out); jmp -20 (to the test)" || no "while bytes"
w12a7e(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) > "$TMP/a7.src"
          "$TMP/golf2" < "$TMP/a7.src" > "$TMP/a7.bin" 2>"$TMP/a7.err"; w12a7g=$?
          python3 boot/golfref.py < "$TMP/a7.src" > /dev/null 2>"$TMP/a7.rerr"; w12a7r=$?
          "$TMP/seed" < "$TMP/a7.src" > "$TMP/a7.sbin" 2>/dev/null; w12a7s=$?
          [ -s "$TMP/a7.bin" ] || [ -s "$TMP/a7.sbin" ] && w12a7s="$w12a7s+binary"
          echo "$w12a7g $w12a7r $w12a7s $(cat "$TMP/a7.err") | $(cat "$TMP/a7.rerr")"; }
w12a7bad=""
for w12a7c in '1⋄|GOLF: ⋄ outside [ ] or { } at line 1' \
              '1Ṅ\n:f⋄;|GOLF: ⋄ outside [ ] or { } at line 2' \
              '0[1⋄]⋄|GOLF: ⋄ outside [ ] or { } at line 1' \
              '0[1⋄2⋄3]|GOLF: ⋄ twice in one block at line 1' \
              '\n\n{0⋄1⋄}|GOLF: ⋄ twice in one block at line 3'; do
  w12a7o=$(printf "${w12a7c%%|*}" | w12a7e)
  [ "$w12a7o" = "2 2 2 ${w12a7c#*|} | ${w12a7c#*|}" ] || w12a7bad="$w12a7bad [$w12a7o]"
done
[ -z "$w12a7bad" ] \
  && ok "⋄ outside [ ] / { } (top level, in a bare word, after the ]) or twice in one block: GOLF: … at line N, exit 2, no binary (golf2, golfref; the seed exits 2)" \
  || no "⋄ errors:$w12a7bad"
w12a7p='0→i{←i4<1+⋄←i2%[“e“⋄“o“]🗲←i1+→i}:s"[_0⋄0≺1+[1⋄2]]Ṅ;0s3s0 3-s'
printf '%s' "$w12a7p" | cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) > "$TMP/a7.src"
"$TMP/seed" < "$TMP/a7.src" > "$TMP/a7.sbin" 2>/dev/null; "$TMP/golf2" < "$TMP/a7.src" > "$TMP/a7.bin" 2>/dev/null
python3 boot/golfref.py < "$TMP/a7.src" > "$TMP/a7.rbin" 2>/dev/null
cmp -s "$TMP/a7.sbin" "$TMP/a7.bin" && cmp -s "$TMP/a7.rbin" "$TMP/a7.bin" && [ "$(printf '%s' "$w12a7p" | gc)" = "eoeo021" ] \
  && ok "seed, golf2 and golfref emit the same bytes for an if-else / while program" || no "⋄ three-way byte parity"
[ "$(python3 tools/codepage.py decode < <(printf '%s' '\else' | python3 tools/codepage.py encode))" = "⋄" ] \
  && ok "\\else encodes to 0xB8 and decodes as ⋄" || no "⋄ code page"
# bench/leetcode/golf/queens.golfj's column loop is a {c⋄body} since W12-A7.
w12a7q=""; grep -q '⋄' bench/leetcode/golf/queens.golfj || w12a7q=" [no ⋄]"
"$EXP/tools/golfc" -j "$EXP/bench/leetcode/golf/queens.golfj" "$TMP/a7q" > /dev/null 2>&1 || w12a7q="$w12a7q [compile]"
for w12a7n in 1 2 3 4 5 6 7 8; do
  [ "$(echo $w12a7n | "$TMP/a7q")" = "$(echo $w12a7n | python3 bench/leetcode/py/queens.py)" ] || w12a7q="$w12a7q [n=$w12a7n]"
done
[ -z "$w12a7q" ] && ok "the queens solution on {⇐v0≡⋄…} agrees with Python for n = 1…8" || no "queens with ⋄:$w12a7q"
# === W12-A5 ===
echo "W12-A5: ⊟ window reduce (a monotonic deque for ⌈ ⌊, f-reduce of each window otherwise)"
w12a5bad=""; w12a5n=0
while IFS= read -r w12a5l; do
  w12a5p=${w12a5l%%  ->*}; w12a5p=${w12a5p%"${w12a5p##*[! ]}"}; w12a5w=${w12a5l##*->  }
  w12a5n=$((w12a5n+1))
  [ "$(printf '%s' "$w12a5p" | gc | sed 's/ *$//')" = "$w12a5w" ] || w12a5bad="$w12a5bad [$w12a5p]"
  [ "$(printf '%s' "$w12a5p" | gref | sed 's/ *$//')" = "$w12a5w" ] || w12a5bad="$w12a5bad oracle[$w12a5p]"
done < <(sed -n '/^### Windows and fixpoints/,/^### /p' REFERENCE.md | sed -n '/^```$/,/^```$/p' | grep -- '  ->  ')
[ -z "$w12a5bad" ] && [ "$w12a5n" -ge 11 ] \
  && ok "REFERENCE.md's ⊟ / ⍣ examples ($w12a5n) print what they say, golf2 and oracle" \
  || no "W12-A5/A6 REFERENCE examples:$w12a5bad"
# Every window size 0..len+1 over lengths 0..9 of signed data, for ⌈ ⌊ (the
# deque), ⩌ and :m⌈; (recognised as max), + and - (- is not associative, so
# it checks the fold order f(f(a,b),c)), against Python.
python3 - "$TMP" <<'PYEOF'
import sys, random
T = sys.argv[1]; random.seed(125)
prog, want = [":m⌈;:k⌊;"], []
ops = [("′⌈", max), ("′⌊", min), ("′⩌", max), ("′m", max), ("′k", min), ("′+", lambda a, b: a + b), ("′-", lambda a, b: a - b)]
for L in range(10):
    a = [random.randint(-9, 9) for _ in range(L)]
    lit = "".join(f"{v}⍆" if v >= 0 else f"0 {-v}-⍆" for v in a)
    for n in range(1, L + 2):
        for g, f in ops:
            prog.append(f"0⍳{lit}{n}{g}⊟⍕␤")
            out = []
            for i in range(L - n + 1):
                acc = a[i]
                for x in a[i + 1:i + n]:
                    acc = f(acc, x)
                out.append(acc)
            want.append(" ".join(map(str, out)))
open(f"{T}/a5win.prog", "w", encoding="utf-8").write("".join(prog))
open(f"{T}/a5win.want", "w").write("\n".join(want) + "\n")
PYEOF
[ "$(gc < "$TMP/a5win.prog" | sed 's/ *$//')" = "$(cat "$TMP/a5win.want")" ] \
  && [ "$(gref < "$TMP/a5win.prog" | sed 's/ *$//')" = "$(cat "$TMP/a5win.want")" ] \
  && ok "lengths 0..9, every n 1..len+1, ⌈ ⌊ ⩌ :m⌈; :k⌊; + - match Python (golf2 and the oracle)" \
  || no "W12-A5 vs Python: $(diff <(gc < "$TMP/a5win.prog" | sed 's/ *$//') "$TMP/a5win.want" | head -4 | tr '\n' ' ')"
# The deque is O(len): a window of 100,000 over a million elements would be
# 10^11 calls of f on the general path.  Here it is two passes.
printf '%s' ':m⌈;1000000⍳100000′⌈⊟∑Ṅ␤1000000⍳100000′⌊⊟∑Ṅ␤1000000⍳⌽100000′m⊟∑Ṅ␤1000000⍳100000′⩍⊟≢Ṅ' \
  | cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/a5big" 2>/dev/null && chmod +x "$TMP/a5big"
[ "$(timeout 20 "$TMP/a5big")" \
    = "$(python3 -c 'print(sum(range(99999,10**6)));print(sum(range(10**6-99999)));print(sum(range(99999,10**6)));print(10**6-99999)')" ] \
  && ok "⌈ ⌊ :m⌈; ⩍ with n = 100,000 over 10^6 elements: the O(n) deque (the general path would never finish)" || no "W12-A5 deque speed"
[ "$(printf '%s' '5⍳3′⌈⊟48>Ṅ␤5⍳3′+⊟48>Ṅ␤0⍳3′+⊟48>Ṅ␤5⍳"3′⌈⊟⌫∑Ṅ' | gc)" = "$(printf '32767\n32767\n32767\n10')" ] \
  && ok "the result is a new tagged list (⌫ of it leaves l alone), on both paths and when empty" || no "W12-A5 tagged result"
[ "$(w110 '7Ṅ5⍳0′+⊟')" = "rc=1 1 GOLF: window size < 1" ] && [ "$(w110 '5⍳0 4-′⌈⊟')" = "rc=1 0 GOLF: window size < 1" ] \
  && [ "$(w110 '5⍳"⌫2′⌈⊟')" = "rc=1 0 GOLF: use after free" ] && [ "$(w110 '5⍳"⌫2′+⊟')" = "rc=1 0 GOLF: use after free" ] \
  && [ "$(w110 '0⍳"⌫9′+⊟')" = "rc=1 0 GOLF: use after free" ] \
  && ok "errors through ‹throw›: window size < 1 (n = 0 and n < 0; earlier output flushed), use after free (deque path, general path, empty list)" || no "W12-A5 errors"
[ "$(w113 ':t"3≡1+[“three“⊃‹throw›]⌈;:g5⍳2′t⊟;′g‹catch›⊐␤5⍳2′⌈⊟⍕␤:h3⍳′⍳€2′⌈⊟⍕;′h‹catch›␤5177392@Ṅ')" \
    = "$(printf 'three\n1 2 3 4 \n[] [0] \n0 rc=0')" ] \
  && ok "a throw from f mid-window is caught, ⊟ runs again; spill stack back to 0; ⌈ on lists takes the general path (elementwise)" \
  || no "W12-A5 catch: $(w113 ':t"3≡1+[“three“⊃‹throw›]⌈;:g5⍳2′t⊟;′g‹catch›⊐␤5177392@Ṅ')"
# Re-entrancy: ⊟ inside ⊟'s f (on lists of lists), ⊟ inside € inside ⊟,
# ⍣ inside ⊟'s f; and the A1 contract under nesting (the counter).
w12a5r=':v3′⌈⊟∑;:w"≢1≻[^]2′+⊟;:c⧺\\⊕\\′w⍣;4⍳5+′⍳€2′⧺⊟′v€⍕␤3⍳4+′⍳€2′⧺⊟⍕␤0 3⍳3+′⍳€2′c⊟′∑€⍕Ṅ'
[ "$(printf '%s' "$w12a5r" | gc | sed 's/ *$//')" = "$(printf '31 44 59\n[0 1 2 3 0 1 2 3 4] [0 1 2 3 4 0 1 2 3 4 5]\n66 372 2')" ] \
  && [ "$(printf '%s' "$w12a5r" | gref)" = "$(printf '%s' "$w12a5r" | gc)" ] \
  && ok "re-entrant: ⊟ in € after ⊟, ⍣ of ⊟ inside ⊟'s f, with a counter threaded under it (golf2 and the oracle)" || no "W12-A5 nesting: $(printf '%s' "$w12a5r" | gc)"
[ "$(printf '%s' '‹heapstats›→b→n 1000⍳"10′⌈⊟⌫"10′⌊⊟⌫"10′+⊟⌫"1′+⊟⌫"2000′+⊟⌫‹heapstats›←b-Ṅ“ “🗲←n-Ṅ␤"10′⌈⊟‹heapstats›←b-Ṅ“ “🗲←n-Ṅ' | gc)" \
    = "$(printf '8016 1\n16032 2')" ] \
  && ok "‹heapstats›: ⊟ keeps only its result (the deque's block is given back), on both paths and when empty" || no "W12-A5 heapstats"
# The leetcode rewrite: sliding-window maximum is one ⊟, checked against the
# Python solution on a small random input.
python3 -c 'import random;random.seed(7);print(5);print(*[random.randint(-99,99) for _ in range(300)])' > "$TMP/a5sm.in"
cat "$TMP/pre.gb" <(python3 tools/codepage.py encode < bench/leetcode/golf/slidemax.golfj) | "$TMP/golf2" > "$TMP/a5sm" 2>/dev/null && chmod +x "$TMP/a5sm"
[ "$("$TMP/a5sm" < "$TMP/a5sm.in" | sed 's/ *$//')" = "$(python3 bench/leetcode/py/slidemax.py < "$TMP/a5sm.in")" ] \
  && ok "bench/leetcode/golf/slidemax.golfj (‹ints›\"0⊇\\\\1↓\\\\′⌈⊟⍕) agrees with py/slidemax.py" || no "W12-A5 slidemax"

# === W12-A6 ===
echo "W12-A6: ⍣ fixpoint (apply f until the result ≣ the previous one)"
[ "$(printf '%s' ':d2/;100′d⍣Ṅ␤:i;5⍳"′i⍣≡Ṅ␤:h"≢1≻[^]1↓;5⍳′h⍣⍕␤:u"≢1≻[^]1↓"⌽⌽\\⌫;9⍳′u⍣⍕␤:s_“ab“⊃;0′s⍣⊐␤:z_0;7′z⍣Ṅ' | gc)" \
    = "$(printf '0\n-1\n4 \n8 \nab\n0')" ] \
  && ok "ints, f returning its own input (same block back), shrinking lists, a fresh copy per step, a constant f (two calls)" || no "W12-A6 basics: $(printf '%s' ':d2/;100′d⍣Ṅ' | gc)"
# Freeing.  1000⍳′h⍣ makes 999 intermediates and keeps only x and the
# result; an f that returns a list HOLDING its argument keeps the argument
# (the result's element is still readable); x itself is never freed.
w12a6f=':h"≢1≻[^]1↓;:w"48>32767≡[⍳^]"0⊇48>32767≡1+[^]‹vec›\\⍆;‹heapstats›→b→n 1000⍳′h⍣⍕‹heapstats›←b-Ṅ“ “🗲←n-Ṅ␤3′w⍣⍕␤5⍳"′w⍣_⍕␤‹heapstats›→b→n 3′w⍣_‹heapstats›_←n-Ṅ'
[ "$(printf '%s' "$w12a6f" | gc | sed 's/ *$//')" = "$(printf '999 8056 2\n[0 1 2]\n0 1 2 3 4\n2')" ] \
  && [ "$(printf '%s' "$w12a6f" | gref)" = "$(printf '%s' "$w12a6f" | gc)" ] \
  && ok "‹heapstats›: 999 intermediates freed (x and the result stay), an argument nested in the result is kept, x is never freed (golf2 and the oracle)" \
  || no "W12-A6 freeing: $(printf '%s' "$w12a6f" | gc)"
[ "$(w113 ':t"3≡1+[“three“⊃‹throw›]2/;:g7′t⍣;′g‹catch›⊐␤9′t⍣Ṅ␤:h"≢1≻[^]1↓;:k′h⍣;4⍳′⍳€1+′k€⍕␤5177392@Ṅ')" \
    = "$(printf 'three\n0\n[] [1] [2] [3] \n0 rc=0')" ] \
  && ok "a throw from f under ‹catch›, then ⍣ again; ⍣ nested in € nested in ⍣-free code; spill stack back to 0" || no "W12-A6 catch"
[ "$(w110 ':h"≢1≻[^]1↓;5⍳"⌫′h⍣')" = "rc=1 0 GOLF: use after free" ] && [ "$(w110 ':u"⌫;5⍳′u⍣')" = "rc=1 0 GOLF: use after free" ] \
  && [ "$(printf '%s' ':h"≢1≻[^]1↓;5⍳′h⍣48>Ṅ␤:g;5⍳′g⍣48>Ṅ' | gc)" = "$(printf '32767\n32767')" ] \
  && ok "use after free: a freed x, and an f that frees its argument (≣ finds it); the result keeps its tag" || no "W12-A6 uaf / tag"
# Nested ⍣: f itself runs ⍣ (and ⊟), with a call counter threaded under it.
w12a6n=':d2/;:e_3′d⍣⊕;:f\\⊕\\′e⍣;0 5⍳′⍳€′∑€′f€⍕Ṅ␤:r"≢1≻[^]2′+⊟;6⍳′r⍣⍕'
[ "$(printf '%s' "$w12a6n" | gc | sed 's/ *$//')" = "$(printf '1 1 1 1 1 5\n80')" ] \
  && [ "$(printf '%s' "$w12a6n" | gref)" = "$(printf '%s' "$w12a6n" | gc)" ] \
  && ok "re-entrant: ⍣ inside ⍣'s f (counted under it), ⍣ of a ⊟ (golf2 and the oracle)" || no "W12-A6 nesting: $(printf '%s' "$w12a6n" | gc)"

# === W12-Z2 ===
echo "W12-Z2: ⇡x / ⇣x — increment / decrement a variable in place (compiler ops)"
# ⇡x is ←x⊕→x and ⇣x is ←x⊖→x, as one inc/dec qword on the variable's cell:
# 2 bytes of source instead of 5, 8 bytes of code instead of 20, and the data
# stack is never touched.  Inside a ⊡ word, a local the word has already named
# is the one bumped.  No not-a-number check: a variable holding a list is
# bumped as a raw cell, like ⇒/⇐ copy one.
w12z2b(){ [ "$(printf '%s' "$1" | gc)" = "$2" ] && [ "$(printf '%s' "$1" | gref)" = "$2" ]; }
w12z2b '5→x⇡x⇡x←xṄ⇣x⇣x⇣x←xṄ' "74" \
  && ok "5→x⇡x⇡x is 7, then ⇣x⇣x⇣x is 4 (golf2 and the oracle)" || no "⇡⇣ basic: $(printf '%s' '5→x⇡x⇡x←xṄ⇣x⇣x⇣x←xṄ' | gc)"
w12z2b '⇡q←qṄ 0→z⇣z←zṄ 0 1-→m⇡m←mṄ 1 63≪1-→w⇡w←w1 63≪≡Ṅ' "1-10-1" \
  && ok "an unset variable starts at 0; 0 decrements to -1; -1 to 0; 2^63-1 wraps to -2^63" || no "⇡⇣ edges"
w12z2b '0→‹count›⇡‹count›⇡‹count›⇡‹count›⇣‹count›←‹count›Ṅ' "2" \
  && ok "⇡‹count› / ⇣‹count› on a long-name variable" || no "⇡ long name"
w12z2b '0→i{←i5<1+⋄←iṄ⇡i}␤3→n{⇣n←n1<}←nṄ' "$(printf '01234\n0')" \
  && ok "⇡i counts a while loop up, ⇣n counts a } loop down" || no "⇡⇣ loops"
w12z2b '⊡f⇒a⇡a⇡a⇐a;10fṄ 50→a⇡a←aṄ' "1251" \
  && ok "in a ⊡ word, ⇡a after ⇒a bumps the local; the variable a is untouched" || no "⇡ local"
w12z2b '⊡g⇡a←aṄ⇒a⇡a⇐aṄ;100→a 7g←aṄ' "1018101" \
  && ok "in a ⊡ word, ⇡a before any ⇒a/⇐a is the variable; after ⇒a, the local" || no "⇡ local vs variable"
w12z2b '⊡h⇒‹acc›⇒b⇣b⇡‹acc›⇡‹acc›⇐‹acc›⇐b;1 9hṄṄ' "011" \
  && ok "long-name and second-slot locals: ⇣b ⇡‹acc›" || no "⇡ long local"
w12z2b ':k⇡x⇡x;0→x kk←xṄ' "4" \
  && ok "⇡x in a plain : word is the variable (no frame)" || no "⇡ in : word"
w12z2b '3→x⇡x“x⇡x“🗲 # ⇡x in a comment
←xṄ' "x⇡x4" && ok "⇡ inside “…“ and in a comment is left alone" || no "⇡ in string/comment"
w94dbin '⇡x⇣x'
[ "$(w94dhas 48ff0425c0034e0048ff0c25c0034e00)" = 1 ] \
  && ok "⇡x⇣x is inc qword [0x4E03C0]; dec qword [0x4E03C0] (48 FF 04/0C 25 imm32)" || no "⇡⇣ variable bytes"
w94dbin '⇡‹n›'
[ "$(w94dhas 48ff042500084e00)" = 1 ] \
  && ok "⇡‹n› is inc qword [0x4E0800], the first long name's cell" || no "⇡ long-name bytes"
w94dbin '⊡f⇒a⇒b⇡a⇣b⇡c;'
[ "$(w94dhas 48ff450048ff4d0848ff042518034e00)" = 1 ] \
  && ok "⊡f⇒a⇒b⇡a⇣b⇡c: inc [rbp+0]; dec [rbp+8]; inc qword [c] (48 FF 45/4D disp8)" || no "⇡⇣ local bytes"
w12z2bad=""
for w12z2c in '⇡1|GOLF: ⇡ needs a variable at line 1' \
              '1Ṅ\n⇣ x|GOLF: ⇣ needs a variable at line 2' \
              '1⇡|GOLF: ⇡ needs a variable at line 1' \
              ':f⇡“a“;|GOLF: ⇡ needs a variable at line 1' \
              '\n⇡⇣x|GOLF: ⇡ needs a variable at line 2' \
              '⇣‹a b›|GOLF: bad long name ‹a› at line 1'; do
  w12z2o=$(printf "${w12z2c%%|*}" | w12a7e)
  [ "$w12z2o" = "2 2 2 ${w12z2c#*|} | ${w12z2c#*|}" ] || w12z2bad="$w12z2bad [$w12z2o]"
done
[ -z "$w12z2bad" ] \
  && ok "⇡ / ⇣ not followed by a letter or ‹long name› (a digit, a space, end of input, a string, another ⇡): GOLF: … at line N, exit 2, no binary (golf2, golfref; the seed exits 2)" \
  || no "⇡⇣ errors:$w12z2bad"
w12z2p='5→x⇡x⇡x⇣x←xṄ0→‹n›⇡‹n›←‹n›Ṅ⊡f⇒a⇡a⇣‹n›⇐a⇡a;3fṄ←‹n›Ṅ⊡g⇡a←aṄ;9→a g'
printf '%s' "$w12z2p" | cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) > "$TMP/z2.src"
"$TMP/seed" < "$TMP/z2.src" > "$TMP/z2.sbin" 2>/dev/null; "$TMP/golf2" < "$TMP/z2.src" > "$TMP/z2.bin" 2>/dev/null
python3 boot/golfref.py < "$TMP/z2.src" > "$TMP/z2.rbin" 2>/dev/null
cmp -s "$TMP/z2.sbin" "$TMP/z2.bin" && cmp -s "$TMP/z2.rbin" "$TMP/z2.bin" && [ "$(printf '%s' "$w12z2p" | gc)" = "614010" ] \
  && ok "seed, golf2 and golfref emit the same bytes for a ⇡ / ⇣ program" || no "⇡⇣ three-way byte parity"
[ "$(python3 tools/codepage.py decode < <(printf '%s' '\vinc\vdec' | python3 tools/codepage.py encode))" = "⇡⇣" ] \
  && [ "$(printf '%s' '⇡⇣' | python3 tools/codepage.py encode | od -An -tx1 | tr -d ' \n')" = "b9ba" ] \
  && ok "\\vinc / \\vdec encode to 0xB9 / 0xBA and decode as ⇡ / ⇣" || no "⇡⇣ code page"

echo "Resource registry (REGISTRY.md): op bytes, mnemonics and glyphs stay disjoint"
python3 tools/codepage.py check \
  && ok "codepage invariants (bytes/mnemonics/glyphs)" || no "codepage invariants (bytes/mnemonics/glyphs)"

echo
echo "v1 bootstrap seed: $(wc -c < self/seed.golf) bytes (self/seed.golf)"
echo "v2 compiler:       $(wc -c < self/golf2.golf) bytes (self/golf2.golf, from self/golf2.golfj)"
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
