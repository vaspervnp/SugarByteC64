; =============================================================================
; hud.asm - the HUD on the right of the board (columns 24-39), as the CPC's:
; points, moves, the level's code, the goals, LEVEL NN, stars, the progress
; tube. Glyphs are one character (4x8), icons 2x2; text may sit at any line.
; =============================================================================

; text: our glyphs' numbers (tools/mkgfx64.py), $fe a space, $ff the end
        .enc "hud"
        .cdef "AZ", GL_LETTER
        .cdef "09", GL_DIGIT
        .cdef "  ", $fe
        .cdef "::", GL_COLON
        .cdef "//", GL_SLASH
        .cdef "xx", GL_TIMES
        .cdef "--", GL_DASH
        .enc "none"

HUD_SCORE_ROW   = 1                     ; jar + points
HUD_MOVES_ROW   = 4                     ; arrows + moves, lock + code
HUD_TEXT_DY     = 4                     ; text next to a 2x2 icon: 4 lines down
HUD_RULE1_ROW   = 6
HUD_GOAL1_ROW   = 8                     ; the goals (icons; the cherry one row up)
HUD_GOAL2_ROW   = 12
HUD_LEVEL_ROW   = 16
HUD_RULE2_ROW   = 19
HUD_STARS_ROW   = 20
HUD_BAR_ROW     = 22
HUD_BAR_SEG     = 13                    ; pieces of the tube between the caps

HUD_ICON_X      = HUD_X+1
HUD_NUM_X       = HUD_X+4
HUD_CODE_ICON_X = HUD_X+8
HUD_CODE_X      = HUD_X+11
HUD_GOAL_NUM_X  = HUD_X+4

; -----------------------------------------------------------------------------
; Glyphs and text
; -----------------------------------------------------------------------------

; A = glyph, X = column, Y = pixel line (0-199). Keeps X.
glyph_at
        stx ga_x
        sty ga_l
        sta ga_g
        asl a                           ; * 10 (up to 500)
        sta t0
        asl a
        asl a
        sta src
        lda #0
        rol a
        sta src+1
        lda src
        clc
        adc t0
        sta src
        lda src+1
        adc #>glyph_gfx
        sta src+1
        lda src
        clc
        adc #<glyph_gfx
        sta src
        bcc +
        inc src+1
+
        ldy #9
-       lda (src),y
        sta gbuf,y
        dey
        bpl -
        lda ga_l
        lsr a
        lsr a
        lsr a
        tay
        sty ga_row
        jsr set_char
        lda ga_l
        and #7
        sta ga_off
        ldx #0                          ; the upper character: lines off..7
        ldy ga_off
-       lda gbuf,x
        sta (bmp),y
        inx
        iny
        cpy #8
        bne -
        jsr _attr
        lda ga_off
        beq _r
        stx ga_n
        ldx ga_x                        ; the lower one: lines 0..off-1
        ldy ga_row
        iny
        jsr set_char
        ldx ga_n
        ldy #0
-       lda gbuf,x
        sta (bmp),y
        iny
        inx
        cpx #8
        bne -
        jsr _attr
_r      ldx ga_x
        rts
_attr   ldy #0
        lda gbuf+8
        sta (scrp),y
        lda gbuf+9
        sta (colp),y
        rts

ga_x    .byte 0
ga_l    .byte 0
ga_g    .byte 0
ga_row  .byte 0
ga_off  .byte 0
ga_n    .byte 0
gbuf    .fill 10

; ptr = text ($fe space, $ff end), X = column, Y = line. X ends after it.
draw_text
        sty dt_l
        ldy #0
_l      lda (ptr),y
        cmp #$ff
        beq _r
        sty dt_i
        cmp #$fe
        beq +
        ldy dt_l
        jsr glyph_at
+       inx
        ldy dt_i
        iny
        bne _l
_r      rts

dt_l    .byte 0
dt_i    .byte 0

; ptr = BCD bytes, Y = how many, X = column, db_l = line. X ends after them.
draw_bcd
        sty db_n
        ldy #0
_l      sty dt_i
        lda (ptr),y
        lsr a
        lsr a
        lsr a
        lsr a
        ldy db_l
        jsr glyph_at
        inx
        ldy dt_i
        lda (ptr),y
        and #15
        ldy db_l
        jsr glyph_at
        inx
        ldy dt_i
        iny
        cpy db_n
        bne _l
        rts

db_n    .byte 0
db_l    .byte 0

; A = BCD, X = column, Y = line: two digits. X ends after them.
draw_bcd1
        sta d1_v
        lda #<d1_v
        sta ptr
        lda #>d1_v
        sta ptr+1
        sty db_l
        ldy #1
        jmp draw_bcd

d1_v    .byte 0

