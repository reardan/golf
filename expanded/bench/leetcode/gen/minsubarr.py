def gen(R, S, w):
    n = max(4, int(1000000 * S))
    a = [R.randint(1, 10000) for _ in range(n)]
    t = R.randint(1, min(sum(a), 5000 * 300))
    w('', f'{t}\n' + ' '.join(map(str, a)) + '\n')
    w('2', '7\n2 3 1 2 4 3\n'); w('3', '4\n1 4 4\n'); w('4', '11\n1 1 1 1 1 1 1 1\n')
    w('5', '15\n1 2 3 4 5\n'); w('6', '16\n1 2 3 4 5\n'); w('7', '1\n1\n'); w('8', '2\n1\n'); w('9', '5\n1 1 1 1 5\n')
