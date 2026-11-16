def gen(R, S, w):
    n = max(4, int(2000 * S ** 0.5))
    g = [[0] * n for _ in range(n)]
    for i in range(n): g[i][i] = 1
    for _ in range(int(0.45 * n)):   # sparse random friendships: a few hundred provinces
        a, b = R.randrange(n), R.randrange(n); g[a][b] = g[b][a] = 1
    w('', ''.join(''.join(map(str, r)) + '\n' for r in g))
    w('2', '110\n110\n001\n'); w('3', '100\n010\n001\n'); w('4', '1\n'); w('5', '11\n11\n')
    w('6', '1001\n0110\n0110\n1001\n')
