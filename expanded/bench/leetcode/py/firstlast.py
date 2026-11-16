import sys
from bisect import bisect_left, bisect_right
t, *a = map(int, sys.stdin.read().split())
lo, hi = bisect_left(a, t), bisect_right(a, t) - 1
print(*((lo, hi) if lo <= hi else (-1, -1)))
