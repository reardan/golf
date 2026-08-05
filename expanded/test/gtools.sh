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
# hexcat is the one tool here with NO Python counterpart, so diff_filter cannot
# apply to it.  Three other oracles do, and together they are stronger than one
# differential would have been:
#   * a ROUND TRIP — decode then encode must reproduce a real binary byte for
#     byte, the compiler itself included.  On its own that would be weak (a
#     reader and a writer wrong in mirrored ways still round-trip), hence:
#   * the BLOB — data/blob.hex is a hex dump whose bytes Python already knows,
#     so `hexcat encode` over it is checked against mkblob2.build_blob2()
#     directly.  That pins the reader to an external truth;
#   * the exact OUTPUT TEXT and line shape, which pins the writer.
# Then every error path, since hexcat is also where the tio error policy (fd 2,
# non-zero status, nothing on stdout) gets exercised for the first time.
if build gtools/hexcat.golfj hexcat; then
  HC=$TMP/hexcat

  bad=""
  for f in build/golf2 self/golf2.golf self/seed.golf data/blob.hex \
           lib/prelude.golfj "$TMP/hexcat"; do
    "$HC" decode < "$f" > "$TMP/h.hex" 2>/dev/null &&
    "$HC" encode < "$TMP/h.hex" > "$TMP/h.bin" 2>/dev/null &&
    cmp -s "$f" "$TMP/h.bin" || bad="$bad $f"
  done
  [ -z "$bad" ] && ok "hexcat: bin -> hex -> bin is byte-identical (golf2 and hexcat itself included)" \
                || no "hexcat: the round trip differs on:$bad"

  # The blob minus its 0 sentinel, which data/blob.hex deliberately omits.
  python3 -c 'import sys; sys.path.insert(0, "tools"); import mkblob2
sys.stdout.buffer.write(mkblob2.build_blob2()[:-1])' > "$TMP/h.blob.py" 2>/dev/null
  "$HC" encode < data/blob.hex > "$TMP/h.blob.golf" 2>/dev/null
  cmp -s "$TMP/h.blob.py" "$TMP/h.blob.golf" \
    && ok "hexcat encode < data/blob.hex is exactly mkblob2's template blob" \
    || no "hexcat encode < data/blob.hex is not the blob mkblob2 builds"

  # These four bytes are chosen to put a digit AND a letter in each of the two
  # nibble positions, so a broken high or low nibble cannot hide behind the
  # other one — the conversion is branchless and the branch is the 9-to-A step.
  printf '\000\017\245\377' | "$HC" decode > "$TMP/h.out" 2>/dev/null
  printf '00 0F A5 FF\n' > "$TMP/h.want"
  cmp -s "$TMP/h.out" "$TMP/h.want" \
    && ok "hexcat decode writes uppercase space-separated pairs, newline-terminated" \
    || no "hexcat decode output is not the documented format"

  # 33 bytes is 16 + 16 + 1: two full lines of 47 columns and a short one of 2.
  shape=$(head -c 33 /dev/zero | "$HC" decode 2>/dev/null | awk '{print length($0)}' | tr '\n' ' ')
  [ "$shape" = "47 47 2 " ] \
    && ok "hexcat decode breaks lines every 16 bytes with no trailing space" \
    || no "hexcat decode line shape is [$shape], want [47 47 2 ]"

  : > "$TMP/h.in"
  "$HC" decode < "$TMP/h.in" > "$TMP/h.out" 2>/dev/null; s1=$?
  "$HC" encode < "$TMP/h.in" > "$TMP/h.out2" 2>/dev/null; s2=$?
  { [ "$s1" = 0 ] && [ "$s2" = 0 ] && [ ! -s "$TMP/h.out" ] && [ ! -s "$TMP/h.out2" ]; } \
    && ok "hexcat: empty input is empty output in both directions" \
    || no "hexcat mishandles empty input"

  printf '# a comment header\n4a\t4B\r\n 4c\n' | "$HC" encode > "$TMP/h.out" 2>/dev/null
  [ "$(cat "$TMP/h.out")" = "JKL" ] \
    && ok "hexcat encode skips whitespace and # comments and takes either digit case" \
    || no "hexcat encode does not skip whitespace/comments as documented"

  # Every one of these must exit non-zero, write no stdout, and say the RIGHT
  # thing on fd 2.  Matching the message and not merely "something on stderr"
  # is what separates the two malformed-hex cases: drop the bounds check that
  # makes a trailing half-byte an error and `l` reads one byte past the buffer,
  # which usually still fails — with the other message, and only by luck.
  err=""
  hcbad(){ lbl=$1; want=$2; shift 2
    "$HC" "$@" < "$TMP/h.in" > "$TMP/h.out" 2>"$TMP/h.err"; st=$?
    { [ "$st" != 0 ] && [ ! -s "$TMP/h.out" ] && grep -q "$want" "$TMP/h.err"; } \
      || err="$err $lbl"
  }
  : > "$TMP/h.in"
  hcbad no-direction         'usage: hexcat encode'
  hcbad unknown-direction    'must be encode or decode' wobble
  hcbad encode-with-a-suffix 'must be encode or decode' encodeX
  printf '414' > "$TMP/h.in"; hcbad odd-digits         'odd number of hex digits' encode
  printf 'zz'  > "$TMP/h.in"; hcbad not-a-hex-digit    'expected two hex digits'  encode
  printf '4 1' > "$TMP/h.in"; hcbad space-inside-pair  'expected two hex digits'  encode
  { printf '41'; printf '\000'; printf '41'; } > "$TMP/h.in"
  hcbad nul-byte             'expected two hex digits'  encode
  [ -z "$err" ] && ok "hexcat diagnoses every bad invocation on fd 2 and exits non-zero" \
                || no "hexcat succeeded, was silent, or gave the wrong reason on:$err"
fi


# @@ W8-ENCODE @@

# @@ W8-DECODE @@

# @@ W8-MKBLOB @@

# @@ W8-MKGOLF2 @@

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
