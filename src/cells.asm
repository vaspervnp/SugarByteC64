; =============================================================================
; cells.asm - the special cells: jelly, icing, chocolate, licorice
;
; cell[]: bits 0-2 the kind (C_*), 3-4 icing layers, 5-6 jelly layers, 7 dirty.
; No candy sits on a blocker (icing, chocolate, licorice) or a hole:
; board[] = EMPTY, and gravity does not go through them.
; =============================================================================

; A = a cell -> nb[0..3] its four neighbours ($ff = outside). Keeps X, Y.
neighbours
        sta t0
        cmp #COLS
        lda #$ff
        bcc +
        lda t0
        sbc #COLS                       ; (C set)
+       sta nb
        lda t0
        cmp #COLS*(ROWS-1)
        lda #$ff
        bcs +
        lda t0
        adc #COLS                       ; (C clear)
+       sta nb+1
        lda t0
        and #7
        beq +
        lda t0
        sec
        sbc #1
        bcs ++
+       lda #$ff
+       sta nb+2
        lda t0
        and #7
        cmp #7
        beq +
        lda t0
        clc
        adc #1
        bcc ++
+       lda #$ff
+       sta nb+3
        rts

; A = a cell -> Z clear if it is a blocker that breaks (icing, chocolate,
; licorice). Keeps X, Y, t0.
breakable
        sty br_y
        tay
        lda cell,y
        and #7
        ldy br_y
        cmp #C_ICING
        bcc _no
        cmp #C_LICORICE+1
        bcs _no
        lda #1
        rts
_no     lda #0
        rts

br_y    .byte 0

; After RESOLVE: every blocker next to a candy that pops takes damage
; (matched = M_BLOCKER), once a move however many candies pop next to it.
mark_blocker_damage
        ldx #0
_cell   lda matched,x
        and #$ff-M_BLOCKER
        beq _next
        txa
        jsr neighbours
        ldy #3
-       lda nb,y
        cmp #$ff
        beq +
        jsr breakable
        beq +
        stx mb_x
        ldx nb,y
        lda matched,x
        ora #M_BLOCKER
        sta matched,x
        ldx mb_x
+       dey
        bpl -
_next   inx
        cpx #COLS*ROWS
        bcc _cell
        rts

mb_x    .byte 0

; X = a cell that has just cleared, A = its matched[]: a blocker loses a layer,
; or the jelly under a candy that popped loses one (100 points). Keeps X.
apply_damage
        and #M_BLOCKER
        beq _jelly
        lda cell,x
        and #7
        cmp #C_ICING
        bne _gone
        lda cell,x                      ; icing: one layer less
        sec
        sbc #1 << ICING_SHIFT
        sta cell,x
        and #ICING_MASK
        bne _r
        beq _clear
_gone   cmp #C_CHOCOLATE
        bne _clear
        lda #1
        sta choc_broken
_clear  lda cell,x                      ; the blocker has gone: a normal cell
        and #$ff-7-ICING_MASK
        sta cell,x
_r      rts
_jelly  lda cell,x
        and #JELLY_MASK
        beq _r
        lda cell,x
        sec
        sbc #1 << JELLY_SHIFT
        sta cell,x
        stx ad_x
        lda #$00
        ldx #$01
        jsr add_score_chain
        ldx ad_x
        rts

ad_x    .byte 0

; After a move that broke no chocolate: one chocolate eats a candy next to it.
; It starts from a random cell, so it does not always spread the same way.
spread_chocolate
        lda choc_broken
        bne _r
        jsr rand
        and #63
        sta sc_c
        lda #COLS*ROWS
        sta sc_n
_cell   ldx sc_c
        lda cell,x
        and #7
        cmp #C_CHOCOLATE
        bne _next
        txa
        jsr neighbours
        ldy #3
_nb     lda nb,y
        cmp #$ff
        beq _nnb
        tax
        lda board,x
        cmp #EMPTY
        beq _nnb
        cmp #INGREDIENT                 ; the ingredients are not eaten
        bcs _nnb
        jsr blocked
        bne _nnb
        lda #EMPTY                      ; eaten
        sta board,x
        lda cell,x
        and #$ff-7-ICING_MASK
        ora #C_CHOCOLATE
        sta cell,x
        txa
        jmp mark_dirty
_nnb    dey
        bpl _nb
_next   lda sc_c
        clc
        adc #1
        and #63
        sta sc_c
        dec sc_n
        bne _cell
_r      rts

sc_c    .byte 0
sc_n    .byte 0
