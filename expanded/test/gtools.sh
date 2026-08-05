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
