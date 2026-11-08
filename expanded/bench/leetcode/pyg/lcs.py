a,b=open(0).read().split();p=[0]*(len(b)+1)
for c in a:
 q=[0]
 for j,d in enumerate(b):q+=p[j]+1 if c==d else max(p[j+1],q[j]),
 p=q
print(p[-1])
