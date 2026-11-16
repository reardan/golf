#!/bin/bash
# check.sh NAME [full] — compile golf/NAME.golfj, compare it with py/NAME.py on
# gen/NAME.py's small inputs (scale 0.001 + edge cases); with `full`, also time
# both on the scale-1 input. Prints bytes and OK / WRONG per input.
B=$(cd "$(dirname "$0")" && pwd); G=$(cd "$B/../.." && pwd); p=$1
T=$(mktemp -d); trap 'rm -rf $T' EXIT
norm() { tr -s ' \n' '  ' | sed 's/ *$//'; }
b=$(python3 "$G/tools/codepage.py" encode < "$B/golf/$p.golfj" | tr -d '\n' | wc -c)
(cd "$G" && tools/golfc -j "$B/golf/$p.golfj" "$T/bin") || { echo "$p: COMPILE FAIL"; exit 1; }
python3 "$B/gen1.py" $p 0.001 $T/s
bad=0
for f in $T/s/$p.txt $T/s/$p[0-9]*.txt; do
  [ -f "$f" ] || continue
  g=$(timeout 20 $T/bin < $f 2>&1 | norm); y=$(python3 "$B/py/$p.py" < $f | norm)
  if [ "$g" = "$y" ]; then echo "  ok    $(basename $f)"; else echo "  WRONG $(basename $f): golf=${g:0:80} py=${y:0:80}"; bad=1; fi
done
if [ "$2" = full ]; then
  python3 "$B/gen1.py" $p 1 $T/f
  s=$(date +%s.%N); g=$(timeout 60 $T/bin < $T/f/$p.txt 2>&1 | norm); e=$(date +%s.%N)
  y=$(python3 "$B/py/$p.py" < $T/f/$p.txt | norm); e2=$(date +%s.%N)
  [ "$g" = "$y" ] && r=OK || { r="WRONG golf=${g:0:60} py=${y:0:60}"; bad=1; }
  printf "  full  golf %.3fs  py %.3fs  %s\n" $(echo "$e-$s"|bc) $(echo "$e2-$e"|bc) "$r"
fi
echo "$p: $b bytes $([ $bad = 0 ] && echo PASS || echo FAIL)"
