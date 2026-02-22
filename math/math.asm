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

; file: stdlib/math/math.asm
; description: Math library using SSE/SSE2 instructions for ManV
;
; All float operations use SSE2 (double precision in xmm registers)
; Integer operations use general registers

section .data
    ; Constants
    pi:        dq 3.14159265358979323846
    tau:       dq 6.28318530717958647692
    e:         dq 2.71828182845904523536
    phi:       dq 1.61803398874989484820
    sqrt2:     dq 1.41421356237309504880
    ln2:       dq 0.69314718055994530941
    ln10:      dq 2.30258509299404568401
    
    ; Masks and special values
    sign_mask:    dq 0x8000000000000000
    exp_mask:     dq 0x7FF0000000000000
    mantissa_mask: dq 0x000FFFFFFFFFFFFF
    inf_value:    dq 0x7FF0000000000000
    neg_inf:      dq 0xFFF0000000000000
    nan_value:    dq 0x7FF8000000000000
    
    ; For polynomial approximations
    sin_coeff_1:  dq -1.66666666666666666667e-01  ; -1/3!
    sin_coeff_2:  dq  8.33333333333333333333e-03  ;  1/5!
    sin_coeff_3:  dq -1.98412698412698412698e-04  ; -1/7!
    sin_coeff_4:  dq  2.75573192239858906526e-06  ;  1/9!
    
    exp_coeff_1:  dq 1.0
    exp_coeff_2:  dq 0.5
    exp_coeff_3:  dq 0.16666666666666666667
    exp_coeff_4:  dq 0.04166666666666666667
    exp_coeff_5:  dq 0.00833333333333333333

section .text
    ; Integer functions
    global int_abs
    global int_min
    global int_max
    global int_clamp
    global int_pow
    global int_sqrt
    global int_gcd
    global int_lcm
    
    ; Float functions (SSE2)
    global float_abs
    global float_min
    global float_max
    global float_clamp
    global float_sqrt
    global float_rsqrt
    global float_floor
    global float_ceil
    global float_round
    global float_trunc
    
    ; Trigonometric functions
    global float_sin
    global float_cos
    global float_tan
    global float_asin
    global float_acos
    global float_atan
    global float_atan2
    
    ; Exponential and logarithmic
    global float_exp
    global float_log
    global float_log2
    global float_log10
    global float_pow
    global float_cbrt
    
    ; Utility functions
    global float_is_nan
    global float_is_inf
    global float_is_finite
    global float_degrees
    global float_radians
    global float_hypot
    global float_fmod

; =============================================================================
; Integer Functions
; =============================================================================

; int_abs(int x) -> int
; Returns absolute value
int_abs:
    mov rax, rdi
    neg rax
    cmovs rax, rdi      ; If result negative, use original
    ret

; int_min(int a, int b) -> int
int_min:
    mov rax, rdi
    cmp rdi, rsi
    cmovg rax, rsi
    ret

; int_max(int a, int b) -> int
int_max:
    mov rax, rdi
    cmp rdi, rsi
    cmovl rax, rsi
    ret

; int_clamp(int x, int min_val, int max_val) -> int
int_clamp:
    cmp rdi, rsi
    cmovl rdi, rsi
    cmp rdi, rdx
    cmovg rdi, rdx
    mov rax, rdi
    ret

; int_pow(int base, int exp) -> int
int_pow:
    push rbx
    xor rax, rax
    inc rax              ; result = 1
    mov rbx, rdi         ; base
    
    test rsi, rsi
    jz .pow_done
    
    cmp rsi, 0
    jl .pow_zero
    
.pow_loop:
    test rsi, rsi
    jz .pow_done
    
    test rsi, 1
    jz .pow_even
    
    imul rax, rbx
    
.pow_even:
    imul rbx, rbx
    sar rsi, 1
    jmp .pow_loop
    
.pow_zero:
    xor rax, rax
    
.pow_done:
    pop rbx
    ret

; int_sqrt(int n) -> int
; Integer square root using Newton's method
int_sqrt:
    push rbx
    push r12
    
    mov r12, rdi         ; n
    
    ; Handle 0 and 1
    cmp r12, 1
    jle .sqrt_small
    
    ; Initial guess: n/2
    mov rax, r12
    shr rax, 1
    
