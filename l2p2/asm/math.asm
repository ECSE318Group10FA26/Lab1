; math.asm - arithmetic demo for a 64-bit cpu instance (N=64, A=7, R=2,
; I=8).  Assemble with:
;     python3 asm/asm.py asm/math.asm --bits 64 -o sim/math.hex
; and run with  TB_NAME=math_tb ../sim.sh l2p2   (from l2p2/)
;
;   task 1: d_neg = -N           (two's complement: ~N + 1)
;   task 2: d_pop = popcount(N)  (SWAR: the 5555.../3333.../0F0F... mask
;          ladder; the masks are 64-bit, far wider than the 8-bit
;          immediate field, so they live in RAM and are applied with
;          memory-source ALU ops)
;   task 3: d_mul = d_ma * d_mb  (shift-and-add; there is no MUL op)
;
; expected outcome (checked by ../tb/math_tb.v):
;   mem[101] = 64'hEDCBA98765432110  (-0x123456789ABCDEF0)
;   mem[102] = 32                    (N has 32 one-bits)
;   mem[105] = 64'd121932631112635269 (123456789 * 987654321)
;   pc = 40 (the halt loop)

; --- task 1: -N ---
        load  r0, [d_n]         ; r0 = N
        not   r0, r0            ; r0 = ~N   (the source goes through the ALU)
        inc   r0                ; r0 = ~N + 1 = -N
        store [d_neg], r0       ; mem[d_neg] = -N

; --- task 2: popcount(N), SWAR ladder (x is in r0, the temp in r1) ---
        load  r0, [d_n]         ; x = N
        mov   r1, r0            ; x = x - ((x>>1) & 0x5555...)  (pairs)
        srl   r1, #1
        and   r1, [d_m1]
        subu  r0, r1
        mov   r1, r0            ; x = (x & 0x3333...) + ((x>>2) & 0x3333...)
        srl   r1, #2            ;   (nibbles)
        and   r1, [d_m2]
        and   r0, [d_m2]
        add   r0, r1
        mov   r1, r0            ; x = (x + (x>>4)) & 0x0F0F...  (bytes)
        srl   r1, #4
        add   r0, r1
        and   r0, [d_m3]
        mov   r1, r0            ; x = x + (x>>8)    (16-bit lanes)
        srl   r1, #8
        add   r0, r1
        mov   r1, r0            ; x = x + (x>>16)   (32-bit lanes)
        srl   r1, #16
        add   r0, r1
        mov   r1, r0            ; x = x + (x>>32)   (the low word)
        srl   r1, #32
        add   r0, r1
        and   r0, #127          ; the count (<= 64) is in the low 7 bits
        store [d_pop], r0       ; mem[d_pop] = popcount(N)

; --- task 3: d_ma * d_mb, shift-and-add ---
        load  r0, [d_ma]        ; a
        load  r1, [d_mb]        ; b
        ldi   r2, #0            ; result = 0
muloop: mov   r3, r1
        and   r3, #1            ; Z=1 iff b's low bit is 0
        be    mulskip
        add   r2, r0            ; result += a
mulskip: sll  r0, #1           ; a <<= 1
        srl   r1, #1            ; b >>= 1   (Z=1 iff b == 0)
        bne   muloop
        store [d_mul], r2       ; mem[d_mul] = a * b

halt:   bra   halt              ; spin

        .org  100
d_n:    .word 0x123456789ABCDEF0        ; N
d_neg:  .word 0
d_pop:  .word 0
d_ma:   .word 123456789
d_mb:   .word 987654321
d_mul:  .word 0
d_m1:   .word 0x5555555555555555        ; SWAR masks
d_m2:   .word 0x3333333333333333
d_m3:   .word 0x0F0F0F0F0F0F0F0F
