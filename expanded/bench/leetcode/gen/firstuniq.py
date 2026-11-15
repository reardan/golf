def gen(R, S, w):
    n = max(60, int(2000000 * S)); A = 'bcdefghijklmnopqrstuvwxyz'
    s = list(A + A) + [R.choice(A) for _ in range(n - 50)]; R.shuffle(s)
    s.insert(R.randint(9 * n // 10, n), 'a')   # the only unique letter, near the end
    w('', ''.join(s) + '\n')
    w('2', 'leetcode\n'); w('3', 'loveleetcode\n'); w('4', 'aabb\n'); w('5', 'z\n'); w('6', 'abcabcd\n'); w('7', 'aa\n')