.sqrt_loop:
    mov rbx, rax
    ; x = (x + n/x) / 2
    mov rax, r12
    xor rdx, rdx
    div rbx
    add rax, rbx
    shr rax, 1
    
    ; Check convergence
    cmp rax, rbx
    jge .sqrt_check_done
    
    ; Check if we're close enough
    sub rbx, rax
    cmp rbx, 1
    ja .sqrt_loop
    
.sqrt_check_done:
    ; Ensure rax*rax <= n
    mov rbx, rax
    imul rbx, rbx
    cmp rbx, r12
    jle .sqrt_done
    dec rax
    jmp .sqrt_check_done
    
.sqrt_small:
    mov rax, r12
    
.sqrt_done:
    pop r12
    pop rbx
    ret

; int_gcd(int a, int b) -> int
; Greatest common divisor using Euclidean algorithm
int_gcd:
    test rsi, rsi
    jz .gcd_done
    
.gcd_loop:
    xor rdx, rdx
    mov rax, rdi
    div rsi
    mov rdi, rsi
    mov rsi, rdx
    test rsi, rsi
    jnz .gcd_loop
    
.gcd_done:
    mov rax, rdi
    ret

; int_lcm(int a, int b) -> int
; Least common multiple
int_lcm:
    push rbx
    push r12
    push r13
    
    mov r12, rdi         ; a
    mov r13, rsi         ; b
    
    ; lcm(a,b) = |a*b| / gcd(a,b)
    ; First compute gcd
    call int_gcd         ; result in rax
    
    ; Compute (a / gcd) * b to avoid overflow
    mov rcx, rax         ; gcd
    mov rax, r12
    xor rdx, rdx
    div rcx              ; a / gcd
    imul rax, r13        ; * b
    
    pop r13
    pop r12
    pop rbx
    ret

; =============================================================================
; Float Functions (SSE2)
; =============================================================================

; float_abs(float x) -> float
float_abs:
    movq rax, xmm0
    and rax, [rel sign_mask]
    xor rax, [rel sign_mask]  ; Clear sign bit via XOR
    movq xmm0, rax
    ret

; float_min(float a, float b) -> float
float_min:
    minsd xmm0, xmm1
    ret

; float_max(float a, float b) -> float
float_max:
    maxsd xmm0, xmm1
    ret

; float_clamp(float x, float min_val, float max_val) -> float
; xmm0 = x, xmm1 = min, xmm2 = max
float_clamp:
    minsd xmm0, xmm2     ; min(x, max)
    maxsd xmm0, xmm1     ; max(result, min)
    ret

; float_sqrt(float x) -> float
float_sqrt:
    sqrtsd xmm0, xmm0
    ret

; float_rsqrt(float x) -> float
; Approximate reciprocal square root
float_rsqrt:
    sqrtsd xmm0, xmm0
    movsd xmm1, [rel one]
    divsd xmm1, xmm0
    movsd xmm0, xmm1
    ret

; float_floor(float x) -> float
float_floor:
    roundsd xmm0, xmm0, 1    ; Round toward -infinity
    ret

; float_ceil(float x) -> float
float_ceil:
    roundsd xmm0, xmm0, 2    ; Round toward +infinity
    ret

; float_round(float x) -> float
float_round:
    roundsd xmm0, xmm0, 0    ; Round to nearest
    ret

; float_trunc(float x) -> float
float_trunc:
    roundsd xmm0, xmm0, 3    ; Round toward zero
    ret

; =============================================================================
; Trigonometric Functions
; =============================================================================

