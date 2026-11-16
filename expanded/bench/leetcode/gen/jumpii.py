def gen(R, S, w):
    n = max(4, int(1000000 * S))
    a = [R.randint(1, 1000) if R.random() < 0.01 else R.randint(0, 6) for _ in range(n)]
    reach = 0   # make the end reachable: lift a stuck position just enough
    for i in range(n - 1):
        if reach <= i:
            a[i] = max(a[i], 1)
        reach = max(reach, i + a[i])
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '2 3 1 1 4\n'); w('3', '2 3 0 1 4\n'); w('4', '0\n'); w('5', '1 2\n'); w('6', '5 0 0 0 0 0\n'); w('7', '1 1 1 1\n')
