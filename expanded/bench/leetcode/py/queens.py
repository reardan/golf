import sys
n = int(sys.stdin.read())
full = (1 << n) - 1
def solve(cols, d1, d2):
    if cols == full:
        return 1
    total = 0
    avail = ~(cols | d1 | d2) & full
    while avail:
        bit = avail & -avail
        avail ^= bit
        total += solve(cols | bit, (d1 | bit) << 1, (d2 | bit) >> 1)
    return total
print(solve(0, 0, 0))
