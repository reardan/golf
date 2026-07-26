#!/usr/bin/env bash
# selfcheck.sh — prove self/golf2.golfj, the v2 compiler written in expanded
# GOLF (M-SELF), without touching the existing build.
#
# self/golf2.golf (the file the ladder in test/run2.sh uses) is generated from
# v1's single-char source by tools/mkblob2.py.  self/golf2.golfj is a hand
# written, semantically identical rewrite of that same compiler in the language
# it grew — named variables instead of stack juggling.  This script builds it
# with today's toolchain and shows the two compilers agree, byte for byte, on
# the programs they compile:
#
#   golf0.py --compiles--> v1c --compiles--> golf2       # today's compiler
#   codepage encode self/golf2.golfj + the blob  = candidate
#   golf2    --compiles--> golf2new                      # the rewrite, built
#   golf2new and golf2 must emit IDENTICAL bytes for the same input
#
# Nothing here writes into the repo: the candidate source and every binary live
# in a temp dir, and self/golf2.golf is used exactly as committed.  Wave 5 owns
# wiring golf2.golfj into tools/golfc + test/run2.sh and the bootstrap ladder.
set -u
cd "$(dirname "$0")/.."
EXP=$(pwd); MIN="$EXP/../minimal"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "Today's toolchain (unchanged: self/golf2.golf exactly as committed)"
python3 "$MIN/boot/golf0.py" < "$MIN/self/golf.golf" > "$TMP/v1c" 2>/dev/null \
  && chmod +x "$TMP/v1c" && ok "golf0.py compiles minimal/self/golf.golf -> v1c" || no "build v1c"
"$TMP/v1c" < self/golf2.golf > "$TMP/golf2" 2>/dev/null \
  && chmod +x "$TMP/golf2" && ok "v1c compiles self/golf2.golf -> golf2" || no "build golf2"

echo "The candidate source: self/golf2.golfj + the spliced template blob"
python3 tools/codepage.py encode < self/golf2.golfj > "$TMP/cand.enc" 2>"$TMP/err" \
  && ok "codepage encode self/golf2.golfj ($(wc -c < "$TMP/cand.enc") bytes)" \
  || { no "encode golf2.golfj"; sed 's/^/       /' "$TMP/err"; }
# Only ops TODAY's golf2 can compile may appear: ASCII, plus the four compiler
# prefixes (′ “ → ←) and the atom bytes.  Anything else and the rewrite could
# never be built by the compiler it replaces.
python3 - "$TMP/cand.enc" <<'PY' && ok "uses only ops today's golf2 can compile" || no "unsupported op byte"
import sys
sys.path.insert(0, "tools")
import codepage, mkblob2
data = open(sys.argv[1], "rb").read()
known = {mkblob2.REF_BYTE, mkblob2.STR_BYTE, mkblob2.SET_BYTE, mkblob2.GET_BYTE}
known |= {b for b, _mn, _gl, _tpl, _d in mkblob2.ATOMS}
used = sorted({b for b in data if b >= 0x80})
sys.stderr.write("       high bytes used: "
                 + " ".join(f"{codepage.BYTE2GLYPH.get(b, '?')}(0x{b:02X})" for b in used) + "\n")
sys.exit(1 if set(used) - known else 0)
PY
# The blob escape is `<len> <len raw bytes> — byte-exact, no stray newline.
python3 -c 'import sys; sys.path.insert(0,"tools"); import mkblob2; b=mkblob2.build_blob2(); sys.stdout.buffer.write(b"\x60"+str(len(b)).encode()+b" "+b)' > "$TMP/blob.esc" \
  && ok "template blob escape built from tools/mkblob2.build_blob2()" || no "build blob escape"
python3 -c '
import sys
enc = open(sys.argv[1], "rb").read(); esc = open(sys.argv[2], "rb").read()
n = enc.count(b"@BLOB@")
if n != 1: sys.exit(f"expected exactly one @BLOB@ marker, found {n}")
open(sys.argv[3], "wb").write(enc.replace(b"@BLOB@", esc))
' "$TMP/cand.enc" "$TMP/blob.esc" "$TMP/cand" \
  && ok "spliced the blob at @BLOB@ ($(wc -c < "$TMP/cand") bytes of source)" || no "splice blob"

echo "Building the rewrite with today's compiler"
"$TMP/golf2" < "$TMP/cand" > "$TMP/golf2new" 2>/dev/null \
  && chmod +x "$TMP/golf2new" && [ -s "$TMP/golf2new" ] \
  && ok "golf2 compiles the candidate -> golf2new ($(wc -c < "$TMP/golf2new") bytes)" \
  || no "golf2 compiles the candidate"

