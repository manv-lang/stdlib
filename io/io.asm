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

; file: stdlib/io/io.asm
; description: I/O library

section .data
    ; Errors code
    invalid_text_error_code     equ 0       ; Error code for invalid text (print function)
    invalid_text_len_error_code equ 1       ; Error code for invalid text length (print function)

    ; Errors messages
    invalid_text_error_msg      db "Invalid text", 0xA         ; Error message for invalid text (print function)
    invalid_text_len_error_msg  db "Invalid text length", 0xA  ; Error message for invalid text length (print function)

section .text
global print, printi, exit, flush_stderr, flush_stdout

; ---------------------------------------------- ;
;       Builtin functions implementations        ;
; ---------------------------------------------- ;

flush:
    ; -- function:
    ;   -> name: flush
    ;   -> args: 
    ;              Name  | Reg Name
    ;           ---------|-----------
    ;
    ;   -> ret: None
    ; -- manv declaration:
    ;   -> fn flush();

    call flush_stdout
    call flush_stderr

flush_stdout:
    ; -- function:
    ;   -> name: flush_stdout
    ;   -> args:
    ;              Name  | Reg Name
    ;           ---------|-----------
    ;
    ;   -> ret: None
    ; -- manv declaration:
    ;   -> fn flush_stdout();

    mov rax, 74                             ; sys_fsync (Flush STDOUT)
    mov rdi, 1
    syscall

flush_stderr:
    ; -- function:
    ;   -> name: flush_stderr
    ;   -> args:
    ;              Name  | Reg Name
    ;           ---------|-----------
    ;
    ;   -> ret: None
    ; -- manv declaration:
    ;   -> fn flush_stderr() -> NULL;

    mov rax, 74                             ; sys_fsync (Flush STDERR)
    mov rdi, 2
    syscall

printi:
    ; -- function:
    ;   -> name: printi
    ;   -> args:
    ;              Name  | Reg Name
    ;           ---------|-----------
    ;               n    |   rdi
    ;   -> ret: None
    ; -- manv declaration:
    ;   -> fn printi(n: int) -> NULL;
    mov     r9, -3689348814741910323
    sub     rsp, 40
    mov     BYTE [rsp+31], 10
    lea     rcx, [rsp+30]
.L2:
    mov     rax, rdi
    lea     r8, [rsp+32]
    mul     r9
    mov     rax, rdi
    sub     r8, rcx
    shr     rdx, 3
    lea     rsi, [rdx+rdx*4]
    add     rsi, rsi
    sub     rax, rsi
    add     eax, 48
    mov     BYTE [rcx], al
    mov     rax, rdi
    mov     rdi, rdx
    mov     rdx, rcx
    sub     rcx, 1
    cmp     rax, 9
    ja      .L2
    lea     rax, [rsp+32]
    mov     edi, 1
    sub     rdx, rax
    xor     eax, eax
    lea     rsi, [rsp+32+rdx]
    mov     rdx, r8
    mov     rax, 1
    syscall
    add     rsp, 40
    ret

print:
    ; -- function:
    ;   -> name: print
    ;   -> args:
    ;              Name  | Reg Name
    ;           ---------|-----------
    ;             text   |   rdi
    ;           text_len |   rsi
    ;
    ;   -> ret: None
    ; -- manv declaration:
    ;   -> fn print(text: str, text_len: int);

    ; Validate the text length
    cmp rsi, 0
    je .invalid_text_len_error

    ; Check if the text is a valid address
    test rdi, rdi
    jz .invalid_text_error

    mov rax, 1      ; sys_write
    mov rdx, rsi    ; message length
    mov rsi, rdi    ; message
    mov rdi, 1      ; STDOUT
    syscall

    ret             ; returning so we don't fall into the exceptions


; ---------------------------------------------- ;
;                   Error handling               ;
; ---------------------------------------------- ;
.invalid_text_error:
    ; Write to STDOUT the error message
    mov rax, 1                          ; sys_write
    mov rdi, 2                          ; STDERR
    mov rsi, invalid_text_error_msg     ; Error message
    mov rdx, 18                         ; Error message length
    syscall

    ; Exit
    mov rax, 60                             ; sys_exit
    mov rdi, invalid_text_error_code        ; error code
    syscall

    ret

.invalid_text_len_error:
    ; Write to STDOUT the error message
    mov rax, 1                              ; sys_write
    mov rdi, 2                              ; STDERR
    mov rsi, invalid_text_len_error_msg     ; Error message
    mov rdx, 21                             ; Error message length
    syscall

    ; Exit
    mov rax, 60                             ; sys_exit
    mov rdi, invalid_text_len_error_code    ; error code
    syscall

    ret

exit:
    mov rax, 60
    mov rdi, 0
    syscall
