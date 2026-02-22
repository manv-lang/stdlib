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

; file: stdlib/memory/gc.asm
; description: Mark & Sweep Garbage Collector runtime for ManV
;
; Object Header Layout (16 bytes):
; +------------------+--------------------+
; | type_id (8B)     | flags (1B)         |
; +------------------+--------------------+
; | generation (1B)  | size (6B)          |
; +------------------+--------------------+
;
; Header Offsets:
HEADER_SIZE       equ 16
TYPE_ID_OFFSET    equ 0
FLAGS_OFFSET      equ 8
GENERATION_OFFSET equ 9
SIZE_OFFSET       equ 10
PAYLOAD_OFFSET    equ 16

; Object Flags
FLAG_MARKED       equ 0x01
FLAG_ROOT         equ 0x02
FLAG_GC_MANAGED   equ 0x04
FLAG_ARENA_MANAGED equ 0x08
FLAG_PINNED       equ 0x10
FLAG_FINALIZED    equ 0x20
FLAG_HAS_FINALIZER equ 0x40

; GC Configuration
GC_DEFAULT_THRESHOLD equ 1048576  ; 1MB
GC_MAX_OBJECTS       equ 1048576  ; Max tracked objects

section .data
    ; GC State
    gc_initialized:     dq 0
    gc_threshold:       dq GC_DEFAULT_THRESHOLD
    gc_allocated_bytes: dq 0
    gc_object_count:    dq 0
    gc_collections:     dq 0
    
    ; Heap management
    gc_heap_start:      dq 0
    gc_heap_end:        dq 0
    gc_heap_size:       dq 0
    
    ; Root tracking
    gc_root_frames:     dq 0       ; Linked list of root frames
    gc_root_count:      dq 0
    
    ; Object list (for sweep phase)
    gc_object_list:     dq 0       ; Head of allocated object list
    gc_object_list_tail: dq 0      ; Tail for fast append
    
    ; Statistics
    gc_total_freed:     dq 0
    gc_total_allocated: dq 0

section .bss
    ; Work buffer for mark stack
    gc_mark_stack:      resq 4096  ; Mark stack (4096 pointers)
    gc_mark_stack_ptr:  resq 1
    
section .text
    global gc_init
    global gc_alloc
    global gc_collect
    global gc_register_frame
    global gc_unregister_frame
    global gc_add_root
    global gc_remove_root
    global gc_get_stats

; =============================================================================
; gc_init - Initialize the garbage collector
; =============================================================================
; Initialize GC heap and state
; Arguments: None
; Returns: rax = 0 on success, -1 on error
; =============================================================================
gc_init:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    
    ; Check if already initialized
    mov rax, [gc_initialized]
    test rax, rax
    jnz .already_initialized
    
    ; Allocate initial heap (4MB)
    mov rax, 9          ; sys_mmap
    xor rdi, rdi        ; addr = NULL
    mov rsi, 4194304    ; size = 4MB
    mov rdx, 0x3        ; prot = PROT_READ | PROT_WRITE
    mov r10, 0x22       ; flags = MAP_PRIVATE | MAP_ANONYMOUS
    xor r8, r8          ; fd = -1
    xor r9, r9          ; offset = 0
    syscall
    
    test rax, rax
    js .init_error
    
    ; Store heap info
    mov [gc_heap_start], rax
    mov [gc_heap_end], rax
    mov qword [gc_heap_size], 4194304
    
    ; Initialize object list
    mov qword [gc_object_list], 0
    mov qword [gc_object_list_tail], 0
    
    ; Mark as initialized
    mov qword [gc_initialized], 1
    xor rax, rax        ; Return 0 = success
    jmp .done
    
.already_initialized:
    xor rax, rax
    jmp .done
    
