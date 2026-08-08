# v1 GOLF examples

Two programs in the **minimal (v1)** language, kept here as regression fixtures:
the expanded compiler must still compile all of v1, and `test/run2.sh` and
`test/selfcheck.sh` assert exactly that against these files.

They are copies of `examples/` on the [`minimal`](../../../tree/minimal) branch
and are frozen with it. Nothing else in `expanded/` reads them — the v2 examples
live one directory up, in the v2 language, with the code page and the prelude.
