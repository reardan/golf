def gen(R, S, w):
    n = max(4, int(10000000 * S)); out = []; L = 0
    while L < n:
        sp = ' ' * R.choice([1, 1, 1, 2, 3]); wd = ''.join(R.choice('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ') for _ in range(R.randint(1, 12)))
        out.append(sp + wd); L += len(sp) + len(wd)
    w('', ''.join(out) + '   \n')
    w('2', 'Hello World\n'); w('3', '   fly me   to   the moon  \n'); w('4', 'luffy is still joyboy\n'); w('5', 'a\n'); w('6', '  Z  \n')
