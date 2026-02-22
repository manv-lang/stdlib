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

; file: stdlib/core/bytes.asm
; description: Bytes builtin methods for ManV

section .text
global bytes_len
global bytes_get
global bytes_set

; =============================================================================
; bytes_len(bytes* b) -> int
; Returns byte count
; Args: rdi = bytes pointer
; Returns: rax = length
; =============================================================================
bytes_len:
    ; Load length from header (8 bytes before data pointer)
    mov rax, [rdi - 8]
    ret

; =============================================================================
; bytes_get(bytes* b, int index) -> Option<int>
; Safe byte access. Returns Option<int>.
; Args: rdi = bytes pointer, rsi = index
; Returns: rax = byte value (or 0 if None), rdx = has_value (1 or 0)
; =============================================================================
bytes_get:
    ; Get length
    mov rcx, [rdi - 8]
    
    ; Check bounds
    cmp rsi, 0
    jl .get_none
    cmp rsi, rcx
    jge .get_none
    
    ; Valid - return byte
    movzx rax, byte [rdi + rsi]
    mov rdx, 1              ; has_value = true
    ret
    
.get_none:
    xor rax, rax
    xor rdx, rdx            ; has_value = false
    ret

; =============================================================================
; bytes_set(bytes* b, int index, int value) -> void
; Sets byte at index
; Args: rdi = bytes pointer, rsi = index, rdx = value (0-255)
; Returns: void
; =============================================================================
bytes_set:
    ; Get length
    mov rcx, [rdi - 8]
    
    ; Check bounds (silent no-op if out of bounds)
    cmp rsi, 0
    jl .set_done
    cmp rsi, rcx
    jge .set_done
    
    ; Set byte (mask to 0-255)
    mov al, dl
    mov [rdi + rsi], al
    
.set_done:
    ret