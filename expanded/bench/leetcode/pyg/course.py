n,*e=map(int,open(0).read().split());a=[[]for _ in range(n)];d=[0]*n
for x,y in zip(e[::2],e[1::2]):a[y]+=x,;d[x]+=1
q=[i for i in range(n)if d[i]<1]
for u in q:
 for v in a[u]:
  d[v]-=1
  if d[v]<1:q+=v,
print(['false','true'][len(q)==n])
