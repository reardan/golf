import sys
t, *a = map(int, sys.stdin.read().split())
lo, hi = 0, len(a)
while lo < hi:
    m = (lo + hi) // 2
    if a[m] < t:
        lo = m + 1
    else:
        hi = m
print(lo)
