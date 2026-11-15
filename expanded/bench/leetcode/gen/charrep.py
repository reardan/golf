def gen(R, S, w):
    n = max(10, int(250000 * S)); A = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    wt = [R.random() ** 3 for _ in A]
    w('', f'{max(1, n // 1000)}\n' + ''.join(R.choices(A, wt, k=n)) + '\n')
    w('2', '2\nABAB\n'); w('3', '1\nAABABBA\n'); w('4', '0\nA\n'); w('5', '1\nA\n'); w('6', '0\nAB\n')
    w('7', '0\nAABBBA\n'); w('8', '3\nABCDE\n'); w('9', '5\nAB\n'); w('10', '2\nAAAA\n'); w('11', '1\nABBBCCCCD\n')
