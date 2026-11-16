def gen(R, S, w):
    n = max(4, int(1000000 * S))
    a = [R.randint(-10000, 10000) for _ in range(n)]
    w('', f'{R.randint(1, n)}\n' + ' '.join(map(str, a)) + '\n')
    w('2', '2\n3 2 1 5 6 4\n'); w('3', '4\n3 2 3 1 2 4 5 5 6\n'); w('4', '1\n-7\n'); w('5', '3\n-1 -1 -1\n')
    w('6', '1\n-5 -3 -9\n'); w('7', '3\n-5 -3 -9\n')
