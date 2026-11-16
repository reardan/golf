import sys
g = [list(r) for r in sys.stdin.read().split()]
R, C = len(g), len(g[0])
best = 0
for i in range(R):
    for j in range(C):
        if g[i][j] == '1':
            g[i][j] = '0'; st = [(i, j)]; a = 0
            while st:   # flood fill, counting cells
                y, x = st.pop(); a += 1
                for v, u in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                    if 0 <= v < R and 0 <= u < C and g[v][u] == '1':
                        g[v][u] = '0'; st.append((v, u))
            best = max(best, a)
print(best)
