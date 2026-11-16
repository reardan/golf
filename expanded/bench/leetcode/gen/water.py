def gen(R, S, w):
    w('', ' '.join(str(R.randint(0, 10**4)) for _ in range(max(4, int(1000000 * S)))) + '\n')
    for i, x in enumerate(['1 8 6 2 5 4 8 3 7', '1 1', '0 0', '4 3 2 1 4', '1 2 1', '2 3 4 5 18 17 6', '5 5 5 5'], 2):
        w(str(i), x + '\n')
