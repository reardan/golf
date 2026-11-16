def gen(R, S, w):
    n = max(4, int(1000000 * S)); t = n // 3
    d = [R.randint(1, 9)] + [R.randint(0, 9) for _ in range(n - t - 1)] + [9] * t   # a long run of trailing 9s
    w('', ' '.join(map(str, d)) + '\n')
    w('2', '1 2 3\n'); w('3', '4 3 2 1\n'); w('4', '9\n'); w('5', '9 9 9 9\n'); w('6', '0\n'); w('7', '1 9 9\n'); w('8', '8 9 9 9 0\n')
