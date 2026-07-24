#!/usr/bin/env bash
# GOLF test suite: milestones M1-M4 plus the self-hosting fixpoint.
# Usage: test/run.sh    (run from anywhere; paths are resolved to the repo root)
set -u
cd "$(dirname "$0")/.."
ROOT=$(pwd)
G="python3 boot/golf0.py"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ printf '  \033[32mok\033[0m   %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

# compile SRC(stdin) -> executable $1 using compiler $2 (default golf0)
comp(){ local out=$1; shift; local cc=${*:-$G}; $cc > "$out" 2>"$TMP/err" && chmod +x "$out"; }

# expect: program-source, stdin, expected-stdout, expected-exit, name
expect(){
  local src=$1 in=$2 exp=$3 code=$4 name=$5
  printf '%s' "$src" | comp "$TMP/p" || { no "$name (compile: $(cat "$TMP/err"))"; return; }
  local got; got=$(printf '%s' "$in" | "$TMP/p"); local rc=$?
  if [ "$got" = "$exp" ] && [ "$rc" = "$code" ]; then ok "$name";
  else no "$name (got '$got' rc=$rc, want '$exp' rc=$code)"; fi
}

echo "M1 - empty program exits 0"
expect '' '' '' 0 'empty -> exit 0'

echo "M2 - literals, arithmetic, I/O"
expect '72)105)10)'        '' $'Hi'   0 'print Hi'
expect '65 1+)10)'         '' $'B'    0 'add'
expect '7 6*2-)10)'        '' '('     0 'mul/sub -> 40'
expect '3"*48+)'           '' '9'     0 'dup 3*3'
expect '42.'               '' ''      42 'exit code'
expect '3 5<1+48+)5 3<1+48+)' '' '01' 0 'unsigned less idiom'

echo "M3 - words, control flow, memory, blob"
expect ':p3"*48+)10);p'    '' $'9'    0 'define+call word'
expect '0[72)]10)'         '' $'H'    0 'if true'
expect '1[72)]10)'         '' ''      0 'if false'
expect '3{65)1-"1<}_'      '' 'AAA'   0 'loop'
expect '65 4259856!4259856@)' '' 'A'  0 'store32/fetch32'
expect '66 4259856,4259856?)' '' 'B'  0 'storebyte/fetchbyte'
expect '`3 ABC"?)1+"?)1+?)' '' 'ABC'  0 'blob escape'
expect '{("[0.])0}'        'cat!' 'cat!' 0 'cat (stdin echo)'
expect ':r"[_^]42)1-r;5r'  '' '*****' 0 'recursion'

echo "Examples"
for ex in hello fizzbuzz; do
  comp "$TMP/$ex" < "examples/$ex.golf" || { no "compile $ex"; continue; }
  ok "compile examples/$ex.golf"
done
[ "$("$TMP/hello")" = "Hello, world!" ] && ok "hello runs" || no "hello runs"
[ "$("$TMP/fizzbuzz" | sed -n '15p')" = "FizzBuzz" ] && ok "fizzbuzz 15=FizzBuzz" || no "fizzbuzz"

echo "M4 - self-hosting fixpoint"
comp "$TMP/s1" < self/golf.golf              || no "golf0 compiles golf.golf"
"$TMP/s1" < self/golf.golf > "$TMP/s2" 2>/dev/null && chmod +x "$TMP/s2" || no "stage1 runs"
"$TMP/s2" < self/golf.golf > "$TMP/s3" 2>/dev/null && chmod +x "$TMP/s3" || no "stage2 runs"
cmp -s "$TMP/s2" "$TMP/s3" && ok "stage2 == stage3 (fixpoint)" || no "stage2 != stage3"
cmp -s "$TMP/s1" "$TMP/s2" && ok "stage1 == stage2 (strict fixpoint)" || echo "  note: strict fixpoint not held (only stage2==stage3 is required)"
# self-hosted compiler matches golf0 on the examples
for ex in hello fizzbuzz; do
  "$TMP/s2" < "examples/$ex.golf" > "$TMP/self_$ex" 2>/dev/null && chmod +x "$TMP/self_$ex"
  cmp -s "$TMP/$ex" "$TMP/self_$ex" && ok "self-hosted compiles $ex identically" || no "self-hosted $ex mismatch"
done

echo
echo "GOLF SCORE (self-hosted compiler): $(wc -c < self/golf.golf) bytes"
echo "Result: $pass passed, $fail failed"
[ "$fail" = 0 ]
