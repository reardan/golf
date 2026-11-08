import sys
a, b = sys.stdin.read().split()
n = len(b)
prev = [0] * (n + 1)
for ch in a:
    cur = [0] * (n + 1)
    for j in range(1, n + 1):
        if ch == b[j - 1]:
            cur[j] = prev[j - 1] + 1
        else:
            cur[j] = max(prev[j], cur[j - 1])
    prev = cur
print(prev[n])
