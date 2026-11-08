#!/usr/bin/env python3
"""golfprune — compile only the prelude a program can reach (W13-I).

tools/golfc used to put the WHOLE encoded lib/prelude.golfj in front of every
program, so even `1Ṅ` was a 125 KB binary.  This module cuts the encoded
prelude down to the definitions the program can reach before golf2 sees it.
golf2, the seed and golfref are untouched: they still compile whatever bytes
they are given, in one pass.

The rule (REFERENCE "Prelude pruning"):

  * The prelude is split into ITEMS.  A definition `:x … ;`, `⊚x … ;` or
    `⊡x … ;` at top level (with whatever it nests) is one item; everything
    between definitions is TOP-LEVEL CODE (the startup instructions: the heap,
    the M-VEC hooks, the not-a-number hook, flush and end hooks, ...), which is
    always kept.
  * A name is REACHED when it occurs as a token in the program (or anything it
    includes), in top-level prelude code, or in the body of a kept definition:
    a one-byte name, a `‹long name›`, `ʘB` (= ‹_dgHH›) and the operand of every
    prefix op (′ → ← ⇡ ⇣) all count, so quotes, chains, aliases and forward
    references are covered.  Two compiler ops call prelude words the source
    does not spell: a 3+-link chain `⊚` forks through ⑂, and a record header
    `⊜` calls ⍳ and I — they reach those too.
  * Every definition of a reached name is kept, transitively; the rest are
    dropped.  A dropped definition leaves its newlines behind, so prelude line
    numbers do not move.
  * The scan over-approximates on purpose (bytes in strings, character
    literals and blobs of the PROGRAM count as names too): keeping a word too
    many costs bytes, dropping one changes behaviour.
  * A program that computes a prelude word's address at run time (rather than
    with ′ or by name) cannot be seen by the scan; `golfc -P` keeps the whole
    prelude, as does GOLFC_FULL=1 in the environment.

Since only unreached definitions go, every call, quote and forward reference
the program and the kept prelude make binds to exactly the body it bound to
before: the program's behaviour is unchanged; only addresses (and the
numbering of long names the program never reaches) differ.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import mkblob2  # noqa: E402

STR = mkblob2.STR_BYTE
LNAME, RNAME = mkblob2.LNAME_BYTE, mkblob2.RNAME_BYTE
DIGRAPH = mkblob2.DIGRAPH_BYTE
DEFINERS = {ord(":"), mkblob2.CHAIN_BYTE, mkblob2.FRAME_BYTE}
PREFIX = {mkblob2.REF_BYTE, mkblob2.SET_BYTE, mkblob2.GET_BYTE,
          mkblob2.LSET_BYTE, mkblob2.LGET_BYTE,
          mkblob2.VINC_BYTE, mkblob2.VDEC_BYTE}
FORK = 0xC7                              # ⑂: what a 3+-link chain calls
# Compiler ops whose expansion calls prelude words by fixed name
# (golfref: ⊚'s fork; ⊜'s constructor ⍳ and accessors I, and the bytes its
# setters spell, kept in case any of them becomes a word one day).
IMPLIED = {mkblob2.CHAIN_BYTE: (FORK,),
           mkblob2.REC_BYTE: (ord("R"), ord("I"), ord("&"), ord("_"),
                              ord("\\"), ord(">"), 0xA2, 0x91, 0xA5)}


def _name(src, i):
    """The name a prefix op or definer takes at src[i]: (name, next i).
    One byte -> int; ‹long› -> bytes; ʘB -> b'_dgHH'."""
    if i >= len(src):
        return None, i
    b = src[i]
    if b == LNAME:
        j = src.find(bytes([RNAME]), i + 1)
        if j < 0:
            return None, len(src)
        return src[i + 1:j], j + 1
    if b == DIGRAPH:
        nb = src[i + 1] if i + 1 < len(src) else 0
        return b"_dg%02X" % nb, min(i + 2, len(src))
    return b, i + 1


def split(src):
    """The encoded prelude as items: ('top', start, end, refs) for top-level
    code, ('def', start, end, names, refs) for one top-level definition.
    Lexes exactly as golf2 does where a `;` could hide: strings, character
    literals, blobs, comments, prefix operands, long names and digraphs."""
    items = []
    i, n = 0, len(src)
    depth = 0                      # open definitions
    start = 0                      # where the current item began
    names, refs = set(), set()
    top_refs = set()

    def flush_top(end):
        if end > start:
            items.append(("top", start, end, set(top_refs)))
        top_refs.clear()

    while i < n:
        c = src[i]
        here = refs if depth else top_refs
        if c <= 32:
            i += 1
            continue
        if c == ord("#"):
            while i < n and src[i] != 10:
                i += 1
            continue
        if 48 <= c <= 57:
            while i < n and 48 <= src[i] <= 57:
                i += 1
            continue
        if c == ord("'"):
            i += 2
            continue
        if c == ord("`"):
            j, v = i + 1, 0
            while j < n and 48 <= src[j] <= 57:
                v = v * 10 + src[j] - 48
                j += 1
            i = j + 1 + v
            continue
        if c == STR:
            j = src.find(bytes([STR]), i + 1)
            i = n if j < 0 else j + 1
            continue
        if c in DEFINERS:
            name, j = _name(src, i + 1)
            if depth == 0:
                flush_top(i)
                start = i
                names, refs = set(), set()
            names.add(name)
            refs.update(IMPLIED.get(c, ()))
            depth += 1
            i = j
            continue
        if c == ord(";"):
            if depth:
                depth -= 1
                i += 1
                if depth == 0:
                    items.append(("def", start, i, names, refs))
                    start = i
                continue
            i += 1                 # a stray ; (golf2 refuses it anyway)
            continue
        if c in PREFIX:
            name, i = _name(src, i + 1)
            if c not in (mkblob2.LSET_BYTE, mkblob2.LGET_BYTE):
                here.add(name)
            continue
        if c == mkblob2.REC_BYTE or c == mkblob2.IMPORT_BYTE:
            raise ValueError("golfprune: ⊜/⎘ in the prelude is not supported")
        name, i = _name(src, i)
        here.add(name)
        here.update(IMPLIED.get(c, ()))
    if depth:
        raise ValueError("golfprune: unterminated definition in the prelude")
    flush_top(n)
    return items


def refs(src):
    """Every name the program bytes could reach — a deliberate over-
    approximation: every byte is a one-byte name, every ‹…› a long name,
    every ʘB its digraph, plus the names ⊚ and ⊜ imply."""
    out = set(src)
    for c in set(src) & set(IMPLIED):
        out.update(IMPLIED[c])
    for m in re.finditer(rb"\xb4([0-9A-Za-z_-]+)\xb5", src):
        out.add(m.group(1))
    for m in re.finditer(rb"\xbd(.)", src, re.S):
        out.add(b"_dg%02X" % m.group(1)[0])
    return out


def prune(prelude, roots):
    """The encoded prelude with every unreachable definition replaced by its
    newlines.  roots: the names the program (and its includes) reach."""
    items = split(prelude)
    by_name = {}
    reach = set(roots)
    for it in items:
        if it[0] == "top":
            reach |= it[3]
        else:
            for nm in it[3]:
                by_name.setdefault(nm, []).append(it)
    work = list(reach)
    kept = set()
    while work:
        nm = work.pop()
        for it in by_name.get(nm, ()):
            if id(it) in kept:
                continue
            kept.add(id(it))
            for r in it[4] | it[3]:
                if r not in reach:
                    reach.add(r)
                    work.append(r)
    out = bytearray()
    for it in items:
        seg = prelude[it[1]:it[2]]
        if it[0] == "top" or id(it) in kept:
            out += seg
        else:
            out += b"\n" * seg.count(b"\n")
    return bytes(out)


def main():
    """golfprune PRELUDE.gb PROG.gb... > pruned.gb  (raw code-page bytes)."""
    pre = open(sys.argv[1], "rb").read()
    roots = set()
    for p in sys.argv[2:]:
        roots |= refs(open(p, "rb").read())
    sys.stdout.buffer.write(prune(pre, roots))


if __name__ == "__main__":
    main()
