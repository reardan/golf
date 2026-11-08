import sys
from collections import deque
n, *e = map(int, sys.stdin.read().split())
adj = [[] for _ in range(n)]
deg = [0] * n
for a, b in zip(e[::2], e[1::2]):
    adj[b].append(a)
    deg[a] += 1
q = deque(i for i in range(n) if deg[i] == 0)
seen = 0
while q:
    u = q.popleft()
    seen += 1
    for v in adj[u]:
        deg[v] -= 1
        if deg[v] == 0:
            q.append(v)
print("true" if seen == n else "false")
