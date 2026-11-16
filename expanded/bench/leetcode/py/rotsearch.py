import sys
t, *a = map(int, sys.stdin.read().split())
lo, hi, ans = 0, len(a) - 1, -1
while lo <= hi:
    m = (lo + hi) // 2
    if a[m] == t:
        ans = m; break
    if a[lo] <= a[m]:
        if a[lo] <= t < a[m]: hi = m - 1
        else: lo = m + 1
    else:
        if a[m] < t <= a[hi]: lo = m + 1
        else: hi = m - 1
print(ans)