; float_sin(float x) -> float
; Taylor series approximation: sin(x) = x - x^3/3! + x^5/5! - x^7/7! + ...
float_sin:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    
    movsd [rbp - 8], xmm0      ; Store x
    
    ; Normalize x to [-pi, pi]
    movsd xmm1, [rel pi]
    divsd xmm0, xmm1           ; x / pi
    roundsd xmm0, xmm0, 3      ; trunc
    mulsd xmm0, xmm1           ; n * pi
    movsd xmm1, [rbp - 8]
    subsd xmm1, xmm0           ; x - n*pi
    movsd xmm0, xmm1
    movsd [rbp - 8], xmm0      ; Store normalized x
    
    ; Compute x^2
    movsd xmm1, xmm0
    mulsd xmm1, xmm0
    movsd [rbp - 16], xmm1     ; x2 = x^2
    
    ; Taylor series: x - x^3/6 + x^5/120 - x^7/5040 + x^9/362880
    
    ; term = x
    movsd xmm2, xmm0           ; term = x
    movsd xmm3, xmm0           ; sum = x
    
    ; term = term * x^2 / 2 / 3  (x^3/6)
    movsd xmm4, [rel sin_coeff_1]
    mulsd xmm2, [rbp - 16]     ; x^3
    mulsd xmm2, xmm4           ; -x^3/6
    addsd xmm3, xmm2           ; sum += term
    
    ; term = term * x^2 / 4 / 5  (x^5/120)
    mulsd xmm2, [rbp - 16]     ; x^5 * coeff
    movsd xmm4, [rel sin_coeff_2]
    movsd xmm2, xmm4
    movsd xmm5, [rbp - 16]
    movsd xmm2, xmm0
    mulsd xmm2, xmm5
    mulsd xmm2, xmm5
    mulsd xmm2, xmm5
    mulsd xmm2, xmm5
    mulsd xmm2, xmm4
    addsd xmm3, xmm2
    
    ; Continue with x^7 term
    movsd xmm2, xmm0
    movsd xmm4, [rel sin_coeff_3]
    mulsd xmm2, [rbp - 16]
    mulsd xmm2, [rbp - 16]
    mulsd xmm2, [rbp - 16]
    mulsd xmm2, xmm4
    addsd xmm3, xmm2
    
    ; x^9 term
    movsd xmm2, xmm0
    movsd xmm4, [rel sin_coeff_4]
    mulsd xmm2, [rbp - 16]
    mulsd xmm2, [rbp - 16]
    mulsd xmm2, [rbp - 16]
    mulsd xmm2, [rbp - 16]
    mulsd xmm2, xmm4
    addsd xmm3, xmm2
    
    movsd xmm0, xmm3
    
    add rsp, 64
    pop rbp
    ret

; float_cos(float x) -> float
; cos(x) = sin(x + pi/2)
float_cos:
    push rbp
    mov rbp, rsp
    
    ; x + pi/2
    movsd xmm1, [rel pi]
    movsd xmm2, [rel two]
    divsd xmm1, xmm2           ; pi/2
    addsd xmm0, xmm1           ; x + pi/2
    
    call float_sin
    
    pop rbp
    ret

; float_tan(float x) -> float
; tan(x) = sin(x) / cos(x)
float_tan:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    
    movsd [rbp - 8], xmm0      ; Save x
    
    call float_sin
    movsd [rbp - 16], xmm0     ; Save sin(x)
    
    movsd xmm0, [rbp - 8]
    call float_cos             ; xmm0 = cos(x)
    
    movsd xmm1, xmm0
    movsd xmm0, [rbp - 16]
    divsd xmm0, xmm1           ; sin/cos
    
    add rsp, 16
    pop rbp
    ret

; float_asin(float x) -> float
; asin(x) ≈ atan2(x, sqrt(1-x^2))
float_asin:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    
    movsd [rbp - 8], xmm0      ; Save x
    
    ; Compute sqrt(1 - x^2)
    movsd xmm1, xmm0
    mulsd xmm1, xmm0           ; x^2
    movsd xmm2, [rel one]
    subsd xmm2, xmm1           ; 1 - x^2
    sqrtsd xmm2, xmm2          ; sqrt(1-x^2)
    
    ; atan2(x, sqrt(1-x^2))
    movsd xmm1, xmm2
    call float_atan2
    
    add rsp, 16
    pop rbp
    ret

