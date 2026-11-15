# gen1.py NAME SCALE DIR — write only gen/NAME.py's inputs (what gen.py writes for it).
import os, random, sys, importlib.util
nm, S, d = sys.argv[1], float(sys.argv[2]), sys.argv[3]
os.makedirs(d, exist_ok=True)
B = os.path.dirname(os.path.abspath(__file__))
sp = importlib.util.spec_from_file_location('g', f'{B}/gen/{nm}.py'); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
m.gen(random.Random(nm), S, lambda suf, s: open(f'{d}/{nm}{suf}.txt', 'w').write(s))
