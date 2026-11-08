#!/bin/bash
# bytes.sh — size of every solution: Golf as encoded code-page bytes, Jelly in its code page, the rest as file bytes.
# The ten W13-F problems (search … bits) have no Jelly solution: their jelly column is "-".
# The last two lines are the totals of the first ten and of all twenty.
B=$(cd "$(dirname "$0")" && pwd); G=$(cd "$B/../.." && pwd); cd "$B"
printf "%-9s %5s %6s %6s %5s %5s\n" problem golf pyg py cpp jelly
k=0; tg=0; ty=0; tp=0; tc=0; tj=0
for p in twosum parens stock longsub prodself topk islands trap slidemax queens \
         search koko oranges course delay redundant coins lcs temps bits; do
  g=$(python3 "$G/tools/codepage.py" encode < golf/$p.golfj | tr -d '\n' | wc -c)
  j=-; [ -f jelly/$p.jelly ] && j=$(python3 -c "import sys;print(len(open(sys.argv[1],encoding='utf-8').read()))" jelly/$p.jelly)
  y=$(wc -c < pyg/$p.py); q=$(wc -c < py/$p.py); c=$(wc -c < cpp/$p.cpp)
  printf "%-9s %5d %6d %6d %5d %5s\n" $p $g $y $q $c $j
  k=$((k+1)); tg=$((tg+g)); ty=$((ty+y)); tp=$((tp+q)); tc=$((tc+c)); [ "$j" = - ] || tj=$((tj+j))
  [ $k = 10 ] && printf "%-9s %5d %6d %6d %5d %5d\n" total10 $tg $ty $tp $tc $tj
done
printf "%-9s %5d %6d %6d %5d %5s\n" total20 $tg $ty $tp $tc -
