def gen(R, S, w):
    n = max(4, int(1500000 * S))
    al = 'abcdefghijklmnopqrstuvwxyz0123456789'
    h = [R.choice(al) for _ in range(n)]
    core = h + ([R.choice(al)] if R.random() < 0.5 else []) + h[::-1]
    out = []
    for c in core:   # random case and punctuation; still a palindrome after cleaning
        while R.random() < 0.3: out.append(R.choice(' ,.:;!?-_\'"@[]`{}()'))
        out.append(c.upper() if R.random() < 0.5 else c)
    w('', ''.join(out) + '\n')
    w('2', 'A man, a plan, a canal: Panama\n'); w('3', 'race a car\n'); w('4', ' \n')
    w('5', '0P\n'); w('6', '1a2a1\n'); w('7', 'ab@`BA\n'); w('8', '.,\n'); w('9', 'a.\n')
