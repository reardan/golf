def gen(R, S, w):
    n = max(4, int(1000000 * S)); a = sorted(R.randint(-10**6, 10**6) for _ in range(n))
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '1 1 2\n'); w('3', '0 0 1 1 1 2 2 3 3 4\n'); w('4', '7\n'); w('5', '-3 -3 -3 -3\n'); w('6', '-5 -1 0 3 8\n')
