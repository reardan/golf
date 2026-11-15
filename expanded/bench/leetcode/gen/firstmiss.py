def gen(R, S, w):
    n = max(4, int(1000000 * S)); a = list(range(1, n + 1)); k = R.randrange(n)
    a = a[:k] + a[k + 1:]
    a += [R.randint(-10**9, 0) for _ in range(n // 10)] + [R.randint(n + 2, 10**9) for _ in range(n // 10)] + R.sample(a, n // 10)
    R.shuffle(a)
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '1 2 0\n'); w('3', '3 4 -1 1\n'); w('4', '7 8 9 11 12\n'); w('5', '1\n'); w('6', '2\n'); w('7', '1 1\n'); w('8', '-5\n'); w('9', '2 1\n')