; float_acos(float x) -> float
; acos(x) = pi/2 - asin(x)
float_acos:
    push rbp
    mov rbp, rsp
    
    call float_asin
    
    movsd xmm1, [rel pi]
    movsd xmm2, [rel two]
    divsd xmm1, xmm2           ; pi/2
    subsd xmm1, xmm0           ; pi/2 - asin(x)
    movsd xmm0, xmm1
    
    pop rbp
    ret

; float_atan(float x) -> float
; Uses polynomial approximation
float_atan:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    movsd [rbp - 8], xmm0      ; Save x
    
    ; Handle |x| > 1 case: atan(x) = pi/2 - atan(1/x) for x > 0
    ;                           atan(x) = -pi/2 - atan(1/x) for x < 0
    
    movsd xmm1, [rel one]
    ucomisd xmm0, xmm1
    ja .atan_large_positive
    
    movsd xmm1, [rel neg_one]
    ucomisd xmm0, xmm1
    jb .atan_large_negative
    
    ; |x| <= 1, use polynomial approximation
    ; atan(x) ≈ x - x^3/3 + x^5/5 - x^7/7 + ...
    
    movsd xmm1, xmm0           ; x
    mulsd xmm1, xmm0           ; x^2
    movsd [rbp - 16], xmm1     ; Store x^2
    
    ; x - x^3/3
    movsd xmm2, xmm0
    mulsd xmm2, xmm1           ; x^3
    divsd xmm2, [rel three]
    subsd xmm0, xmm2
    
    ; + x^5/5
    movsd xmm2, xmm1
    mulsd xmm2, xmm1           ; x^4
    mulsd xmm2, xmm1           ; x^6
    movsd xmm3, xmm0
    mulsd xmm3, xmm1           ; x^3
    divsd xmm2, [rel five]
    addsd xmm0, xmm2
    
    ; - x^7/7
    movsd xmm2, xmm1
    mulsd xmm2, xmm1
    mulsd xmm2, xmm1
    mulsd xmm2, xmm0
    divsd xmm2, [rel seven]
    subsd xmm0, xmm2
    
    jmp .atan_done
    
.atan_large_positive:
    ; atan(x) = pi/2 - atan(1/x)
    movsd xmm1, [rel one]
    divsd xmm1, xmm0           ; 1/x
    movsd xmm0, xmm1
    call float_atan
    movsd xmm1, [rel pi]
    movsd xmm2, [rel two]
    divsd xmm1, xmm2
    subsd xmm1, xmm0
    movsd xmm0, xmm1
    jmp .atan_done
    
.atan_large_negative:
    ; atan(x) = -pi/2 - atan(1/x)
    movsd xmm1, [rel neg_one]
    divsd xmm1, xmm0           ; 1/x (positive)
    movsd xmm0, xmm1
    call float_atan
    movsd xmm1, [rel pi]
    movsd xmm2, [rel two]
    divsd xmm1, xmm2
    addsd xmm0, xmm1
    negsd xmm0
    
.atan_done:
    add rsp, 32
    pop rbp
    ret

; float_atan2(float y, float x) -> float
; Two-argument arctangent
float_atan2:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    
    movsd [rbp - 8], xmm0      ; y
    movsd [rbp - 16], xmm1     ; x
    
    ; Handle special cases
    pxor xmm2, xmm2
    
    ; x == 0?
    ucomisd xmm1, xmm2
    je .atan2_x_zero
    
    ; y == 0?
    ucomisd xmm0, xmm2
    je .atan2_y_zero
    
    ; General case: atan(|y/x|) with quadrant adjustment
    movsd xmm0, [rbp - 8]
    divsd xmm0, xmm1           ; y/x
    call float_atan
    
    ; Adjust for quadrant
    movsd xmm1, [rbp - 16]
    xorpd xmm2, xmm2
    ucomisd xmm1, xmm2
    ja .atan2_done              ; x > 0, atan is correct
    
    ; x < 0
    movsd xmm1, [rel pi]
    addsd xmm0, xmm1           ; atan + pi for y >= 0
    movsd xmm1, [rbp - 8]
    ucomisd xmm1, xmm2
    jae .atan2_done
    subsd xmm0, [rel pi]
    subsd xmm0, [rel pi]       ; atan - pi for y < 0
    jmp .atan2_done
    
