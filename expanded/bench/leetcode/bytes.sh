#!/bin/bash
# bytes.sh — size of every solution: Golf as encoded code-page bytes, Jelly in its code page,
# the rest as file bytes; "-" where a language has no solution (pyg, C++ and Jelly cover only
# some of the 100). Totals after the first ten, the first twenty and all of them.
B=$(cd "$(dirname "$0")" && pwd); G=$(cd "$B/../.." && pwd); cd "$B"
printf "%-11s %5s %6s %6s %5s %5s\n" problem golf pyg py cpp jelly
k=0; tg=0; tp=0
sz() { [ -f "$1" ] && wc -c < "$1" || echo -; }
for p in $(sed -n '/^### Byte ceilings$/,/^### /p' README.md | sed -n 's/^| \([a-z]*\) | \([0-9]*\) |$/\1/p'); do
  g=$(python3 "$G/tools/codepage.py" encode < golf/$p.golfj | tr -d '\n' | wc -c)
  j=-; [ -f jelly/$p.jelly ] && j=$(python3 -c "import sys;print(len(open(sys.argv[1],encoding='utf-8').read()))" jelly/$p.jelly)
  q=$(wc -c < py/$p.py)
  printf "%-11s %5d %6s %6d %5s %5s\n" $p $g $(sz pyg/$p.py) $q $(sz cpp/$p.cpp) $j
  k=$((k+1)); tg=$((tg+g)); tp=$((tp+q))
  case $k in 10|20) printf "%-11s %5d %6s %6d\n" total$k $tg "" $tp;; esac
done
printf "%-11s %5d %6s %6d\n" total$k $tg "" $tp
