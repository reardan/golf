import sys
k, *a = map(int, sys.stdin.read().split())
def pieces(cap):   # greedy: start a new piece when the next number would overflow
    c, s = 1, 0
    for x in a:
        if s + x > cap:
            c += 1; s = x
        else:
            s += x
    return c
lo, hi = max(a), sum(a)
while lo < hi:
    mid = (lo + hi) // 2
    if pieces(mid) <= k:
        hi = mid
    else:
        lo = mid + 1
print(lo)
