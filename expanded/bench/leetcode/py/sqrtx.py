import sys
x = int(sys.stdin.read())
lo, hi = 0, x
while lo < hi:  # largest r with r*r <= x
    m = (lo + hi + 1) // 2
    if m * m <= x:
        lo = m
    else:
        hi = m - 1
print(lo)
