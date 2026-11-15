def gen(R, S, w):
    h = str(R.randint(10**4, 2 * 10**4))   # a 9-digit palindrome below 2^31
    w('', h + h[-2::-1] + '\n')
    for i, x in enumerate(['121', '-121', '10', '0', '7', '1000000001', '2147447412', '-2147483648', '123', '1001', '2147483647'], 2):
        w(str(i), x + '\n')
