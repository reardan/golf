def gen(R, S, w):
    m = max(2, int(500 * S ** 0.5)); n = max(2, int(400 * S ** 0.5))
    w('', ''.join(' '.join(str(R.randint(-100, 100)) for _ in range(n)) + '\n' for _ in range(m)))
    w('2', '1 2 3\n4 5 6\n7 8 9\n'); w('3', '1 2 3 4\n5 6 7 8\n9 10 11 12\n'); w('4', '7\n'); w('5', '1\n2\n3\n')
    w('6', '1 2 3 4\n'); w('7', '1 2\n3 4\n5 6\n7 8\n'); w('8', '-1 -2 -3\n-4 -5 -6\n')
