def gen(R, S, w):
    L = max(4, int(2000 * S ** 0.5))
    s = ''.join(R.choice('ab') for _ in range(L)); p = []; i = 0
    while i < L:   # p matches s: runs of s become '*', single letters '?'
        r = R.random()
        if r < 0.05: p.append('*'); i += R.randint(0, 20)
        elif r < 0.15: p.append('?'); i += 1
        else: p.append(s[i]); i += 1
    w('', s + '\n' + ''.join(p) + '\n')
    for i, (a, b) in enumerate([('aa', 'a'), ('aa', '*'), ('cb', '?a'), ('adceb', '*a*b'), ('acdcb', 'a*c?b'), ('', ''), ('', '*'),
                                ('', '?'), ('abc', ''), ('abc', '***'), ('abc', 'a*?'), ('mississippi', 'm??*ss*?i*pi'), ('ab', '*?*?*')]):
        w(str(i + 2), a + '\n' + b + '\n')
