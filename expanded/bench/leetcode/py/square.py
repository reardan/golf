import sys
g = sys.stdin.read().split()
m = len(g[0])
prev, best = [0] * (m + 1), 0
for row in g:
    cur = [0] * (m + 1)
    for j in range(1, m + 1):
        if row[j - 1] == '1':
            cur[j] = min(prev[j], prev[j - 1], cur[j - 1]) + 1
            if cur[j] > best:
                best = cur[j]
    prev = cur
print(best * best)
