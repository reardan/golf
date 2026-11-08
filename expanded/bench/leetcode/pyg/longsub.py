l={};s=b=0
for i,c in enumerate(input()):s=max(s,l.get(c,-1)+1);l[c]=i;b=max(b,i-s+1)
print(b)
