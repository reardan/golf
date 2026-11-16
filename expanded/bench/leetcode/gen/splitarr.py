def gen(R, S, w):
    n = max(4, int(500000 * S))
    a = [R.randint(0, 10000) for _ in range(n)]
    w('', f'{R.randint(2, 50)}\n' + ' '.join(map(str, a)) + '\n')
    w('2', '2\n7 2 5 10 8\n'); w('3', '2\n1 2 3 4 5\n'); w('4', '1\n5\n'); w('5', '3\n1 4 4\n')
    w('6', '5\n0 0 0 0 0\n'); w('7', '1\n0 3 0 4\n'); w('8', '4\n9 0 0 9 0 9\n')
