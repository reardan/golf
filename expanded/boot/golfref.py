#!/usr/bin/env python3
"""Python reference compiler (oracle) for expanded GOLF (v2).

Reads a v2 GOLF program (raw code-page bytes) on stdin and writes a standalone
ELF64 x86-64 Linux executable to stdout — the same contract the frozen v1
reference compiler had, but for the *full* v2 language.

This is a full oracle, not a shim:

  * **Atoms are auto-inherited** from tools/mkblob2.ATOMS, the single source of
    truth for the code-page atom templates.  Adding an atom there makes it work
    here with no edit to this file.  (W11-3A's ⊷ ⊶ stack-pointer atoms, and the
    divide-by-zero hook call in the ÷ ∣ / % templates, arrive that way: the
    oracle's binaries run ‹catch› / ‹throw› exactly as golf2's do, which
    test/run2.sh's W11-3A block checks.)
  * **Compiler ops are implemented natively** here: ′ ref (0x8C), “ str (0x8E),
    → set (0x8F), ← get (0x90), ⊚ chain (0xB0), ⊡ ⇒ ⇐ (0xB1-0xB3) and the
    M2 long-name brackets ‹ › (0xB4/0xB5), and W11-2A's include ⎘ (0xB6),
    spliced in place here, and W11-4A's record header ⊜ (0xB7), expanded into
    the same words golf2 emits.  These change the compiler's
    *logic*, not just its template table, so they cannot be inherited — they are
    transcribed from the authoritative cases in self/seed.golfv1 and
    self/golf2.golfj, whose byte allocations tools/mkblob2.py owns.
  * **Off the bootstrap path.**  The real ladder is v1c -> self/seed.golf ->
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
sys.path.insert(0, HERE)                                # boot/v1.py
sys.path.insert(0, os.path.join(HERE, "..", "tools"))    # tools/mkblob2.py
import v1        # frozen v1: ELF header, prologue/epilogue, v1 op templates
import mkblob2   # v2: the atom table (byte -> template) and v2's STARTUP2

BASE = v1.BASE          # ELF load address; file offset f maps to VA BASE+f
CAP = mkblob2.PROGRAM_CAP   # W11-1E: largest image (192 KB); p_filesz = its size

# v1's op templates plus every v2 atom.  A local copy: the frozen module is read
# from, never written to.
TEMPLATES = dict(v1.TEMPLATES)
# (So W9-1A's signed ⌈ ⌊ — cmovl/cmovg — reach the oracle from that table alone.)
TEMPLATES.update({chr(b): list(tpl) for b, _mn, _gl, tpl, _d in mkblob2.ATOMS})
# M-VEC: the bare + - * ⌈ ⌊ are polymorphic — a hook-cell shape dispatch in front
# of the unchanged scalar body (see mkblob2._poly).  Applied LAST: dict update
# keeps the last write, while the blob's `f` returns the FIRST record for a key
# and therefore emits the override instead of the original — same result, so the
# oracle and the self-hosted compiler stay in agreement.
# W12-O1's not-a-number check in front of ± ⊕ ⊖ ² ⊗ ⊘ (mkblob2._numchk) is an
# override too, so it reaches the oracle through this same line.
TEMPLATES.update({chr(b): list(tpl) for b, tpl in mkblob2.OVERRIDES.items()})

# Compiler-logic ops (prefixes / delimiters, not templates).
REF_BYTE = mkblob2.REF_BYTE   # ′  push a word's or atom's runtime address
STR_BYTE = mkblob2.STR_BYTE   # “  string literal delimiter (open and close)
SET_BYTE = mkblob2.SET_BYTE   # →  pop TOS into a named variable
GET_BYTE = mkblob2.GET_BYTE   # ←  push a named variable
CHAIN_BYTE = mkblob2.CHAIN_BYTE  # ⊚  define a word as a tacit chain of links
FRAME_BYTE = mkblob2.FRAME_BYTE  # ⊡  define a word with a frame of locals
LSET_BYTE = mkblob2.LSET_BYTE    # ⇒  pop TOS into a local slot
LGET_BYTE = mkblob2.LGET_BYTE    # ⇐  push a local slot
LNAME_BYTE = mkblob2.LNAME_BYTE  # ‹  opens a long name (M2)
RNAME_BYTE = mkblob2.RNAME_BYTE  # ›  closes it
IMPORT_BYTE = mkblob2.IMPORT_BYTE  # ⎘  ⎘“path“ includes a file (W11-2A)
REC_BYTE = mkblob2.REC_BYTE  # ⊜  ⊜‹point›‹x›‹y›; a record header (W11-4A)
ELSE_BYTE = mkblob2.ELSE_BYTE  # ⋄  c[a⋄b] if-else, {c⋄body} top-tested while (W12-A7)
VINC_BYTE = mkblob2.VINC_BYTE  # ⇡x  inc qword [x] (W12-Z2)
VDEC_BYTE = mkblob2.VDEC_BYTE  # ⇣x  dec qword [x]
DIGRAPH_BYTE = mkblob2.DIGRAPH_BYTE  # ʘB  the long name ‹_dgHH› (W13-B, S6)
FORK_BYTE = 0xC7              # ⑂  the prelude word a 3+-link chain forks through
VARBANK = 0x4E0000            # variable bank: cell for name c is VARBANK + 8*c
VARSTRIDE = 8                 # M3W: 8 bytes per name (it was 4, and truncated)


# --------------------------------------------------------------------- compile
def compile_bytes(src: bytes) -> bytes:
    out = bytearray(v1.HEADER)
    # M-MEM: v2 binaries shrink p_memsz and seed rbp below the smaller BSS.
    # Both values come from mkblob2 so the oracle and golf2 cannot drift.
    out[mkblob2.MEMSZ_OFF:mkblob2.MEMSZ_OFF + 8] = mkblob2.MEMSZ.to_bytes(8, "little")
    # W8/M-TOOL: and STARTUP2 now carries the entry-`rsp` stash in front of that
    # `mov ebp, RSTACK_TOP`, so a compiled program can reach argv.  Imported, not
    # re-spelled: the oracle and the self-hosted compiler must not drift into
    # different prologues, and run2.sh's oracle-parity case gates exactly that.
    # W9-2C: it also mprotects the guard page below the return stack
    # (mkblob2.GUARD_LO), so a runaway recursion faults instead of corrupting.
    out += mkblob2.STARTUP2
    dict_ = {}          # name byte -> file offset of word body (its prologue)
    stack = []          # backpatch stack: (kind, offset)
    chain = None        # M-CHAIN2: the link bytes taken so far, or None
    frame = False       # M-FRAME: inside a ⊡ definition, which owns a slab
    flocals = []        # M-FRAME2: its locals' name numbers, in order of first use
    fsites = []         # M-FRAME2: its frame-size immediates, patched at ';'
    longs = []          # M2: long names in order of first appearance; name
                        # number LONG_BASE + i, exactly as golf2 interns them
    pending = {}        # M2/W10-A: name -> call/jmp sites awaiting its body
    included = []       # W11-2A: include-once table, the paths as written
    # W11-2A: the open includes, innermost last.  W11-3B made each a record of
    # where its spliced bytes start and end, which file it is (k+1 for
    # `included[k]`; the program is file 0, `top`), where its line count starts
    # (its start, or just past a form feed between tokens) and the ranges its
    # own closed includes were spliced into, whose lines are not its own.
    top = {"start": 0, "end": None, "file": 0, "reset": 0, "holes": []}
    segs = []
    pending_at = {}     # W11-3B: name -> where() of its first forward use
    i, n = 0, len(src)

    def emit(bs):
        out.extend(bs)

    def where(at):
        """W11-3B: golf2's ‹where› — ` at [path ]line N` for source offset `at`,
        N counted in the file that is being read there."""
        seg = segs[-1] if segs else top
        lo = seg["reset"]
        nl = src.count(b"\n", lo, at)
        for a, b in seg["holes"]:
            if b > lo:
                nl -= src.count(b"\n", max(a, lo), min(b, at))
        name = included[seg["file"] - 1] + b" " if seg["file"] else b""
        return b" at " + name + b"line " + str(nl + 1).encode()

    def die(msg):
        """A golf2-format compile error at the current offset, exit 2."""
        sys.stderr.buffer.write(b"GOLF: " + msg + where(i) + b"\n")
        raise SystemExit(2)

    def patch32(at, target):
        """Store the rel32 that jumps from just-after-`at` to `target`.  Both are
        buffer offsets; VA is BASE+offset, so the difference is the same."""
        rel = target - (at + 4)
        out[at:at + 4] = rel.to_bytes(4, "little", signed=True)

    def emit_lit(v):
        # Local (not v1's) so v2 literals can grow past 32 bits (M4).  Mirrors
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

    def push_ref(name):
        """Emit `push <the address of the word or atom named `name`>`.

        A defined word has a body to point at.  An atom does not — it is a
        template, not callable code — so its template is wrapped in a thunk
        (jumped over) and the thunk's address is pushed instead.  Shared by ′
        and by M-CHAIN2's chain links, exactly as the word `X` is in
        self/golf2.golfj."""
        if name in dict_:                            # a defined word: its body VA
            emit([0x68]); emit_u32(BASE + dict_[name])
            return
        if name >= mkblob2.LONG_BASE or chr(name) not in TEMPLATES:
            # Not an atom: a word defined later (M2, W10-A) — a thunk
            emit([0xE9]); emit_u32(5)                # [jmp rel32] to it, jumped
            thunk = len(out)                         # over; the rel32 is a
            forward(0xE9, name)                      # forward site like any call
            emit([0x68]); emit_u32(BASE + thunk)
            return
        emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")
        thunk = len(out)
        emit(v1.PROLOGUE)
        emit(TEMPLATES[chr(name)])
        emit(v1.EPILOGUE)
        patch32(patch, len(out))                     # land on the push below
        emit([0x68]); emit_u32(BASE + thunk)

    def forward(op, name):
        """M2/W10-A: `op rel32` to a name not defined yet; its definition
        patches the site (golf2 threads the same sites through the placeholders,
        so once patched the bytes are identical)."""
        emit([op]); pending.setdefault(name, []).append(len(out))
        pending_at.setdefault(name, where(i))
        emit(b"\0\0\0\0")

    def define(name):
        """Bind `name` to the body starting here, and patch its forward sites."""
        dict_[name] = len(out)
        pending_at.pop(name, None)
        for site in pending.pop(name, []):
            patch32(site, dict_[name])

    def shown(name):
        """A name number as golf2's diagnostics show it: the byte, or ‹name›."""
        if name < mkblob2.LONG_BASE:
            return bytes([name])
        return "‹".encode() + longs[name - mkblob2.LONG_BASE] + "›".encode()

    def read_long():
        """M2: the bytes after ‹ up to ›, interned to a name number.  Checked
        byte by byte in golf2's order, so a bad name is reported as golf2 does
        (W11-3B): what was read before the offending byte, at that byte."""
        nonlocal i
        start = i
        while True:
            eof = i >= n                               # golf2 reads 0 there
            b = 0 if eof else src[i]
            i += 0 if eof else 1
            if b == RNAME_BYTE and i - 1 > start:
                break
            if (b == RNAME_BYTE or not (chr(b).isascii() and (chr(b).isalnum() or b in b"_-"))
                    or i - 1 - start >= mkblob2.LONG_LEN):
                die("bad long name ‹".encode() + src[start:i if eof else i - 1] + "›".encode())
        name = src[start:i - 1]
        if name not in longs:
            if len(longs) >= mkblob2.LONG_MAX:
                die("too many long names ‹".encode() + name + "›".encode())
            longs.append(name)
        return mkblob2.LONG_BASE + longs.index(name)

    def digraph():
        """W13-B (S6): ʘ then any byte B is the long name ‹_dgHH› (HH = B in
        upper-case hex), interned like the same text after ‹.  golf2's ‹read›
        gives 0 at end of input, so a trailing ʘ is ‹_dg00› there too."""
        nonlocal i
        b = src[i] if i < n else 0
        i += 1 if i < n else 0
        return intern(b"_dg%02X" % b)

    def take_name():
        """A prefix's operand: one byte, a whole ‹long name›, or ʘB (W13-B)."""
        b = take()
        if b == DIGRAPH_BYTE:
            return digraph()
        return read_long() if b == LNAME_BYTE else b

    def call_or_template(b):
        """Compile one ordinary token: its template, or a call to that word."""
        if b < 256 and chr(b) in TEMPLATES:
            emit(TEMPLATES[chr(b)])
            return
        if b not in dict_:                           # not defined yet: a forward
            forward(0xE8, b)                         # call (M2; one-byte names
            return                                   # too since W10-A)
        emit([0xE8]); site = len(out); emit(b"\0\0\0\0")
        patch32(site, dict_[b])

    def take():
        """Consume one raw byte (the operand of a prefix op)."""
        nonlocal i
        if i >= n:
            raise SystemExit("golfref: unexpected end of input after prefix op")
        b = src[i]; i += 1
        return b

    def include():
        """W11-2A: ⎘“path“ — golf2 swaps the file onto fd 0; here its bytes
        are spliced in at i, with a newline after them so that no token runs
        across the file's end (golf2's reader sees end of file there).  Same
        search (as written, then lib/), include-once on the path's bytes, depth
        and table bounds, and the same diagnostics, exit 2."""
        nonlocal src, n
        path = b""
        def bad(what):
            die(what + b" " + path)
        if i >= n or src[i] != STR_BYTE:
            bad(b"cannot include")
        j = i + 1
        while j < n and src[j] != STR_BYTE and j - i - 1 < mkblob2.IMPORT_LEN:
            j += 1
        path = src[i + 1:j]
        if j >= n or src[j] != STR_BYTE:
            bad(b"cannot include")
        rest = j + 1                                 # just past the closing “
        if path in included:
            return rest, b""
        if len(segs) >= mkblob2.IMPORT_DEPTH:
            bad(b"includes nested too deeply")
        if len(included) >= mkblob2.IMPORT_FILES:
            bad(b"too many includes")
        included.append(path)
        for cand in (d + path for d in mkblob2.IMPORT_DIRS):  # ., lib/, vendor/
            try:
                with open(cand, "rb") as f:
                    return rest, f.read() + b"\n"
            except IsADirectoryError:                # golf2 reads it as empty
                return rest, b"\n"
            except OSError:
                pass
        bad(b"cannot include")

    def legal(b):
        """golf2's ‹legal›: may byte b stand in a long name (0-9 A-Z a-z _ -)?"""
        return b < 128 and (chr(b).isalnum() or b in b"_-")

    def intern(name):
        """golf2's ‹intern›: a name's number, claiming the next one if new."""
        if name not in longs:
            if len(longs) >= mkblob2.LONG_MAX:
                die("too many long names ‹".encode() + name + "›".encode())
            longs.append(name)
        return mkblob2.LONG_BASE + longs.index(name)

    def record():
        """W11-4A: ⊜‹point›‹x›‹y›; — golf2's ‹defrecord›.  The header expands to
        the words golf2 emits, token for token (see self/golf2.golfj, Records):
            :‹point› n⍳ (per field k, last first) \\&16≪16>(8k+8)﹢⊛ ;
            :‹point-x› k⊇;   :‹set-point-x› &k⊇_&16≪16>(8k+8)﹢⊛;
        with the names interned in that order, so the numbers match too."""
        nonlocal i
        def rbyte():                                 # golf2's ‹read›: 0 at the
            nonlocal i                               # end of the file (here,
            end = segs[-1]["end"] - 1 if segs else n  # the newline include()
            if i >= end:                             # appends is past it)
                return 0
            i += 1
            return src[i - 1]
        b = rbyte()
        rec = read_long() if b == LNAME_BYTE else b
        if b == DIGRAPH_BYTE:                        # W13-B: golf2's ‹getname›
            rec = digraph()
        if rec < mkblob2.LONG_BASE and not legal(rec):
            die(b"bad record name " + bytes([rec]))
        fields = []
        while True:
            b = rbyte()
            if b == ord(';'):
                if not fields:
                    die(b"record without fields " + shown(rec))
                break
            if b == 0:
                die(b"record without ; " + shown(rec))
            if b < 33:
                continue
            if b == LNAME_BYTE:
                b = read_long()
            if b < mkblob2.LONG_BASE and not legal(b):
                die(b"bad record field " + bytes([b]))
            if len(fields) >= mkblob2.REC_MAX:
                die(b"too many record fields " + shown(rec))
            fields.append(b)
        def spelled(name):
            return bytes([name]) if name < mkblob2.LONG_BASE else longs[name - mkblob2.LONG_BASE]
        def invent(*parts):
            name = b"".join(parts)
            if len(name) > mkblob2.LONG_LEN:         # ‹badname›: what fitted
                die("bad long name ‹".encode() + name[:mkblob2.LONG_LEN] + "›".encode())
            return intern(name)
        def header(name):                            # ':'s header
            emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")
            define(name)
            emit(v1.PROLOGUE)
            return patch
        def end(patch):
            emit(v1.EPILOGUE); patch32(patch, len(out))
        def store(k):                                # &16≪16>(8k+8)﹢⊛
            call_or_template(ord('&')); emit_lit(16); call_or_template(0xA2)
            emit_lit(16); call_or_template(ord('>')); emit_lit(8 * k + 8)
            call_or_template(0x91); call_or_template(0xA5)
        patch = header(rec)
        emit_lit(len(fields)); call_or_template(ord('R'))
        for k in reversed(range(len(fields))):
            call_or_template(ord('\\')); store(k)
        end(patch)
        for k, f in enumerate(fields):
            patch = header(invent(spelled(rec), b"-", spelled(f)))
            emit_lit(k); call_or_template(ord('I'))
            end(patch)
            patch = header(invent(b"set-", spelled(rec), b"-", spelled(f)))
            call_or_template(ord('&')); emit_lit(k); call_or_template(ord('I'))
            call_or_template(ord('_')); store(k)
            end(patch)

    while i < n:
        while segs and i >= segs[-1]["end"]:         # W11-2A: left an include
            done = segs.pop()
            (segs[-1] if segs else top)["holes"].append((done["start"], done["end"]))
        c = src[i]; i += 1
        ch = chr(c)
        if c <= 32:
            if c == 12:                              # W11-3B: a form feed
                (segs[-1] if segs else top)["reset"] = i   # restarts the count
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
            name = take_name()
            emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")  # jmp over body
            define(name)                             # body = prologue address
            stack.append(('def', patch))
            emit(v1.PROLOGUE)
            continue
        if ch == ';':                                # end definition (any kind)
            if chain is not None:                    # 1 or 2 links never forked
                for b in chain[:2] if len(chain) < 3 else []:
                    call_or_template(b)
                chain = None
            if frame:                                # M-FRAME: release the slab,
                frame = False                        # now that its size is known
                size = 8 * len(flocals)              # (M-FRAME2): patch every
                for at in fsites:                    # earlier immediate with it
                    out[at:at + 4] = size.to_bytes(4, "little")
                emit(mkblob2.FRAME_RELEASE); emit_u32(size)
            emit(v1.EPILOGUE)
            kind, patch = stack.pop()
            assert kind == 'def', "; without :"
            patch32(patch, len(out))
            continue
        if ch == '^':                                # M-FRAME: early return.  A
            if frame:                                # plain template until now;
                emit(mkblob2.FRAME_RELEASE)          # it is a case only so it
                fsites.append(len(out)); emit_u32(0) # (size patched at ';')
            emit(TEMPLATES['^'])                     # can release a ⊡ frame.
            continue
        if ch == '[':                                # if (execute when TOS==0)
            emit([0x58, 0x48, 0x85, 0xC0, 0x0F, 0x85]); patch = len(out); emit(b"\0\0\0\0")
            stack.append(('if', patch))
            continue
        if ch == ']':                                # end if (or its else)
            kind, patch = stack.pop()
            assert kind in ('if', 'else'), "] without ["
            patch32(patch, len(out))
            continue
        if ch == '{':                                # loop start (emits nothing)
            stack.append(('loop', len(out)))
            continue
        if ch == '}':                                # loop back while TOS==0
            top_ = stack.pop()
            if top_[0] == 'while':                   # W12-A7: {c⋄body} — back
                _, target, exit_ = top_              # to the test always, then
                emit([0xE9]); site = len(out); emit(b"\0\0\0\0")  # land the exit
                patch32(site, target)
                patch32(exit_, len(out))
                continue
            kind, target = top_
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
            push_ref(take_name())
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
        if c == SET_BYTE:                            # →x : pop rax; mov [x],rax
            emit([0x58, 0x48, 0x89, 0x04, 0x25])
            emit_u32(VARBANK + VARSTRIDE * take_name())
            continue
        if c == GET_BYTE:                            # ←x : mov rax,[x]; push rax
            emit([0x48, 0x8B, 0x04, 0x25])
            emit_u32(VARBANK + VARSTRIDE * take_name()); emit([0x50])
            continue

        if c == FRAME_BYTE:                          # ⊡name … ; : with locals
            name = take_name()                       # the header is ':'s, plus
            emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")
            define(name)
            stack.append(('def', patch))
            emit(v1.PROLOGUE)
            emit(mkblob2.FRAME_RESERVE)              # ... a slab sized at ';'
            fsites = [len(out)]; emit_u32(0)         # (M-FRAME2), one cell per
            flocals = []                             # distinct local named
            frame = True                             # which '^' and ';' release
            continue
        if c in (LSET_BYTE, LGET_BYTE):              # ⇒x / ⇐x : a frame slot
            name = take_name()                       # a..z (W12-Z3), or a ‹long name›
            if name < 256 and not 0 <= name - ord('a') < 26:
                die(b"local out of range " + shown(name))
            if not frame:                            # outside ⊡: M-FRAME's fixed
                if name >= 256 or name - ord('a') >= 8:  # a..h slot; a long name
                    die(b"local out of range " + shown(name))  # (or i..z) has
                slot = name - ord('a')               # nowhere to go
            else:                                    # M-FRAME2: first appearance
                if name not in flocals:              # claims the next slot
                    if len(flocals) >= mkblob2.FRAME_MAX_LOCALS:
                        die(b"too many locals " + shown(name))
                    flocals.append(name)
                slot = flocals.index(name)
            if c == LSET_BYTE:                       # pop rax; mov [rbp+d],rax
                emit([0x58, 0x48, 0x89, 0x45, 8 * slot])
            else:                                    # mov rax,[rbp+d]; push rax
                emit([0x48, 0x8B, 0x45, 8 * slot, 0x50])
            continue

        if c in (VINC_BYTE, VDEC_BYTE):              # W12-Z2: ⇡x / ⇣x, in memory
            glyph = "⇡" if c == VINC_BYTE else "⇣"
            if i >= n:                               # golf2 reads 0 at the end
                die((glyph + " needs a variable").encode())
            name = take_name()                       # a letter, or a ‹long name›
            if name < 256 and not (65 <= name < 91 or 97 <= name < 123):
                die((glyph + " needs a variable").encode())
            k = 0 if c == VINC_BYTE else 8           # /0 inc, /1 dec: modrm + 8
            if frame and name in flocals:            # a local this ⊡ word has
                emit([0x48, 0xFF, 0x45 + k, 8 * flocals.index(name)])  # named
            else:                                    # inc/dec qword [rbp+d] ...
                emit([0x48, 0xFF, 0x04 + k, 0x25])   # ... or qword [cell]
                emit_u32(VARBANK + VARSTRIDE * name)
            continue

        if c == IMPORT_BYTE:                         # W11-2A: ⎘“path“
            i, data = include()
            if data:
                src = src[:i] + data + src[i:]; n = len(src)
                for seg in segs:
                    seg["end"] += len(data)
                segs.append({"start": i, "end": i + len(data), "reset": i,
                             "file": len(included), "holes": []})
            continue
        if c == ELSE_BYTE:                           # W12-A7: ⋄
            kind = stack[-1][0] if stack else None
            if kind == 'if':                         # c[a⋄b]: a ends with a jmp
                _, patch = stack.pop()               # to ']', and '['s jnz
                emit([0xE9]); site = len(out); emit(b"\0\0\0\0")  # lands on b
                patch32(patch, len(out))
                stack.append(('else', site))
            elif kind == 'loop':                     # {c⋄body}: leave unless c==0
                _, target = stack.pop()
                emit([0x58, 0x48, 0x85, 0xC0, 0x0F, 0x85]); site = len(out); emit(b"\0\0\0\0")
                stack.append(('while', target, site))
            elif kind in ('else', 'while'):
                die("⋄ twice in one block".encode())
            else:
                die("⋄ outside [ ] or { }".encode())
            continue
        if c == REC_BYTE:                            # W11-4A: ⊜‹point›‹x›‹y›;
            record()
            continue
        if c == CHAIN_BYTE:                          # ⊚name … ; : a tacit chain
            name = take_name()                       # the header is ':'s
            emit([0xE9]); patch = len(out); emit(b"\0\0\0\0")
            define(name)
            stack.append(('def', patch))
            emit(v1.PROLOGUE)
            chain = []                               # links from here to ';'
            continue
        if c == DIGRAPH_BYTE:                        # W13-B: ʘB as a token is
            c = digraph()                            # ‹_dgHH›, a link or a call
        elif c == LNAME_BYTE:                        # M2: ‹name› as a token — its
            c = read_long()                          # number then stands for it,
                                                     # as a link or as a call
        if chain is not None:
            # Inside a chain body this token is a LINK, not a call.  The count
            # decides the train: the third link emits ′f ′g ′h and the ⑂ that
            # forks them, and a fourth or later link is an ordinary call applied
            # to what the fork left.  A 1- or 2-link chain is flushed by ';'.
            chain.append(c)
            if len(chain) == 3:
                for b in chain:
                    push_ref(b)
                call_or_template(FORK_BYTE)
            elif len(chain) > 3:
                call_or_template(c)
            continue

        call_or_template(c)                          # v1 op, v2 atom, or a call
        continue

    if stack:
        raise SystemExit(f"golfref: unbalanced blocks: {stack}")
    def undefined(shown, name):                      # W11-3B: golf2's message,
        sys.stderr.buffer.write(b"GOLF: undefined word " + shown  # at the
                                + pending_at[name] + b"\n")       # first use
        raise SystemExit(2)
    for b in range(mkblob2.LONG_BASE):               # W10-A: a one-byte name
        if b in pending:                             # called, never defined
            undefined(bytes([b]), b)
    for k, name in enumerate(longs):                 # M2: called, never defined
        if mkblob2.LONG_BASE + k in pending:
            undefined("‹".encode() + name + "›".encode(), mkblob2.LONG_BASE + k)
    emit(mkblob2.AUTOEXIT2)                          # W11-1C: flush hook, exit(0)
    if len(out) > CAP:                               # W11-1E: golf2's diagnostic
        sys.stderr.write("GOLF: program too large\n")
        raise SystemExit(2)
    # W11-1E: p_filesz is the image's true size (golf2 and the seed patch it
    # the same way), so the kernel maps exactly the file and BSS starts after it.
    out[v1.FILESZ_OFF:v1.FILESZ_OFF + 8] = len(out).to_bytes(8, "little")
    return bytes(out)


def main():
    sys.stdout.buffer.write(compile_bytes(sys.stdin.buffer.read()))


if __name__ == "__main__":
    main()
