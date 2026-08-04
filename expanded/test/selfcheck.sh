#!/usr/bin/env bash
# selfcheck.sh — M-SELF: the compiler's own source, written in expanded GOLF.
#
# Since M-SELF the compiler's logic lives in self/golf2.golfj (v2 GOLF: named
# variables, one op per line) and tools/mkblob2.py encodes it into the generated
# self/golf2.golf.  self/seed.golf carries the SAME compiler written in v1 GOLF,
# purely so v1c can bootstrap it.  test/run2.sh's ladder gates the fixpoint
# (golf2 == golf2').  This script gates the two things the ladder cannot see:
#
#   1. The committed generated files are exactly what tools/mkblob2.py emits —
#      self/golf2.golf is a fresh code-page encode of self/golf2.golfj with the
#      blob spliced in at @BLOB@, and both files embed the IDENTICAL blob.
#   2. seed and golf2 are the same compiler written twice, in two different
#      languages, and they emit BYTE-IDENTICAL binaries for every input.  The
#      ladder cannot check this: once seed has produced golf2 it is never
#      consulted again, so a divergence between the two source forms would go
#      unnoticed there.
#
#   golf0.py --compiles--> v1c  --compiles--> seed    # logic in v1 GOLF
#                                seed --compiles--> golf2   # logic in v2 GOLF
#   seed and golf2 must emit IDENTICAL bytes for the same input
#
# Nothing here writes into the repo: every binary lives in a temp dir and the
# self/*.golf sources are used exactly as committed.
set -u
cd "$(dirname "$0")/.."
EXP=$(pwd); MIN="$EXP/../minimal"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "The generated sources are exactly what tools/mkblob2.py emits"
# Regenerating must be a no-op against what is committed: self/golf2.golf is a
# code-page encode of self/golf2.golfj + the spliced blob, nothing more.
python3 - <<'PY' && ok "self/seed.golf == mkblob2.build_seed()" || no "self/seed.golf is stale"
import sys; sys.path.insert(0, "tools"); import mkblob2
sys.exit(0 if mkblob2.build_seed() == open("self/seed.golf","rb").read() else 1)
PY
python3 - <<'PY' && ok "self/golf2.golf == fresh encode of self/golf2.golfj + blob" || no "self/golf2.golf is stale"
import sys; sys.path.insert(0, "tools"); import mkblob2
want, got = mkblob2.build_golf2(), open("self/golf2.golf","rb").read()
if want != got:
    sys.stderr.write(f"       generated {len(want)} bytes, committed {len(got)}\n")
sys.exit(0 if want == got else 1)
PY
# Both compilers must carry the same template table, or "identical bytes" below
# would only mean "identical given different blobs".
python3 - <<'PY' && ok "seed.golf and golf2.golf embed the identical template blob" || no "blobs differ"
import sys; sys.path.insert(0, "tools"); import mkblob2
esc = mkblob2.blob_escape()
sys.stderr.write(f"       blob escape: {len(esc)} bytes\n")
seed, g2 = open("self/seed.golf","rb").read(), open("self/golf2.golf","rb").read()
sys.exit(0 if seed.count(esc) == 1 and g2.count(esc) == 1 else 1)
PY
# The GOLF-written tools under gtools/ cannot read a Python literal, so the code
# page and the template blob are also checked in as data (data/codepage.tsv,
# data/blob.hex), generated from the same tables by tools/mktables.py.  Nothing
# on the build path reads them, so only this check can notice when an atom is
# added to mkblob2.ATOMS and the data files are not regenerated — at which point
# every gtools/ program would silently be working from a stale code page.
python3 - <<'PY' && ok "data/codepage.tsv + data/blob.hex == mktables.py's output" || no "a data/ table is stale"
import sys; sys.path.insert(0, "tools"); import mktables
bad = [n for n, build in mktables.OUTPUTS
       if build() != open("data/" + n, "rb").read()]
for n in bad:
    sys.stderr.write(f"       data/{n} differs — run: python3 tools/mktables.py\n")
sys.exit(1 if bad else 0)
PY
# Only ops the SEED can compile may appear in golf2.golf's code: ASCII, plus the
# four compiler prefixes (′ “ → ←) and the atom bytes.  Anything else and the
# compiler could never be built by the seed that bootstraps it.  Checked on the
# encoded source before the splice — the blob is arbitrary raw bytes.
python3 - <<'PY' && ok "golf2.golfj uses only ops the seed can compile" || no "unsupported op byte"
import sys
sys.path.insert(0, "tools")
import codepage, mkblob2
data = codepage.encode(open("self/golf2.golfj", encoding="utf-8").read())
known = {mkblob2.REF_BYTE, mkblob2.STR_BYTE, mkblob2.SET_BYTE, mkblob2.GET_BYTE,
         mkblob2.CHAIN_BYTE}
known |= {b for b, _mn, _gl, _tpl, _d in mkblob2.ATOMS}
used = sorted({b for b in data if b >= 0x80})
sys.stderr.write("       high bytes used: "
                 + " ".join(f"{codepage.BYTE2GLYPH.get(b, '?')}(0x{b:02X})" for b in used) + "\n")
sys.exit(1 if set(used) - known else 0)
PY

