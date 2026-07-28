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
[ "$(oracle vectorize)" = "$(printf '0 2 4 6 8 \n14\n10 11 12 13 14 ')" ] \
  && ok "oracle: vectorize.golfj behaves identically" || no "oracle vectorize.golfj"

echo "Vectorization (M-JELLY slice): ⊞ zip (elementwise), broadcast via closures"
[ "$(printf '%s' '5R5R\ref+ZSNE'      | gc)" = "20" ] && ok "zip (′atom +) then sum" || no "zip"
[ "$(printf '%s' '4R4R\ref*ZSNE'      | gc)" = "14" ] && ok "dot product (′atom *)" || no "dot"
[ "$(printf '%s' '10→k:f←k+;5R′fMQE' | gc)" = "10 11 12 13 14 " ] && ok "broadcast (closure)" || no "broadcast"
tools/golfc -j examples/vectorize.golfj "$TMP/vec" 2>/dev/null
[ "$("$TMP/vec" 2>/dev/null)" = "$(printf '0 2 4 6 8 \n14\n10 11 12 13 14 ')" ] && ok "golfc examples/vectorize.golfj" || no "vectorize.golfj"

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
# prelude's top-level init; base+span is the return-stack top 0xC00000.
[ "$(printf '%s' '5177396@ 5177400@\radd N E' | gc)" = "12582912" ] \
  && ok "heap-bounds cells initialized (base+span = 0xC00000)" || no "heap bounds cells"
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
# @@ W6-MEM @@
# @@ W7-DOCS @@
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
# The -1 marker is a full 64-bit -1 on the data stack — and stops being one the
# moment it is parked in a →x/←x variable, because the bank is FOUR bytes per
# name and ←x zero-extends.  A tool that writes `q →x ←x 0≺ [ … ]` never takes
# its not-found branch.  Pinned here because it is a trap in the CALLER, so no
# amount of care inside lib/ttext.golfj can prevent it.
[ "$(printf '%s' '“abc“→s ←s4\radd 3 122 q N E ←s4\radd 3 122 q →x ←x N E' | gtt)" \
   = "$(printf '%s\n%s' -1 4294967295)" ] \
  && ok "not-found is -1 on the stack — and 4294967295 through a →x variable" || no "-1 through a variable"

# @@ W8-TOOLS @@


echo "Capstone: lists + higher-order + vectorization + strings + variables together"
tools/golfc -j examples/capstone.golfj "$TMP/cap" 2>/dev/null
[ "$("$TMP/cap" 2>/dev/null)" = "$(printf '30\n14\n5\nKhoor')" ] && ok "golfc examples/capstone.golfj" || no "capstone.golfj"

echo "Resource registry (REGISTRY.md): op bytes, mnemonics and glyphs stay disjoint"
python3 tools/codepage.py check \
  && ok "codepage invariants (bytes/mnemonics/glyphs)" || no "codepage invariants (bytes/mnemonics/glyphs)"

echo
echo "v1 bootstrap seed: $(wc -c < self/seed.golf) bytes (self/seed.golf)"
echo "v2 compiler:       $(wc -c < self/golf2.golf) bytes (self/golf2.golf, from self/golf2.golfj)"
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
