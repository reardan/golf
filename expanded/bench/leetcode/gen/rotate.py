def gen(R, S, w):
    n = max(2, int(1000 * S ** 0.5))
    w('', ''.join(' '.join(str(R.randint(-1000, 1000)) for _ in range(n)) + '\n' for _ in range(n)))
    w('2', '1 2 3\n4 5 6\n7 8 9\n'); w('3', '5 1 9 11\n2 4 8 10\n13 3 6 7\n15 14 12 16\n'); w('4', '7\n'); w('5', '-1 -2\n-3 -4\n')
