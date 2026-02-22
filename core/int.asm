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

; file: stdlib/core/int.asm
; description: Integer builtin methods for ManV

; Constants
INT_MIN equ -9223372036854775808

section .data
    ; Panic message for INT_MIN
    int_min_panic_msg: db "panic: int.abs() called on INT_MIN", 10, 0
    int_min_panic_len: equ 35

section .text
global int_abs
global int_abs_wrapping
global int_clamp
global int_min
global int_max
global int_pow
global int_to_str

; =============================================================================
; int_abs(int x) -> int
; Returns absolute value. Panics on INT_MIN.
; Args: rdi = value
; Returns: rax = |x|
; =============================================================================
int_abs:
    ; Check for INT_MIN (0x8000000000000000)
    cmp rdi, INT_MIN
    je .abs_panic
    
    ; Standard negation
    mov rax, rdi
    neg rax
    cmovs rax, rdi          ; if result negative, use original (was positive)
    ret
    
.abs_panic:
    ; Print panic message
    mov rax, 1              ; sys_write
    mov rdi, 2              ; stderr
    lea rsi, [rel int_min_panic_msg]
    mov rdx, int_min_panic_len
    syscall
    
    ; Exit with error code
    mov rax, 60             ; sys_exit
    mov rdi, 1              ; exit code
    syscall

; =============================================================================
; int_abs_wrapping(int x) -> int
; Returns absolute value with wrapping on overflow
; Args: rdi = value
; Returns: rax = |x| (wraps on INT_MIN)
; =============================================================================
int_abs_wrapping:
    mov rax, rdi
    neg rax
    cmovs rax, rdi          ; if result negative, use original
    ret

; =============================================================================
; int_clamp(int x, int min_val, int max_val) -> int
; Clamps value to [min_val, max_val] range
; Args: rdi = value, rsi = min, rdx = max
; Returns: rax = clamped value
; =============================================================================
int_clamp:
    ; First clamp to min
    cmp rdi, rsi
    cmovl rdi, rsi          ; if x < min, x = min
    
    ; Then clamp to max
    cmp rdi, rdx
    cmovg rdi, rdx          ; if x > max, x = max
    
    mov rax, rdi
    ret

; =============================================================================
; int_min(int a, int b) -> int
; Returns minimum of two values
; Args: rdi = a, rsi = b
; Returns: rax = min(a, b)
; =============================================================================
int_min:
    mov rax, rdi
    cmp rdi, rsi
    cmovg rax, rsi          ; if a > b, return b
    ret

; =============================================================================
; int_max(int a, int b) -> int
; Returns maximum of two values
; Args: rdi = a, rsi = b
; Returns: rax = max(a, b)
; =============================================================================
int_max:
    mov rax, rdi
    cmp rdi, rsi
    cmovl rax, rsi          ; if a < b, return b
    ret

; =============================================================================
; int_pow(int base, int exp) -> int
; Raises base to power exp (integer exponent)
; Args: rdi = base, rsi = exponent
; Returns: rax = base^exp
; =============================================================================
int_pow:
    push rbx
    
    ; Handle edge cases
    test rsi, rsi           ; exp == 0?
    jz .pow_one             ; base^0 = 1
    
    cmp rsi, 0
    jl .pow_zero            ; negative exponent -> 0 (integer division)
    
    mov rax, 1              ; result = 1
    mov rbx, rdi            ; base
    
.pow_loop:
    test rsi, rsi
    jz .pow_done
    
    test rsi, 1             ; exp is odd?
    jz .pow_even
    
    ; Multiply result by base
    imul rax, rbx
    
.pow_even:
    ; Square the base
    imul rbx, rbx
    
    ; Shift exponent right
    sar rsi, 1
    
    jmp .pow_loop
    
.pow_one:
    mov rax, 1
    jmp .pow_done
    
.pow_zero:
    xor rax, rax
    
.pow_done:
    pop rbx
    ret

; =============================================================================
; int_to_str(int x) -> str*
; Converts integer to heap-allocated string
; Args: rdi = value
; Returns: rax = pointer to string
; =============================================================================
int_to_str:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi            ; save value
    mov r13, 0              ; digit count
    mov r14, 0              ; negative flag
    
    ; Check if negative
    test rdi, rdi
    jns .to_str_positive
    
    ; Handle INT_MIN specially (can't negate)
    cmp rdi, INT_MIN
    je .to_str_int_min
    
    ; Mark as negative and negate
    mov r14, 1
    neg r12
    
.to_str_positive:
    ; Count digits
    mov rax, r12
    mov rcx, 10
    
.count_loop:
    test rax, rax
    jz .count_done
    
    xor rdx, rdx
    div rcx                 ; divide by 10
    inc r13
    jmp .count_loop
    
.count_done:
    ; Handle zero case
    test r13, r13
    jnz .allocate
    
    mov r13, 1              ; "0" has 1 digit
    
.allocate:
    ; Add 1 for negative sign if needed
    mov rax, r13
    add rax, r14
    
    ; Allocate memory: 8 bytes header + digits + 1 null
    add rax, 9
    
    ; Use brk to allocate
    mov rdi, 0
    mov rax, 12             ; sys_brk
    syscall
    
    mov r15, rax            ; save base pointer
    add rax, r13
    add rax, r14
    add rax, 9
    
    mov rdi, rax
    mov rax, 12
    syscall
    
    ; Store length in header
    mov rax, r13
    add rax, r14            ; add negative sign length
    mov [r15], rax
    
    ; Pointer to data
    lea rbx, [r15 + 8]
    
    ; Add negative sign if needed
    cmp r14, 1
    jne .convert_digits
    
    mov byte [rbx], '-'
    inc rbx
    
.convert_digits:
    ; Convert digits (reverse order)
    mov rax, r12
    lea rdi, [rbx + r13 - 1] ; point to end of digit buffer
    
    mov rcx, 10
    
.digit_loop:
    test rax, rax
    jz .digits_done
    
    xor rdx, rdx
    div rcx
    
    add rdx, '0'            ; convert to ASCII
    mov [rdi], dl
    dec rdi
    jmp .digit_loop
    
.digits_done:
    ; Handle zero
    test r13, r13
    jnz .return_result
    
    mov byte [rbx], '0'
    
.return_result:
    ; Add null terminator
    mov byte [rbx + r13], 0
    
    ; Return pointer to data
    lea rax, [r15 + 8]
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
    
.to_str_int_min:
    ; Special case: return "-9223372036854775808"
    ; Allocate 28 bytes (8 header + 20 digits + null)
    mov rdi, 0
    mov rax, 12
    syscall
    
    mov r15, rax
    mov rdi, rax
    add rdi, 28
    mov rax, 12
    syscall
    
    ; Store length
    mov qword [r15], 20
    
    ; Copy string
    lea rdi, [r15 + 8]
    mov byte [rdi], '-'
    lea rsi, [rdi + 1]
    mov rax, '922337203'
    mov [rsi], rax
    mov rax, '685477580'
    mov [rsi + 9], rax
    mov byte [rsi + 18], '8'
    mov byte [rsi + 19], 0
    
    lea rax, [r15 + 8]
    jmp .return_result