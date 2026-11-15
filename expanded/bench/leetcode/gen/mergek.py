def gen(R, S, w):
    k = max(2, int(1000 * S ** 0.5)); N = max(4, int(300000 * S))
    ls = [[] for _ in range(k)]
    for _ in range(N):
        ls[R.randrange(k)].append(R.randint(-10**4, 10**4))
    w('', ''.join(' '.join(map(str, sorted(l))) + '\n' for l in ls))
    w('2', '1 4 5\n1 3 4\n2 6\n'); w('3', ''); w('4', '\n'); w('5', '\n-3 -1\n\n-2\n'); w('6', '5\n')
