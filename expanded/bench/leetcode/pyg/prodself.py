a=[*map(int,open(0).read().split())];n=len(a);o=[1]*n;p=q=1
for i in range(n):o[i]*=p;p*=a[i];o[~i]*=q;q*=a[~i]
print(*o)
