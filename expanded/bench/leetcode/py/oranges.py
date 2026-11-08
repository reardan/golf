import sys
from collections import deque
g = [list(map(int, r)) for r in sys.stdin.read().split()]
R, C = len(g), len(g[0])
q = deque((i, j) for i in range(R) for j in range(C) if g[i][j] == 2)
fresh = sum(r.count(1) for r in g)
t = 0
while q and fresh:
    for _ in range(len(q)):
        i, j = q.popleft()
        for y, x in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
            if 0 <= y < R and 0 <= x < C and g[y][x] == 1:
                g[y][x] = 2
                fresh -= 1
                q.append((y, x))
    t += 1
print(-1 if fresh else t)
