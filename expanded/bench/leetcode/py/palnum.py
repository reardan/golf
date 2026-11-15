import sys
x = int(sys.stdin.read())
if x < 0 or (x % 10 == 0 and x != 0):
    print('false')
else:
    r = 0
    while x > r:
        r = r * 10 + x % 10
        x //= 10
    print('true' if x == r or x == r // 10 else 'false')
