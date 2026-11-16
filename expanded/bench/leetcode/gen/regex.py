def gen(R, S, w):
    # a pattern of letters, dots and stars over 'ab', and a string it matches
    k = max(4, int(2000 * S ** 0.5)); p = []; s = []
    for _ in range(k):
        c = R.choice('ab.') if R.random() < 0.9 else '.'
        if R.random() < 0.4:
            p.append(c + '*'); s += [R.choice('ab') if c == '.' else c for _ in range(R.randint(0, 3))]
        else:
            p.append(c); s.append(R.choice('ab') if c == '.' else c)
    s = ''.join(s) or 'a'
    w('', s + '\n' + ''.join(p) + '\n')
    for i, (a, b) in enumerate([('aa', 'a'), ('aa', 'a*'), ('ab', '.*'), ('aab', 'c*a*b'), ('mississippi', 'mis*is*p*.'),
                                ('a', 'ab*'), ('ab', '.*c'), ('aaa', 'a*a'), ('a', '.*..a*'), ('aaa', 'ab*a*c*a'),
                                ('ab', '.*..'), ('bbbba', '.*a*a'), ('a', 'b*'), ('abcd', 'd*')], 2):
        w(str(i), a + '\n' + b + '\n')
