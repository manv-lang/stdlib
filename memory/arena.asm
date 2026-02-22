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

; file: stdlib/memory/arena.asm
; description: Arena (bump allocator) runtime for ManV
;
; Arena Header Layout (64 bytes):
; +------------------+--------------------+
; | base_ptr (8B)    | current_ptr (8B)   |
; +------------------+--------------------+
; | capacity (8B)    | original_cap (8B)  |
; +------------------+--------------------+
; | offset (8B)      | block_count (4B)   |
; +------------------+--------------------+
; | flags (4B)       | alignment (4B)     |
; +------------------+--------------------+
; | growth_count (4B)| padding (8B)       |
; +------------------+--------------------+
;
; Header Offsets:
ARENA_HEADER_SIZE      equ 64
ARENA_BASE_PTR         equ 0
ARENA_CURRENT_PTR      equ 8
ARENA_CAPACITY         equ 16
ARENA_ORIGINAL_CAP     equ 24
ARENA_OFFSET           equ 32
ARENA_BLOCK_COUNT      equ 40
ARENA_FLAGS            equ 44
ARENA_ALIGNMENT        equ 48
ARENA_GROWTH_COUNT     equ 52

; Object Header (for arena objects)
HEADER_SIZE            equ 16
TYPE_ID_OFFSET         equ 0
FLAGS_OFFSET           equ 8
GENERATION_OFFSET      equ 9
SIZE_OFFSET            equ 10
PAYLOAD_OFFSET         equ 16

; Arena Flags
ARENA_FLAG_CAN_GROW       equ 0x01
ARENA_FLAG_WARN_GROWTH    equ 0x02
ARENA_FLAG_GROWTH_WARNED  equ 0x04
ARENA_FLAG_FINALIZED      equ 0x08

; Object Flags
FLAG_ARENA_MANAGED   equ 0x08

; Default settings
ARENA_DEFAULT_CAPACITY equ 4096
ARENA_DEFAULT_ALIGNMENT equ 16

section .data
    ; Global arena tracking
    arena_count:       dq 0
    arena_total_memory: dq 0
    
    ; Growth warning message
    arena_growth_warn_msg: db "[WARN] Arena growing beyond initial capacity", 10, 0
    arena_growth_warn_len equ $ - arena_growth_warn_msg

section .text
    global arena_new
    global arena_alloc
    global arena_free
    global arena_reset
    global arena_get_stats
    global arena_available

; =============================================================================
; arena_new - Create a new arena
; =============================================================================
; Arguments:
;   rdi = initial capacity (0 for default)
; Returns: rax = pointer to arena header, or 0 on error
; =============================================================================
arena_new:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi        ; r12 = capacity
    
    ; Use default capacity if 0
    test r12, r12
    jnz .capacity_set
    mov r12, ARENA_DEFAULT_CAPACITY
    
.capacity_set:
    ; Ensure minimum alignment
    add r12, 15
    and r12, ~15
    
    ; Calculate total allocation size (header + capacity)
    lea r13, [r12 + ARENA_HEADER_SIZE]
    
    ; Allocate memory via mmap
    mov rax, 9          ; sys_mmap
    xor rdi, rdi        ; addr = NULL
    mov rsi, r13        ; size
    mov rdx, 0x3        ; prot = PROT_READ | PROT_WRITE
    mov r10, 0x22       ; flags = MAP_PRIVATE | MAP_ANONYMOUS
    xor r8, r8          ; fd = -1
    xor r9, r9          ; offset = 0
    syscall
    
    test rax, rax
    js .alloc_error
    
    ; Initialize arena header
    ; base_ptr
    lea rbx, [rax + ARENA_HEADER_SIZE]
    mov [rax + ARENA_BASE_PTR], rbx
    
    ; current_ptr (same as base initially)
    mov [rax + ARENA_CURRENT_PTR], rbx
    
    ; capacity
    mov [rax + ARENA_CAPACITY], r12
    
    ; original_capacity
    mov [rax + ARENA_ORIGINAL_CAP], r12
    
    ; offset
    mov qword [rax + ARENA_OFFSET], 0
    
    ; block_count
    mov dword [rax + ARENA_BLOCK_COUNT], 1
    
    ; flags (can grow + warn on growth)
    mov dword [rax + ARENA_FLAGS], ARENA_FLAG_CAN_GROW | ARENA_FLAG_WARN_GROWTH
    
    ; alignment
    mov dword [rax + ARENA_ALIGNMENT], ARENA_DEFAULT_ALIGNMENT
    
    ; growth_count
    mov dword [rax + ARENA_GROWTH_COUNT], 0
    
    ; Update global stats
    inc qword [arena_count]
    add qword [arena_total_memory], r13
    
    ; Return arena header pointer
    mov rax, rax
    jmp .done
    
.alloc_error:
    xor rax, rax
    
.done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; =============================================================================
; arena_alloc - Allocate memory in an arena
; =============================================================================
; Arguments:
;   rdi = arena header pointer
;   rsi = size to allocate
;   rdx = alignment (0 for default)
; Returns: rax = pointer to allocated memory, or 0 on error
; =============================================================================
arena_alloc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi        ; r12 = arena header
    mov r13, rsi        ; r13 = size
    mov r14, rdx        ; r14 = alignment
    
    ; Use default alignment if 0
    test r14, r14
    jnz .align_set
    mov r14, ARENA_DEFAULT_ALIGNMENT
    
