import sys
l1, l2 = sys.stdin.read().split('\n')[:2]
a, b = list(map(int, l1.split())), list(map(int, l2.split()))
if len(a) > len(b):
    a, b = b, a
m, n = len(a), len(b)
half = (m + n + 1) // 2
lo, hi = 0, m
INF = float('inf')
while True:
    i = (lo + hi) // 2; j = half - i
    al = a[i - 1] if i else -INF; ar = a[i] if i < m else INF
    bl = b[j - 1] if j else -INF; br = b[j] if j < n else INF
    if al > br: hi = i - 1
    elif bl > ar: lo = i + 1
    else:
        left = max(al, bl)
        print(float(left) if (m + n) % 2 else (left + min(ar, br)) / 2)
        break
