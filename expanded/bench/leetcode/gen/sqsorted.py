def gen(R, S, w):
    n = max(4, int(500000 * S))
    a = sorted(R.randint(-10**6, 10**6) for _ in range(n))
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '-4 -1 0 3 10\n'); w('3', '-7 -3 2 3 11\n'); w('4', '5\n')
    w('5', '-9 -5 -5 -2 -1\n'); w('6', '0 0 0\n'); w('7', '-3 -3 3 3\n')
