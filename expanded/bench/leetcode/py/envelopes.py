import sys
from bisect import bisect_left
a = list(map(int, sys.stdin.read().split()))
env = sorted(zip(a[::2], a[1::2]), key=lambda p: (p[0], -p[1]))
tails = []
for _, h in env:
    i = bisect_left(tails, h)
    if i == len(tails):
        tails.append(h)
    else:
        tails[i] = h
print(len(tails))
