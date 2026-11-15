def gen(R, S, w):
    n = max(2, int(500000 * S)); a = R.sample(range(-10**9, 10**9), n)
    a = a + a[1:]; R.shuffle(a)
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '2 2 1\n'); w('3', '4 1 2 1 2\n'); w('4', '1\n')
