def roman(n):
    out = ''
    for v, s in ((1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'),
                 (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')):
        while n >= v: out += s; n -= v
    return out
def gen(R, S, w):
    # LeetCode stops at 3999; the large input is a million-M numeral with a random tail
    w('', 'M' * max(4, int(1000000 * S)) + roman(R.randint(1, 3999)) + '\n')
    for i, x in enumerate(['III', 'LVIII', 'MCMXCIV', 'IV', 'IX', 'XL', 'MMMCMXCIX', 'CDXLIV', 'I', 'XCIX', 'MMMDCCCLXXXVIII'], 2):
        w(str(i), x + '\n')
