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

; file: stdlib/core/array.asm
; description: Array builtin methods for ManV

; Array Memory Layout:
;   Static: elements stored inline
;   Dynamic: [len: 8 bytes][capacity: 8 bytes][data: N * element_size]
;   Pointer points to data (length at offset -8 for dynamic arrays)

section .data
    ; Panic message for out of bounds
    oob_panic_msg: db "panic: array.at() index out of bounds", 10, 0
    oob_panic_len: equ 38

section .text
global array_len
global array_get
global array_at
global array_set
global array_is_empty

; =============================================================================
; array_len(void* arr) -> int
; Returns array length
; Args: rdi = array pointer
; Returns: rax = length
; Note: For static arrays, this could be a compile-time constant
; =============================================================================
array_len:
    ; Load length from header (8 bytes before data pointer for dynamic arrays)
    ; For static arrays, caller should use compile-time constant
    mov rax, [rdi - 8]
    ret

; =============================================================================
; array_get(void* arr, int index) -> Option<T>
; Safe element access. Returns Option<T>.
; Args: rdi = array pointer, rsi = index
; Returns: rax = element value (or 0 if None), rdx = has_value (1 or 0)
; =============================================================================
array_get:
    ; Get array length
    mov rcx, [rdi - 8]
    
    ; Check bounds
    cmp rsi, 0
    jl .get_none            ; index < 0
    cmp rsi, rcx
    jge .get_none           ; index >= len
    
    ; Valid - return element
    ; Assuming 8-byte elements for now
    mov rax, [rdi + rsi * 8]
    mov rdx, 1              ; has_value = true
    ret
    
.get_none:
    xor rax, rax
    xor rdx, rdx            ; has_value = false
    ret

; =============================================================================
; array_at(void* arr, int index) -> T
; Unsafe element access. Panics on out of bounds.
; Args: rdi = array pointer, rsi = index
; Returns: rax = element value
; =============================================================================
array_at:
    ; Get array length
    mov rcx, [rdi - 8]
    
    ; Check bounds
    cmp rsi, 0
    jl .at_panic
    cmp rsi, rcx
    jge .at_panic
    
    ; Valid - return element
    mov rax, [rdi + rsi * 8]
    ret
    
.at_panic:
    ; Print panic message
    push rdi
    push rsi
    mov rax, 1              ; sys_write
    mov rdi, 2              ; stderr
    lea rsi, [rel oob_panic_msg]
    mov rdx, oob_panic_len
    syscall
    pop rsi
    pop rdi
    
    ; Exit with error code
    mov rax, 60             ; sys_exit
    mov rdi, 1
    syscall

; =============================================================================
; array_set(void* arr, int index, void* value) -> void
; Sets element at index
; Args: rdi = array pointer, rsi = index, rdx = value pointer
; Returns: void
; =============================================================================
array_set:
    ; Get array length
    mov rcx, [rdi - 8]
    
    ; Check bounds (silent no-op if out of bounds)
    cmp rsi, 0
    jl .set_done
    cmp rsi, rcx
    jge .set_done
    
    ; Set element (assuming 8-byte elements)
    mov rax, [rdx]
    mov [rdi + rsi * 8], rax
    
.set_done:
    ret

; =============================================================================
; array_is_empty(void* arr) -> bool
; Returns 1 if array is empty, 0 otherwise
; Args: rdi = array pointer
; Returns: rax = 1 or 0
; =============================================================================
array_is_empty:
    cmp qword [rdi - 8], 0
    setz al
    movzx rax, al
    ret