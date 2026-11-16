def gen(R, S, w):
    n = max(4, int(100000 * S))
    pats = [str(R.randint(1, 999)) for _ in range(30)]
    def one():
        r = R.random()
        if r < 0.4:   # repeats of a short pattern, cut anywhere: the hard ties of a+b vs b+a
            p = R.choice(pats); return int((p * 10)[:R.randint(1, 10)])
        if r < 0.5: return R.choice([0, 1, 9, 10, 100, 1000000000])
        return R.randint(0, 10 ** R.randint(1, 9))
    a = [min(one(), 10 ** 9) for _ in range(n)]
    w('', ' '.join(map(str, a)) + '\n')
    w('2', '10 2\n'); w('3', '3 30 34 5 9\n'); w('4', '0 0\n'); w('5', '0\n'); w('6', '1\n')
    w('7', '432 43243\n'); w('8', '121 12\n'); w('9', '999999998 999999997 999999999\n')
    w('10', '1000000000 100000000 0 10\n'); w('11', '824 938 1399 5607 6973 5703 9609 4398 8247\n')
