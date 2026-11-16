def gen(R, S, w):
    L = 'abcdefghijklmnopqrstuvwxyz'
    p = ''.join(R.choice(L) for _ in range(40)); k = R.randint(20, 39)
    a = [p + ''.join(R.choice(L) for _ in range(R.randint(0, 20))) for _ in range(max(2, int(200000 * S)))]
    a[R.randrange(len(a))] = p[:k] + ('z' if p[k] != 'z' else 'y')   # the answer is p[:k]
    w('', ''.join(s + '\n' for s in a))
    for i, x in enumerate([['flower', 'flow', 'flight'], ['dog', 'racecar', 'car'], ['a'], ['ab', 'ab', 'ab'],
                           ['abc', 'ab'], ['a', 'b'], ['ab', 'abc', 'abd']], 2):
        w(str(i), ''.join(s + '\n' for s in x))
