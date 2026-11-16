def gen(R, S, w):
    n = max(4, int(1000000 * S)); m = min(n, max(2, int(2000 * S ** 0.5)))
    s = [R.choice('ab') for _ in range(n)]
    h = [R.choice('ab') for _ in range(m // 2)]; p = h + h[::-1]   # one planted long palindrome
    i = R.randrange(n - len(p) + 1); s[i:i + len(p)] = p
    w('', ''.join(s) + '\n')
    w('2', 'abc\n'); w('3', 'aaa\n'); w('4', 'a\n'); w('5', 'aaaaaaaaaa\n'); w('6', 'abacabadabacaba\n')
    w('7', 'ab\n'); w('8', 'zz\n')
