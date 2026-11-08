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
#   ../SEEDS --pins------> v1c  --compiles--> seed    # logic in v1 GOLF
#                                seed --compiles--> golf2   # logic in v2 GOLF
#   seed and golf2 must emit IDENTICAL bytes for the same input
#
# Nothing here writes into the repo: every binary lives in a temp dir and the
# self/*.golf sources are used exactly as committed.
set -u
cd "$(dirname "$0")/.."
EXP=$(pwd); SEED_ROOT=$(cd "$EXP/.." && pwd)
. "$EXP/tools/seed.sh"
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
# compiler ops (′ “ → ← ⊚ ⊡ ⇒ ⇐, and since M2 the long-name brackets ‹ ›, which
# golf2.golfj's own M2 words are named with) and the atom bytes.  Anything else and the
# compiler could never be built by the seed that bootstraps it.  Checked on the
# encoded source before the splice — the blob is arbitrary raw bytes.
python3 - <<'PY' && ok "golf2.golfj uses only ops the seed can compile" || no "unsupported op byte"
import sys
sys.path.insert(0, "tools")
import codepage, mkblob2
data = codepage.encode(open("self/golf2.golfj", encoding="utf-8").read())
known = {mkblob2.REF_BYTE, mkblob2.STR_BYTE, mkblob2.SET_BYTE, mkblob2.GET_BYTE,
         mkblob2.CHAIN_BYTE, mkblob2.FRAME_BYTE, mkblob2.LSET_BYTE,
         mkblob2.LGET_BYTE, mkblob2.LNAME_BYTE, mkblob2.RNAME_BYTE}
known |= {b for b, _mn, _gl, _tpl, _d in mkblob2.ATOMS}
used = sorted({b for b in data if b >= 0x80})
sys.stderr.write("       high bytes used: "
                 + " ".join(f"{codepage.BYTE2GLYPH.get(b, '?')}(0x{b:02X})" for b in used) + "\n")
sys.exit(1 if set(used) - known else 0)
PY

echo "Walking the ladder: v1c -> seed (v1 GOLF) -> golf2 (v2 GOLF)"
ensure_seed v1c && ok "v1c (pinned release binary, ../SEEDS)" || { no "v1c unavailable"; exit 1; }
"$SEED" < self/seed.golf > "$TMP/seed" 2>/dev/null \
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
both hello examples/v1/hello.golf
[ "$("$TMP/new.hello" 2>/dev/null)" = "Hello, world!" ] \
  && ok "golf2 compiles examples/v1/hello.golf" || no "golf2 hello"
both fizz examples/v1/fizzbuzz.golf
[ "$("$TMP/new.fizz" 2>/dev/null | sed -n '15p')" = "FizzBuzz" ] \
  && ok "golf2 compiles examples/v1/fizzbuzz.golf" || no "golf2 fizzbuzz"
[ "$("$TMP/new.fizz" 2>/dev/null)" = "$("$TMP/old.fizz" 2>/dev/null)" ] \
  && ok "fizzbuzz output matches seed's build exactly" || no "fizzbuzz output differs"

echo "It compiles the v2 language (prelude + examples, via the code page)"
python3 tools/codepage.py encode < lib/prelude.golfj > "$TMP/pre.gb"
printf '\f' >> "$TMP/pre.gb"   # as tools/golfc does: diagnostics count lines from the program (W11-3B)
for ex in lists strings vars vectorize capstone chaindef locals; do
  cat "$TMP/pre.gb" <(python3 tools/codepage.py encode < "examples/$ex.golfj") > "$TMP/src.$ex"
  both "$ex" "$TMP/src.$ex"
  o=$("$TMP/old.$ex" 2>/dev/null); n=$("$TMP/new.$ex" 2>/dev/null)
  [ -n "$o" ] && [ "$n" = "$o" ] \
    && ok "prelude + examples/$ex.golfj runs identically" || no "examples/$ex.golfj output"
done

echo "Byte-for-byte agreement: the two source forms are the same compiler"
# M2: long names — every place one can stand, forward calls and a forward ′,
# mutual recursion — through both source forms.
printf '%s' ':‹square›²;⊚‹mean›∑≢÷;⊡‹hyp›⇒a⇒b⇐a‹square›⇐b‹square›+;:‹even›"[_0^]⊖‹odd›;:‹odd›"[_1^]⊖‹even›;3 4‹hyp›Ṅ5⍳‹mean›Ṅ9‹odd›Ṅ7→‹count›←‹count›Ṅ3⍳′‹square›€⍕4′‹later›⍎Ṅ:‹later›⊕;' \
  | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.longnames"
