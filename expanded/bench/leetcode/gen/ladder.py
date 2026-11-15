def gen(R, S, w):
    n = max(4, int(100000 * S)); L = 6
    words = list({''.join(R.choice('abcdefghij') for _ in range(L)) for _ in range(n)})
    R.shuffle(words)
    b = ''.join(R.choice('abcdefghij') for _ in range(L))
    w('', f'{b}\n{words[0]}\n' + ' '.join(words) + '\n')
    w('2', 'hit\ncog\nhot dot dog lot log cog\n'); w('3', 'hit\ncog\nhot dot dog lot log\n'); w('4', 'a\nc\na b c\n')
    w('5', 'ab\ncd\nad cd\n'); w('6', 'hot\ndog\nhot dog\n'); w('7', 'hit\nhot\nhot\n'); w('8', 'abc\nxyz\nabc abd xbd xyd xyz xyz\n')
    w('10', 'aa\nbb\ncc bb bc\n')
    w('9', 'red\ntax\nted tex red tax tad den rex pee\n')
