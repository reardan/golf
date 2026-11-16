; lib/native.asm -- the prelude's machine-code routines (W18).
; tools/mknative.py assembles each `;; @word ‹name›` section (nasm -f bin,
; BITS 64) into the NATIVE block of lib/prelude.golfj.  Read that tool's
; docstring for the byte rules and the calling convention: [rsp] is the
; return address (popped into r11), the Golf data stack is above it, TOS first.
; Everything before the first @word line is prepended to every routine.

;; @word ‹_ncp›  src dst n -> ; copy n cells forward (n >= 0; dst <= src or disjoint)
        pop r11
        pop rcx
        pop rdi
        pop rsi
        mov r10, 4               ; cmp reg, imm encodes ModRM F8-FF: compare registers
.l4:    cmp rcx, r10
        jb .l1
        movups xmm0, [rsi]
        movups xmm1, [rsi+16]
        movups [rdi], xmm0
        movups [rdi+16], xmm1
        add rsi, 32
        add rdi, 32
        sub rcx, 4
        jmp .l4
.l1:    test rcx, rcx
        jz .done
        mov rax, [rsi]
        mov [rdi], rax
        add rsi, 8
        add rdi, 8
        sub rcx, 1
        jmp .l1
.done:  push r11
        ret

;; @word ‹_nscan›  p e -> p'   the first cell in [p, e) that may point into the heap, else e
; A candidate v has ((v << 16) - B) < S unsigned, with B and S the heap base and
; bump offset shifted left 16 (‹_17_scan› stores them at 4399648 and 4399656).
        pop r11
        pop rdx
        pop rsi
        mov r8, [4399648]
        mov r9, [4399656]
.l:     cmp rsi, rdx
        jae .done
        mov rax, [rsi]
        shl rax, 16
        sub rax, r8
        cmp rax, r9
        jb .done
        add rsi, 8
        jmp .l
.done:  push rsi
        push r11
        ret

;; @word ‹_nelt›  end p d dr mode -> end p' x y 0 | end end 1
; The elementwise kernel behind ‹_12p3_go› (every ‹_12p3_ll… li… il…› loop).
; mode = op*4 + shape: op 0 + 1 - 2 * 3 ⌊ 4 ⌈ (signed); shape 0 ll (y is the
; cell at p+d), 1 li (y is the scalar d), 2 il (x is the scalar d, y the
; cell).  It runs the op over the cells from p while both operands are ints,
; writing to p+dr, and stops at end (flag 1) or at the first pair holding a
; tag-0x7FFF cell (a nested list): flag 0 with that pair, for Golf to recurse.
        pop r11
        pop r12
        pop r10
        pop r9
        pop rsi
        pop rdx
        mov r13, r12
        and r13, 3
        shr r12, 2
        mov ebx, 2
        mov r8d, 0x8000
        sub r8, 1
        jmp .l
.bail:  push rdx
        push rsi
        push rax
        push rcx
        push 0
        push r11
        ret
.done:  push rdx
        push rsi
        push 1
        push r11
        ret
        times 8 nop
.l:     cmp rsi, rdx
        jae .done
        mov rax, [rsi]
        mov rcx, r9
        test r13, r13
        jnz .s1
        mov rcx, [rsi+r9]
        jmp .ld
.s1:    cmp r13, rbx
        jne .ld
        xchg rax, rcx
.ld:    mov rdi, rax
        shr rdi, 48
        cmp rdi, r8
        je .bail
        mov rdi, rcx
        shr rdi, 48
        cmp rdi, r8
        je .bail
        mov rdi, r12
        test r12, r12            ; test rdi, rdi is 48 85 FF
        jz .add
        sub rdi, 1
        jz .sub
        sub rdi, 1
        jz .mul
        sub rdi, 1
        jz .min
        cmp rax, rcx
        cmovl rax, rcx
        jmp .st
.min:   cmp rax, rcx
        cmovg rax, rcx
        jmp .st
.mul:   imul rax, rcx
        jmp .st
.sub:   sub rax, rcx
        jmp .st
.add:   add rax, rcx
.st:    mov [rsi+r10], rax
        add rsi, 8
        jmp .l

;; @word ‹_nhash›  h p e -> h' p'   FNV-1a over the int cells from p (‹hash›)
; Eight byte rounds per cell, low byte first, exactly as ‹_2b_h8›.  Stops at e
; or at the first cell whose tag is 0x7FFF (maybe a nested list: ‹hash›
; decides with T and recurses).
        pop r11
        pop rdx
        pop rsi
        pop rax
        mov r8d, 0x8000
        sub r8, 1
        mov r9, 0x100000001B3
        jmp .l
.done:  push rax
        push rsi
        push r11
        ret
        times 12 nop
.l:     cmp rsi, rdx
        jae .done
        mov rcx, [rsi]
        mov rdi, rcx
        shr rdi, 48
        cmp rdi, r8
        je .done
        mov r10d, 4
.r:     movzx ebx, cl
        xor rax, rbx
        imul rax, r9
        shr rcx, 8
        movzx ebx, cl
        xor rax, rbx
        imul rax, r9
        shr rcx, 8
        sub r10, 1
        jnz .r
        add rsi, 8
        jmp .l

