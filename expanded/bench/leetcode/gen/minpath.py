def gen(R, S, w):
    m = max(4, int(1000 * S ** 0.5)); n = m + 3
    w('', f'{m} {n}\n' + ''.join(' '.join(str(R.randint(0, 200)) for _ in range(n)) + '\n' for _ in range(m)))
    w('2', '3 3\n1 3 1\n1 5 1\n4 2 1\n'); w('3', '2 3\n1 2 3\n4 5 6\n'); w('4', '1 1\n0\n')
    w('5', '1 4\n5 0 2 7\n'); w('6', '4 1\n3\n0\n9\n1\n'); w('7', '3 3\n0 0 0\n0 0 0\n0 0 0\n')
    w('8', '3 4\n1 9 9 9\n1 9 1 1\n1 1 1 9\n')
