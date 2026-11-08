g=open(0).read().split();s={(i,j)for i,r in enumerate(g)for j,c in enumerate(r)if'1'==c};n=0
while s:
 n+=1;t=[s.pop()]
 while t:y,x=t.pop();q={(y+1,x),(y-1,x),(y,x+1),(y,x-1)}&s;s-=q;t+=q
print(n)
