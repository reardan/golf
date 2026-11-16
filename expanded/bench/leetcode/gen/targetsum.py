def gen(R, S, w):
    n = max(4, int(40 * S ** 0.25)); m = max(4, int(5000 * S ** 0.5))
    a = [R.randint(0, m) for _ in range(n)]
    for i in R.sample(range(n), 2): a[i] = 0
    t = R.randint(-m, m); t -= (sum(a) + t) % 2   # same parity as the sum, so the answer is not 0
    w('', f'{t}\n' + ' '.join(map(str, a)) + '\n')
    w('2', '3\n1 1 1 1 1\n'); w('3', '1\n1\n'); w('4', '2\n1\n'); w('5', '0\n0 0 0\n'); w('6', '-3\n1 2\n')
    w('7', '-1000\n1000\n'); w('8', '1001\n1000\n'); w('9', '0\n1 2 3 4\n'); w('10', '5\n2 7 9 13 27 31\n')
