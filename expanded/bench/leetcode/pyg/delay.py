from heapq import*
n,k,*e=map(int,open(0).read().split());a=[[]for _ in range(n+1)];D={};h=[(0,k)]
for i in range(0,len(e),3):a[e[i]]+=(e[i+1],e[i+2]),
while h:
 d,u=heappop(h)
 if u in D:continue
 D[u]=d
 for v,w in a[u]:heappush(h,(d+w,v))
print(max(D.values())if len(D)==n else-1)
