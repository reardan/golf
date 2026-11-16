def gen(R, S, w):
    n = max(20, int(500000 * S)); A = 'ABCDEFGHIJabcdefghij'
    s = ''.join(R.choice(A) for _ in range(n))
    t = ''.join(R.choice(A) for _ in range(30))
    w('', s + '\n' + t + '\n')
    w('2', 'ADOBECODEBANC\nABC\n'); w('3', 'a\na\n'); w('4', 'a\naa\n'); w('5', 'ab\nb\n')
    w('6', 'aa\naa\n'); w('7', 'bba\nab\n'); w('8', 'abc\nd\n'); w('9', 'cabwefgewcwaefgcf\ncae\n')
