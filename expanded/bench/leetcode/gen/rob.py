def gen(R, S, w):
    n = max(4, int(1000000 * S))
    w('', ' '.join(str(R.randint(0, 400)) for _ in range(n)) + '\n')
    w('2', '1 2 3 1\n'); w('3', '2 7 9 3 1\n'); w('4', '5\n'); w('5', '0 0 0\n'); w('6', '2 1 1 2\n'); w('7', '1 3\n')
