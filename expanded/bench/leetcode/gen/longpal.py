def gen(R, S, w):
    n = max(10, int(5000000 * S)); A = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    w('', ''.join(R.choice(A) for _ in range(n)) + '\n')
    w('2', 'abccccdd\n'); w('3', 'a\n'); w('4', 'Aa\n'); w('5', 'bb\n'); w('6', 'ccc\n'); w('7', 'aAbBcCaAbBcC\n'); w('8', 'zZyYxX\n')
