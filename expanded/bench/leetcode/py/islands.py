import sys
g = [list(r) for r in sys.stdin.read().split()]
R, C = len(g), len(g[0]) if g else 0
n = 0
for i in range(R):
    for j in range(C):
        if g[i][j] == '1':
            n += 1
            g[i][j] = '0'
            st = [(i, j)]
            while st:
                y, x = st.pop()
                for v, u in ((y+1, x), (y-1, x), (y, x+1), (y, x-1)):
                    if 0 <= v < R and 0 <= u < C and g[v][u] == '1':
                        g[v][u] = '0'
                        st.append((v, u))
print(n)
