import sys
a = list(map(int, sys.stdin.read().split()))
i, j = 0, len(a) - 1
out = [0] * len(a)
for k in range(len(a) - 1, -1, -1):   # two pointers: the larger square goes last
    if abs(a[i]) > abs(a[j]):
        out[k] = a[i] * a[i]; i += 1
    else:
        out[k] = a[j] * a[j]; j -= 1
print(*out)
