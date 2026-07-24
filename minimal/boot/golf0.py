#!/usr/bin/env python3
"""GOLF stage-0 reference compiler.

Reads a GOLF program on stdin, writes a standalone ELF64 x86-64 Linux
executable to stdout.  This is the bootstrap compiler: clarity over golf.
It exists to compile the self-hosted compiler (self/golf.golf) at least once.

Model: no parser, no AST.  Tokenize -> per-token machine-code template ->
concatenate bytes -> backpatch rel32 jumps.  Every op is one ASCII char.

See README.md for the full language spec.  The machine-code templates here
are the single source of truth; tools/mkblob.py mirrors them into the blob
embedded in self/golf.golf.
"""
import sys

# ------------------------------------------------------------------ layout
BASE = 0x400000          # ELF load address; file offset f maps to VA BASE+f
ENTRY = BASE + 120       # entry point: right after the 120-byte header
FILESZ = 0x10000         # fixed p_filesz (binary must stay under this)

# ------------------------------------------------------------ ELF header
def _u(v, n):            # little-endian unsigned, n bytes
    return v.to_bytes(n, "little")

EHDR = (
    b"\x7fELF" + bytes([2, 1, 1, 0]) + b"\0" * 8   # e_ident
    + _u(2, 2)           # e_type    = ET_EXEC
    + _u(0x3e, 2)        # e_machine = EM_X86_64
    + _u(1, 4)           # e_version
    + _u(ENTRY, 8)       # e_entry
    + _u(64, 8)          # e_phoff   = 64 (Phdr right after Ehdr)
    + _u(0, 8)           # e_shoff
    + _u(0, 4)           # e_flags
    + _u(64, 2)          # e_ehsize
    + _u(56, 2)          # e_phentsize
    + _u(1, 2)           # e_phnum
    + _u(0, 2)           # e_shentsize
    + _u(0, 2)           # e_shnum
    + _u(0, 2)           # e_shstrndx
)
PHDR = (
    _u(1, 4)             # p_type  = PT_LOAD
    + _u(7, 4)           # p_flags = RWX
    + _u(0, 8)           # p_offset
    + _u(BASE, 8)        # p_vaddr
    + _u(BASE, 8)        # p_paddr
    + _u(FILESZ, 8)      # p_filesz (fixed; pages past real EOF are never touched)
    + _u(0x800000, 8)    # p_memsz  (spans data region + return stack up to 0xC00000)
    + _u(0x1000, 8)      # p_align
)
HEADER = EHDR + PHDR
assert len(HEADER) == 120, len(HEADER)

STARTUP = bytes([0xBD, 0x00, 0x00, 0xC0, 0x00])          # mov ebp, 0xC00000
AUTOEXIT = bytes([0x31, 0xFF, 0x6A, 0x3C, 0x58, 0x0F, 0x05])  # exit(0)
PROLOGUE = bytes([0x48, 0x83, 0xED, 0x08, 0x8F, 0x45, 0x00])  # sub rbp,8; pop [rbp]
EPILOGUE = bytes([0xFF, 0x75, 0x00, 0x48, 0x83, 0xC5, 0x08, 0xC3])  # push[rbp];add rbp,8;ret

# ---------------------------------------------------- table-driven op templates
TEMPLATES = {
    '"': [0xFF, 0x34, 0x24],                              # dup   push [rsp]
    '_': [0x58],                                          # drop  pop rax
    '\\': [0x58, 0x59, 0x50, 0x51],                       # swap
    '&': [0xFF, 0x74, 0x24, 0x08],                        # over  push [rsp+8]
    '+': [0x58, 0x48, 0x01, 0x04, 0x24],                  # add
    '-': [0x58, 0x48, 0x29, 0x04, 0x24],                  # sub / equality
    '*': [0x59, 0x58, 0x48, 0x0F, 0xAF, 0xC1, 0x50],      # mul
    '/': [0x59, 0x58, 0x31, 0xD2, 0x48, 0xF7, 0xF1, 0x50],  # udiv
    '%': [0x59, 0x58, 0x31, 0xD2, 0x48, 0xF7, 0xF1, 0x52],  # umod
    '<': [0x59, 0x58, 0x48, 0x29, 0xC8, 0x48, 0x19, 0xC0, 0x50],  # uless -> -1/0
    '@': [0x58, 0x8B, 0x00, 0x50],                        # fetch32 (zero-extends)
    '!': [0x58, 0x59, 0x89, 0x08],                        # store32
    '?': [0x58, 0x0F, 0xB6, 0x00, 0x50],                  # fetch byte
    ',': [0x58, 0x59, 0x88, 0x08],                        # store byte
    '(': [0x6A, 0x00, 0x31, 0xC0, 0x31, 0xFF, 0x48, 0x89,
          0xE6, 0x6A, 0x01, 0x5A, 0x0F, 0x05],            # read byte (0 on EOF)
    ')': [0x6A, 0x01, 0x58, 0x89, 0xC7, 0x48, 0x89, 0xE6,
          0x89, 0xC2, 0x0F, 0x05, 0x58],                  # write byte
    '.': [0x5F, 0x6A, 0x3C, 0x58, 0x0F, 0x05],            # exit(TOS)
    '^': list(EPILOGUE),                                  # early return
}

# --------------------------------------------------------------------- compile
def compile_bytes(src: bytes) -> bytes:
    out = bytearray(HEADER)
    out += STARTUP
    dict_ = {}          # char -> file offset of word body (prologue)
    stack = []          # backpatch stack: (kind, offset)
    i, n = 0, len(src)

    def emit(bs):
        out.extend(bs)

    def patch32(at, target):
        rel = target - (at + 4)
        out[at:at + 4] = rel.to_bytes(4, "little", signed=True)

    def emit_lit(v):
        assert 0 <= v < 0x80000000, f"literal out of range: {v}"
        emit([0x68]); emit(v.to_bytes(4, "little"))

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
            emit_lit(src[i]); i += 1
            continue
        if ch == ':':                                # define word
            name = src[i]; i += 1
            emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")  # jmp over body
            dict_[name] = len(out)                   # body = prologue address
            stack.append(('def', patch))
            emit(PROLOGUE)
            continue
        if ch == ';':                                # end definition
            emit(EPILOGUE)
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
            emit([0xE9]); emit(v.to_bytes(4, "little"))   # jmp over data
            data_off = len(out)
            emit(data)
            emit([0x68]); emit((BASE + data_off).to_bytes(4, "little"))  # push VA
            continue
        if ch in TEMPLATES:
            emit(TEMPLATES[ch])
            continue
        # otherwise: call a user-defined word
        if c not in dict_:
            raise SystemExit(f"golf0: undefined word {ch!r} (0x{c:02x}) at byte {i-1}")
        emit([0xE8]); site = len(out); emit(b"\0\0\0\0")
        patch32(site, dict_[c])
        continue

    if stack:
        raise SystemExit(f"golf0: unbalanced blocks: {stack}")
    emit(AUTOEXIT)
    if len(out) >= FILESZ:
        raise SystemExit(f"golf0: output {len(out)} bytes exceeds p_filesz {FILESZ}")
    return bytes(out)


def main():
    src = sys.stdin.buffer.read()
    # NUL is reserved as EOF; it must not appear outside blob data.  Blobs are
    # consumed inline above, so any NUL the scanner would see is an error.
    sys.stdout.buffer.write(compile_bytes(src))


if __name__ == "__main__":
    main()