.atan2_x_zero:
    ; x = 0
    movsd xmm0, [rel pi]
    movsd xmm1, [rel two]
    divsd xmm0, xmm1           ; pi/2
    movsd xmm1, [rbp - 8]
    pxor xmm2, xmm2
    ucomisd xmm1, xmm2
    jae .atan2_done
    movsd xmm0, [rel neg_pi_half]
    jmp .atan2_done
    
.atan2_y_zero:
    ; y = 0
    movsd xmm0, [rbp - 16]
    pxor xmm2, xmm2
    ucomisd xmm0, xmm2
    ja .atan2_ret_zero          ; x > 0
    movsd xmm0, [rel pi]       ; return pi for x < 0
    jmp .atan2_done
    
.atan2_ret_zero:
    xorpd xmm0, xmm0
    
.atan2_done:
    add rsp, 16
    pop rbp
    ret

; =============================================================================
; Exponential and Logarithmic Functions
; =============================================================================

; float_exp(float x) -> float
; e^x using Taylor series
float_exp:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    movsd [rbp - 8], xmm0      ; Save x
    
    ; Handle overflow/underflow
    movsd xmm1, [rel exp_max]
    ucomisd xmm0, xmm1
    ja .exp_overflow
    
    movsd xmm1, [rel exp_min]
    ucomisd xmm1, xmm0
    ja .exp_underflow
    
    ; Compute exp(x) = (1 + x/n)^n for large n, or use Taylor
    ; Taylor: e^x = 1 + x + x^2/2! + x^3/3! + x^4/4! + ...
    
    ; result = 1.0
    movsd xmm0, [rel one]
    movsd [rbp - 16], xmm0     ; result = 1.0
    
    ; term = x
    movsd xmm1, [rbp - 8]
    movsd [rbp - 24], xmm1     ; term = x
    
    ; Add first term
    addsd xmm0, xmm1
    movsd [rbp - 16], xmm0
    
    ; x^2
    mulsd xmm1, [rbp - 8]      ; x^2
    movsd [rbp - 32], xmm1     ; Store x^2
    
    ; term = x^2 / 2
    movsd xmm1, [rbp - 32]
    divsd xmm1, [rel two]
    movsd [rbp - 24], xmm1
    movsd xmm0, [rbp - 16]
    addsd xmm0, xmm1
    movsd [rbp - 16], xmm0
    
    ; term = x^3 / 6
    movsd xmm1, [rbp - 32]
    mulsd xmm1, [rbp - 8]      ; x^3
    divsd xmm1, [rel six]
    movsd xmm0, [rbp - 16]
    addsd xmm0, xmm1
    movsd [rbp - 16], xmm0
    
    ; term = x^4 / 24
    movsd xmm1, [rbp - 32]
    mulsd xmm1, [rbp - 32]     ; x^4
    divsd xmm1, [rel twentyfour]
    movsd xmm0, [rbp - 16]
    addsd xmm0, xmm1
    movsd [rbp - 16], xmm0
    
    ; term = x^5 / 120
    movsd xmm1, [rbp - 32]
    mulsd xmm1, [rbp - 32]     ; x^4
    mulsd xmm1, [rbp - 8]      ; x^5
    divsd xmm1, [rel 120]
    movsd xmm0, [rbp - 16]
    addsd xmm0, xmm1
    movsd [rbp - 16], xmm0
    
    ; term = x^6 / 720
    movsd xmm1, [rbp - 32]
    mulsd xmm1, [rbp - 32]     ; x^4
    mulsd xmm1, [rbp - 32]     ; x^6
    divsd xmm1, [rel 720]
    movsd xmm0, [rbp - 16]
    addsd xmm0, xmm1
    
    jmp .exp_done
    
.exp_overflow:
    movsd xmm0, [rel inf_value]
    jmp .exp_done
    
.exp_underflow:
    xorpd xmm0, xmm0           ; Return 0
    
.exp_done:
    add rsp, 32
    pop rbp
    ret

