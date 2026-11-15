def gen(R, S, w):
    n = max(4, int(1000000 * S)); m = min(n, max(2, int(2000 * S ** 0.5)))
    al = 'ab01'
    s = [R.choice(al) for _ in range(n)]
    for k in range(3):   # three planted palindromes; the last is one longer, odd
        h = [R.choice(al) for _ in range(m // 2)]; p = h + ([R.choice(al)] if k == 2 else []) + h[::-1]
        i = R.randrange(n - len(p) + 1); s[i:i + len(p)] = p
    w('', ''.join(s) + '\n')
    w('2', 'babad\n'); w('3', 'cbbd\n'); w('4', 'a\n'); w('5', 'ac\n'); w('6', '0110\n')
    w('7', 'aaaa\n'); w('8', 'abcda\n'); w('9', 'forgeeksskeegfor\n'); w('10', '9\n')