both longnames "$TMP/src.longnames"
[ "$("$TMP/new.longnames" 2>/dev/null)" = "252070 1 4 5" ] \
  && ok "prelude + a long-name program runs (M2)" || no "long-name program output"

# M-FRAME2 (W9-4D): sized frames — long and one-letter locals mixed, a zero-local
# ⊡ word, early ^ exits patched through the frame-size list, two frame sizes
# calling each other — through both source forms.
printf '%s' '⊡‹sum›"[_0^]⇒‹acc›⇐‹acc›1-‹sum›⇐‹acc›+0[^]9;⊡‹mix›⇒a⇒‹x›⇒b⇐a⇐‹x›-⇐b*⇐a+;⊡‹nil›1+;⊡‹two›⇒‹p›⇒‹q›⇐‹p›‹sum›⇐‹q›‹nil›+;100‹sum›Ṅ␤2 7 3‹mix›Ṅ␤5 10‹two›Ṅ' \
  | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.frames"
both frames "$TMP/src.frames"
[ "$("$TMP/new.frames" 2>/dev/null)" = "$(printf '5050\n-5\n61')" ] \
  && ok "prelude + a sized-frame program runs (M-FRAME2)" || no "sized-frame program output: $("$TMP/new.frames" 2>/dev/null)"

# W12-Z3: one-letter locals past h inside ⊡ — i…z mixed with a and a long
# name, recursing, and all 16 slots as one-letter names — through both.
printf '%s' '⊡‹t›⇒r⇐r[0^]⇐r⇒s⇐s2*⇒a⇐a⇒‹acc›⇐r1-‹t›⇒z⇐z⇐‹acc›+⇐s-;⊡‹w›⇒k⇒l⇒m⇒n⇒o⇒p⇒q⇒r⇒s⇒t⇒u⇒v⇒w⇒x⇒y⇒z⇐k⇐z-⇐q+;100‹t›Ṅ␤1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16‹w›Ṅ' \
  | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.locz"
both locz "$TMP/src.locz"
[ "$("$TMP/new.locz" 2>/dev/null)" = "$(printf '5050\n25')" ] \
  && ok "prelude + one-letter locals i…z in ⊡ words runs (W12-Z3)" || no "i–z locals program output: $("$TMP/new.locz" 2>/dev/null)"

# W10-A: one-byte forward references — calls, ′ and a chain link to words
# defined further down — and a program with 1024 long names (the prelude's
# included), through both source forms.
printf '%s' ':a"0-[_0^]1-b;:b"0-[_1^]1-a;3′d⍎Ṅ⊚mq≢÷;:q∑;5⍳mṄ7aṄ:d⊗;' \
  | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.fwd1"
both fwd1 "$TMP/src.fwd1"
[ "$("$TMP/new.fwd1" 2>/dev/null)" = "621" ] \
  && ok "prelude + one-byte forward references runs (W10-A)" || no "one-byte forward program output"
w10p=$(grep -v '^ *#' lib/prelude.golfj | grep -oE '‹[0-9A-Za-z_-]+›' | sort -u | wc -l | tr -d ' ')
python3 -c 'import sys; n=int(sys.argv[1]); sys.stdout.write("‹v%d›" % n + "".join(":‹v%d›%d→‹v%d›;" % (k, k, k) for k in range(1, n + 1)) + "←‹v%d›Ṅ" % n)' \
  $((1024 - w10p)) | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.names1k"
both names1k "$TMP/src.names1k"
[ "$("$TMP/new.names1k" 2>/dev/null)" = "$((1024 - w10p))" ] \
  && ok "prelude + 1024 long names in all runs (W10-A)" || no "1024 long-name program output"

# W11-2A: ⎘“path“ includes — nested, repeated (include-once) and a file that
# includes itself — through both source forms.  The seed reaches open/dup/dup2
# through its K word (a syscall blob), golf2 through ⎈.
printf '%s' ':‹sq›"*;' | python3 tools/codepage.py encode > "$TMP/inc.sq.g2"
printf '%s' "⎘“$TMP/inc.sq.g2“⎘“$TMP/inc.cube.g2“:‹cube›\"‹sq›*;12" | python3 tools/codepage.py encode > "$TMP/inc.cube.g2"
printf '%s' "⎘“$TMP/inc.cube.g2“‹cube›Ṅ⎘“$TMP/inc.sq.g2“3‹sq›Ṅ" \
  | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.include"
