import sys
from itertools import accumulate
h = list(map(int, sys.stdin.read().split()))
L = list(accumulate(h, max))
R = list(accumulate(reversed(h), max))[::-1]
print(sum(min(l, r) - x for l, r, x in zip(L, R, h)))
