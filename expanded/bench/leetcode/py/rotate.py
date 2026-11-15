import sys
m = [list(map(int, r.split())) for r in sys.stdin.read().splitlines() if r.strip()]
n = len(m)
for i in range(n):                      # transpose, then reverse each row: in place
    for j in range(i + 1, n):
        m[i][j], m[j][i] = m[j][i], m[i][j]
for r in m:
    r.reverse()
print('\n'.join(' '.join(map(str, r)) for r in m))