; A = icon (ICON_*), X = column, Y = row: 2x2 characters
draw_icon
        stx blk_x
        sty blk_y
        sta t0                          ; * 40 (up to 280)
        asl a
        asl a
        adc t0                          ; * 5
        ldx #0
        stx src+1
        asl a
        rol src+1
        asl a
        rol src+1
        asl a
        rol src+1
        clc
        adc #<icon_gfx
        sta src
        lda src+1
        adc #>icon_gfx
        sta src+1
        lda #2
        sta blk_w
        sta blk_h
        lda #10
        sta blk_rec
        jmp draw_block

; -----------------------------------------------------------------------------
; The HUD, once at the start of a level (on a cleared screen)
; -----------------------------------------------------------------------------
hud_init
        ldy #ROWS*3-1                   ; the seam with the board: a grey line
-       ldx #HUD_X
        jsr set_char
        sty t3
        ldy #7
        lda #$c0
-       sta (bmp),y
        dey
        bpl -
        iny
        lda #GREY
        sta (colp),y
        ldy t3
        dey
        bpl --
        lda #ICON_SCORE
        ldx #HUD_ICON_X
        ldy #HUD_SCORE_ROW
        jsr draw_icon
        lda #ICON_MOVES
        ldx #HUD_ICON_X
        ldy #HUD_MOVES_ROW
        jsr draw_icon
        ldy #HUD_RULE1_ROW*8
        jsr hud_rule
        ldy #HUD_RULE2_ROW*8
        jsr hud_rule
        lda #GL_BAR+0                   ; the tube's caps
        ldx #HUD_X+1
        ldy #HUD_BAR_ROW*8
        jsr glyph_at
        lda #GL_BAR+3
        ldx #HUD_X+2+HUD_BAR_SEG
        ldy #HUD_BAR_ROW*8
        jsr glyph_at
        lda cur_level
        jsr hud_show_code
        jsr hud_goals_init
        lda #1
        sta hud_dirty
        ; (on)

; what changes - only when it has changed
hud_update
        lda hud_dirty
        bne +
        rts
+       lda #0
        sta hud_dirty
        lda #<score
        sta ptr
        lda #>score
        sta ptr+1
        lda #HUD_SCORE_ROW*8+HUD_TEXT_DY
        sta db_l
        ldx #HUD_NUM_X
        ldy #3
        jsr draw_bcd
        lda moves
        ldx #HUD_NUM_X
        ldy #HUD_MOVES_ROW*8+HUD_TEXT_DY
        jsr draw_bcd1
        jsr hud_goals_update
        jsr hud_stars
        jmp hud_bar

; Y = line: the candy rule across the HUD
hud_rule
        sty hr_l
        ldx #HUD_X+1
-       lda #GL_RULE
        ldy hr_l
        jsr glyph_at
        inx
        cpx #HUD_X+15
        bcc -
        rts

hr_l    .byte 0

; the three stars: full as many as earned so far
hud_stars
        jsr stars_now
        sta t4
        ldx #HUD_X+2
        lda #3
        sta t3
-       lda #ICON_STAR_ON
        dec t4
        bpl +
        lda #ICON_STAR_OFF
+       stx hs_x
        ldy #HUD_STARS_ROW
        jsr draw_icon
        lda hs_x
        clc
        adc #5
        tax
        dec t3
        bne -
        rts

hs_x    .byte 0

; the progress tube: full at the points of 3 stars
hud_bar
        jsr progress
        sta t4
        ldx #HUD_X+2
-       lda #GL_BAR+2                   ; full
        dec t4
        bpl +
        lda #GL_BAR+1                   ; empty
+       ldy #HUD_BAR_ROW*8
        jsr glyph_at
        inx
        cpx #HUD_X+2+HUD_BAR_SEG
        bcc -
        rts

; -> A = pieces of the tube (0..13): points * 13 / the 3 stars' points
progress
        lda score                       ; the points / 100, binary
        ldx score+1
        jsr bcd4_bin
        sta pg_s
        stx pg_s+1
        lda lv_star3
        ldx lv_star3+1
        jsr bcd4_bin
        sta pg_d
        stx pg_d+1
        lda pg_s                        ; reached: full
        cmp pg_d
        lda pg_s+1
        sbc pg_d+1
        bcc +
        lda #HUD_BAR_SEG
        rts
+       lda #0                          ; pg_m = points * 13
        sta pg_m
        sta pg_m+1
        ldy #13
-       lda pg_m
        clc
        adc pg_s
        sta pg_m
        lda pg_m+1
        adc pg_s+1
        sta pg_m+1
        dey
        bne -
        lda #0                          ; every piece = one more threshold / 13
        sta pg_a
        sta pg_a+1
        ldy #0
-       lda pg_a
        clc
        adc pg_d
        sta pg_a
        lda pg_a+1
        adc pg_d+1
        sta pg_a+1
        lda pg_a                        ; pg_a >= pg_m: done
        cmp pg_m
        lda pg_a+1
        sbc pg_m+1
        bcs +
        iny
        bne -
+       tya
        rts

pg_s    .word 0
pg_d    .word 0
pg_m    .word 0
pg_a    .word 0

