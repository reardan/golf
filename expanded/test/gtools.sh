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
if build gtools/encode.golfj gencode; then
  diff_filter gencode python3 tools/codepage.py encode

  # The path to data/codepage.tsv.  With no argument the tool reads it from the
  # working directory, which is what lets diff_filter above run it as a bare
  # stdin->stdout filter exactly like the Python; argv[1] overrides that, and
  # is the only way to run it from anywhere else.  Both directions are checked
  # here, because the default alone would pass every test above while the tool
  # was in fact unusable outside expanded/.
  python3 tools/codepage.py encode < examples/lists.golfj > "$TMP/argv.py"
  ( cd "$TMP" && "$TMP/gencode" "$EXP/data/codepage.tsv" ) \
      < examples/lists.golfj > "$TMP/argv.golf" 2>/dev/null
  cmp -s "$TMP/argv.golf" "$TMP/argv.py" \
    && ok "gencode takes the table's path from argv[1]" \
    || no "gencode ignores or mishandles argv[1]"
  ( cd "$TMP" && "$TMP/gencode" ) < examples/lists.golfj \
      >/dev/null 2>"$TMP/nopath.err"
  st=$?
  [ "$st" = 1 ] && grep -q 'code-page table' "$TMP/nopath.err" \
    && ok "gencode without argv[1], outside expanded/: names the missing table" \
    || no "gencode outside expanded/ (status $st): $(head -1 "$TMP/nopath.err")"

  # The two fatal cases.  codepage.py raises SystemExit, i.e. one line on stderr
  # and status 1, having written nothing at all to stdout; a build script that
  # sailed past a bad source would poison whatever it wrote next.  The unknown
  # mnemonic reproduces Python's message text exactly (it is built from the
  # input buffer, backslash and all); the not-in-the-code-page one deliberately
  # does not — Python names the character and its code point, which needs a
  # UTF-8 decoder and Python's repr rules, so the GOLF tool names the byte.
  printf '1 \\zzz 2' > "$TMP/badmn"
  "$TMP/gencode" < "$TMP/badmn" > "$TMP/badmn.out" 2>"$TMP/badmn.err"
  st=$?
  python3 tools/codepage.py encode < "$TMP/badmn" >/dev/null 2>"$TMP/badmn.pyerr"
  [ "$st" = 1 ] && [ ! -s "$TMP/badmn.out" ] \
    && cmp -s "$TMP/badmn.err" "$TMP/badmn.pyerr" \
    && ok "gencode: unknown mnemonic -> exit 1, Python's message on stderr" \
    || no "gencode unknown mnemonic (status $st): $(head -1 "$TMP/badmn.err")"
  printf 'a\303\251b' > "$TMP/badch"
  "$TMP/gencode" < "$TMP/badch" > "$TMP/badch.out" 2>"$TMP/badch.err"
  st=$?
  [ "$st" = 1 ] && [ ! -s "$TMP/badch.out" ] \
    && grep -q 'not in the code page' "$TMP/badch.err" \
    && ok "gencode: a character outside the code page -> exit 1 on stderr" \
    || no "gencode non-code-page char (status $st): $(head -1 "$TMP/badch.err")"

  # The claim byte-identity is really standing in for.  Encode the COMPILER's
  # own source with the GOLF tool, splice the template blob in the way
  # mkblob2.build_golf2() does — after encoding, into the raw byte stream, since
  # a `#` inside the blob would otherwise eat a "line" — and put the result back
  # on the ladder.  build/golf2 is the compiler the ladder converged on, so
  # rebuilding it from the GOLF-encoded source and getting the same bytes IS the
  # golf2 == golf2' fixpoint, reached through this tool.
  "$TMP/gencode" < self/golf2.golfj > "$TMP/g2.enc" 2>/dev/null
  python3 - "$TMP/g2.enc" "$TMP/g2.golf" <<'SPLICE'
import sys; sys.path.insert(0, "tools")
import mkblob2
enc = open(sys.argv[1], "rb").read()
assert enc.count(b"@BLOB@") == 1, "the marker did not survive encoding"
open(sys.argv[2], "wb").write(enc.replace(b"@BLOB@", mkblob2.blob_escape()))
SPLICE
  cmp -s "$TMP/g2.golf" self/golf2.golf \
    && ok "gencode + the blob splice reproduces self/golf2.golf byte for byte" \
    || no "gencode + the blob splice differs from self/golf2.golf"
  build/golf2 < "$TMP/g2.golf" > "$TMP/g2" 2>/dev/null && chmod +x "$TMP/g2"
  cmp -s "$TMP/g2" build/golf2 \
    && ok "a GOLF-encoded compiler source still reaches the fixpoint" \
    || no "the GOLF-encoded self/golf2.golf does not rebuild golf2"
fi

# @@ W8-DECODE @@

# @@ W8-MKBLOB @@

# @@ W8-MKGOLF2 @@

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
