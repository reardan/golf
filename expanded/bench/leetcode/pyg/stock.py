m=9e9;b=0
for p in map(int,open(0).read().split()):m=min(m,p);b=max(b,p-m)
print(b)
