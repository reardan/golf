import sys
m = [list(map(int, r.split())) for r in sys.stdin.read().splitlines() if r.strip()]
top, bot, left, right = 0, len(m) - 1, 0, len(m[0]) - 1
out = []
while top <= bot and left <= right:
    out += m[top][left:right + 1]
    out += [m[i][right] for i in range(top + 1, bot + 1)]
    if top < bot and left < right:
        out += m[bot][left:right][::-1]
        out += [m[i][left] for i in range(bot - 1, top, -1)]
    top, bot, left, right = top + 1, bot - 1, left + 1, right - 1
print(' '.join(map(str, out)))