both include "$TMP/src.include"
[ "$("$TMP/new.include" 2>/dev/null)" = "17289" ] \
  && ok "prelude + nested, repeated and self includes run (W11-2A)" || no "include program output"

# W11-4A: ⊜ records — long and one-byte names, a forward call to an accessor,
# a setter — and an include found through vendor/ (the third search place),
# through both source forms.
mkdir -p "$TMP/rec/vendor"
printf '%s' '⊜‹pt›‹x›‹y›;:‹n2›"‹pt-x›²&‹pt-y›²+;' | python3 tools/codepage.py encode > "$TMP/rec/vendor/rpt.g2"
printf '%s' ':‹fy›‹q-b›;⎘“rpt.g2“⊜q a ‹b›;3 4‹pt›‹n2›Ṅ7 8q9‹set-q-a›"‹fy›\\‹q-a›+Ṅ7→‹v›←‹v›Ṅ' \
  | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.records"
( cd "$TMP/rec" && "$TMP/seed" < "$TMP/src.records" > "$TMP/old.records" 2>/dev/null; chmod +x "$TMP/old.records"
  "$TMP/golf2" < "$TMP/src.records" > "$TMP/new.records" 2>/dev/null; chmod +x "$TMP/new.records" )
[ "$("$TMP/new.records" 2>/dev/null)" = "25177" ] \
  && ok "prelude + records and a vendor/ include run (W11-4A)" || no "records program output: $("$TMP/new.records" 2>&1)"

# W12-A7: ⋄ — if-else and the top-tested while, nested in each other and in a
# word, through both source forms (both push the same block tags).
printf '%s' ':s"[_0⋄0≺1+[1⋄2]]Ṅ;0→i{←i4<1+⋄←i2%[“e“⋄“o“]🗲←i1+→i}0s3s0 3-s0→i{←i2<1+⋄0→k{←k2<1+⋄←i←k+Ṅ←k1+→k}←i1+→i}{1⋄9Ṅ}' \
  | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.else"
both else "$TMP/src.else"
[ "$("$TMP/new.else" 2>/dev/null)" = "eoeo0210112" ] \
  && ok "prelude + an if-else / while program runs (W12-A7)" || no "⋄ program output: $("$TMP/new.else" 2>/dev/null)"

# W12-Z2: ⇡ / ⇣ on one-byte and long variables, on a ⊡ word's named local, and
# on a name a ⊡ word has not named (the variable), through both source forms.
printf '%s' '5→x⇡x⇡x⇣x←xṄ0→‹n›⇡‹n›⇡‹n›←‹n›Ṅ⊡f⇒a⇡a⇡a⇣‹n›⇐a;3fṄ←‹n›Ṅ⊡g⇡a←aṄ;9→a g' \
  | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/src.step"
both step "$TMP/src.step"
[ "$("$TMP/new.step" 2>/dev/null)" = "625110" ] \
  && ok "prelude + a ⇡/⇣ program runs (W12-Z2)" || no "⇡⇣ program output: $("$TMP/new.step" 2>/dev/null)"

for t in hello fizz lists strings vars vectorize capstone chaindef locals longnames frames locz fwd1 names1k include records else step; do
  cmp -s "$TMP/old.$t" "$TMP/new.$t" \
    && ok "golf2 == seed on $t" \
    || { no "golf2 differs from seed on $t"; cmp -l "$TMP/old.$t" "$TMP/new.$t" 2>/dev/null | head -5 | sed 's/^/       /'; }
done

# W11-3B: `golf2 -g` only adds the symbol map on fd 2, so it still emits the
# seed's bytes (the seed ignores argv) — over the same corpus.
w113b=""
for t in hello fizz lists strings vars vectorize capstone chaindef locals longnames frames locz fwd1 names1k include else step; do
  case $t in hello) s=examples/v1/hello.golf;; fizz) s=examples/v1/fizzbuzz.golf;; *) s="$TMP/src.$t";; esac
  "$TMP/golf2" -g < "$s" > "$TMP/g.$t" 2> "$TMP/g.$t.map" && cmp -s "$TMP/g.$t" "$TMP/old.$t" || w113b="$w113b $t"
