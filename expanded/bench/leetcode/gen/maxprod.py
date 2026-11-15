def gen(R, S, w):
    n = max(4, int(1000000 * S)); a = []
    while len(a) < n:   # zero-separated runs whose products stay within 32 bits
        bits = 0
        for _ in range(R.randint(1, 60)):
            x = R.choice([1, -1, 1, -1, 2, -2, 3, -3, 10, -10])
            bits += abs(x).bit_length()
            if bits > 30: break
            a.append(x)
        a.append(0)
    a = a[:n]
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '2 3 -2 4\n'); w('3', '-2 0 -1\n'); w('4', '-2\n'); w('5', '0\n'); w('6', '-2 3 -4\n')
    w('7', '-1 -1\n'); w('8', '3 -1 4\n'); w('9', '-3 0 -2 0 -1\n'); w('10', '0 -2 -3 0 1 1 1\n')
