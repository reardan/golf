import sys
r = list(map(int, sys.stdin.read().split()))
n = len(r)
c = [1] * n
for i in range(1, n):
    if r[i] > r[i - 1]:
        c[i] = c[i - 1] + 1
for i in range(n - 2, -1, -1):
    if r[i] > r[i + 1] and c[i] <= c[i + 1]:
        c[i] = c[i + 1] + 1
print(sum(c))
