#!/bin/bash
# micro.sh — per-element cost of the hot prelude words (best of 3), from cases.txt.
# Each case is timed whole, including the ⍳ it builds: subtract the `iota` row
# to get a word's own cost.
B=$(cd "$(dirname "$0")" && pwd); G=$(cd "$B/../.." && pwd); T=$(mktemp -d); trap 'rm -rf $T' EXIT
best(){ local b=999999; for r in 1 2 3; do local s=$(date +%s%N); "$1" > /dev/null; local e=$(date +%s%N); local d=$(( (e-s)/1000 )); [ $d -lt $b ] && b=$d; done; echo $b; }
grep -v '^#' "$B/cases.txt" | while IFS='|' read -r name n prog; do
  name=$(echo $name); n=$(echo $n); prog=$(echo "$prog" | sed 's/^ *//')
  printf '%s' "$prog" > "$T/p.golfj"; (cd "$G" && tools/golfc -j "$T/p.golfj" "$T/p") > /dev/null || { echo "$name: compile error"; continue; }
  us=$(best "$T/p")
  printf '%-8s %8.2f ns/element  (%d us for %s)\n' "$name" "$(echo "$us * 1000 / $n" | bc -l)" "$us" "$n"
done