; A = BCD hundreds (high), X = BCD (low) -> A (low), X (high) = binary 0..9999
bcd4_bin
        stx b4_lo
        jsr bcd2bin
        sta b4_h                        ; * 100 = * 64 + * 32 + * 4
        lda #0
        sta b4_r+1
        lda b4_h
        asl a
        asl a
        sta b4_r                        ; * 4 (< 256)
        lda b4_h
        ldx #5
        sta b4_t
        lda #0
        sta b4_t+1
-       asl b4_t                        ; * 32
        rol b4_t+1
        dex
        bne -
        lda b4_r
        clc
        adc b4_t
        sta b4_r
        lda b4_r+1
        adc b4_t+1
        sta b4_r+1
        asl b4_t                        ; * 64
        rol b4_t+1
        lda b4_r
        clc
        adc b4_t
        sta b4_r
        lda b4_r+1
        adc b4_t+1
        sta b4_r+1
        lda b4_lo
        jsr bcd2bin
        clc
        adc b4_r
        pha
        lda b4_r+1
        adc #0
        tax
        pla
        rts

b4_lo   .byte 0
b4_h    .byte 0
b4_r    .word 0
b4_t    .word 0

; A = level: the lock and its code
hud_show_code
        jsr level_code
        lda #ICON_LOCK
        ldx #HUD_CODE_ICON_X
        ldy #HUD_MOVES_ROW
        jsr draw_icon
        lda lc_hi
        ldx #HUD_CODE_X
        ldy #HUD_MOVES_ROW*8+HUD_TEXT_DY
        jsr draw_bcd1
        lda lc_lo
        ldy #HUD_MOVES_ROW*8+HUD_TEXT_DY
        jmp draw_bcd1

; -----------------------------------------------------------------------------
; The level's goals: an icon or a candy and "x NN", or the points to reach.
; Under them, "LEVEL NN".
; -----------------------------------------------------------------------------
hud_goals_init
        lda lv_goal
        bne _notscore
        lda #ICON_SCORE                 ; points: the jar and "NNNN00"
        ldx #HUD_ICON_X
        ldy #HUD_GOAL1_ROW
        jsr draw_icon
        lda #<lv_star1
        sta ptr
        lda #>lv_star1
        sta ptr+1
        lda #HUD_GOAL1_ROW*8+HUD_TEXT_DY
        sta db_l
        ldx #HUD_GOAL_NUM_X
        ldy #2
        jsr draw_bcd
        lda #GL_DIGIT
        ldy #HUD_GOAL1_ROW*8+HUD_TEXT_DY
        jsr glyph_at
        inx
        lda #GL_DIGIT
        ldy #HUD_GOAL1_ROW*8+HUD_TEXT_DY
        jsr glyph_at
        jmp _level
_notscore
        cmp #G_ENDLESS
        beq _level
        cmp #G_INGREDIENTS
        beq _ingr
        lda #ICON_JELLY                 ; jelly
        ldx #HUD_ICON_X
        ldy #HUD_GOAL1_ROW
        jsr draw_icon
        ldy #HUD_GOAL1_ROW*8+HUD_TEXT_DY
        jsr hud_times
        lda lv_goal
        cmp #G_BOTH
        bne _level
        ldy #HUD_GOAL2_ROW
        jmp _cherry
_ingr   ldy #HUD_GOAL1_ROW
_cherry sty t3                          ; the ingredients: a cherry
        dey
        sty blk_y
        lda #HUD_ICON_X
        sta blk_x
        lda #INGREDIENT
        jsr draw_candy_at
        lda t3
        asl a
        asl a
        asl a
        adc #HUD_TEXT_DY
        tay
        jsr hud_times
_level  lda #<txt_level                 ; LEVEL NN
        sta ptr
        lda #>txt_level
        sta ptr+1
        ldx #HUD_X+2
        ldy #HUD_LEVEL_ROW*8
        jsr draw_text
        inx
        lda cur_level
        clc
        adc #1
        jsr bin2bcd
        ldy #HUD_LEVEL_ROW*8
        jmp draw_bcd1

        .enc "hud"
txt_level
        .text "LEVEL", $ff
        .enc "none"

; Y = line: the "x" next to a goal's icon
hud_times
        lda #GL_TIMES
        ldx #HUD_GOAL_NUM_X
        jmp glyph_at

hud_goals_update
        lda lv_goal
        beq _r
        cmp #G_ENDLESS
        beq _r
        cmp #G_INGREDIENTS
        beq _ingr
        jsr count_jelly                 ; jelly left
        jsr bin2bcd
        ldx #HUD_GOAL_NUM_X+1
        ldy #HUD_GOAL1_ROW*8+HUD_TEXT_DY
        jsr draw_bcd1
        lda lv_goal
        cmp #G_BOTH
        bne _r
        ldy #HUD_GOAL2_ROW*8+HUD_TEXT_DY
        bne _ingr2
_ingr   ldy #HUD_GOAL1_ROW*8+HUD_TEXT_DY
_ingr2  lda ingr_left
        ldx #HUD_GOAL_NUM_X+1
        jmp draw_bcd1
_r      rts
