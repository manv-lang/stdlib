; MIT License

; Copyright (c) 2025 ramsy0dev

; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:

; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.

; file: stdlib/core/float.asm
; description: Float builtin methods for ManV

section .text
global float_abs
global float_floor
global float_ceil
global float_round
global float_is_nan
global float_is_inf
global float_is_finite
global float_to_str

; =============================================================================
; float_abs(float x) -> float
; Returns absolute value
; Args: xmm0 = value (float in SSE register)
; Returns: xmm0 = |x|
; =============================================================================
float_abs:
    ; Clear sign bit using AND with 0x7FFFFFFFFFFFFFFF
    movq rax, xmm0
    btr rax, 63             ; clear sign bit
    movq xmm0, rax
    ret

; =============================================================================
; float_floor(float x) -> float
; Rounds down to nearest integer
; Args: xmm0 = value
; Returns: xmm0 = floor(x)
; =============================================================================
float_floor:
    roundsd xmm0, xmm0, 1   ; round toward -infinity
    ret

; =============================================================================
; float_ceil(float x) -> float
; Rounds up to nearest integer
; Args: xmm0 = value
; Returns: xmm0 = ceil(x)
; =============================================================================
float_ceil:
    roundsd xmm0, xmm0, 2   ; round toward +infinity
    ret

; =============================================================================
; float_round(float x) -> float
; Rounds to nearest integer
; Args: xmm0 = value
; Returns: xmm0 = round(x)
; =============================================================================
float_round:
    roundsd xmm0, xmm0, 0   ; round to nearest
    ret

; =============================================================================
; float_is_nan(float x) -> bool
; Returns 1 if NaN, 0 otherwise
; Args: xmm0 = value
; Returns: rax = 1 or 0
; =============================================================================
float_is_nan:
    movq rax, xmm0
    ; NaN check: exponent all 1s and mantissa non-zero
    mov rcx, rax
    shl rcx, 1              ; remove sign bit
    cmp rcx, 0x7FF0000000000000
    jae .is_nan_true        ; exponent all 1s
    xor rax, rax
    ret
    
.is_nan_true:
    ; Check if mantissa is non-zero
    mov rcx, rax
    shl rcx, 12             ; remove exponent (52 bits of mantissa)
    test rcx, rcx
    setnz al
    movzx rax, al
    ret

; =============================================================================
; float_is_inf(float x) -> bool
; Returns 1 if infinity, 0 otherwise
; Args: xmm0 = value
; Returns: rax = 1 or 0
; =============================================================================
float_is_inf:
    movq rax, xmm0
    ; Infinity: exponent all 1s and mantissa zero
    mov rcx, rax
    shl rcx, 1              ; remove sign bit
    cmp rcx, 0x7FF0000000000000
    sete al
    movzx rax, al
    ret

; =============================================================================
; float_is_finite(float x) -> bool
; Returns 1 if finite (not NaN or infinity), 0 otherwise
; Args: xmm0 = value
; Returns: rax = 1 or 0
; =============================================================================
float_is_finite:
    movq rax, xmm0
    mov rcx, rax
    shl rcx, 1              ; remove sign bit
    cmp rcx, 0x7FF0000000000000
    setb al                 ; set if exponent not all 1s
    movzx rax, al
    ret

; =============================================================================
; float_to_str(float x) -> str*
; Converts float to heap-allocated string
; Args: xmm0 = value
; Returns: rax = pointer to string
; Note: Simplified implementation - full implementation would need snprintf
; =============================================================================
float_to_str:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Allocate buffer (32 bytes should be enough for most floats)
    mov rdi, 0
    mov rax, 12             ; sys_brk
    syscall
    
    mov rbx, rax
    add rax, 48             ; 8 header + 32 data + 8 spare
    mov rdi, rax
    mov rax, 12
    syscall
    
    ; Use cvtsd2si to convert to integer (truncates)
    ; For proper conversion, we'd need to call libc's sprintf
    ; This is a simplified version
    
    cvtsd2si r12, xmm0      ; convert to integer
    
    ; Store length placeholder
    mov qword [rbx], 0
    
    ; Store "float" as placeholder (full implementation needs formatting)
    lea rdi, [rbx + 8]
    
    ; Convert integer part
    mov rax, r12
    mov rcx, 10
    xor r8, r8
    
.convert_loop:
    test rax, rax
    jz .convert_done
    
    xor rdx, rdx
    div rcx
    add rdx, '0'
    mov [rdi + r8], dl
    inc r8
    jmp .convert_loop
    
.convert_done:
    ; Reverse the digits
    test r8, r8
    jnz .do_reverse
    mov byte [rdi], '0'
    mov r8, 1
    
.do_reverse:
    ; Simple reverse
    xor r9, r9
.reverse_loop:
    cmp r9, r8
    jge .reverse_done
    
    mov al, [rdi + r9]
    mov dl, [rdi + r8 - 1]
    mov [rdi + r9], dl
    mov [rdi + r8 - 1], al
    dec r8
    inc r9
    jmp .reverse_loop
    
.reverse_done:
    ; Null terminate
    mov byte [rdi + r9], 0
    
    ; Update length
    mov [rbx], r9
    
    ; Return pointer to data
    lea rax, [rbx + 8]
    
    pop r12
    pop rbx
    pop rbp
    ret