def gen(R, S, w):
    n = max(4, int(2000000 * S))
    w('', ' '.join('1' if R.random() < 0.9 else '0' for _ in range(n)) + '\n')
    w('2', '1 1 0 1 1 1\n'); w('3', '1 0 1 1 0 1\n'); w('4', '0\n'); w('5', '1\n'); w('6', '0 0 0\n'); w('7', '1 1 1 1\n')
