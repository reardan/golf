import sys
lines = sys.stdin.read().split('\n')
gas, cost = list(map(int, lines[0].split())), list(map(int, lines[1].split()))
total = tank = start = 0
for i, (g, c) in enumerate(zip(gas, cost)):
    total += g - c
    tank += g - c
    if tank < 0:
        start, tank = i + 1, 0
print(start if total >= 0 else -1)
