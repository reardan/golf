import sys
g = sys.stdin.read().split()
n = len(g)
seen = [False] * n
k = 0
for s in range(n):
    if not seen[s]:
        k += 1; seen[s] = True; st = [s]
        while st:   # depth-first over the adjacency matrix row
            u = st.pop()
            for v, c in enumerate(g[u]):
                if c == '1' and not seen[v]:
                    seen[v] = True; st.append(v)
print(k)