# --------------------------------------------------------------------------
# Everything below compares golf2new against golf2 on real inputs.  Behaviour
# first (does the compiled program do the right thing), then the much stronger
# claim: the two compilers emit the SAME BYTES.
# --------------------------------------------------------------------------
both(){ # both <name> <source file> — compile with each compiler, require identity
  "$TMP/golf2"    < "$2" > "$TMP/old.$1" 2>/dev/null; chmod +x "$TMP/old.$1"
  "$TMP/golf2new" < "$2" > "$TMP/new.$1" 2>/dev/null; chmod +x "$TMP/new.$1"
}

echo "The rewrite still compiles all of v1"
both hello "$MIN/examples/hello.golf"
[ "$("$TMP/new.hello" 2>/dev/null)" = "Hello, world!" ] \
  && ok "golf2new compiles minimal/examples/hello.golf" || no "golf2new hello"
both fizz "$MIN/examples/fizzbuzz.golf"
[ "$("$TMP/new.fizz" 2>/dev/null | sed -n '15p')" = "FizzBuzz" ] \
  && ok "golf2new compiles minimal/examples/fizzbuzz.golf" || no "golf2new fizzbuzz"
[ "$("$TMP/new.fizz" 2>/dev/null)" = "$("$TMP/old.fizz" 2>/dev/null)" ] \
  && ok "fizzbuzz output matches golf2's build exactly" || no "fizzbuzz output differs"

echo "The rewrite compiles the v2 language (prelude + examples, via the code page)"
python3 tools/codepage.py encode < lib/prelude.golfj > "$TMP/pre.gb"
for ex in lists strings vars vectorize capstone; do
  cat "$TMP/pre.gb" <(python3 tools/codepage.py encode < "examples/$ex.golfj") > "$TMP/src.$ex"
  both "$ex" "$TMP/src.$ex"
  o=$("$TMP/old.$ex" 2>/dev/null); n=$("$TMP/new.$ex" 2>/dev/null)
  [ -n "$o" ] && [ "$n" = "$o" ] \
    && ok "prelude + examples/$ex.golfj runs identically" || no "examples/$ex.golfj output"
done

echo "Byte-for-byte agreement: the two compilers emit identical binaries"
for t in hello fizz lists strings vars vectorize capstone; do
  cmp -s "$TMP/old.$t" "$TMP/new.$t" \
    && ok "golf2new == golf2 on $t" \
    || { no "golf2new differs from golf2 on $t"; cmp -l "$TMP/old.$t" "$TMP/new.$t" 2>/dev/null | head -5 | sed 's/^/       /'; }
done

echo "Every compiler op the rewrite implements, exercised through it"
gnew(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) > "$TMP/p.src"
        "$TMP/golf2new" < "$TMP/p.src" > "$TMP/p" 2>/dev/null && chmod +x "$TMP/p" && "$TMP/p"; }
[ "$(printf '%s' '100⍳∑ṄE'          | gnew)" = "4950" ]       && ok "numbers, words, calls, loops" || no "basic"
[ "$(printf '%s' ':d\dbl;5R\refdMQE'| gnew)" = "0 2 4 6 8 " ] && ok "′ ref + quotations"    || no "ref"
[ "$(printf '%s' '“desserts“UVJ'    | gnew)" = "stressed" ]   && ok "“ string literals"     || no "str"
[ "$(printf '%s' '7→a3→b←a←b+←a←b-*N10)' | gnew)" = "40" ]    && ok "→ / ← named variables" || no "vars"
[ "$(printf '%s' '`5 HELLO?)'       | gnew)" = "H" ]          && ok "\` raw blob escape"    || no "blob"
[ "$(printf '%s' "'1)"              | gnew)" = "1" ]          && ok "' char literals"       || no "char lit"

echo "The wave-5 fixpoint (informational — wave 5 owns this, never a gate here)"
"$TMP/golf2new" < "$TMP/cand" > "$TMP/golf2new2" 2>/dev/null && chmod +x "$TMP/golf2new2"
if cmp -s "$TMP/golf2new" "$TMP/golf2new2"; then
  printf '       fixpoint: YES — golf2new compiles its own source to itself, byte for byte;\n'
  printf '                 the wave-5 self-hosting fixpoint already holds.\n'
else
  printf '       fixpoint: no — golf2new(candidate) differs from golf2(candidate):\n'
  cmp -l "$TMP/golf2new" "$TMP/golf2new2" 2>&1 | head -5 | sed 's/^/                 /'
fi

echo
echo "candidate source: $(wc -c < "$TMP/cand") bytes ($(wc -c < "$TMP/cand.enc") of code, $(wc -c < "$TMP/blob.esc") of blob)"
echo "self/golf2.golf:  $(wc -c < self/golf2.golf) bytes"
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
