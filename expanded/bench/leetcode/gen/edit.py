def gen(R, S, w):
    L = max(4, int(2000 * S ** 0.5))
    a = ''.join(R.choice('abcd') for _ in range(L))
    b = list(a)
    for _ in range(L // 3):   # a mutated copy, so the distance is well below L
        i = R.randrange(len(b) + 1); op = R.randrange(3)
        if op == 0: b.insert(i, R.choice('abcd'))
        elif i < len(b):
            if op == 1: del b[i]
            else: b[i] = R.choice('abcd')
    w('', a + '\n' + ''.join(b) + '\n')
    w('2', 'horse\nros\n'); w('3', 'intention\nexecution\n'); w('4', '\nabc\n'); w('5', 'abc\n\n')
    w('6', '\n\n'); w('7', 'a\na\n'); w('8', 'ab\nba\n'); w('9', 'kitten\nsitting\n')