.init_error:
    mov rax, -1
    
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; =============================================================================
; gc_alloc - Allocate a GC-managed object
; =============================================================================
; Arguments:
;   rdi = size (payload size, not including header)
;   rsi = type_id
; Returns: rax = pointer to payload, or 0 on error
; =============================================================================
gc_alloc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    
    mov r12, rdi        ; r12 = payload size
    mov r13, rsi        ; r13 = type_id
    
    ; Ensure GC is initialized
    mov rax, [gc_initialized]
    test rax, rax
    jz .alloc_init_first
    
    ; Calculate total size (header + payload + alignment padding)
    lea rbx, [r12 + HEADER_SIZE]
    add rbx, 15
    and rbx, ~15        ; 16-byte aligned
    
    ; Check if we need to trigger GC
    mov rax, [gc_allocated_bytes]
    add rax, rbx
    cmp rax, [gc_threshold]
    jle .skip_gc
    
    ; Trigger collection
    call gc_collect
    
.skip_gc:
    ; Check heap space
    mov rax, [gc_heap_end]
    add rax, rbx
    cmp rax, [gc_heap_start]
    add rax, [gc_heap_size]
    ja .alloc_need_more_space
    
    ; Allocate from heap
    mov rax, [gc_heap_end]
    mov rdi, rax        ; Object pointer
    
    ; Initialize header
    mov qword [rdi + TYPE_ID_OFFSET], r13  ; type_id
    mov byte [rdi + FLAGS_OFFSET], FLAG_GC_MANAGED
    mov byte [rdi + GENERATION_OFFSET], 0
    ; Store size (6 bytes)
    mov rdx, r12
    mov [rdi + SIZE_OFFSET], dx
    shr rdx, 16
    mov [rdi + SIZE_OFFSET + 2], dx
    shr rdx, 16
    mov [rdi + SIZE_OFFSET + 4], dx
    
    ; Add to object list
    lea rdx, [rdi + HEADER_SIZE]  ; This becomes prev pointer
    ; For simplicity, we use first 8 bytes of payload as next pointer
    ; (only for GC-internal linked list)
    
    ; Update heap end
    mov [gc_heap_end], rax
    add qword [gc_heap_end], rbx
    
    ; Update stats
    add qword [gc_allocated_bytes], rbx
    add qword [gc_object_count], 1
    add qword [gc_total_allocated], rbx
    
    ; Return payload pointer
    lea rax, [rdi + HEADER_SIZE]
    jmp .alloc_done
    
.alloc_init_first:
    ; Initialize GC and retry
    push r12
    push r13
    call gc_init
    pop r13
    pop r12
    test rax, rax
    jns gc_alloc        ; Retry allocation
    jmp .alloc_error
    
.alloc_need_more_space:
    ; For now, just fail (could expand heap here)
    ; TODO: Implement heap expansion
    
.alloc_error:
    xor rax, rax
    jmp .alloc_done
    
.alloc_done:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; =============================================================================
; gc_collect - Trigger garbage collection
; =============================================================================
; Arguments: None
; Returns: rax = number of objects freed
; =============================================================================
gc_collect:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    
    ; Increment collection count
    inc qword [gc_collections]
    
    ; Phase 1: Mark all roots
    call gc_mark_roots
    
    ; Phase 2: Sweep unmarked objects
    xor r14, r14        ; Count freed objects
    mov r12, [gc_heap_start]
    
.sweep_loop:
    ; Check if we've reached the end
    mov rax, [gc_heap_end]
    cmp r12, rax
    jae .sweep_done
    
    ; Get flags
    mov bl, [r12 + FLAGS_OFFSET]
    
    ; Check if GC-managed
    test bl, FLAG_GC_MANAGED
    jz .sweep_next
    
    ; Check if marked
    test bl, FLAG_MARKED
    jnz .sweep_unmark
    
    ; Not marked - free this object
    ; Clear GC_MANAGED flag to mark as freed
    and bl, ~FLAG_GC_MANAGED
    mov [r12 + FLAGS_OFFSET], bl
    
    ; Get size for stats
    movzx rax, word [r12 + SIZE_OFFSET]
    movzx rcx, word [r12 + SIZE_OFFSET + 2]
    shl rcx, 16
    or rax, rcx
    movzx rcx, word [r12 + SIZE_OFFSET + 4]
    shl rcx, 32
    or rax, rcx
    
    add qword [gc_total_freed], rax
    sub qword [gc_allocated_bytes], rax
    sub qword [gc_object_count], 1
    inc r14
    
    jmp .sweep_next
    
