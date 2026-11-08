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
EXP=$(pwd); SEED_ROOT=$(cd "$EXP/.." && pwd)
. "$EXP/tools/seed.sh"
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

# @@ W8-PIPELINE @@
# The claim the whole milestone is for, and the one case no single tool could
# make: the compiler's own source, regenerated with NO Python in the pipeline.
#
#     gmkblob data/blob.hex                    -> the ` blob escape
#     gencode < self/golf2.golfj | gmkgolf2 ESC -> self/golf2.golf
#
# Each tool proves itself against its Python counterpart under its own anchor
# above; each was also developed against Python stand-ins for its neighbours,
# which is the shadow architecture working as intended — byte-identical stages
# are interchangeable parts.  But "every stage matches" and "the stages compose"
# are different claims, and only this one is the deliverable.  mkgolf2's own
# block deliberately drives Python's blob_escape rather than guessing a
# sibling's command line, so without this case the full chain is never run.
#
# Then the real test, which is not byte-identity at all: put the result back on
# the bootstrap ladder.  A compiler source assembled by GOLF programs must still
# compile ITSELF to a byte-identical binary — golf2 == golf2' — and that
# compiler must still compile ordinary GOLF.
if build gtools/mkblob.golfj  pmkblob  \
&& build gtools/encode.golfj  pencode  \
&& build gtools/mkgolf2.golfj pmkgolf2; then
  "$TMP/pmkblob" data/blob.hex > "$TMP/p.esc" 2>/dev/null
  "$TMP/pencode" < self/golf2.golfj 2>/dev/null \
    | "$TMP/pmkgolf2" "$TMP/p.esc" > "$TMP/p.golf2" 2>/dev/null
  cmp -s "$TMP/p.golf2" self/golf2.golf \
    && ok "the whole pipeline, no Python: mkblob + encode + mkgolf2 rebuild self/golf2.golf" \
    || no "the GOLF-only pipeline does not reproduce self/golf2.golf"

  # v1c -> seed -> golf2 -> golf2', but with the GOLF-generated source at the
  # golf2 rung instead of the committed one.
  ensure_seed v1c || { no "v1c unavailable"; exit 1; }
  "$SEED"      < self/seed.golf  > "$TMP/pseed"  2>/dev/null; chmod +x "$TMP/pseed"
  "$TMP/pseed" < "$TMP/p.golf2"  > "$TMP/pg2"    2>/dev/null; chmod +x "$TMP/pg2"
  "$TMP/pg2"   < "$TMP/p.golf2"  > "$TMP/pg2p"   2>/dev/null; chmod +x "$TMP/pg2p"
  cmp -s "$TMP/pg2" "$TMP/pg2p" \
    && ok "fixpoint on the GOLF-generated source: golf2 == golf2'" \
    || no "the GOLF-generated compiler source does not reach the fixpoint"

  # ...and it is a working compiler, not just a stable one.
  printf '%s' '5R\ref\sqrMSNE' | python3 tools/codepage.py encode > "$TMP/pprog.gb" 2>/dev/null
  cat <(python3 tools/codepage.py encode < lib/prelude.golfj) "$TMP/pprog.gb" \
    | "$TMP/pg2p" > "$TMP/pprog" 2>/dev/null && chmod +x "$TMP/pprog"
  [ "$("$TMP/pprog" 2>/dev/null)" = "30" ] \
    && ok "that compiler still compiles GOLF (sum of squares 0..4 -> 30)" \
    || no "the GOLF-generated compiler miscompiles"
fi

