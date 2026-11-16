def gen(R, S, w):
    side = max(4, int(1000 * S ** 0.5))
    w('', ''.join(''.join('1' if R.random() < 0.8 else '0' for _ in range(side)) + '\n' for _ in range(side)))
    w('2', '10100\n10111\n11111\n10010\n'); w('3', '0\n'); w('4', '1\n'); w('5', '00\n00\n')
    w('6', '01\n10\n'); w('7', '111\n111\n'); w('8', '0110\n1111\n0110\n')