; float_log(float x) -> float
; Natural logarithm using Newton's method or series
float_log:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    movsd [rbp - 8], xmm0      ; Save x
    
    ; Check for x <= 0
    pxor xmm1, xmm1
    ucomisd xmm0, xmm1
    jbe .log_error
    
    ; Check for x == 1
    movsd xmm1, [rel one]
    ucomisd xmm0, xmm1
    je .log_one
    
    ; Use log(x) = log2(x) * ln(2)
    ; First compute log2(x) using bit manipulation
    
    ; Get exponent
    movq rax, xmm0
    mov rcx, rax
    shr rcx, 52               ; Extract exponent
    sub rcx, 1023             ; Unbias
    
    ; Get mantissa
    mov rdx, rax
    and rdx, [rel mantissa_mask]
    or rdx, [rel implicit_one]  ; Add implicit 1
    ; Reconstruct: mantissa/2^52 gives value in [1, 2)
    
    ; For now, use approximation: log(1+x) ≈ x - x^2/2 + x^3/3 - ...
    ; Where x is (input - 1) for input close to 1
    
    movsd xmm1, [rel one]
    subsd xmm0, xmm1          ; x - 1
    
    ; Taylor series for log(1+u)
    movsd [rbp - 16], xmm0    ; u = x - 1
    
    ; log(1+u) ≈ u - u^2/2 + u^3/3 - u^4/4 + ...
    
    movsd xmm1, xmm0          ; u
    mulsd xmm1, xmm0          ; u^2
    movsd [rbp - 24], xmm1    ; Store u^2
    
    movsd xmm2, xmm0          ; result = u
    
    ; - u^2/2
    movsd xmm3, xmm1
    divsd xmm3, [rel two]
    subsd xmm2, xmm3
    
    ; + u^3/3
    movsd xmm3, xmm1
    mulsd xmm3, xmm0          ; u^3
    divsd xmm3, [rel three]
    addsd xmm2, xmm3
    
    ; - u^4/4
    movsd xmm3, xmm1
    mulsd xmm3, xmm1          ; u^4
    divsd xmm3, [rel four]
    subsd xmm2, xmm3
    
    ; + u^5/5
    movsd xmm3, xmm1
    mulsd xmm3, xmm1          ; u^4
    mulsd xmm3, xmm0          ; u^5
    divsd xmm3, [rel five]
    addsd xmm2, xmm3
    
    movsd xmm0, xmm2
    jmp .log_done
    
.log_error:
    ; x <= 0, return -inf or NaN
    movsd xmm0, [rel neg_inf]
    jmp .log_done
    
.log_one:
    xorpd xmm0, xmm0          ; log(1) = 0
    
.log_done:
    add rsp, 32
    pop rbp
    ret

; float_log2(float x) -> float
float_log2:
    push rbp
    mov rbp, rsp
    
    call float_log
    divsd xmm0, [rel ln2]     ; log2(x) = ln(x) / ln(2)
    
    pop rbp
    ret

; float_log10(float x) -> float
float_log10:
    push rbp
    mov rbp, rsp
    
    call float_log
    divsd xmm0, [rel ln10]    ; log10(x) = ln(x) / ln(10)
    
    pop rbp
    ret

; float_pow(float base, float exp) -> float
float_pow:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    
    movsd [rbp - 8], xmm0     ; Save base
    movsd [rbp - 16], xmm1    ; Save exp
    
    ; pow(x, y) = exp(y * log(x))
    
    ; First check for special cases
    pxor xmm2, xmm2
    ucomisd xmm0, xmm2
    jb .pow_error             ; base < 0
    
    ; log(base)
    call float_log
    
    ; y * log(base)
    mulsd xmm0, [rbp - 16]
    
    ; exp(result)
    call float_exp
    
    jmp .pow_done
    
.pow_error:
    ; Negative base, return NaN
    movsd xmm0, [rel nan_value]
    
.pow_done:
    add rsp, 16
    pop rbp
    ret

