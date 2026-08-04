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
# decode's INPUT is raw code-page bytes and $CORPUS is .golfj source, which is
# decode's OUTPUT — so diff_filter cannot be used as it stands.  The corpus is
# encoded by the Python first, and three inputs that are not encoded source at
# all are added: data/blob.hex (plain ASCII with no atom byte in it),
# self/golf2.golf (a real compiled artifact, so arbitrary high bytes) and all
# 256 byte values in order, which is what exercises the \xNN fallback and every
# encode-only row at once.
if build gtools/decode.golfj gdecode; then
  mkdir -p "$TMP/dec"
  for f in $CORPUS; do
    python3 tools/codepage.py encode < "$f" > "$TMP/dec/$(echo "$f" | tr / _).gb"
  done
  python3 -c 'import sys;sys.stdout.buffer.write(bytes(range(256)))' > "$TMP/dec/all256.bin"
  cp data/blob.hex "$TMP/dec/blob.hex.bin"; cp self/golf2.golf "$TMP/dec/golf2.golf.bin"
  bad=""; badm=""
  for f in "$TMP"/dec/*; do
    "$TMP/gdecode"                 < "$f" > "$TMP/g.out" 2>/dev/null
    python3 tools/codepage.py decode < "$f" > "$TMP/p.out" 2>/dev/null
    cmp -s "$TMP/g.out" "$TMP/p.out" || bad="$bad $(basename "$f")"
    "$TMP/gdecode" -m                 < "$f" > "$TMP/g.out" 2>/dev/null
    python3 tools/codepage.py decode -m < "$f" > "$TMP/p.out" 2>/dev/null
    cmp -s "$TMP/g.out" "$TMP/p.out" || badm="$badm $(basename "$f")"
  done
  [ -z "$bad" ]  && ok "gdecode matches codepage.py decode on every encoded source" \
                 || no "gdecode differs on:$bad"
  [ -z "$badm" ] && ok "gdecode -m matches codepage.py decode -m on the same inputs" \
                 || no "gdecode -m differs on:$badm"
  # The \xNN fallback, pinned as text rather than left implicit in the sweep
  # above: NUL and 0xFF have no ED row and are not printable, and the hex is
  # UPPERCASE.  0x52 next to them is the asymmetry — ⍳ and \range encode to it,
  # and it still decodes as the plain letter R.
  [ "$(printf '\000R\377' | "$TMP/gdecode")" = '\x00R\xFF' ] \
    && ok "gdecode: \\xNN fallback is uppercase, and 0x52 stays a plain R" \
    || no "gdecode \\xNN fallback"
  # run2.sh asserts that the code page round-trips for examples/atoms.golfj
  # (decode -m | encode | cmp).  Same assertion with the GOLF decoder in the
  # middle, over the whole corpus: what it produces is real source that the
  # Python encoder reads back to the very bytes it was handed.
  rt=""
  for f in "$TMP"/dec/*.gb; do
    "$TMP/gdecode" -m < "$f" | python3 tools/codepage.py encode 2>/dev/null \
      | cmp -s - "$f" || rt="$rt $(basename "$f")"
  done
  [ -z "$rt" ] && ok "gdecode -m | codepage.py encode reproduces the input bytes" \
               || no "gdecode round trip differs on:$rt"
fi

# @@ W8-MKBLOB @@

# @@ W8-MKGOLF2 @@

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