;; @word ‹_nword›  p e -> q s   the next word of a code list (‹words›)
; Skips blank cells (32 and 9..13) from p; s is the first non-blank (e if none)
; and q the first blank after it (or e).
        pop r11
        pop rdx
        pop rsi
        mov r8d, 32
        mov r9d, 5
        jmp .b
.eof:   push rdx
        push rdx
        push r11
        ret
        times 12 nop
.b:     cmp rsi, rdx
        jae .eof
        mov rax, [rsi]
        cmp rax, r8
        je .nb
        sub rax, 9
        cmp rax, r9
        jae .w
.nb:    add rsi, 8
        jmp .b
.w:     lea rdi, [rsi]           ; mov rdi, rsi is 48 89 F7
        jmp .c
.out:   push rsi
        push rdi
        push r11
        ret
        times 12 nop
.c:     add rsi, 8
        cmp rsi, rdx
        jae .out
        mov rax, [rsi]
        cmp rax, r8
        je .out
        sub rax, 9
        cmp rax, r9
        jb .out
        jmp .c

;; @word ‹_nnl›  p e -> q   the first byte 10 in [p, e), else e (‹_15_line›)
        pop r11
        pop rdx
        pop rsi
        jmp .l
.done:  push rsi
        push r11
        ret
        times 14 nop
.l:     cmp rsi, rdx
        jae .done
        cmp byte [rsi], 10
        je .done
        add rsi, 1
        nop                      ; a backward jump needs 17+ bytes
        jmp .l

;; @word ‹_nwid›  src dst n ->   widen n bytes at src into n cells at dst
        pop r11
        pop rcx
        pop rdi
        pop rsi
        jmp .l
.done:  push r11
        ret
        times 14 nop
.l:     test rcx, rcx
        jz .done
        movzx eax, byte [rsi]
        mov [rdi], rax
        add rsi, 1
        add rdi, 8
        sub rcx, 1
        jmp .l

;; @word ‹_nints›  p e ->   ‹ints›'s scanner over the buffer bytes [p, e)
; The same state machine as the Golf ‹_12p1_chunk› it replaces, with its
; state in the W12-P1 cells (base 0x4F0D00 = 5180672): +0x10 the number so
; far (c2), +0x18 the sign (c3: 0 negative), +0x28 the next result slot (c5),
; +0x38 the mode (c7: 0 between words, 1 in the digits, 2 in the rest of a
; word).  Blanks are 32 and 9..13; a word may start with one + or -; digits
; accumulate (wrapping); a word ends at a blank, and digits followed by
; anything else run to the next blank.  A number is written when its word
; ends; one still open at e stays open for the next chunk.  The caller
; ensures room for (e - p)/2 + 2 more cells first.
        pop r11
        pop rdx
        pop rsi
        mov ebx, 0x4F0C00
        add ebx, 0x100
        mov r8, [rbx+0x10]
        mov r9, [rbx+0x18]
        mov r10, [rbx+0x38]
        mov rdi, [rbx+0x28]
        mov r12d, 10
        mov r13d, 5
        mov r14d, 32
        mov r15d, 45
        jmp .top
.save:  mov [rbx+0x10], r8
        mov [rbx+0x18], r9
        mov [rbx+0x38], r10
        mov [rbx+0x28], rdi
        push r11
        ret
        times 4 nop
.top:   cmp rsi, rdx
        jae .save
        test r10, r10
        jz .s0
        mov rax, r10
        sub rax, 1
        jz .m1
        jmp .m2
; mode 0: skip blanks, then start a word
.s0:    movzx eax, byte [rsi]
        cmp r14d, eax
        je .b0
        mov ecx, eax
        sub ecx, 9
        cmp ecx, r13d
        jae .start
.b0:    add rsi, 1
        cmp rsi, rdx
        jb .s0
        jmp .save
.tsave: jmp .save                ; trampolines: a backward jump over 128
.ttop:  jmp .top                 ; bytes would need FF bytes
.start: xor r8d, r8d
        mov r10d, 1
        mov r9d, 1
        cmp r15d, eax
        jb .m1
        jne .plus
        xor r9d, r9d
        add rsi, 1
        jmp .m1
.plus:  mov ecx, 43
        cmp ecx, eax
        jne .m1
        add rsi, 1
        nop                      ; keeps a jump offset off 0x0D
; mode 1: digits
.m1:    cmp rsi, rdx
        jae .tsave
        movzx eax, byte [rsi]
        sub eax, 48
        cmp eax, r12d
        jae .nd
        imul r8, r12
        add r8, rax
        add rsi, 1
        jmp .m1
.ttop2: jmp .ttop
.nd:    mov r10d, 2
        movzx eax, byte [rsi]
        cmp r14d, eax
        je .emit1
        mov ecx, eax
        sub ecx, 9
        cmp ecx, r13d
        jae .m2
.emit1: add rsi, 1
        jmp .emit
; mode 2: the rest of the word, up to a blank (left for mode 0)
.m2:    cmp rsi, rdx
        jae .tsave
        movzx eax, byte [rsi]
        cmp r14d, eax
        je .emit
        mov ecx, eax
        sub ecx, 9
        cmp ecx, r13d
        jb .emit
        add rsi, 1
        jmp .m2
.emit:  mov rax, r8
        test r9, r9
        jnz .pos
        xor eax, eax
        sub rax, r8
.pos:   mov [rdi], rax
        add rdi, 8
        xor r10d, r10d
        jmp .ttop2
