; =============================================================================
; level.asm - the levels, the goals and the stars
;
; The data: src/data/levels.asm, from levels/levels.txt (tools/levels.py).
; =============================================================================

; A = level (from 0): its header into the variables, its cells into cell[].
; The levels have no address table: they are decoded in order up to it.
load_level
        sta ll_n
        inc ll_n
        lda #<levels
        sta ptr
        lda #>levels
        sta ptr+1
-       jsr decode_level
        dec ll_n
        bne -
        lda lv_colours
        sta ncolours
        lda lv_moves
        sta moves
        lda lv_ingr
        sta ingr_left
        jsr bcd2bin
        sta ingr_spawn
        rts

ll_n    .byte 0

; reads a byte at ptr, ptr + 1. Keeps X, Y.
get_byte
        sty gb_y
        ldy #0
        lda (ptr),y
        inc ptr
        bne +
        inc ptr+1
+       ldy gb_y
        ora #0
        rts

gb_y    .byte 0

; ptr = a level (tools/levels.py) -> ptr = the next one
decode_level
        jsr get_byte                    ; flags
        sta dl_flags
        and #3
        sta lv_goal
        lda dl_flags
        lsr a
        lsr a
        and #3
        clc
        adc #4
        sta lv_colours
        jsr get_byte
        sta lv_moves
        lda dl_flags                    ; ingredients only if the goal wants them
        and #2
        beq +
        jsr get_byte
+       sta lv_ingr
        ldx #lv_star1
        jsr _star
        ldx #lv_star2
        jsr _star
        ldx #lv_star3
        jsr _star
        lda #0                          ; the cell of the stream
        sta dl_e
_run    jsr get_byte                    ; kind << 4 | length - 1
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        tax
        lda cell_kinds,x
        sta dl_v
        pla
        and #15
        tax
        inx                             ; X = the length
_put    lda dl_flags                    ; bit 4: mirrored
        and #$10
        beq _plain
        lda dl_e                        ; mirrored: row * 8 + column, and its image
        and #$fc
        asl a
        sta t0
        lda dl_e
        and #3
        ora t0
        tay
        lda dl_v
        sta cell,y
        tya
        eor #7
        tay
        lda dl_v
        sta cell,y
        jmp _inc
_plain  ldy dl_e
        lda dl_v
        sta cell,y
_inc    inc dl_e
        dex
        bne _put
        lda dl_flags
        and #$10
        beq +
        lda dl_e
        asl a
        jmp ++
+       lda dl_e
+       cmp #COLS*ROWS
        bcc _run
        rts
; X = the star's variable: (ptr) * 500 points -> BCD hundreds, MSB first
_star   jsr get_byte
        tay
        lda #0
        sta 0,x
        sta 1,x
        sed
-       clc
        lda 1,x
        adc #5
        sta 1,x
        lda 0,x
        adc #0
        sta 0,x
        dey
        bne -
        cld
        rts

dl_flags .byte 0
dl_e    .byte 0
dl_v    .byte 0

; A = BCD -> A = binary. Keeps X, Y.
bcd2bin
        pha
        and #$f0
        lsr a                           ; tens * 8
        sta t0
        lsr a
        lsr a                           ; tens * 2
        clc
        adc t0
        sta t0
        pla
        and #$0f
        clc
        adc t0
        rts

; A = binary 0-99 -> A = BCD. Keeps X, Y.
bin2bcd
        sty bb_y
        ldy #0
-       cmp #10
        bcc +
        sbc #10
        iny
        bne -
+       sta t0
        tya
        asl a
        asl a
        asl a
        asl a
        ora t0
        ldy bb_y
        rts

bb_y    .byte 0

; -> A = cells with jelly left. Keeps Y.
count_jelly
        ldx #COLS*ROWS-1
        lda #0
        sta t0
-       lda cell,x
        and #JELLY_MASK
        beq +
        inc t0
+       dex
        bpl -
        lda t0
        rts

; X = a points threshold (zero page, BCD hundreds, MSB first) -> C clear if
; the score has not reached it
score_below
        lda score
        cmp 0,x
        bne +
        lda score+1
        cmp 1,x
+       rts                             ; C set: score >= threshold

; -> A = the stars earned so far by the points (0-3)
stars_now
        ldy #0
        ldx #lv_star1
        jsr score_below
        bcc _done
        iny
        ldx #lv_star2
        jsr score_below
        bcc _done
        iny
        ldx #lv_star3
        jsr score_below
        bcc _done
        iny
_done   tya
        rts

; C set if the level's goal is met
goal_met
        lda lv_goal
        cmp #G_ENDLESS
        beq _no
        cmp #G_SCORE
        bne _jelly
        ldx #lv_star1                   ; points
        jmp score_below
_jelly  cmp #G_INGREDIENTS
        beq _ingr
        jsr count_jelly
        bne _no
        lda lv_goal
        cmp #G_JELLY
        beq _yes
_ingr   lda ingr_left
        beq _yes
_no     clc
        rts
_yes    sec
        rts

; The level is over: three stars in the middle of the board, big as many as
; were earned
draw_win_stars
        jsr stars_now
        bne +
        lda #1                          ; the goal is met: at least one
+       sta win_n
        lda #0
        sta dw_i
-       lda dw_i
        clc
        adc #3*COLS+2
        jsr draw_bg
        ldx #OV_STAR+1                  ; the i-th is big if i < stars
        lda dw_i
        cmp win_n
        bcc +
        ldx #OV_STAR
+       lda dw_i
        clc
        adc #3*COLS+2
        jsr draw_overlay
        inc dw_i
        lda dw_i
        cmp #3
        bcc -
        rts

dw_i    .byte 0
