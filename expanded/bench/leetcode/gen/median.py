def gen(R, S, w):
    m = max(2, int(500000 * S)); n = m + 1
    a = sorted(R.randint(-10**6, 10**6) for _ in range(m)); b = sorted(R.randint(-10**6, 10**6) for _ in range(n))
    w('', ' '.join(map(str, a)) + '\n' + ' '.join(map(str, b)) + '\n')
    for i, x in enumerate(['1 3\n2', '1 2\n3 4', '0 0\n0 0', '\n1', '2\n', '-1\n0', '-5 -2\n-4', '1\n2', '-2\n1', '-3 -1\n',
                           '-1000000 1000000\n-1000000', '-7\n-8 -6 3 4'], 2):
        w(str(i), x + '\n')
