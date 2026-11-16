import sys
from bisect import bisect_left
tails = []
for x in map(int, sys.stdin.read().split()):
    i = bisect_left(tails, x)
    if i == len(tails):
        tails.append(x)
    else:
        tails[i] = x
print(len(tails))
