import sys, heapq
lists = [list(map(int, r.split())) for r in sys.stdin.read().split('\n')]
print(' '.join(map(str, heapq.merge(*lists))))
