#!/bin/bash
# bench.sh [DIR] — run Golf / Python / C++ on DIR/<problem>.txt (default in/, made by
# `python3 gen.py 1 in`), check the three outputs agree, print best-of-3 wall seconds.
B=$(cd "$(dirname "$0")" && pwd); cd "$B"; D=${1:-in}
O=$(mktemp); E=$(mktemp); trap 'rm -f $O $E' EXIT
norm() { tr -s ' \n' '  ' | sed 's/ *$//'; }
t() { local f=$1; shift; local best=999; for r in 1 2 3; do local s=$(date +%s.%N); "$@" < "$f" > "$O" 2> "$E"; local e=$(date +%s.%N); local d=$(echo "$e - $s" | bc); best=$(echo "if ($d < $best) $d else $best" | bc); done; echo $best; }
for p in twosum parens stock longsub prodself topk islands trap slidemax queens \
         search koko oranges course delay redundant coins lcs temps bits; do
  f=$D/$p.txt
  tg=$(t $f bin/$p); og=$(norm < $O); eg=$(head -c 200 $E)
  tp=$(t $f python3 py/$p.py); op=$(norm < $O)
  tc=$(t $f bin/${p}_cpp); oc=$(norm < $O)
  ok=OK; [ "$og" = "$op" ] && [ "$op" = "$oc" ] || ok="MISMATCH g=${og:0:40} p=${op:0:40} c=${oc:0:40} $eg"
  printf "%-9s golf %6.3f  py %6.3f  cpp %6.3f  %s\n" $p $tg $tp $tc "$ok"
done
