def gen(R, S, w):
    n = max(4, int(1000000 * S)); a = list(range(n + 1)); a.pop(R.randrange(n + 1)); R.shuffle(a)
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '3 0 1\n'); w('3', '0 1\n'); w('4', '9 6 4 2 3 5 7 0 1\n'); w('5', '0\n'); w('6', '1\n'); w('7', '1 2 3\n')
