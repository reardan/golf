#!/usr/bin/env bash
# Expanded GOLF (v2) test suite + bootstrap ladder.
#
#   golf0.py  --compiles-->  v1c        (the frozen minimal compiler)
#   v1c       --compiles-->  golf2      (v2 seed, written in v1 GOLF)
#   golf2     --compiles-->  golf2'     ; require golf2 == golf2'  (fixpoint)
#   golf2     --compiles-->  examples using the new operators
set -u
cd "$(dirname "$0")/.."
EXP=$(pwd); MIN="$EXP/../minimal"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "Regenerate the v2 seed source"
python3 tools/mkblob2.py 2>&1 | sed 's/^/  /'

echo "Bootstrap ladder"
python3 "$MIN/boot/golf0.py" < "$MIN/self/golf.golf" > "$TMP/v1c" 2>/dev/null && chmod +x "$TMP/v1c" \
  && ok "build v1c (minimal compiler)" || no "build v1c"
"$TMP/v1c" < self/golf2.golf > "$TMP/golf2" 2>/dev/null && chmod +x "$TMP/golf2" \
  && ok "v1c compiles golf2.golf" || no "v1c compiles golf2.golf"
"$TMP/golf2" < self/golf2.golf > "$TMP/golf2b" 2>/dev/null && chmod +x "$TMP/golf2b"
cmp -s "$TMP/golf2" "$TMP/golf2b" && ok "golf2 self-hosts (fixpoint)" || no "golf2 fixpoint"

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

echo "Quotations: ′ ref (push a word's address), ⍎ exec (indirect call)"
[ "$(printf '%s' ':d\dbl;3\refd\exec48+)' | atom)" = "6" ] && ok "ref + exec" || no "ref/exec"

echo "List type (prelude library): A alloc R range L len I index S sum N num M map F fold Q print"
python3 tools/codepage.py encode < lib/prelude.golfj > "$TMP/pre.gb"    # encoded prelude
gc(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) | "$TMP/golf2" > "$TMP/p" 2>/dev/null \
        && chmod +x "$TMP/p" && "$TMP/p"; }
[ "$(printf '%s' '5R L N E'    | gc)" = "5" ]    && ok "range + len"       || no "range/len"
[ "$(printf '%s' '10R 4 I N E' | gc)" = "4" ]    && ok "index"             || no "index"
[ "$(printf '%s' '100R S N E'  | gc)" = "4950" ] && ok "sum of range(100)"  || no "sum range"
[ "$(printf '%s' '12345N E'    | gc)" = "12345" ]&& ok "decimal printer"   || no "printer"
[ "$(printf '%s' ':d\dbl;5R\refdMSNE'  | gc)" = "20" ] && ok "map (double, sum)" || no "map"
[ "$(printf '%s' ':x\max;6R 0\refxFNE' | gc)" = "5" ]  && ok "fold (max)"        || no "fold"
[ "$(printf '%s' ':q\sqr;4R\refqMQE'   | gc)" = "0 1 4 9 " ] && ok "map + print list" || no "map/print"
[ "$(printf '%s' ':i\inc;4R\refiMPNE'  | gc)" = "24" ]  && ok "product"  || no "product"
[ "$(printf '%s' '5RVQE'               | gc)" = "4 3 2 1 0 " ] && ok "reverse" || no "reverse"
[ "$(printf '%s' ':e2%;10R\refeWSNE'   | gc)" = "20" ]  && ok "filter (even, sum)" || no "filter"
tools/golfc -j examples/lists.golfj "$TMP/lists" 2>/dev/null
[ "$("$TMP/lists" 2>/dev/null)" = "$(printf '4950\n20\n5')" ] && ok "golfc examples/lists.golfj" || no "lists.golfj"

echo
echo "v2 seed size: $(wc -c < self/golf2.golf) bytes"
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
