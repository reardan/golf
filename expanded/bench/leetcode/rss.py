import resource, subprocess, sys
# rss.py infile cmd... : peak RSS (KB) of child
subprocess.run(sys.argv[2:], stdin=open(sys.argv[1]), stdout=subprocess.DEVNULL)
print(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)
