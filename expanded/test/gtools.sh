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
# mkblob is the one tool here whose Python counterpart is not a subcommand but a
# function, so the oracle is a one-line `python3 -c` rather than diff_filter —
# and its input is the one file in the repo it was written for, which is why it
# is checked BOTH ways round: as `gmkblob data/blob.hex` and as a bare filter.
if build gtools/mkblob.golfj gmkblob; then
  python3 -c 'import sys; sys.path.insert(0,"tools"); import mkblob2; sys.stdout.buffer.write(mkblob2.blob_escape())' > "$TMP/mkblob.py.out"

  "$TMP/gmkblob" data/blob.hex > "$TMP/mkblob.arg.out" 2>"$TMP/mkblob.arg.err"
  cmp -s "$TMP/mkblob.arg.out" "$TMP/mkblob.py.out" \
    && ok "mkblob data/blob.hex == mkblob2.blob_escape() ($(wc -c < "$TMP/mkblob.py.out" | tr -d ' ') bytes)" \
    || { no "mkblob data/blob.hex differs from mkblob2.blob_escape()"; sed 's/^/       /' "$TMP/mkblob.arg.err" | head -3; }

  "$TMP/gmkblob" < data/blob.hex > "$TMP/mkblob.in.out" 2>/dev/null
  cmp -s "$TMP/mkblob.in.out" "$TMP/mkblob.py.out" \
    && ok "mkblob as a bare stdin filter emits the same bytes" \
    || no "mkblob as a bare stdin filter differs from mkblob2.blob_escape()"

  # The claim worth making.  The escape this tool emits is the exact text
  # self/golf2.golf embeds, so splice it in at @BLOB@ the way build_golf2() does
  # and the result must be the committed file byte for byte — after which the
  # `golf2 == golf2'` fixpoint below is a statement about a compiler whose
  # template blob was assembled by GOLF.
  python3 - "$TMP/mkblob.arg.out" "$TMP/golf2.golf" <<'PY'
import sys
sys.path.insert(0, "tools")
import codepage, mkblob2
enc = codepage.encode(open("self/golf2.golfj", encoding="utf-8").read())
assert enc.count(mkblob2.BLOB_MARKER) == 1
esc = open(sys.argv[1], "rb").read()
open(sys.argv[2], "wb").write(enc.replace(mkblob2.BLOB_MARKER, esc))
PY
  cmp -s "$TMP/golf2.golf" self/golf2.golf \
    && ok "self/golf2.golfj spliced with mkblob's escape == the committed self/golf2.golf" \
    || no "mkblob's escape spliced into self/golf2.golfj does not reproduce self/golf2.golf"

  if build/golf2 < "$TMP/golf2.golf" > "$TMP/golf2.bin" 2>/dev/null \
     && chmod +x "$TMP/golf2.bin" \
     && "$TMP/golf2.bin" < "$TMP/golf2.golf" > "$TMP/golf2.bin2" 2>/dev/null \
     && cmp -s "$TMP/golf2.bin" "$TMP/golf2.bin2"; then
    ok "the compiler carrying mkblob's blob reaches golf2 == golf2'"
  else
    no "the compiler carrying mkblob's blob does not reach the fixpoint"
  fi

  # Corruption.  A build tool that emitted a subtly wrong blob would poison the
  # next bootstrap, so every case here must exit non-zero, say why on fd 2, and
  # leave stdout EMPTY — half a blob still looks like a file.
  bad_mkblob(){
    printf '%b' "$2" > "$TMP/mkblob.bad"
    "$TMP/gmkblob" "$TMP/mkblob.bad" > "$TMP/mkblob.bad.out" 2>"$TMP/mkblob.bad.err"
    st=$?
    if [ "$st" = 1 ] && [ ! -s "$TMP/mkblob.bad.out" ] && grep -q "$3" "$TMP/mkblob.bad.err"; then
      ok "mkblob rejects $1"
    else
      no "mkblob mishandles $1 (exit $st): $(cat "$TMP/mkblob.bad.err")"
    fi
  }
  bad_mkblob "a truncated record line"     '01 03 AA BB\n'        'length byte disagrees'
  bad_mkblob "a length byte that lies"     '01 02 AA BB CC\n'     'length byte disagrees'
  bad_mkblob "a trailing space"            '01 01 AA \n'          'not space-separated hex pairs'
  bad_mkblob "a non-hex digit"             '01 03 AA GG CC\n'     'not a pair of hex digits'
  bad_mkblob "a tab between hex pairs"     '01 01 AA\t01 01 BB\n' 'exactly one space'
  bad_mkblob "a duplicate record key"      '01 01 AA\n01 01 BB\n' 'duplicate record key'
  bad_mkblob "a 0 key"                     '00 01 AA\n'           'key 0 is the sentinel'
  bad_mkblob "a line with no length byte"  'A3\n'                 'shorter than a key'
  bad_mkblob "an input with no records"    '# only a comment\n'   'no records'

  # `gmkblob in.hex out.bin` is the mistake the argument form invites, and
  # ignoring the second word would put the blob on the terminal and look fine.
  "$TMP/gmkblob" data/blob.hex "$TMP/mkblob.nope" > "$TMP/mkblob.two.out" 2>"$TMP/mkblob.two.err"
  st=$?
  if [ "$st" = 1 ] && [ ! -s "$TMP/mkblob.two.out" ] && [ ! -e "$TMP/mkblob.nope" ]; then
    ok "mkblob refuses a second argument instead of treating it as an output path"
  else
    no "mkblob accepted a second argument (exit $st)"
  fi
fi


# @@ W8-MKGOLF2 @@

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