echo "Walking the ladder: v1c -> seed (v1 GOLF) -> golf2 (v2 GOLF)"
python3 "$MIN/boot/golf0.py" < "$MIN/self/golf.golf" > "$TMP/v1c" 2>/dev/null \
  && chmod +x "$TMP/v1c" && ok "golf0.py compiles minimal/self/golf.golf -> v1c" || no "build v1c"
"$TMP/v1c" < self/seed.golf > "$TMP/seed" 2>/dev/null \
  && chmod +x "$TMP/seed" && [ -s "$TMP/seed" ] \
  && ok "v1c compiles self/seed.golf -> seed ($(wc -c < "$TMP/seed") bytes)" || no "build seed"
"$TMP/seed" < self/golf2.golf > "$TMP/golf2" 2>/dev/null \
  && chmod +x "$TMP/golf2" && [ -s "$TMP/golf2" ] \
  && ok "seed compiles self/golf2.golf -> golf2 ($(wc -c < "$TMP/golf2") bytes)" || no "build golf2"

# --------------------------------------------------------------------------
# Everything below compares golf2 (logic in v2 GOLF) against seed (the same
# logic in v1 GOLF) on real inputs.  Behaviour first (does the compiled program
# do the right thing), then the much stronger claim: the two compilers emit the
# SAME BYTES.
# --------------------------------------------------------------------------
both(){ # both <name> <source file> — compile with each compiler, require identity
  "$TMP/seed"  < "$2" > "$TMP/old.$1" 2>/dev/null; chmod +x "$TMP/old.$1"
  "$TMP/golf2" < "$2" > "$TMP/new.$1" 2>/dev/null; chmod +x "$TMP/new.$1"
}

echo "The v2-GOLF compiler still compiles all of v1"
both hello "$MIN/examples/hello.golf"
[ "$("$TMP/new.hello" 2>/dev/null)" = "Hello, world!" ] \
  && ok "golf2 compiles minimal/examples/hello.golf" || no "golf2 hello"
both fizz "$MIN/examples/fizzbuzz.golf"
[ "$("$TMP/new.fizz" 2>/dev/null | sed -n '15p')" = "FizzBuzz" ] \
  && ok "golf2 compiles minimal/examples/fizzbuzz.golf" || no "golf2 fizzbuzz"
[ "$("$TMP/new.fizz" 2>/dev/null)" = "$("$TMP/old.fizz" 2>/dev/null)" ] \
  && ok "fizzbuzz output matches seed's build exactly" || no "fizzbuzz output differs"

echo "It compiles the v2 language (prelude + examples, via the code page)"
python3 tools/codepage.py encode < lib/prelude.golfj > "$TMP/pre.gb"
for ex in lists strings vars vectorize capstone chaindef; do
  cat "$TMP/pre.gb" <(python3 tools/codepage.py encode < "examples/$ex.golfj") > "$TMP/src.$ex"
  both "$ex" "$TMP/src.$ex"
  o=$("$TMP/old.$ex" 2>/dev/null); n=$("$TMP/new.$ex" 2>/dev/null)
  [ -n "$o" ] && [ "$n" = "$o" ] \
    && ok "prelude + examples/$ex.golfj runs identically" || no "examples/$ex.golfj output"
done

echo "Byte-for-byte agreement: the two source forms are the same compiler"
for t in hello fizz lists strings vars vectorize capstone chaindef; do
  cmp -s "$TMP/old.$t" "$TMP/new.$t" \
    && ok "golf2 == seed on $t" \
    || { no "golf2 differs from seed on $t"; cmp -l "$TMP/old.$t" "$TMP/new.$t" 2>/dev/null | head -5 | sed 's/^/       /'; }
done

echo "Every compiler op the v2-GOLF source implements, exercised through it"
gnew(){ cat "$TMP/pre.gb" <(python3 tools/codepage.py encode) > "$TMP/p.src"
        "$TMP/golf2" < "$TMP/p.src" > "$TMP/p" 2>/dev/null && chmod +x "$TMP/p" && "$TMP/p"; }
[ "$(printf '%s' '100⍳∑ṄE'          | gnew)" = "4950" ]       && ok "numbers, words, calls, loops" || no "basic"
[ "$(printf '%s' ':d\dbl;5R\refdMQE'| gnew)" = "0 2 4 6 8 " ] && ok "′ ref + quotations"    || no "ref"
[ "$(printf '%s' '“desserts“UVJ'    | gnew)" = "stressed" ]   && ok "“ string literals"     || no "str"
[ "$(printf '%s' '7→a3→b←a←b+←a←b-*N10)' | gnew)" = "40" ]    && ok "→ / ← named variables" || no "vars"
[ "$(printf '%s' '⊚m∑≢÷;5⍳mṄ'      | gnew)" = "2" ]           && ok "⊚ chain definitions"  || no "chain"
[ "$(printf '%s' '`5 HELLO?)'       | gnew)" = "H" ]          && ok "\` raw blob escape"    || no "blob"
[ "$(printf '%s' "'1)"              | gnew)" = "1" ]          && ok "' char literals"       || no "char lit"

echo
echo "self/golf2.golfj: $(wc -c < self/golf2.golfj) bytes of hand-written v2 GOLF"
echo "self/golf2.golf:  $(wc -c < self/golf2.golf) bytes (generated: encoded source + blob)"
echo "self/seed.golf:   $(wc -c < self/seed.golf) bytes (generated: the v1-GOLF bootstrap rung)"
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
