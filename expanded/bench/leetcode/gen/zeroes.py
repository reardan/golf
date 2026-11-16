def gen(R, S, w):
    n = max(4, int(300000 * S))
    a = [0 if R.random() < 0.3 else R.randint(-2**31, 2**31 - 1) for _ in range(n)]
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '0 1 0 3 12\n'); w('3', '0\n'); w('4', '5 -3 7\n'); w('5', '0 0 0 -1\n'); w('6', '-2147483648 0 2147483647\n')
