import sys
p = list(map(int, sys.stdin.read().split()))
hold, sold, rest = -p[0], 0, 0      # holding, just sold today, free to buy
for x in p[1:]:
    hold, sold, rest = max(hold, rest - x), hold + x, max(rest, sold)
print(max(sold, rest))
