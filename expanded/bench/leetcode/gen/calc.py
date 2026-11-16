def gen(R, S, w):
    N = max(20, int(3000000 * S))
    def expr(budget, depth):   # a random valid expression of about `budget` characters
        out = ['-' if R.random() < 0.2 else '']
        while True:
            if depth < 40 and budget > 30 and R.random() < 0.25:
                b = R.randint(10, min(budget, 2000)); out.append('(' + expr(b, depth + 1) + ')'); budget -= b
            else:
                out.append(str(R.randint(0, 10 ** R.randint(1, 6)))); budget -= 4
            if budget <= 0: return ''.join(out)
            sp = ' ' if R.random() < 0.3 else ''
            out.append(sp + R.choice('+-') + sp)
    w('', expr(N, 0) + '\n')
    w('2', '1 + 1\n'); w('3', ' 2-1 + 2 \n'); w('4', '(1+(4+5+2)-3)-(6+8)\n'); w('5', '-(2+3)\n')
    w('6', '- (3 + (4 + 5))\n'); w('7', '2147483647\n'); w('8', '1-(     -2)\n'); w('9', '(((7)))\n')
    w('10', '-1-(-(-(2-3)))+10\n'); w('11', '0\n')
