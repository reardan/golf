#!/bin/bash
# bytes.sh — size of every solution: Golf as encoded code-page bytes, Jelly in its code page, the rest as file bytes
B=$(cd "$(dirname "$0")" && pwd); G=$(cd "$B/../.." && pwd); cd "$B"
printf "%-9s %5s %6s %6s %5s %5s\n" problem golf pyg py cpp jelly
for p in twosum parens stock longsub prodself topk islands trap slidemax queens; do
  g=$(python3 "$G/tools/codepage.py" encode < golf/$p.golfj | tr -d '\n' | wc -c)
  j=$(python3 -c "import sys;print(len(open(sys.argv[1],encoding='utf-8').read()))" jelly/$p.jelly)
  printf "%-9s %5d %6d %6d %5d %5d\n" $p $g $(wc -c < pyg/$p.py) $(wc -c < py/$p.py) $(wc -c < cpp/$p.cpp) $j
done
