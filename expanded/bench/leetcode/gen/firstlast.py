def gen(R, S, w):
    n = max(4, int(1000000 * S)); a = sorted(R.randint(-10**5, 10**5) for _ in range(n))
    w('', f'{a[R.randrange(n)]}\n' + ' '.join(map(str, a)) + '\n')
    for i, x in enumerate(['8\n5 7 7 8 8 10', '6\n5 7 7 8 8 10', '0\n', '1\n1', '2\n2 2', '4\n1 2 3', '-3\n-3 -3 -3 0',
                           '0\n1 2 3', '5\n5 7 7 8 8 10'], 2):
        w(str(i), x + '\n')
