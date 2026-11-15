import sys
a = sorted(map(int, sys.stdin.read().split()))
n, count = len(a), 0
for i in range(n - 2):
    if i and a[i] == a[i - 1]:
        continue
    lo, hi = i + 1, n - 1
    while lo < hi:
        s = a[i] + a[lo] + a[hi]
        if s < 0:
            lo += 1
        elif s > 0:
            hi -= 1
        else:
            count += 1
            lo += 1
            while lo < hi and a[lo] == a[lo - 1]:
                lo += 1
            hi -= 1
print(count)
