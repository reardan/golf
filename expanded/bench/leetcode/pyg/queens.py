n=int(input());F=(1<<n)-1
def f(c,a,b):
 if c==F:return 1
 t=0;v=~(c|a|b)&F
 while v:x=v&-v;v^=x;t+=f(c|x,(a|x)<<1,(b|x)>>1)
 return t
print(f(0,0,0))
