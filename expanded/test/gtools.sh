#!/usr/bin/env bash
# gtools.sh — the differential suite for the GOLF-written build tools (M-TOOL).
#
# Everything under gtools/ is a second implementation of a Python tool that
# already exists.  That is the whole safety story: the Python version stays the
# build path and the source of truth, and the GOLF version is trusted exactly as
# far as it produces BYTE-IDENTICAL output on real input.  Same relationship
# boot/golfref.py has to the compiler — an oracle off the bootstrap ladder.
#
# So every case here has the same shape:
#
#     GOLF tool < real repo file   ==   python3 tool < the same file
#
# "Real repo file" matters.  A hand-written fixture would only prove the tool
# handles what its author thought of; lib/prelude.golfj, self/golf2.golfj and
# examples/*.golfj between them contain every glyph, every mnemonic, the raw
# blob escape, string literals and comments — the actual surface.
#
# Nothing here writes into the repo: tools emit to $TMP and are compared there.
#
#   bash test/gtools.sh          (also run by CI, after run2.sh and selfcheck.sh)
set -u
cd "$(dirname "$0")/.."
EXP=$(pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

# The real sources every filter is checked against.
CORPUS="lib/prelude.golfj self/golf2.golfj $(echo examples/*.golfj)"

# build <prog.golfj> <name> — compile a tool, or report why not.  Returns 1 and
# records a failure if the tool does not build, so a broken tool is a red test
# rather than a silently skipped one.
build(){
  if [ ! -e "$1" ]; then return 2; fi          # not implemented yet: skipped
  gtools/build "$1" "$TMP/$2" 2>"$TMP/$2.err" && return 0
  no "$2 does not compile"; sed 's/^/       /' "$TMP/$2.err" | head -5; return 1
}

# diff_filter <name> <python-command...> — run the GOLF tool and the Python tool
# over the whole corpus and require byte-identical output for every file.
diff_filter(){
  name=$1; shift
  bad=""
  for f in $CORPUS; do
    "$TMP/$name" < "$f" > "$TMP/g.out" 2>/dev/null
    "$@"         < "$f" > "$TMP/p.out" 2>/dev/null
    cmp -s "$TMP/g.out" "$TMP/p.out" || bad="$bad $f"
  done
  [ -z "$bad" ] && ok "$name matches its Python counterpart on every source" \
                || { no "$name differs on:$bad"; }
}

echo "GOLF-written build tools vs the Python originals (M-TOOL)"

# Wave 3 of M-TOOL fills these in parallel — one tool per agent.  They are
# spaced out on purpose: git merges two inserts cleanly only when the hunks do
# not share context lines.  Work under your own anchor only.

# @@ W8-HEXCAT @@

# @@ W8-ENCODE @@

# @@ W8-DECODE @@

# @@ W8-MKBLOB @@

# @@ W8-MKGOLF2 @@

# gtools/mkgolf2 — the capstone.  It is the THIRD stage of a pipeline,
#
#   gtools/encode < self/golf2.golfj | gtools/mkgolf2 BLOB-ESC > self/golf2.golf
#
# and does the splice and nothing else, so it is checked against
# mkblob2.build_golf2() with the other two stages supplied by PYTHON.  That is
# the shadow architecture used rather than merely tested: because each stage's
# two implementations are byte-identical, either one may stand in for the other,
# which is also what let this tool be written and verified while gtools/encode
# and gtools/mkblob were still being authored alongside it.
#
# Three claims, each stronger than the last: the same bytes as the Python
# function, the same bytes as the committed artifact, and — the real one — a
# compiler source produced by a GOLF program that still reaches the fixpoint.
if build gtools/mkgolf2.golfj gmkgolf2; then
  python3 - "$TMP" <<'PY'
import sys
sys.path.insert(0, "tools")
import mkblob2
t = sys.argv[1]
open(t + "/blob.esc", "wb").write(mkblob2.blob_escape())
open(t + "/g2.py",    "wb").write(mkblob2.build_golf2())
PY
  python3 tools/codepage.py encode < self/golf2.golfj > "$TMP/g2.enc"

  "$TMP/gmkgolf2" "$TMP/blob.esc" < "$TMP/g2.enc" > "$TMP/g2.golf" 2>"$TMP/g2.err"
  n=$(wc -c < "$TMP/g2.golf" | tr -d ' ')
  cmp -s "$TMP/g2.golf" "$TMP/g2.py" \
    && ok "mkgolf2 == mkblob2.build_golf2(), $n bytes" \
    || { no "mkgolf2 differs from mkblob2.build_golf2()"; sed 's/^/       /' "$TMP/g2.err"; }

  # The committed artifact itself — the file every rung of the ladder is built
  # from.  Regenerating it is the point of the tool; note that it is compared in
  # $TMP and NEVER written back into the repo.
  cmp -s "$TMP/g2.golf" self/golf2.golf \
    && ok "mkgolf2 reproduces the committed self/golf2.golf byte for byte" \
    || no "mkgolf2 output differs from self/golf2.golf"

  # The strongest form: compile the GOLF-generated source with the bootstrapped
  # golf2, then compile self/golf2.golf with the result, and require the two
  # binaries to be identical.  A compiler source produced by a GOLF program has
  # to reach golf2 == golf2' or it is not the compiler source.
  if build/golf2 < "$TMP/g2.golf" > "$TMP/g2a" 2>/dev/null && chmod +x "$TMP/g2a" \
     && "$TMP/g2a" < self/golf2.golf > "$TMP/g2b" 2>/dev/null && chmod +x "$TMP/g2b" \
     && [ -s "$TMP/g2a" ] && cmp -s "$TMP/g2a" "$TMP/g2b"; then
    ok "the compiler built from mkgolf2's output self-hosts (golf2 == golf2')"
  else
    no "mkgolf2's output does not reach the golf2 == golf2' fixpoint"
  fi

  # Raw-byte plumbing, over a stream long enough to cross tio's 8192-byte output
  # buffer several times: NULs, 0x8E (the string delimiter) and 0x23 ('#') on
  # both sides of the marker must all pass through untouched, since the splice
  # happens after encoding precisely so that nothing interprets them.
  python3 - "$TMP" <<'PY'
import sys
t = sys.argv[1]
head = bytes(range(256)) * 100
tail = b"#\x8e\x00 tail #\n" * 500
blob = open(t + "/blob.esc", "rb").read()
open(t + "/big.in",  "wb").write(head + b"@BLOB@" + tail)
open(t + "/big.py",  "wb").write(head + blob     + tail)
PY
  "$TMP/gmkgolf2" "$TMP/blob.esc" < "$TMP/big.in" > "$TMP/big.out" 2>/dev/null
  cmp -s "$TMP/big.out" "$TMP/big.py" \
    && ok "mkgolf2 passes NULs and code bytes through, across buffer flushes" \
    || no "mkgolf2 corrupts a raw byte stream"

  # The marker count is checked, and a bad count writes NOTHING.  mkblob2 raises
  # SystemExit naming the count; this names it too, on fd 2, and exits 1.  A
  # tool that emitted a half-spliced self/golf2.golf would poison the next
  # bootstrap, so "no output at all" is as much of the contract as the status.
  printf 'no marker anywhere in here' > "$TMP/mg0.in"
  "$TMP/gmkgolf2" "$TMP/blob.esc" < "$TMP/mg0.in" > "$TMP/mg0.out" 2>"$TMP/mg0.err"
  st=$?
  { [ "$st" = 1 ] && [ ! -s "$TMP/mg0.out" ] \
    && grep -q 'mkgolf2: expected exactly one @BLOB@ marker' "$TMP/mg0.err" \
    && grep -q 'found 0' "$TMP/mg0.err"; } \
    && ok "mkgolf2: no marker is fatal (exit 1, 'found 0', nothing written)" \
    || no "mkgolf2: no marker not reported (exit $st)"

  printf 'aa@BLOB@bb@BLOB@cc' > "$TMP/mg2.in"
  "$TMP/gmkgolf2" "$TMP/blob.esc" < "$TMP/mg2.in" > "$TMP/mg2.out" 2>"$TMP/mg2.err"
  st=$?
  { [ "$st" = 1 ] && [ ! -s "$TMP/mg2.out" ] \
    && grep -q 'found 2' "$TMP/mg2.err"; } \
    && ok "mkgolf2: two markers is fatal (exit 1, 'found 2', nothing written)" \
    || no "mkgolf2: two markers not reported (exit $st)"

  # The pipe joint itself, once gtools/encode lands: the same artifact with the
  # first stage supplied by GOLF instead of codepage.py.  Only `encode` is
  # driven here, because it is the stage that feeds this one's STDIN and so is
  # the only joint this tool can get wrong.  gtools/mkblob is deliberately not
  # invoked: its whole contract is "the bytes blob_escape() returns", the
  # W8-MKBLOB case above proves it, and reading those bytes from Python instead
  # tests the same composition without this file having to guess a sibling's
  # command line.  Absent gtools/encode, the case simply does not appear — which
  # is the state this tool was developed and first verified in.
  if [ -e gtools/encode.golfj ] && gtools/build gtools/encode.golfj "$TMP/xenc" >/dev/null 2>&1; then
    "$TMP/xenc" < self/golf2.golfj > "$TMP/x.enc" 2>/dev/null
    "$TMP/gmkgolf2" "$TMP/blob.esc" < "$TMP/x.enc" > "$TMP/x.golf" 2>/dev/null
    cmp -s "$TMP/x.golf" self/golf2.golf \
      && ok "encode | mkgolf2 rebuilds self/golf2.golf end to end" \
      || no "the encode | mkgolf2 pipeline does not rebuild self/golf2.golf"
  fi
fi

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
