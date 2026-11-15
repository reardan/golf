def gen(R, S, w):
    n = max(4, int(500000 * S)); a = []
    while len(a) < n:   # runs up and down, so the counts grow
        k = R.randint(1, 50); x = R.randint(0, 20000); d = R.choice([-1, 0, 1])
        for _ in range(k): a.append(max(0, min(20000, x))); x += d * R.randint(0, 50)
    w('', ' '.join(map(str, a[:n])) + '\n')
    w('2', '1 0 2\n'); w('3', '1 2 2\n'); w('4', '5\n'); w('5', '1 2 3 4 5\n'); w('6', '5 4 3 2 1\n')
    w('7', '3 3 3\n'); w('8', '1 3 2 2 1\n'); w('9', '1 2 87 87 87 2 1\n')
