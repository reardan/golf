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
EXP=$(pwd); MIN="$EXP/../minimal"
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

  # golf0.py -> v1c -> seed -> golf2 -> golf2', but with the GOLF-generated
  # source at the golf2 rung instead of the committed one.
  python3 "$MIN/boot/golf0.py" < "$MIN/self/golf.golf" > "$TMP/pv1c" 2>/dev/null; chmod +x "$TMP/pv1c"
  "$TMP/pv1c"  < self/seed.golf  > "$TMP/pseed"  2>/dev/null; chmod +x "$TMP/pseed"
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

echo
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