.align_set:
    ; Ensure minimum size
    test r13, r13
    jnz .size_set
    mov r13, 1
    
.size_set:
    ; Get current offset
    mov rax, [r12 + ARENA_OFFSET]
    
    ; Calculate aligned offset
    ; aligned = (offset + alignment - 1) & ~(alignment - 1)
    mov rbx, rax
    add rbx, r14
    dec rbx
    neg r14
    inc r14
    and rbx, r14        ; rbx = aligned offset
    neg r14
    dec r14
    
    ; Calculate new offset
    lea r15, [rbx + r13]  ; r15 = new offset
    
    ; Check capacity
    cmp r15, [r12 + ARENA_CAPACITY]
    ja .need_growth
    
    ; We have space - allocate
    mov [r12 + ARENA_OFFSET], r15
    
    ; Get base pointer and calculate result
    mov rax, [r12 + ARENA_BASE_PTR]
    add rax, rbx        ; rax = base + aligned_offset
    
    ; Update current_ptr
    mov [r12 + ARENA_CURRENT_PTR], rax
    
    jmp .alloc_done
    
.need_growth:
    ; Check if growth is allowed
    mov ecx, [r12 + ARENA_FLAGS]
    test ecx, ARENA_FLAG_CAN_GROW
    jz .alloc_fail
    
    ; Emit warning if needed
    test ecx, ARENA_FLAG_WARN_GROWTH
    jz .grow_silent
    
    test ecx, ARENA_FLAG_GROWTH_WARNED
    jnz .grow_silent
    
    ; Print warning
    push rax
    push rdi
    push rsi
    push rdx
    
    mov rax, 1          ; sys_write
    mov rdi, 2          ; stderr
    lea rsi, [rel arena_growth_warn_msg]
    mov rdx, arena_growth_warn_len
    syscall
    
    pop rdx
    pop rsi
    pop rdi
    pop rax
    
    ; Mark as warned
    or ecx, ARENA_FLAG_GROWTH_WARNED
    mov [r12 + ARENA_FLAGS], ecx
    
.grow_silent:
    ; Grow arena (for simplicity, just fail for now)
    ; TODO: Implement arena growth with additional blocks
    
.alloc_fail:
    xor rax, rax
    jmp .alloc_done
    
.alloc_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; =============================================================================
; arena_free - Free an entire arena
; =============================================================================
; Arguments:
;   rdi = arena header pointer
; Returns: None
; =============================================================================
arena_free:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rdi        ; rbx = arena header
    
    ; Mark as finalized
    or dword [rbx + ARENA_FLAGS], ARENA_FLAG_FINALIZED
    
    ; Get base pointer for munmap
    mov rdi, rbx        ; The header is at the start of allocation
    
    ; Calculate total size
    mov rsi, [rbx + ARENA_CAPACITY]
    add rsi, ARENA_HEADER_SIZE
    
    ; Update global stats
    sub qword [arena_total_memory], rsi
    dec qword [arena_count]
    
    ; Release memory
    mov rax, 11         ; sys_munmap
    syscall
    
    pop rbx
    pop rbp
    ret

; =============================================================================
; arena_reset - Reset arena (keep memory, clear offset)
; =============================================================================
; Arguments:
;   rdi = arena header pointer
; Returns: None
; =============================================================================
arena_reset:
    push rbp
    mov rbp, rsp
    
    ; Clear offset
    mov qword [rdi + ARENA_OFFSET], 0
    
    ; Reset current_ptr to base
    mov rax, [rdi + ARENA_BASE_PTR]
    mov [rdi + ARENA_CURRENT_PTR], rax
    
    ; Reset block count (for future multi-block support)
    mov dword [rdi + ARENA_BLOCK_COUNT], 1
    
    pop rbp
    ret

; =============================================================================
; arena_available - Get available space in arena
; =============================================================================
; Arguments:
;   rdi = arena header pointer
; Returns: rax = available bytes
; =============================================================================
arena_available:
    push rbp
    mov rbp, rsp
    
    mov rax, [rdi + ARENA_CAPACITY]
    sub rax, [rdi + ARENA_OFFSET]
    
    pop rbp
    ret

; =============================================================================
; arena_get_stats - Get arena statistics
; =============================================================================
; Arguments:
;   rdi = arena header pointer
;   rsi = pointer to stats struct (4 * 8 bytes)
; Returns: None
; =============================================================================
arena_get_stats:
    push rbp
    mov rbp, rsp
    
    ; capacity
    mov rax, [rdi + ARENA_CAPACITY]
    mov [rsi], rax
    
    ; used
    mov rax, [rdi + ARENA_OFFSET]
    mov [rsi + 8], rax
    
    ; available
    mov rax, [rdi + ARENA_CAPACITY]
    sub rax, [rdi + ARENA_OFFSET]
    mov [rsi + 16], rax
    
    ; growth_count
    mov eax, [rdi + ARENA_GROWTH_COUNT]
    mov [rsi + 24], rax
    
    pop rbp
    ret