.sweep_unmark:
    ; Clear mark for next collection
    and bl, ~FLAG_MARKED
    mov [r12 + FLAGS_OFFSET], bl
    
.sweep_next:
    ; Move to next object
    movzx rax, word [r12 + SIZE_OFFSET]
    movzx rcx, word [r12 + SIZE_OFFSET + 2]
    shl rcx, 16
    or rax, rcx
    movzx rcx, word [r12 + SIZE_OFFSET + 4]
    shl rcx, 32
    or rax, rcx
    lea r12, [r12 + HEADER_SIZE + rax]
    add r12, 15
    and r12, ~15       ; Align
    jmp .sweep_loop
    
.sweep_done:
    mov rax, r14
    
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; =============================================================================
; gc_mark_roots - Mark all root objects
; =============================================================================
; Arguments: None
; Returns: None
; =============================================================================
gc_mark_roots:
    push rbp
    mov rbp, rsp
    
    ; Initialize mark stack
    lea rax, [rel gc_mark_stack]
    mov [gc_mark_stack_ptr], rax
    
    ; Walk root frames
    mov rax, [gc_root_frames]
    
.mark_frame_loop:
    test rax, rax
    jz .mark_done
    
    ; Frame structure: [count (8)] [root1 (8)] [root2 (8)] ... [next_frame (8)]
    mov rcx, [rax]      ; root count
    lea rdx, [rax + 8]  ; first root pointer
    
.mark_root_loop:
    test rcx, rcx
    jz .next_frame
    
    ; Get root pointer
    mov rdi, [rdx]
    test rdi, rdi
    jz .skip_root
    
    ; Mark this object
    push rax
    push rcx
    push rdx
    call gc_mark_object
    pop rdx
    pop rcx
    pop rax
    
.skip_root:
    add rdx, 8
    dec rcx
    jmp .mark_root_loop
    
.next_frame:
    ; Move to next frame
    mov rax, [rdx]      ; next_frame pointer is after all roots
    jmp .mark_frame_loop
    
.mark_done:
    ; Process mark stack
    call gc_process_mark_stack
    
    pop rbp
    ret

; =============================================================================
; gc_mark_object - Mark a single object
; =============================================================================
; Arguments:
;   rdi = pointer to object payload
; Returns: None
; =============================================================================
gc_mark_object:
    push rbp
    mov rbp, rsp
    
    ; Get header pointer
    sub rdi, HEADER_SIZE
    
    ; Check if already marked
    mov al, [rdi + FLAGS_OFFSET]
    test al, FLAG_MARKED
    jnz .already_marked
    
    ; Check if GC-managed
    test al, FLAG_GC_MANAGED
    jz .not_gc_object
    
    ; Mark it
    or al, FLAG_MARKED
    mov [rdi + FLAGS_OFFSET], al
    
    ; Push onto mark stack for tracing
    mov rax, [gc_mark_stack_ptr]
    mov [rax], rdi
    add qword [gc_mark_stack_ptr], 8
    
.already_marked:
.not_gc_object:
    pop rbp
    ret

; =============================================================================
; gc_process_mark_stack - Process objects on mark stack
; =============================================================================
; Arguments: None
; Returns: None
; =============================================================================
gc_process_mark_stack:
    push rbp
    mov rbp, rsp
    push rbx
    
