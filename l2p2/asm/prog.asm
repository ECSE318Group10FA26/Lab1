; prog.asm - test program for cpu_tb (ISA v2: op dst, src with
; register / [memory] / #immediate operand types)
;
; expected outcome (checked by ../tb/cpu_tb.v):
;   mem[163] = 27, mem[164] = 0, mem[165] = 20 (MOVSR snapshot),
;   mem[166] = 8'hFC, mem[162] untouched (8'hA5: three skipped stores),
;   mem[167] untouched (0: the group writes hit only their group),
;   mem[168..169] = AB 8A (store.2), mem[170..171] = AB 8A (2-word
;   round trip), mem[172..175] = AB 8A 00 00 (store.4, whole block),
;   mem[176] = AB (block round trip),
;   R0 = 0, R1 = 3, R2 = 32'h8AAB, R3 = 20, status = 5'b10100 (P,Z),
;   pc = 152

        load  r0, [d_five]      ; R0 = 5        (memory source)
        ldi   r1, #3            ; R1 = 3        (immediate source)
        add   r0, r1            ; R0 = 8
        and   r0, r1            ; R0 = 0, Z=1
        be    after_store       ; taken
        store [d_skip], r0      ; skipped
after_store:
        xor   r0, r1            ; R0 = 3  (two 1-bits: even parity, P=1)
        sll   r0, r1            ; R0 = 24 (P=1)
        store [d_res0], r0      ; mem[163] = 24
        add   [d_res0], r1      ; mem[163] = 27  (read-modify-write!)
        not   r3, r1            ; R3 = ~3 = 32'hFFFFFFFC (source through the ALU)
        store [d_not], r3       ; mem[166] = 8'hFC (the low word)
        ldi   r2, #3            ; R2 = 3
loop:   dec   r2                ; R2--
        bne   loop              ; while R2 != 0
        store [d_res1], r2      ; mem[164] = 0
        subu  r0, r1            ; R0 = 21 (three 1-bits: odd, P=0), Z=0, C=1
        bsr   c_set, c          ; C=1: taken (odd flag index: exercises
                                ;        the BSR sel/address field split)
        sle   r0, r1            ; skipped
c_set:  sle   r0, r1            ; R0 = 0 -> status = 5'b10100 (P=1, Z=1)
        bsr   p_even, p         ; P=1: taken
        store [d_skip], r0      ; skipped
        nop                     ; skipped
p_even:
        movsr r3                ; R3 = status = 20
        store [d_sr], r3        ; mem[165] = 20
        ldi   r2, #0x8AAB       ; R2 = 32'h8AAB
        store.2 [d_wide], r2    ; mem[168] = 8'hAB, mem[169] = 8'h8A
        load.2 r2, [d_wide]     ; R2 = 32'h8AAB (2-word round trip)
        store.2 [d_wide2], r2   ; mem[170] = 8'hAB, mem[171] = 8'h8A
        store.4 [d_long], r2    ; mem[172..175] = AB 8A 00 00 (whole block)
        load.4 r2, [d_long]     ; R2 = 32'h8AAB (block round trip)
        store [d_res4], r2      ; mem[176] = 8'hAB
        ldi   r2, #land         ; R2 = 140 (the word address of land)
        jmp   r2                ; branch via register (bra r2)
        store [d_skip], r0      ; only runs if the jmp FAILED (clobbers d_skip)
land:   ldi   r2, #0x8AAB       ; R2 = 32'h8AAB (a 16-bit immediate: needs I=16)
        and   r0, r0            ; R0 = 0 (unchanged): status back to 5'b10100 (P,Z)
        bra   halt
halt:   bra   halt

        .org  160
d_five:  .word 5
d_three: .word 3
d_skip:  .word 0xA5
d_res0:  .word 0
d_res1:  .word 0
d_sr:    .word 0
d_not:   .word 0
d_pad:   .word 0               ; pair alignment for d_wide
d_wide:  .word 0, 0            ; 2-word group
d_wide2: .word 0, 0            ; 2-word group
d_long:  .word 0, 0, 0, 0      ; 4-word group (a whole block)
d_res4:  .word 0
