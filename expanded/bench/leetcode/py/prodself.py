import sys
a = list(map(int, sys.stdin.read().split()))
n = len(a)
out = [1] * n
p = 1
for i in range(n):
    out[i] = p
    p *= a[i]
p = 1
for i in reversed(range(n)):
    out[i] *= p
    p *= a[i]
print(*out)
