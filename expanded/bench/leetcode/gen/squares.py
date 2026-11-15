def gen(R, S, w):
    n = max(8, int(30000 * S)); n -= (n - 7) % 8   # n = 8b+7: the answer is 4, the DP's worst case
    w('', f'{n}\n')
    w('2', '12\n'); w('3', '13\n'); w('4', '1\n'); w('5', '7\n'); w('6', '4\n'); w('7', '2\n'); w('8', '3\n'); w('9', '10000\n'); w('10', '9999\n')
