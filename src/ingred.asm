; =============================================================================
; ingred.asm - the ingredients: cherry and nut
;
; board[] = INGREDIENT | 0 (cherry) or | 1 (nut). They do not match, do not
; pop from specials, the chocolate does not eat them; they fall with gravity
; and swap like the candies. When they reach the bottom they are collected.
; =============================================================================

; X = a column that fills from the top: maybe an ingredient drops in instead of
; nextc[X]. One on the board at a time; odds 1 / (ingr_odds+1) every fill.
; Keeps X.
try_ingredient
        lda ingr_spawn
        beq _r
        lda ingr_board
        bne _r
        jsr rand
        and ingr_odds
        bne _r
        dec ingr_spawn
        lda #1
        sta ingr_board
        jsr rand
        and #1
        ora #INGREDIENT
        sta nextc,x
_r      rts

; The ingredients on the bottom row, or just above a hole, go: 1,000 points
; each. Z clear if one was collected (there is a gap to fill).
collect_ingredients
        lda #0
        sta ci_n
        ldx #0
_cell   lda board,x
        cmp #EMPTY
        beq _next
        cmp #INGREDIENT
        bcc _next
        cpx #COLS*(ROWS-1)              ; on the bottom, or just above a hole
        bcs _out
        lda cell+COLS,x
        and #7
        cmp #C_HOLE
        bne _next
_out    lda #EMPTY
        sta board,x
        inc ci_n
        dec ingr_board
        sed
        lda ingr_left
        sec
        sbc #1
        sta ingr_left
        cld
        stx ci_x
        lda #$00
        ldx #$10
        jsr add_score_chain             ; (and hud_dirty)
        lda ci_x
        jsr draw_bg
        lda ci_x
        ldx #OV_STAR+1                  ; a star until the fall covers it
        jsr draw_overlay
        ldx ci_x
_next   inx
        cpx #COLS*ROWS
        bcc _cell
        lda ci_n
        beq +
        lda #SFX_COLLECT
        sta sfx_request
        lda #1
+       rts

ci_n    .byte 0
ci_x    .byte 0