; float_cbrt(float x) -> float
; Cube root using Newton's method
float_cbrt:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    
    movsd [rbp - 8], xmm0     ; Save x
    
    ; Handle negative x
    xorpd xmm1, xmm1
    ucomisd xmm0, xmm1
    jb .cbrt_negative
    
    ; Initial guess: x^(1/3) ≈ 1 for x ≈ 1, adjust for scale
    movsd xmm1, [rel one_third]
    call float_pow
    jmp .cbrt_done
    
.cbrt_negative:
    ; cbrt(-x) = -cbrt(x)
    movsd xmm1, [rel sign_mask]
    xorpd xmm0, xmm1          ; Make positive
    movsd [rbp - 16], xmm0
    
    movsd xmm1, [rel one_third]
    call float_pow
    
    ; Negate result
    movsd xmm1, [rel sign_mask]
    xorpd xmm0, xmm1
    
.cbrt_done:
    add rsp, 16
    pop rbp
    ret

; =============================================================================
; Utility Functions
; =============================================================================

; float_is_nan(float x) -> int
float_is_nan:
    movq rax, xmm0
    mov rcx, rax
    shl rcx, 1               ; Remove sign bit
    cmp rcx, [rel exp_mask]
    setae al
    movzx rax, al
    
    ; Check mantissa is non-zero
    mov rcx, rax
    shl rcx, 12
    test rcx, rcx
    setnz al
    movzx rax, al
    ret

; float_is_inf(float x) -> int
float_is_inf:
    movq rax, xmm0
    mov rcx, rax
    shl rcx, 1               ; Remove sign bit
    cmp rcx, [rel exp_mask]
    sete al
    movzx rax, al
    ret

; float_is_finite(float x) -> int
float_is_finite:
    movq rax, xmm0
    mov rcx, rax
    shl rcx, 1               ; Remove sign bit
    cmp rcx, [rel exp_mask]
    setb al
    movzx rax, al
    ret

; float_degrees(float radians) -> float
float_degrees:
    mulsd xmm0, [rel rad_to_deg]
    ret

; float_radians(float degrees) -> float
float_radians:
    mulsd xmm0, [rel deg_to_rad]
    ret

; float_hypot(float x, float y) -> float
; sqrt(x^2 + y^2)
float_hypot:
    mulsd xmm0, xmm0         ; x^2
    mulsd xmm1, xmm1         ; y^2
    addsd xmm0, xmm1         ; x^2 + y^2
    sqrtsd xmm0, xmm0
    ret

; float_fmod(float x, float y) -> float
; Floating-point modulo
float_fmod:
    push rbp
    mov rbp, rsp
    
    ; Check for division by zero
    pxor xmm2, xmm2
    ucomisd xmm1, xmm2
    je .fmod_nan
    
    ; fmod(x, y) = x - trunc(x/y) * y
    movsd xmm2, xmm0         ; Save x
    divsd xmm0, xmm1         ; x / y
    roundsd xmm0, xmm0, 3    ; trunc(x/y)
    mulsd xmm0, xmm1         ; trunc(x/y) * y
    movsd xmm1, xmm2         ; Restore x
    subsd xmm1, xmm0         ; x - trunc(x/y) * y
    movsd xmm0, xmm1
    
    jmp .fmod_done
    
.fmod_nan:
    movsd xmm0, [rel nan_value]
    
.fmod_done:
    pop rbp
    ret

; =============================================================================
; Additional Constants
; =============================================================================

section .data
    one:          dq 1.0
    two:          dq 2.0
    three:        dq 3.0
    four:         dq 4.0
    five:         dq 5.0
    six:          dq 6.0
    seven:        dq 7.0
    twentyfour:   dq 24.0
    120:          dq 120.0
    720:          dq 720.0
    neg_one:      dq -1.0
    one_third:    dq 0.33333333333333333333
    
    implicit_one: dq 0x3FF0000000000000  ; 1.0 in double format
    
    exp_max:      dq 709.782712893384    ; Max x where exp(x) doesn't overflow
    exp_min:      dq -708.396418532264   ; Min x where exp(x) doesn't underflow
    
    rad_to_deg:   dq 57.2957795130823208768  ; 180/pi
    deg_to_rad:   dq 0.01745329251994329577  ; pi/180
    neg_pi_half:  dq -1.57079632679489661923