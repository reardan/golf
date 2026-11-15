def gen(R, S, w):
    n = max(4, int(1000000 * S)); a = sorted(R.sample(range(-10**9, 10**9), n)); k = R.randrange(n)
    a = a[k:] + a[:k]
    w('', f'{a[R.randrange(n)]}\n' + ' '.join(map(str, a)) + '\n')
    for i, x in enumerate(['0\n4 5 6 7 0 1 2', '3\n4 5 6 7 0 1 2', '0\n1', '1\n1', '1\n3 1', '5\n5 1 3', '3\n5 1 3',
                           '-5\n-3 -1 -10 -7', '8\n1 3 5'], 2):
        w(str(i), x + '\n')
