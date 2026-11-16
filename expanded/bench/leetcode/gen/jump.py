def gen(R, S, w):
    n = max(4, int(1000000 * S))
    a = [R.choice([0, 0, 1, 2, 3]) for _ in range(n)]
    reach = 0   # reachable up to a wall of zeros near the end, so the answer is false
    for i in range(n - 1):
        if reach <= i:
            a[i] = max(a[i], 1)
        reach = max(reach, i + a[i])
    for i in range(max(1, n - 50), n - 1):
        a[i] = 0
    a[n - 51 if n > 60 else 0] = min(a[n - 51 if n > 60 else 0], 1)
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '2 3 1 1 4\n'); w('3', '3 2 1 0 4\n'); w('4', '0\n'); w('5', '0 1\n'); w('6', '1 0\n'); w('7', '2 0 0\n'); w('8', '1 1 0 1\n')