.process_loop:
    ; Check if stack empty
    lea rax, [rel gc_mark_stack]
    cmp [gc_mark_stack_ptr], rax
    jle .done
    
    ; Pop object
    sub qword [gc_mark_stack_ptr], 8
    mov rax, [gc_mark_stack_ptr]
    mov rdi, [rax]
    
    ; Trace this object (find internal pointers)
    ; For now, just skip - real implementation would read type metadata
    ; and trace all gc<T> fields
    
    jmp .process_loop
    
.done:
    pop rbx
    pop rbp
    ret

; =============================================================================
; gc_register_frame - Register a stack frame with GC roots
; =============================================================================
; Arguments:
;   rdi = pointer to frame (first 8 bytes = count, then root pointers)
; Returns: None
; =============================================================================
gc_register_frame:
    push rbp
    mov rbp, rsp
    
    ; Get count
    mov rcx, [rdi]
    
    ; Calculate frame size
    lea rdx, [rdi + 8 + rcx * 8]  ; Pointer to next_frame field
    
    ; Link into frame list
    mov rax, [gc_root_frames]
    mov [rdx], rax      ; Set next_frame
    mov [gc_root_frames], rdi
    
    ; Update root count
    add [gc_root_count], rcx
    
    pop rbp
    ret

; =============================================================================
; gc_unregister_frame - Unregister a stack frame
; =============================================================================
; Arguments:
;   rdi = pointer to frame
; Returns: None
; =============================================================================
gc_unregister_frame:
    push rbp
    mov rbp, rsp
    push rbx
    
    mov rbx, rdi        ; rbx = frame to remove
    
    ; Get count
    mov rcx, [rbx]
    sub [gc_root_count], rcx
    
    ; Unlink from list
    mov rax, [gc_root_frames]
    cmp rax, rbx
    jne .search_frame
    
    ; First in list
    lea rdx, [rbx + 8 + rcx * 8]  ; next_frame pointer
    mov rax, [rdx]
    mov [gc_root_frames], rax
    jmp .done
    
.search_frame:
    ; Walk list to find predecessor
    mov rdx, rax
    
.search_loop:
    test rdx, rdx
    jz .done            ; Not found
    
    ; Get next pointer
    mov rcx, [rdx]      ; count
    lea rax, [rdx + 8 + rcx * 8]  ; next_frame location
    mov rax, [rax]
    
    cmp rax, rbx
    je .found
    
    mov rdx, rax
    jmp .search_loop
    
.found:
    ; rdx points to predecessor
    mov rcx, [rbx]      ; count of frame to remove
    lea rax, [rbx + 8 + rcx * 8]  ; next_frame of removed frame
    mov rax, [rax]
    
    ; Update predecessor's next
    mov rcx, [rdx]
    lea rdi, [rdx + 8 + rcx * 8]
    mov [rdi], rax
    
.done:
    pop rbx
    pop rbp
    ret

; =============================================================================
; gc_add_root / gc_remove_root - Single root management
; =============================================================================
gc_add_root:
    push rbp
    mov rbp, rsp
    
    ; For simplicity, add to a global root list
    ; Real implementation would use frame-based registration
    
    pop rbp
    ret

gc_remove_root:
    push rbp
    mov rbp, rsp
    pop rbp
    ret

; =============================================================================
; gc_get_stats - Get GC statistics
; =============================================================================
; Returns memory stats via pointer
; Arguments:
;   rdi = pointer to stats struct (5 * 8 bytes)
; Returns: None
; =============================================================================
gc_get_stats:
    mov rax, [gc_allocated_bytes]
    mov [rdi], rax
    mov rax, [gc_object_count]
    mov [rdi + 8], rax
    mov rax, [gc_collections]
    mov [rdi + 16], rax
    mov rax, [gc_total_freed]
    mov [rdi + 24], rax
    mov rax, [gc_total_allocated]
    mov [rdi + 32], rax
    ret