done
[ -z "$w113b" ] && [ "$(grep -c '^‹sq› 0x4' "$TMP/g.include.map")" = 1 ] \
  && ok "golf2 -g == seed on every input above, and the map names the included ‹sq› (W11-3B)" || no "golf2 -g differs from seed on:$w113b"

echo "Both compilers reject an undefined word, with the same status"
# This is the ONE place the two source forms deliberately differ, so it is
# asserted here rather than left to drift.  Both test dict[name] before emitting
# `call rel32` and both exit(2) when it is zero — that is the decision, and it
# has to match or they are not the same compiler.  Only golf2 also writes
# `GOLF: undefined word <name>` to fd 2: seed.golf's source is v1 GOLF, compiled
# by the frozen v1c, whose entire output surface is `)` (one byte to fd 1) and
# `.` (exit), and fd 1 is carrying the binary.  The seed's error path is
# unreachable in the build anyway — its one job is self/golf2.golf, which is
# valid by construction.
cat "$TMP/pre.gb" <(printf '%s' '5qN' | python3 tools/codepage.py encode) > "$TMP/bad.src"
"$TMP/seed"  < "$TMP/bad.src" > "$TMP/bad.old" 2>"$TMP/bad.olderr"; sst=$?
"$TMP/golf2" < "$TMP/bad.src" > "$TMP/bad.new" 2>"$TMP/bad.newerr"; gst=$?
[ "$sst" = 2 ] && [ "$gst" = 2 ] \
  && ok "seed and golf2 both exit 2 on an undefined word" \
  || no "undefined-word status differs (seed $sst, golf2 $gst)"
[ ! -s "$TMP/bad.old" ] && [ ! -s "$TMP/bad.new" ] \
  && ok "neither leaves a partial binary on fd 1" || no "partial binary on rejection"
[ "$(cat "$TMP/bad.newerr")" = "GOLF: undefined word q at line 1" ] && [ ! -s "$TMP/bad.olderr" ] \
  && ok "golf2 explains it on fd 2; the seed, in v1 GOLF, cannot" || no "diagnostic text"
