#!/usr/bin/env python3
"""Assemble self/golf.golf from readable code sections + a generated blob.

golf.golf is the self-hosted GOLF compiler.  It is a mix of printable ASCII
code and one raw-byte blob holding every machine-code template (single source
of truth: imported from boot/golf0.py).  Editors would mangle the raw bytes,
so we regenerate the file from this script instead of editing it by hand.

Blob record format:  [key][len][len bytes] ... terminated by a 0 key byte.
  key 1 = prologue     key 2 = cond-prefix (58 48 85 C0 0F)
  key 3 = startup      key 4 = ELF header (120 bytes)
  key 5 = autoexit     table ops keyed by their ASCII code
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "boot"))
import golf0  # single source of truth for templates/header

COND = bytes([0x58, 0x48, 0x85, 0xC0, 0x0F])  # shared prefix of '[' and '}'

def rec(key, data):
    assert 1 <= len(data) <= 255, (key, len(data))
    return bytes([key, len(data)]) + bytes(data)

def build_blob():
    b = bytearray()
    b += rec(1, golf0.PROLOGUE)
    b += rec(2, COND)
    b += rec(3, golf0.STARTUP)
    b += rec(4, golf0.HEADER)
    b += rec(5, golf0.AUTOEXIT)
    # table ops, keyed by ASCII code of the op char
    for ch, tpl in golf0.TEMPLATES.items():
        b += rec(ord(ch), tpl)
    b += bytes([0])                 # sentinel
    return bytes(b)

# ---- code sections (printable ASCII).  Spaces are only load-bearing after a
# ---- blob count; elsewhere they are cosmetic and stripped in the golfed pass.
# Words, in definition-before-use order.  See self/ANNOTATED.md for a listing.
WORDS = (
    ":m4259840;"                                        # m: data base D
    ":a m4+\\&@+\\!;"                                    # a: advance P by n
    ":o m4+@!1a;"                                        # o: emit byte
    ":w m4+@!4a;"                                        # w: emit dword
    ':k"m4+@\\-4-\\!;'                                   # k: backpatch pop site
    ':c{\\"?o1+\\1-"1<}__;'                              # c: copy n bytes -> out
    ':C"1+?\\2+\\c;'                                     # C: copy template @rec
    ':f m12+!m8+@{"?"[_^]m12+@-[^]"1+?2++0};'            # f: find record for key
    ":E fC;"                                             # E: emit template for key
    ':e"f"?[_232o m2048+\\4*+@m4+@4+-w^]\\_C;'           # e: table op or call
    ':D0{("48-10<[_^]48-\\10*+0};'                       # D: read decimal
    ':g m16+@"[_(^]0m16+!;'                              # g: get char (pending Q)
    ':h{("10-[_^]"[_^]_0};'                              # h: skip comment line
    ':t "33<1+[_^]'                                      # whitespace
    '"35-[_h^]'                                          # '#' comment
    '"48-10<1+[48-{("48-10<[m16+!104o w^]48-\\10*+0}]'   # digit -> number
    '"39-[_(104o w^]'                                    # "'" char literal
    '"58-[_(233o m4+@4+\\m2048+\\4*+! m4+@0w1E^]'        # ':' define word
    '"59-[_94Ek^]'                                       # ';' end def
    '"91-[_2E133o m4+@0w^]'                              # '[' if
    '"93-[_k^]'                                          # ']' end if
    '"123-[_m4+@^]'                                      # '{' loop start
    '"125-[_2E132o m4+@4+-w^]'                           # '}' loop end
    '"96-[_D233o"w m4+@69632-m12+!{(o1-"1<}_104o m12+@w^]'  # '`' blob
    "e;"                                                 # default: e
)
INIT = "m4096+m4+!"                                      # P = B
TAIL = "m8+!4E3E{g\"m!t m@1<}5E" 'm4096+{"?)1+"m4+@<1+}_'  # after blob

def golf(s):
    """Apply verified size-reducing rewrites: replace common byte sequences
    with 1-char accessor words.  Correctness is guaranteed by the self-hosting
    fixpoint test, which fails loudly if any rewrite changes behaviour.
      P = m4+@       fetch output pointer
      Y = m2048+\\4*+  dict slot address for key-on-top
      Z = 48-\\10*+    fold a decimal digit into an accumulator
      L = 104o       emit the push-imm32 opcode (0x68)
    All replacements run before any definition is injected, so the injected
    defs keep their literal byte sequences."""
    s = s.replace("m4+@", "P")
    s = s.replace("m2048+\\4*+", "Y")
    s = s.replace("48-\\10*+", "Z")
    s = s.replace("104o", "L")
    s = s.replace(":m4259840;", ":m4259840;:Pm4+@;")
    s = s.replace(":oP!1a;", ":oP!1a;:L104o;")
    s = s.replace(":EfC;", ":EfC;:Ym2048+\\4*+;:Z48-\\10*+;")
    return s

def build_source():
    blob = build_blob()
    # Spaces in the code sections are cosmetic (GOLF treats bytes <=32 as
    # whitespace); strip them for the golfed artifact.  The single space after
    # the blob byte-count is part of the ` escape syntax and is added here.
    code = lambda s: golf(s.replace(" ", "")).encode()
    parts = [code(WORDS), code(INIT),
             b"`" + str(len(blob)).encode() + b" " + blob,
             code(TAIL)]
    return b"".join(parts)

def main():
    src = build_source()
    out = os.path.join(HERE, "..", "self", "golf.golf")
    with open(out, "wb") as f:
        f.write(src)
    sys.stderr.write(f"wrote {out}: {len(src)} bytes (blob {len(build_blob())})\n")

if __name__ == "__main__":
    main()
