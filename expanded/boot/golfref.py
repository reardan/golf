#!/usr/bin/env python3
"""Python reference compiler for expanded GOLF (v2), for debugging.

The real bootstrap path is `v1c` compiling `self/golf2.golf` (see DESIGN.md);
this file is just a convenient oracle. It reuses v1's reference compiler and
adds v2's new op templates, so v2 programs can be compiled in Python and
cross-checked against the self-hosted `golf2`.
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "minimal", "boot"))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
import golf0
import mkblob2

golf0.TEMPLATES.update({k: list(v) for k, v in mkblob2.NEW_OPS.items()})

def main():
    sys.stdout.buffer.write(golf0.compile_bytes(sys.stdin.buffer.read()))

if __name__ == "__main__":
    main()
