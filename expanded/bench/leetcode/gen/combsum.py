def gen(R, S, w):
    # the count of combinations stays below 2^62, so it fits a 64-bit int
    T = max(10, int(100000 * S)); c = R.sample(range(max(2, T // 20), max(12, T // 4)), 20)
    w('', f'{T}\n' + ' '.join(map(str, c)) + '\n')
    for i, x in enumerate(['7\n2 3 6 7', '8\n2 3 5', '1\n2', '1\n1', '2\n1', '18\n7 3 2', '40\n2 3 4 5 6 7 8 9 10 11 12',
                           '30\n31 32', '40\n40'], 2):
        w(str(i), x + '\n')
