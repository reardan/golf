#!/usr/bin/env bash
# The merge gate (W9): every branch must pass this before it is merged, and the
# integration branch must pass it after every merge.
#   1. run2.sh       the bootstrap ladder, the golf2 == golf2' fixpoint, the
#                    language tests and the doc assertions (W7A)
#   2. selfcheck.sh  seed and golf2 are one compiler; generated files are fresh
#   3. gtools.sh     the GOLF build tools match their Python twins
#   4. the generated compiler sources match the generator (no hand edits)
set -u
EXP=$(cd "$(dirname "$0")/.." && pwd); cd "$EXP"; mkdir -p build
st=0
for t in run2 selfcheck gtools; do
  if bash "test/$t.sh" > "build/gate.$t.log" 2>&1; then
    echo "gate: $t  $(grep '^Result:' "build/gate.$t.log" | tail -1)"
  else
    echo "gate: $t  FAILED  $(grep '^Result:' "build/gate.$t.log" | tail -1)"
    grep -E 'FAIL' "build/gate.$t.log" | head -20 | sed 's/^/    /'
    st=1
  fi
done
if git diff --quiet -- self/golf2.golf self/seed.golf; then
  echo "gate: generated sources match the generator"
else
  echo "gate: self/*.golf differ from what tools/mkblob2.py generates — commit the regenerated files"
  st=1
fi
[ "$st" = 0 ] && echo "gate: GREEN" || echo "gate: RED"
exit "$st"
