def gen(R, S, w):
    A = max(4, int(100000 * S)); lo = max(1, int(300 * S)); c = R.sample(range(lo, max(lo + 15, int(3000 * S))), 12)
    w('', f'{A}\n' + ' '.join(map(str, c)) + '\n')   # answer about 2^35 at full size
    w('2', '5\n1 2 5\n'); w('3', '3\n2\n'); w('4', '10\n10\n'); w('5', '0\n7\n'); w('6', '0\n1 2\n')
    w('7', '7\n2 4\n'); w('8', '500\n3 5 7 8 9 10 11\n'); w('9', '1\n2 3\n')
