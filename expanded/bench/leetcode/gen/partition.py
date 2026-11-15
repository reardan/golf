def gen(R, S, w):
    n = max(4, int(200 * S ** 0.5))   # LeetCode's limits: 200 numbers, each 1 … 100
    a = [R.randint(1, 100) for _ in range(n)]
    if sum(a) % 2: a[0] += 1 if a[0] < 100 else -1
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '1 5 11 5\n'); w('3', '1 2 3 5\n'); w('4', '1\n'); w('5', '2 2\n'); w('6', '1 1\n'); w('7', '3 3 3 4 5\n')
    w('8', '100\n'); w('9', '2 3\n'); w('10', ' '.join(['99'] * 199 + ['1']) + '\n'); w('11', ' '.join(['100'] * 200) + '\n')
