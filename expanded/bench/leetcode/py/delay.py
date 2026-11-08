import sys, heapq
n, k, *e = map(int, sys.stdin.read().split())
adj = [[] for _ in range(n + 1)]
for i in range(0, len(e), 3):
    adj[e[i]].append((e[i + 1], e[i + 2]))
dist = [None] * (n + 1)
h = [(0, k)]
while h:
    d, u = heapq.heappop(h)
    if dist[u] is not None:
        continue
    dist[u] = d
    for v, w in adj[u]:
        if dist[v] is None:
            heapq.heappush(h, (d + w, v))
r = dist[1:]
print(-1 if None in r else max(r))
