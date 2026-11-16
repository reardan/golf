#!/bin/bash
# bench.sh [DIR] [NAME…] — run Golf / Python / C++ on DIR/<problem>.txt (default in/, made by
# `python3 gen.py 1 in`), check the outputs agree, print best-of-3 wall seconds.
# The problems are README.md's "Byte ceilings" rows (all 100), or the NAMEs given.
# C++ exists for the first twenty only; its column is "-" for the rest.
B=$(cd "$(dirname "$0")" && pwd); cd "$B"; D=${1:-in}; shift
O=$(mktemp); E=$(mktemp); trap 'rm -f $O $E' EXIT
norm() { tr -s ' \n' '  ' | sed 's/ *$//'; }
t() { local f=$1; shift; local best=999; for r in 1 2 3; do local s=$(date +%s.%N); "$@" < "$f" > "$O" 2> "$E"; local e=$(date +%s.%N); local d=$(echo "$e - $s" | bc); best=$(echo "if ($d < $best) $d else $best" | bc); done; echo $best; }
P=${*:-$(sed -n '/^### Byte ceilings$/,/^### /p' README.md | sed -n 's/^| \([a-z]*\) | \([0-9]*\) |$/\1/p')}
for p in $P; do
  f=$D/$p.txt
  tg=$(t $f bin/$p); og=$(norm < $O); eg=$(head -c 200 $E)
  tp=$(t $f python3 py/$p.py); op=$(norm < $O)
  ok=OK; tc=-; oc=$op
  [ -x bin/${p}_cpp ] && { tc=$(t $f bin/${p}_cpp); oc=$(norm < $O); }
  [ "$og" = "$op" ] && [ "$op" = "$oc" ] || ok="MISMATCH g=${og:0:40} p=${op:0:40} c=${oc:0:40} $eg"
  printf "%-11s golf %6.3f  py %6.3f  cpp %6s  %s\n" $p $tg $tp $tc "$ok"
done
