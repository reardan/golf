g={(i,j):c for i,r in enumerate(open(0).read().split())for j,c in enumerate(r)}
q=[k for k in g if'2'==g[k]];f={k for k in g if'1'==g[k]};t=0
while q and f:
 n=[]
 for i,j in q:
  for k in(i+1,j),(i-1,j),(i,j+1),(i,j-1):
   if k in f:f-={k};n+=k,
 q=n;t+=1
print(-1 if f else t)
