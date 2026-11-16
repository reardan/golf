def gen(R, S, w):
    n = max(20, int(200000 * S))
    words = set()
    while len(words) < 40:
        words.add(''.join(R.choice('ab') for _ in range(R.randint(2, 12))))
    words = sorted(words); s = []
    while len(s) < n: s += R.choice(words)
    w('', ''.join(s) + '\n' + ' '.join(words) + '\n')
    w('2', 'leetcode\nleet code\n'); w('3', 'applepenapple\napple pen\n'); w('4', 'catsandog\ncats dog sand and cat\n')
    w('5', 'a\nb\n'); w('6', 'aaaaaaa\naaaa aaa\n'); w('7', 'ab\na b\n'); w('8', 'a\na\n')
    w('9', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaab\na aa aaa aaaa aaaaa\n')
