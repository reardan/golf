import sys
h, *p = map(int, sys.stdin.read().split())
lo, hi = 1, max(p)
while lo < hi:
    k = (lo + hi) // 2
    if sum((x + k - 1) // k for x in p) <= h:
        hi = k
    else:
        lo = k + 1
print(lo)
