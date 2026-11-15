def gen(R, S, w):
    n = max(5, int(1000000 * S)) | 1; k = n // 2 + 1
    a = [R.randint(-10**9, 10**9)] * k + [R.randint(-10**9, 10**9) for _ in range(n - k)]
    R.shuffle(a)
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '3 2 3\n'); w('3', '2 2 1 1 1 2 2\n'); w('4', '5\n'); w('5', '-7 3 -7\n'); w('6', '1 2 2\n')