# @@ W9-1B-STRINGS @@
# String literals are literal: both encoders copy the text between two
# delimiters verbatim (one escape, \“; 0x8E fatal), and both decoders copy a
# literal's bytes back out raw.  The corpus above already holds every literal
# the repo's sources use; these fixtures add the cases no real source has —
# mnemonic and glyph text inside a literal, `#`, the escape, `\str` as either
# delimiter, an unclosed literal, and the 0x8E error (status and message too).
if [ -x "$TMP/gencode" ] && [ -x "$TMP/gdecode" ]; then
  mkdir -p "$TMP/lit"
  printf '%s' '“a\nb \sqr ⊕ # not a comment“🗲 # a comment “x' > "$TMP/lit/1"
  printf '%s' '“say \“hi\““🗲 \strx\“y\str “q\str \strr“ “é\\str' > "$TMP/lit/2"
  printf '%s' '““ “\“\““ 1 “unclosed \sqr ⊕' > "$TMP/lit/3"
  printf '%s' '“ok“ “Ď“' > "$TMP/lit/4"
  bad=""
  for f in "$TMP"/lit/*; do
    "$TMP/gencode" < "$f" > "$TMP/l.g" 2> "$TMP/l.ge"; gs=$?
    python3 tools/codepage.py encode < "$f" > "$TMP/l.p" 2> "$TMP/l.pe"; ps=$?
    { [ "$gs" = "$ps" ] && cmp -s "$TMP/l.g" "$TMP/l.p" && cmp -s "$TMP/l.ge" "$TMP/l.pe"; } \
      || bad="$bad $(basename "$f")"
  done
  grep -q 'cannot contain byte 0x8E' "$TMP/l.ge" || bad="$bad no-0x8E-error"
  [ -z "$bad" ] && ok "gencode == codepage.py on literal strings (verbatim, \\“, \\str, the 0x8E error)" \
                || no "gencode literal strings differ on:$bad"
  bad=""
  python3 -c 'import sys;sys.stdout.buffer.write(bytes(range(256))*2+b"\x8ea\\\x8e\x8e\\\x8e x\x8e\\\xe2\x80\x9c\xe2\x80")' > "$TMP/lit/raw.gb"
  for f in "$TMP"/lit/[123] "$TMP"/lit/raw.gb; do
    case $f in *.gb) g=$f ;; *) g=$f.gb; python3 tools/codepage.py encode < "$f" > "$g" ;; esac
    for m in "" -m; do
      "$TMP/gdecode" $m < "$g" > "$TMP/l.g" 2>/dev/null
      python3 tools/codepage.py decode $m < "$g" > "$TMP/l.p" 2>/dev/null
      cmp -s "$TMP/l.g" "$TMP/l.p" || bad="$bad $(basename "$g")$m"
    done
  done
  [ -z "$bad" ] && ok "gdecode == codepage.py decode on literal strings, raw bytes included" \
                || no "gdecode literal strings differ on:$bad"
fi

# @@ W14-L-TABLES @@
# gtools/tables: everything tools/mkblob2.py, tools/mktables.py and
# codepage.py's table/reference/check build from the source data
# (data/ops.tsv, data/templates.txt, data/v1.hex), built by a GOLF program from
# the same files.  Each command is diffed against its Python twin AND against
# the committed artifact where there is one; then the two compiler sources it
# writes go back on the ladder, from the pinned v1c up, with no Python-built
# source on it; then both implementations are fed the same broken tables and
# must fail with the same message.
if build gtools/tables.golfj gtables; then
  GT=$TMP/gtables
  python3 - "$TMP" <<'PY'
import sys
sys.path.insert(0, "tools")
import codepage, mkblob2, mktables
t = sys.argv[1]
for name, data in (("blob", mkblob2.build_blob2()), ("escape", mkblob2.blob_escape()),
                   ("blobhex", mktables.build_blob_hex()),
                   ("codepage", mktables.build_codepage_tsv()),
                   ("seed", mkblob2.build_seed()), ("golf2", mkblob2.build_golf2())):
    open(f"{t}/tl.py.{name}", "wb").write(data)
r = open("REFERENCE.md", encoding="utf-8").read()
a, z = r.find(codepage.REF_BEGIN), r.find(codepage.REF_END)
open(f"{t}/tl.committed.reference", "w", encoding="utf-8").write(
    r[a + len(codepage.REF_BEGIN) + 1:z] if 0 <= a < z else "NO MARKERS")
PY
  python3 tools/codepage.py table     > "$TMP/tl.py.table"
  python3 tools/codepage.py reference > "$TMP/tl.py.reference"
  python3 tools/codepage.py check     > "$TMP/tl.py.check" 2>&1
  cp data/blob.hex     "$TMP/tl.committed.blobhex"
  cp data/codepage.tsv "$TMP/tl.committed.codepage"
  cp self/seed.golf    "$TMP/tl.committed.seed"
  cp self/golf2.golf   "$TMP/tl.committed.golf2"
  for c in blob escape blobhex codepage seed golf2 table reference check; do
    "$GT" "$c" > "$TMP/tl.g.$c" 2> "$TMP/tl.g.$c.err"; st=$?
    if [ "$st" = 0 ] && [ ! -s "$TMP/tl.g.$c.err" ] && cmp -s "$TMP/tl.g.$c" "$TMP/tl.py.$c"; then
      if [ -e "$TMP/tl.committed.$c" ]; then
        cmp -s "$TMP/tl.g.$c" "$TMP/tl.committed.$c" \
          && ok "gtables $c == Python == the committed file ($(wc -c < "$TMP/tl.g.$c" | tr -d ' ') bytes)" \
          || no "gtables $c matches Python but not the committed file (stale?)"
      else
        ok "gtables $c == Python ($(wc -c < "$TMP/tl.g.$c" | tr -d ' ') bytes)"
      fi
    else
      no "gtables $c (status $st) differs from Python: $(head -c 200 "$TMP/tl.g.$c.err")"
    fi
  done

  # The ladder, with both rungs' sources written by GOLF: the pinned v1c
  # compiles gtables' seed, that seed compiles gtables' golf2, and the result
  # must compile itself to itself and still compile GOLF.
  ensure_seed v1c || { no "v1c unavailable"; exit 1; }
  "$SEED"        < "$TMP/tl.g.seed"  > "$TMP/tl.seed" 2>/dev/null; chmod +x "$TMP/tl.seed"
  "$TMP/tl.seed" < "$TMP/tl.g.golf2" > "$TMP/tl.g2"   2>/dev/null; chmod +x "$TMP/tl.g2"
  "$TMP/tl.g2"   < "$TMP/tl.g.golf2" > "$TMP/tl.g2p"  2>/dev/null
  { [ -s "$TMP/tl.g2" ] && cmp -s "$TMP/tl.g2" "$TMP/tl.g2p" && cmp -s "$TMP/tl.g2" build/golf2; } \
    && ok "v1c -> gtables seed -> gtables golf2 reaches golf2 == golf2' == build/golf2" \
    || no "the gtables-generated sources do not reach the fixpoint"
  printf '%s' '5R\ref\sqrMSNE' | python3 tools/codepage.py encode > "$TMP/tl.prog.gb"
  cat <(python3 tools/codepage.py encode < lib/prelude.golfj) "$TMP/tl.prog.gb" \
    | "$TMP/tl.g2" > "$TMP/tl.prog" 2>/dev/null && chmod +x "$TMP/tl.prog"
  [ "$("$TMP/tl.prog" 2>/dev/null)" = "30" ] \
    && ok "and that compiler compiles GOLF (sum of squares 0..4 -> 30)" \
    || no "the gtables-generated compiler miscompiles"

  # Bad invocations: no command, an unknown one, a second argument.
  bad=""
  for a in "" wobble "blob extra"; do
    "$GT" $a > "$TMP/tl.u.out" 2> "$TMP/tl.u.err"; st=$?
    { [ "$st" = 2 ] && [ ! -s "$TMP/tl.u.out" ] && grep -q '^usage: gtables ' "$TMP/tl.u.err"; } \
      || bad="$bad [${a:-none}]"
  done
  [ -z "$bad" ] && ok "gtables: no command, an unknown one or an extra argument -> usage on fd 2, exit 2" \
                || no "gtables usage errors:$bad"

  # Broken tables.  A copy of the tree (the Python finds data/ next to tools/,
  # gtables in its working directory), one corruption at a time; both must exit
  # 1 with the SAME text on fd 2 and gtables must write nothing on stdout.  The
  # Python side is mkblob2.build_blob2() for the loader's and expander's errors
  # and `codepage.py check` for the namespace rules.
  mkdir -p "$TMP/tl.tree"; cp -r tools boot data self lib "$TMP/tl.tree/"
  bad=""; n=0
  tlbad(){ lbl=$1; f=$2; cmd=$3; edit=$4
    ( cd "$TMP/tl.tree" || exit 1
      cp "$EXP/data/ops.tsv" data/ops.tsv; cp "$EXP/data/templates.txt" data/templates.txt
      python3 -c "import sys; p=sys.argv[1]; s=open(p,encoding='utf-8').read(); t=$edit
assert t != s, 'the edit changed nothing'; open(p,'w',encoding='utf-8').write(t)" "data/$f" || exit 1
      "$GT" "$cmd" > g.out 2> g.err; gs=$?
      if [ "$cmd" = check ]; then python3 tools/codepage.py check > /dev/null 2> p.err; ps=$?
      else python3 -c 'import sys; sys.path.insert(0,"tools"); import mkblob2; mkblob2.build_blob2()' 2> p.err; ps=$?; fi
      [ "$gs" = 1 ] && [ "$ps" = 1 ] && [ ! -s g.out ] && [ -s g.err ] && cmp -s g.err p.err ) \
      || bad="$bad $lbl"
    n=$((n+1))
  }
  tlbad fields     ops.tsv blob  "s.replace('A\t7E\tnot\t~\tbitwise NOT','A\t7E\tnot\t~')"
  tlbad table      ops.tsv blob  "s.replace('A\t7E\tnot','X\t7E\tnot')"
  tlbad byte       ops.tsv blob  "s.replace('L\tE0\tdput','L\te0\tdput')"
  tlbad mnemonic   ops.tsv blob  "s.replace('L\tE0\tdput','L\tE0\tdput2')"
  tlbad glyph      ops.tsv blob  "s.replace('\tṖ\t','\tṖṖ\t')"
  tlbad dupbyte    ops.tsv check "s.replace('L\tE0\tdput','L\tDF\tdput')"
  tlbad prefix     ops.tsv check "s.replace('L\tE0\tdput','L\tE0\tdg')"
  tlbad dupmn      ops.tsv check "s.replace('L\tE0\tdput','L\tE0\tdget')"
  tlbad dupglyph   ops.tsv check "s.replace('\tṖ\t','\tĠ\t')"
  tlbad twoerrs    ops.tsv check "s.replace('L\tE0\tdput\tṖ','L\tDF\tdge\tĠ')"
  tlbad notpl      ops.tsv blob  "s.replace('A\tAE\tscall','A\tAF\tscall')"
  tlbad statement  templates.txt blob "s.replace('def flush\n','deff flush\n')"
  tlbad indent     templates.txt blob "s.replace('# expanded/data/templates.txt','  41 # expanded/data/templates.txt')"
  tlbad deftwice   templates.txt blob "s.replace('def endhook\n','def flush\n')"
  tlbad hexbyte    templates.txt blob "s.replace('tpl 7E 58','tpl 7G 58')"
  tlbad tpltwice   templates.txt blob "s.replace('tpl 24 58','tpl 7E 58')"
  tlbad notatom    templates.txt blob "s.replace('tpl AE 58','tpl AF 90\ntpl AE 58')"
  tlbad nolabel    templates.txt blob "s.replace('74 >no FF D0','74 >nope FF D0')"
  tlbad labtwice   templates.txt blob "s.replace('    no:\n','    no: no:\n')"
  tlbad badjump    templates.txt blob "s.replace('74 >no FF D0','74 >9no FF D0')"
  tlbad rel8       templates.txt blob "s.replace('    div: 48 99','    div: 48 99 ' + '90 '*130)"
  tlbad nofrag     templates.txt blob "s.replace('    hookcall(w:4F0B10)','    hookcal(w:4F0B10)')"
  tlbad argcount   templates.txt blob "s.replace('    hookcall(w:4F0B10)','    hookcall(w:4F0B10,01)')"
  tlbad emptyarg   templates.txt blob "s.replace('    hookcall(w:4F0B10)','    hookcall()')"
  tlbad token      templates.txt blob "s.replace('tpl 7E 58 48','tpl 7E 58 4%8')"
  tlbad nested     templates.txt blob "s.replace('numchk(atom:80)','numchk(numchk(atom:80))')"
  tlbad notparam   templates.txt blob "s.replace('48 8B 04 25 \$cell','48 8B 04 25 \$cel')"
  tlbad nov1       templates.txt blob "s.replace('rec 01 v1:01','rec 01 v1:0F')"
  tlbad v1offset   templates.txt blob "s.replace('div0guard v1:2F+2','div0guard v1:2F+x')"
  tlbad noatomtpl  templates.txt blob "s.replace('numchk(atom:80)','numchk(atom:8F)')"
  tlbad cycle      templates.txt blob "s.replace('    hookcall(w:4F0990)','    flush')"
  tlbad paramname  templates.txt blob "s.replace('def divchk minus1 push','def divchk minus1 9push')"
  tlbad takes      templates.txt blob "s.replace('\nv1ops\n','\nv1ops 01\n')"
  tlbad needs      templates.txt blob "s.replace('\nrec 07 22','\nrec\n 07 22')"
  [ -z "$bad" ] && ok "gtables and Python fail alike on $n broken tables (status 1, the same message, nothing on stdout)" \
                || no "gtables and Python fail differently on:$bad"
fi

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
