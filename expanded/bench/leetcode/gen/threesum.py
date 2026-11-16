def gen(R, S, w):
    V = max(10, int(10**4 * S)); w('', ' '.join(str(R.randint(-V, V)) for _ in range(max(40, int(3000 * S)))) + '\n')
    for i, x in enumerate(['-1 0 1 2 -1 -4', '0 1 1', '0 0 0', '0 0 0 0', '-2 0 1 1 2', '1 1 -2', '3 0 -2 -1 1 2',
                           '-1 -1 2 2 0 0', '1 2 -2 -1', '-4 2 2 2 2 -1 -1 5 -3'], 2):
        w(str(i), x + '\n')
