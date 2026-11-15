def gen(R, S, w):
    side = max(4, int(1000 * S ** 0.5))
    g = [''.join('0' if R.random() < 0.08 else '1' for _ in range(side)) for _ in range(side)]
    w('', '\n'.join(g) + '\n')
    w('2', '10100\n10111\n11111\n10010\n'); w('3', '01\n10\n'); w('4', '0\n'); w('5', '1\n')
    w('6', '1111\n1111\n1111\n'); w('7', '0000\n'); w('8', '1\n1\n1\n'); w('9', '0111\n1111\n1110\n')
