def gen(R, S, w):
    n = max(4, int(1000000 * S))
    while True:
        g = [R.randint(0, 10**4) for _ in range(n)]
        c = [R.randint(0, 10**4) for _ in range(n)]
        d = sum(g) - sum(c)
        if d < 0: g[R.randrange(n)] += -d + R.randint(0, 100)   # make a full circuit possible
        e, m = 0, []
        for x, y in zip(g, c): m.append(e); e += x - y
        if m.count(min(m)) == 1: break   # LeetCode promises the start is unique
    w('', ' '.join(map(str, g)) + '\n' + ' '.join(map(str, c)) + '\n')
    w('2', '1 2 3 4 5\n3 4 5 1 2\n'); w('3', '2 3 4\n3 4 3\n'); w('4', '5\n4\n'); w('5', '2\n2\n')
    w('6', '1\n2\n'); w('7', '5 1 2 3 4\n4 4 1 5 1\n'); w('8', '0 0 9\n1 1 1\n')
