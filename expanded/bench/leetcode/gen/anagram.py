def gen(R, S, w):
    n = max(4, int(2000000 * S))
    s = [R.choice('abcdefghijklmnopqrstuvwxyz') for _ in range(n)]
    t = s[:]; R.shuffle(t)
    w('', ''.join(s) + '\n' + ''.join(t) + '\n')   # an anagram: true
    w('2', 'anagram\nnagaram\n'); w('3', 'rat\ncar\n'); w('4', 'a\nab\n'); w('5', 'ab\na\n')
    w('6', 'a\na\n'); w('7', 'aab\nabb\n')
