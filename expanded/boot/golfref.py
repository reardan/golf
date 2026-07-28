#!/usr/bin/env python3
"""Python reference compiler (oracle) for expanded GOLF (v2).

Reads a v2 GOLF program (raw code-page bytes) on stdin and writes a standalone
ELF64 x86-64 Linux executable to stdout — the same contract as v1's
minimal/boot/golf0.py, but for the *full* v2 language.

This is a full oracle, not a shim:

  * **Atoms are auto-inherited** from tools/mkblob2.ATOMS, the single source of
    truth for the code-page atom templates.  Adding an atom there makes it work
    here with no edit to this file.
  * **Compiler ops are implemented natively** here: ′ ref (0x8C), “ str (0x8E),
    → set (0x8F) and ← get (0x90).  These four change the compiler's *logic*, not
    just its template table, so they cannot be inherited — they are transcribed
    from the authoritative v1-GOLF case strings REF_CASE / STR_CASE / SET_CASE /
    GET_CASE in tools/mkblob2.py.
  * **Off the bootstrap path.**  The real ladder is golf0.py -> v1c ->
    self/golf2.golf (see DESIGN.md); nothing here is ever compiled or trusted by
    it.  This file exists to cross-check the self-hosted golf2 differentially:
    the two compilers agree on *behaviour*, not necessarily on byte layout.

Only structural constants (ELF header, prologue/epilogue, the v1 op templates)
are imported from the frozen v1 compiler; the compile loop is local so v2 can
diverge from it freely.  The startup stub is v2's own — `mkblob2.STARTUP2`, v1's
with the entry-`rsp` stash in front — because that is what the blob carries and
the two must emit the same program prologue.
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "minimal", "boot"))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
import golf0     # frozen v1: ELF header, prologue/epilogue, v1 op templates
import mkblob2   # v2: the atom table (byte -> template) and v2's STARTUP2

BASE = golf0.BASE          # ELF load address; file offset f maps to VA BASE+f
FILESZ = golf0.FILESZ      # fixed p_filesz (binary must stay under this)

# v1's op templates plus every v2 atom.  A local copy: the frozen module is read
# from, never written to.
TEMPLATES = dict(golf0.TEMPLATES)
TEMPLATES.update({chr(b): list(tpl) for b, _mn, _gl, tpl, _d in mkblob2.ATOMS})
# M-VEC: the bare + - * ⌈ ⌊ are polymorphic — a hook-cell shape dispatch in front
# of the unchanged scalar body (see mkblob2._poly).  Applied LAST: dict update
# keeps the last write, while the blob's `f` returns the FIRST record for a key
# and therefore emits the override instead of the original — same result, so the
# oracle and the self-hosted compiler stay in agreement.
TEMPLATES.update({chr(b): list(tpl) for b, tpl in mkblob2.OVERRIDES.items()})

# Compiler-logic ops (prefixes / delimiters, not templates).
REF_BYTE = mkblob2.REF_BYTE   # ′  push a word's or atom's runtime address
STR_BYTE = mkblob2.STR_BYTE   # “  string literal delimiter (open and close)
SET_BYTE = mkblob2.SET_BYTE   # →  pop TOS into a named variable
GET_BYTE = mkblob2.GET_BYTE   # ←  push a named variable
VARBANK = 0x4E0000            # variable bank: cell for name c is VARBANK + 4*c


# --------------------------------------------------------------------- compile
def compile_bytes(src: bytes) -> bytes:
    out = bytearray(golf0.HEADER)
    # M-MEM: v2 binaries shrink p_memsz and seed rbp below the smaller BSS.
    # Both values come from mkblob2 so the oracle and golf2 cannot drift.
    out[mkblob2.MEMSZ_OFF:mkblob2.MEMSZ_OFF + 8] = mkblob2.MEMSZ.to_bytes(8, "little")
    # W8/M-TOOL: and STARTUP2 now carries the entry-`rsp` stash in front of that
    # `mov ebp, RSTACK_TOP`, so a compiled program can reach argv.  Imported, not
    # re-spelled: the oracle and the self-hosted compiler must not drift into
    # different prologues, and run2.sh's oracle-parity case gates exactly that.
    out += mkblob2.STARTUP2
    dict_ = {}          # name byte -> file offset of word body (its prologue)
    stack = []          # backpatch stack: (kind, offset)
    i, n = 0, len(src)

    def emit(bs):
        out.extend(bs)

    def patch32(at, target):
        """Store the rel32 that jumps from just-after-`at` to `target`.  Both are
        buffer offsets; VA is BASE+offset, so the difference is the same."""
        rel = target - (at + 4)
        out[at:at + 4] = rel.to_bytes(4, "little", signed=True)

    def emit_lit(v):
        # Local (not golf0's) so v2 literals can grow past 32 bits (M4).  Mirrors
        # the `W` word in self/golf2.golfj byte for byte: `push imm32` sign-
        # extends, so it only reproduces 0..2^31-1; anything wider goes through
        # rax, the only x86-64 form carrying a full 64-bit immediate.  Below 2^31
        # the encoding is unchanged, so small literals still compile identically.
        v &= 0xFFFFFFFFFFFFFFFF        # the compiler's accumulator is a register
        if v < 0x80000000:
            emit([0x68]); emit(v.to_bytes(4, "little"))      # push imm32
        else:
            emit([0x48, 0xB8]); emit(v.to_bytes(8, "little"))  # mov rax, imm64
            emit([0x50])                                       # push rax

    def emit_u32(v):
        emit(v.to_bytes(4, "little"))

    def take():
        """Consume one raw byte (the operand of a prefix op)."""
        nonlocal i
        if i >= n:
            raise SystemExit("golfref: unexpected end of input after prefix op")
        b = src[i]; i += 1
        return b

    while i < n:
        c = src[i]; i += 1
        ch = chr(c)
        if c <= 32:
            continue
        if ch == '#':                                # comment to end of line
            while i < n and src[i] != 10:
                i += 1
            continue
        if 48 <= c <= 57:                            # integer literal (greedy)
            v = c - 48
            while i < n and 48 <= src[i] <= 57:
                v = v * 10 + (src[i] - 48); i += 1
            emit_lit(v)
            continue
        if ch == "'":                                # char literal
            emit_lit(take())
            continue
        if ch == ':':                                # define word
            name = take()
            emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")  # jmp over body
            dict_[name] = len(out)                   # body = prologue address
            stack.append(('def', patch))
            emit(golf0.PROLOGUE)
            continue
        if ch == ';':                                # end definition
            emit(golf0.EPILOGUE)
            kind, patch = stack.pop()
            assert kind == 'def', "; without :"
            patch32(patch, len(out))
            continue
        if ch == '[':                                # if (execute when TOS==0)
            emit([0x58, 0x48, 0x85, 0xC0, 0x0F, 0x85]); patch = len(out); emit(b"\0\0\0\0")
            stack.append(('if', patch))
            continue
        if ch == ']':                                # end if
            kind, patch = stack.pop()
            assert kind == 'if', "] without ["
            patch32(patch, len(out))
            continue
        if ch == '{':                                # loop start (emits nothing)
            stack.append(('loop', len(out)))
            continue
        if ch == '}':                                # loop back while TOS==0
            kind, target = stack.pop()
            assert kind == 'loop', "} without {"
            emit([0x58, 0x48, 0x85, 0xC0, 0x0F, 0x84]); site = len(out); emit(b"\0\0\0\0")
            patch32(site, target)                    # negative rel32
            continue
        if ch == '`':                                # raw blob escape
            v = 0
            while 48 <= src[i] <= 57:
                v = v * 10 + (src[i] - 48); i += 1
            assert src[i] == 32, "blob count must be followed by a space"
            i += 1
            data = src[i:i + v]; i += v
            assert len(data) == v, "blob truncated"
            emit([0xE9]); emit_u32(v)                     # jmp over data
            data_off = len(out)
            emit(data)
            emit([0x68]); emit_u32(BASE + data_off)       # push VA
            continue

        # ---------------------------------------------------- v2 compiler logic
        if c == REF_BYTE:                            # ′name -> push name's VA
            name = take()
            if name in dict_:                        # a defined word: its body VA
                emit([0x68]); emit_u32(BASE + dict_[name])
                continue
            if chr(name) not in TEMPLATES:
                raise SystemExit(
                    f"golfref: ′ on unknown word 0x{name:02x} at byte {i-1}")
            # An atom has no callable body, so wrap its template in a thunk:
            #   jmp over; [prologue][template][epilogue]; push thunk VA
            emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")
            thunk = len(out)
            emit(golf0.PROLOGUE)
            emit(TEMPLATES[chr(name)])
            emit(golf0.EPILOGUE)
            patch32(patch, len(out))                 # land on the push below
            emit([0x68]); emit_u32(BASE + thunk)
            continue
        if c == STR_BYTE:                            # “bytes“ -> byte block
            # jmp over; [len:u32][bytes...]; push VA of the length word.
            emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")
            lenoff = len(out); emit(b"\0\0\0\0")     # length, filled in below
            count = 0
            while True:
                if i >= n:
                    raise SystemExit("golfref: unterminated string literal")
                b = src[i]; i += 1
                if b == STR_BYTE:                    # same byte opens and closes
                    break
                emit([b]); count += 1
            out[lenoff:lenoff + 4] = count.to_bytes(4, "little")
            patch32(patch, len(out))
            emit([0x68]); emit_u32(BASE + lenoff)
            continue
        if c == SET_BYTE:                            # →x : pop rax; mov [x],eax
            emit([0x58, 0x89, 0x04, 0x25]); emit_u32(VARBANK + 4 * take())
            continue
        if c == GET_BYTE:                            # ←x : mov eax,[x]; push rax
            emit([0x8B, 0x04, 0x25]); emit_u32(VARBANK + 4 * take()); emit([0x50])
            continue

        if ch in TEMPLATES:                          # v1 op or v2 atom
            emit(TEMPLATES[ch])
            continue
        # otherwise: call a user-defined word
        if c not in dict_:
            raise SystemExit(f"golfref: undefined word {ch!r} (0x{c:02x}) at byte {i-1}")
        emit([0xE8]); site = len(out); emit(b"\0\0\0\0")
        patch32(site, dict_[c])
        continue

    if stack:
        raise SystemExit(f"golfref: unbalanced blocks: {stack}")
    emit(golf0.AUTOEXIT)
    if len(out) >= FILESZ:
        raise SystemExit(f"golfref: output {len(out)} bytes exceeds p_filesz {FILESZ}")
    return bytes(out)


def main():
    sys.stdout.buffer.write(compile_bytes(sys.stdin.buffer.read()))


if __name__ == "__main__":
    main()