# W9-1C: `′q` reaches the same rejection through X, which hands a name that is
# neither a word nor an atom to `e` — in both source forms.
cat "$TMP/pre.gb" <(printf '%s' '3⍳′q€⍕' | python3 tools/codepage.py encode) > "$TMP/badref.src"
"$TMP/seed"  < "$TMP/badref.src" > "$TMP/badref.old" 2>/dev/null; sst=$?
"$TMP/golf2" < "$TMP/badref.src" > "$TMP/badref.new" 2>"$TMP/badref.newerr"; gst=$?
[ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badref.old" ] && [ ! -s "$TMP/badref.new" ] \
  && [ "$(cat "$TMP/badref.newerr")" = "GOLF: undefined word q at line 1" ] \
  && ok "both reject ′ of an undefined name the same way (W9-1C)" \
  || no "′undefined rejection differs (seed $sst, golf2 $gst)"

# M2: a long name called but never defined is rejected at end of input by both,
# and only golf2 can say which one.
cat "$TMP/pre.gb" <(printf '%s' ':‹f›‹g›;' | python3 tools/codepage.py encode) > "$TMP/badlong.src"
"$TMP/seed"  < "$TMP/badlong.src" > "$TMP/badlong.old" 2>/dev/null; sst=$?
"$TMP/golf2" < "$TMP/badlong.src" > "$TMP/badlong.new" 2>"$TMP/badlong.newerr"; gst=$?
[ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badlong.old" ] && [ ! -s "$TMP/badlong.new" ] \
  && [ "$(cat "$TMP/badlong.newerr")" = "GOLF: undefined word ‹g› at line 1" ] \
  && ok "both reject an undefined long name at end of input (M2)" \
  || no "undefined long name rejection differs (seed $sst, golf2 $gst)"

# W10-A: a one-byte name called (or quoted) but never defined is rejected at end
# of input by both — no longer at the call — and only golf2 can say which.
cat "$TMP/pre.gb" <(printf '%s' ':fq;′r_' | python3 tools/codepage.py encode) > "$TMP/badone.src"
"$TMP/seed"  < "$TMP/badone.src" > "$TMP/badone.old" 2>/dev/null; sst=$?
"$TMP/golf2" < "$TMP/badone.src" > "$TMP/badone.new" 2>"$TMP/badone.newerr"; gst=$?
[ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badone.old" ] && [ ! -s "$TMP/badone.new" ] \
  && [ "$(cat "$TMP/badone.newerr")" = "GOLF: undefined word q at line 1" ] \
  && ok "both reject a one-byte name never defined, at end of input (W10-A)" \
  || no "undefined one-byte name rejection differs (seed $sst, golf2 $gst)"
# W10-A: the 1025th long name is refused by both.
python3 -c 'import sys; sys.stdout.write("".join(":‹v%d›;" % k for k in range(1, int(sys.argv[1]) + 1)))' \
  $((1025 - w10p)) | python3 tools/codepage.py encode | cat "$TMP/pre.gb" - > "$TMP/badmany.src"
"$TMP/seed"  < "$TMP/badmany.src" > "$TMP/badmany.old" 2>/dev/null; sst=$?
"$TMP/golf2" < "$TMP/badmany.src" > "$TMP/badmany.new" 2>"$TMP/badmany.newerr"; gst=$?
[ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badmany.old" ] && [ ! -s "$TMP/badmany.new" ] \
  && [ "$(cat "$TMP/badmany.newerr")" = "GOLF: too many long names ‹v$((1025 - w10p))› at line 1" ] \
  && ok "both refuse the 1025th long name (W10-A)" \
  || no "too-many-long-names rejection differs (seed $sst, golf2 $gst)"

# M-FRAME2 (W9-4D): a 17th local in one ⊡ word is refused by both (16 keep
# every slot a disp8), and only golf2 can say which.
w94d=""; for k in $(seq 1 17); do w94d="$w94d⇒‹l$k›"; done
cat "$TMP/pre.gb" <(printf '%s' "⊡f$w94d;" | python3 tools/codepage.py encode) > "$TMP/badloc.src"
"$TMP/seed"  < "$TMP/badloc.src" > "$TMP/badloc.old" 2>/dev/null; sst=$?
"$TMP/golf2" < "$TMP/badloc.src" > "$TMP/badloc.new" 2>"$TMP/badloc.newerr"; gst=$?
[ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badloc.old" ] && [ ! -s "$TMP/badloc.new" ] \
  && [ "$(cat "$TMP/badloc.newerr")" = "GOLF: too many locals ‹l17› at line 1" ] \
  && ok "both reject a 17th local in one ⊡ word (M-FRAME2)" \
  || no "too-many-locals rejection differs (seed $sst, golf2 $gst)"

# W12-Z3: outside a ⊡ word a one-letter local past h is still refused by both.
cat "$TMP/pre.gb" <(printf '%s' ":f⇒q;" | python3 tools/codepage.py encode) > "$TMP/badlq.src"
"$TMP/seed"  < "$TMP/badlq.src" > "$TMP/badlq.old" 2>/dev/null; sst=$?
"$TMP/golf2" < "$TMP/badlq.src" > "$TMP/badlq.new" 2>"$TMP/badlq.newerr"; gst=$?
[ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badlq.old" ] && [ ! -s "$TMP/badlq.new" ] \
  && [ "$(cat "$TMP/badlq.newerr")" = "GOLF: local out of range q at line 1" ] \
  && ok "both reject ⇒q outside a ⊡ word (W12-Z3)" \
  || no "⇒q-outside-⊡ rejection differs (seed $sst, golf2 $gst)"

# W11-2A: a missing include is refused by both; only golf2 can say which.
cat "$TMP/pre.gb" <(printf '%s' "⎘“$TMP/inc.none.g2“1Ṅ" | python3 tools/codepage.py encode) > "$TMP/badinc.src"
"$TMP/seed"  < "$TMP/badinc.src" > "$TMP/badinc.old" 2>"$TMP/badinc.olderr"; sst=$?
"$TMP/golf2" < "$TMP/badinc.src" > "$TMP/badinc.new" 2>"$TMP/badinc.newerr"; gst=$?
[ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badinc.old" ] && [ ! -s "$TMP/badinc.new" ] && [ ! -s "$TMP/badinc.olderr" ] \
  && [ "$(cat "$TMP/badinc.newerr")" = "GOLF: cannot include $TMP/inc.none.g2 at line 1" ] \
  && ok "both refuse a missing include, exit 2 (W11-2A)" \
  || no "missing-include rejection differs (seed $sst, golf2 $gst)"

# W11-4A: a malformed record header is refused by both; only golf2 can say how.
w114a=""
for w114s in '⊜‹p›;|record without fields ‹p›' '⊜‹p›‹x›|record without ; ‹p›' '⊜‹p›x(;|bad record field (' '⊜(x;|bad record name ('; do
  cat "$TMP/pre.gb" <(printf '%s' "${w114s%%|*}" | python3 tools/codepage.py encode) > "$TMP/badrec.src"
  "$TMP/seed"  < "$TMP/badrec.src" > "$TMP/badrec.old" 2>"$TMP/badrec.olderr"; sst=$?
  "$TMP/golf2" < "$TMP/badrec.src" > "$TMP/badrec.new" 2>"$TMP/badrec.newerr"; gst=$?
  [ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badrec.old" ] && [ ! -s "$TMP/badrec.new" ] && [ ! -s "$TMP/badrec.olderr" ] \
    && [ "$(cat "$TMP/badrec.newerr")" = "GOLF: ${w114s#*|} at line 1" ] || w114a="$w114a [${w114s%%|*}: seed $sst, golf2 $gst]"
done
[ -z "$w114a" ] && ok "both refuse a malformed ⊜ header, exit 2 (W11-4A)" || no "malformed-record rejection differs:$w114a"

# W12-A7: a ⋄ outside [ ] / { }, or twice in one block, is refused by both.
w12a7=""
for w12a7s in '1⋄|⋄ outside [ ] or { }' ':f⋄;|⋄ outside [ ] or { }' '0[1⋄2⋄3]|⋄ twice in one block' '{0⋄1⋄}|⋄ twice in one block'; do
  cat "$TMP/pre.gb" <(printf '%s' "${w12a7s%%|*}" | python3 tools/codepage.py encode) > "$TMP/badelse.src"
  "$TMP/seed"  < "$TMP/badelse.src" > "$TMP/badelse.old" 2>"$TMP/badelse.olderr"; sst=$?
  "$TMP/golf2" < "$TMP/badelse.src" > "$TMP/badelse.new" 2>"$TMP/badelse.newerr"; gst=$?
  [ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badelse.old" ] && [ ! -s "$TMP/badelse.new" ] && [ ! -s "$TMP/badelse.olderr" ] \
    && [ "$(cat "$TMP/badelse.newerr")" = "GOLF: ${w12a7s#*|} at line 1" ] || w12a7="$w12a7 [${w12a7s%%|*}: seed $sst, golf2 $gst]"
done
[ -z "$w12a7" ] && ok "both refuse a stray or second ⋄, exit 2 (W12-A7)" || no "stray-⋄ rejection differs:$w12a7"

# W12-Z2: ⇡ / ⇣ need a letter or a ‹long name› after them; both refuse anything else.
w12z2=""
for w12z2s in '⇡1|⇡ needs a variable' '⇣ x|⇣ needs a variable' '1⇡|⇡ needs a variable' ':f⇡“a“;|⇡ needs a variable'; do
  cat "$TMP/pre.gb" <(printf '%s' "${w12z2s%%|*}" | python3 tools/codepage.py encode) > "$TMP/badstep.src"
  "$TMP/seed"  < "$TMP/badstep.src" > "$TMP/badstep.old" 2>"$TMP/badstep.olderr"; sst=$?
  "$TMP/golf2" < "$TMP/badstep.src" > "$TMP/badstep.new" 2>"$TMP/badstep.newerr"; gst=$?
  [ "$sst" = 2 ] && [ "$gst" = 2 ] && [ ! -s "$TMP/badstep.old" ] && [ ! -s "$TMP/badstep.new" ] && [ ! -s "$TMP/badstep.olderr" ] \
    && [ "$(cat "$TMP/badstep.newerr")" = "GOLF: ${w12z2s#*|} at line 1" ] || w12z2="$w12z2 [${w12z2s%%|*}: seed $sst, golf2 $gst]"
done
[ -z "$w12z2" ] && ok "both refuse ⇡ / ⇣ without a variable, exit 2 (W12-Z2)" || no "⇡⇣ rejection differs:$w12z2"

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
