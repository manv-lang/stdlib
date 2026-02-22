; MIT License
;
; Copyright (c) 2025 ramsy0dev
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

; file: stdlib/core/mem.asm
; description: Memory utility functions for ManV

section .text
global mem_copy
global mem_set
global mem_compare
global mem_move
global mem_zero

; =============================================================================
; mem_copy(void* dest, void* src, int n) -> void*
; Copies n bytes from src to dest. Returns dest.
; Args: rdi = dest, rsi = src, rdx = n
; Returns: rax = dest
; Note: Does NOT handle overlapping regions - use mem_move for that
; =============================================================================
mem_copy:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi            ; r12 = dest (save for return)
    mov r13, rdx            ; r13 = count
    
    ; Check for zero length
    test r13, r13
    jz .copy_done
    
    ; Check if we can use SSE (16-byte aligned, at least 16 bytes)
    cmp r13, 16
    jb .copy_bytes
    
    ; Check alignment
    mov rax, rdi
    or rax, rsi
    and rax, 15
    jnz .copy_bytes         ; Not aligned, use byte copy
    
    ; Copy 16 bytes at a time using SSE
.copy_sse:
    cmp r13, 16
    jb .copy_remaining
    
    movdqu xmm0, [rsi]
    movdqu [rdi], xmm0
    
    add rdi, 16
    add rsi, 16
    sub r13, 16
    jmp .copy_sse
    
.copy_remaining:
    ; Copy remaining bytes
    test r13, r13
    jz .copy_done
    
.copy_bytes:
    mov al, [rsi]
    mov [rdi], al
    inc rdi
    inc rsi
    dec r13
    jnz .copy_bytes
    
.copy_done:
    mov rax, r12            ; Return dest
    
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; =============================================================================
; mem_set(void* dest, int value, int n) -> void*
; Sets n bytes of dest to value. Returns dest.
; Args: rdi = dest, rsi = value (byte), rdx = n
; Returns: rax = dest
; =============================================================================
mem_set:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rdi            ; Save dest for return
    mov rcx, rdx            ; Count
    mov al, sil             ; Value byte
    
    ; Check for zero length
    test rcx, rcx
    jz .set_done
    
    ; Check if we can use SSE (at least 16 bytes)
    cmp rcx, 16
    jb .set_bytes
    
    ; Check alignment
    test rdi, 15
    jnz .set_bytes          ; Not aligned
    
    ; Fill 16 bytes at a time
    movd xmm0, eax
    pshuflw xmm0, xmm0, 0   ; Broadcast low word
    pshufd xmm0, xmm0, 0    ; Broadcast to all 4 dwords
    
.set_sse:
    cmp rcx, 16
    jb .set_remaining
    
    movdqu [rdi], xmm0
    
    add rdi, 16
    sub rcx, 16
    jmp .set_sse
    
.set_remaining:
    test rcx, rcx
    jz .set_done
    
.set_bytes:
    mov [rdi], al
    inc rdi
    dec rcx
    jnz .set_bytes
    
.set_done:
    mov rax, rbx            ; Return dest
    pop rbx
    pop rbp
    ret

; =============================================================================
; mem_compare(void* s1, void* s2, int n) -> int
; Compares n bytes of s1 and s2.
; Args: rdi = s1, rsi = s2, rdx = n
; Returns: rax = 0 if equal, <0 if s1 < s2, >0 if s1 > s2
; =============================================================================
mem_compare:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rcx, rdx            ; Count
    
    ; Check for zero length
    test rcx, rcx
    jz .compare_equal
    
.compare_loop:
    mov al, [rdi]
    mov bl, [rsi]
    
    cmp al, bl
    jl .compare_less
    jg .compare_greater
    
    inc rdi
    inc rsi
    dec rcx
    jnz .compare_loop
    
.compare_equal:
    xor rax, rax
    jmp .compare_done
    
.compare_less:
    mov rax, -1
    jmp .compare_done
    
.compare_greater:
    mov rax, 1
    
.compare_done:
    pop rbx
    pop rbp
    ret

; =============================================================================
; mem_move(void* dest, void* src, int n) -> void*
; Copies n bytes from src to dest, handling overlapping regions.
; Args: rdi = dest, rsi = src, rdx = n
; Returns: rax = dest
; =============================================================================
mem_move:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    mov r12, rdi            ; r12 = dest (save for return)
    mov r13, rsi            ; r13 = src
    mov r14, rdx            ; r14 = count
    
    ; Check for zero length
    test r14, r14
    jz .move_done
    
    ; Check for overlap - if dest > src and dest < src + n, copy backwards
    mov rax, r13
    add rax, r14
    cmp r12, r13
    ja .check_overlap
    jmp .forward_copy
    
.check_overlap:
    cmp r12, rax
    jb .backward_copy
    
.forward_copy:
    ; Forward copy (same as mem_copy)
    mov rdi, r12
    mov rsi, r13
    mov rcx, r14
    
.forward_loop:
    mov al, [rsi]
    mov [rdi], al
    inc rdi
    inc rsi
    dec rcx
    jnz .forward_loop
    jmp .move_done
    
.backward_copy:
    ; Copy from end to beginning
    mov rdi, r12
    add rdi, r14
    dec rdi
    mov rsi, r13
    add rsi, r14
    dec rsi
    mov rcx, r14
    
.backward_loop:
    mov al, [rsi]
    mov [rdi], al
    dec rdi
    dec rsi
    dec rcx
    jnz .backward_loop
    
.move_done:
    mov rax, r12            ; Return dest
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; =============================================================================
; mem_zero(void* dest, int n) -> void*
; Zeros n bytes of dest. Returns dest.
; Args: rdi = dest, rsi = n
; Returns: rax = dest
; =============================================================================
mem_zero:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rdi            ; Save dest for return
    mov rcx, rsi            ; Count
    
    ; Check for zero length
    test rcx, rcx
    jz .zero_done
    
    ; Check if we can use SSE (at least 16 bytes)
    cmp rcx, 16
    jb .zero_bytes
    
    ; Check alignment
    test rdi, 15
    jnz .zero_bytes
    
    ; Zero 16 bytes at a time
    pxor xmm0, xmm0
    
.zero_sse:
    cmp rcx, 16
    jb .zero_remaining
    
    movdqu [rdi], xmm0
    
    add rdi, 16
    sub rcx, 16
    jmp .zero_sse
    
.zero_remaining:
    test rcx, rcx
    jz .zero_done
    
.zero_bytes:
    mov byte [rdi], 0
    inc rdi
    dec rcx
    jnz .zero_bytes
    
.zero_done:
    mov rax, rbx            ; Return dest
    pop rbx
    pop rbp
    ret