; =============================================================================
; menu.asm - the menu and the scores
;
; The title and the candy canes (draw_frame), four plates, the pointer left of
; the chosen one, a row of candies above the foot.
;
;   PLAY       the level cur_level from the start
;   LEVEL NN   fire: "CODE 0000" - left/right a digit, up/down its value,
;              fire accepts, RUN/STOP cancels
;   SOUND ON   fire: music on/off
;   SCORES     the best points and stars of every level
; =============================================================================

MENU_ITEMS      = 4
MENU_ROW0       = 5                     ; the first plate's row
MENU_STEP       = 3
MENU_TILES      = 6                     ; a plate: left, 4 middle, right
MENU_X          = 8                     ; the plate's column
MENU_PLATE_W    = MENU_TILES*4
MENU_PTR_X      = 3                     ; the pointer
MENU_CANDY_ROW  = 17
MENU_CREDIT_ROW = 21
MI_PLAY         = 0
MI_LEVELS       = 1
MI_SOUND        = 2
MI_SCORES       = 3

; the start: every variable (and the progress) 0, and the menu
menu_start
        lda #0
        ldx #G_END-G_START-1
-       sta G_START,x
        dex
        bpl -
        ldx #0
-       sta BOARD,x
        sta ARRAYS,x
        sta BEST,x
        inx
        bne -
        sta cur_level
        sta menu_sel
        lda #1
        sta mus_on
        jsr menu_enter
        lda #VOICE_SUGARBYTE
        jmp say

; from the start or from the game (RUN/STOP): the whole menu screen
menu_enter
        lda #S_MENU
        sta state
        lda #0
        sta anim_k
        sta foot_on
        sta spr_on
        sta VIC_SPR_ENA
        lda #TUNE_MENU
        sta snd_want
        lda #$0b                        ; built with the display off
        sta VIC_CTRL1
        lda #MENU_BG
        sta VIC_BG0
        lda #BLACK
        sta VIC_BORDER
        jsr draw_frame
        lda #0
-       pha
        jsr draw_plate
        pla
        clc
        adc #1
        cmp #MENU_ITEMS
        bcc -
        lda #0                          ; the six colours, over the foot
        sta t3
-       lda t3
        asl a
        asl a
        adc t3                          ; * 5 columns
        adc #6
        sta blk_x
        lda #MENU_CANDY_ROW
        sta blk_y
        lda t3
        jsr draw_candy_at
        inc t3
        lda t3
        cmp #6
        bcc -
        lda #<txt_credit                ; the signatures
        sta ptr
        lda #>txt_credit
        sta ptr+1
        ldx #(40-CREDIT_LEN)/2
        ldy #MENU_CREDIT_ROW*8
        jsr draw_text
        jsr draw_pointer
        lda #1
        sta title_on
        lda #$3b
        sta VIC_CTRL1
        rts

        .enc "hud"
txt_credit
        .text "REVIVE8BIT - 2026 - VASPER"
CREDIT_LEN = * - txt_credit
        .byte $ff
txt_play        .text "PLAY", $ff
txt_level_nn    .text "LEVEL "
txt_code        .text "CODE "
txt_sound_on    .text "SOUND ON", $ff
txt_sound_off   .text "SOUND OFF", $ff
txt_scores      .text "SCORES", $ff
        .enc "none"

; A = item -> A = its plate's row
menu_item_row
        sta t0
        asl a
        adc t0
        adc #MENU_ROW0
        rts

; A = item: its plate and its label
draw_plate
        sta menu_tmp
        jsr menu_item_row
        sta blk_y
        lda #0
        sta dp_t
-       lda dp_t                        ; the tiles
        asl a
        asl a
        adc #MENU_X
        sta blk_x
        ldx #MT_PLATE_M
        lda dp_t
        bne +
        ldx #MT_PLATE_L
+       cmp #MENU_TILES-1
        bne +
        ldx #MT_PLATE_R
+       jsr menu_tile
        inc dp_t
        lda dp_t
        cmp #MENU_TILES
        bcc -
        lda menu_tmp                    ; the label, centred
        jsr menu_label
        ldy #0
-       lda (ptr),y
        cmp #$ff
        beq +
        iny
        bne -
+       sty t0
        lda #MENU_PLATE_W
        sec
        sbc t0
        lsr a
        adc #MENU_X
        tax
        lda menu_tmp
        jsr menu_item_row
        asl a
        asl a
        asl a
        adc #8
        tay
        jmp draw_text

dp_t    .byte 0

; X = tile (MT_*), blk_x/blk_y: 4x3 characters
menu_tile
        txa                             ; * 120 = * 128 - * 8
        asl a
        asl a
        asl a
        sta t0
        txa
        lsr a
        sta src+1
        lda #0
        ror a
        sec
        sbc t0
        sta src
        lda src+1
        sbc #0
        sta src+1
        lda src
        clc
        adc #<menu_gfx
        sta src
        lda src+1
        adc #>menu_gfx
        sta src+1
        lda #4
        sta blk_w
        lda #3
        sta blk_h
        lda #10
        sta blk_rec
        jmp draw_block

; A = item -> ptr = its label (in menu_buf if it changes)
menu_label
        cmp #MI_PLAY
        bne +
        lda #<txt_play
        ldx #>txt_play
        bne _set
+       cmp #MI_SCORES
        bne +
        lda #<txt_scores
        ldx #>txt_scores
        bne _set
+       cmp #MI_SOUND
        bne _levels
        lda #<txt_sound_on
        ldx #>txt_sound_on
        ldy mus_on
        bne _set
        lda #<txt_sound_off
        ldx #>txt_sound_off
_set    sta ptr
        stx ptr+1
        rts
_levels lda state
        cmp #S_CODE
        beq _code
        ldx #5                          ; "LEVEL NN"
-       lda txt_level_nn,x
        sta menu_buf,x
        dex
        bpl -
        ldx #6
        lda cur_level
        clc
        adc #1
        jsr bin2bcd
        jsr put_bcd_digits
        jmp _end
_code   ldx #4                          ; "CODE dddd" - the digit being changed blinks
-       lda txt_code,x
        sta menu_buf,x
        dex
        bpl -
        ldy #0
        ldx #5
-       lda code_dig,y
        clc
        adc #GL_DIGIT
        sta t0
        cpy code_pos
        bne +
        lda anim_k
        and #8
        beq +
        lda #$fe
        sta t0
+       lda t0
        sta menu_buf,x
        inx
        iny
        cpy #4
        bcc -
_end    lda #$ff
        sta menu_buf,x
        lda #<menu_buf
        sta ptr
        lda #>menu_buf
        sta ptr+1
        rts

; A = BCD -> two digits at menu_buf+X, X += 2
put_bcd_digits
        pha
        lsr a
        lsr a
        lsr a
        lsr a
        sta menu_buf,x
        inx
        pla
        and #15
        sta menu_buf,x
        inx
        rts

; the pointer next to the chosen item, in its phase (the stripes "run")
draw_pointer
        lda menu_sel
        jsr menu_item_row
        sta blk_y
        lda #MENU_PTR_X
        sta blk_x
        ldx #MT_POINTER
        lda anim_k
        and #8
        beq +
        inx
+       jmp menu_tile

; A = item: its pointer off
erase_pointer
        jsr menu_item_row
        sta blk_y
        lda #MENU_PTR_X
        sta blk_x
        lda #4
        sta blk_w
        lda #3
        sta blk_h
        jmp blank_block

st_menu
        inc anim_k
        lda anim_k
        and #7
        bne +
        jsr draw_pointer
+       jsr get_dir
        and #J_UP|J_DOWN
        beq _fire
        sta t3
        lda menu_sel
        jsr erase_pointer
        lda t3
        and #J_UP
        beq _down
        dec menu_sel
        bpl _set
        lda #MENU_ITEMS-1
        sta menu_sel
        bne _set
_down   inc menu_sel
        lda menu_sel
        cmp #MENU_ITEMS
        bcc _set
        lda #0
        sta menu_sel
_set    jsr draw_pointer
        lda #SFX_SELECT
        sta sfx_request
_fire   lda joy_edge
        and #J_FIRE
        beq _r
        lda menu_sel
        bne _notplay
        lda anim_k                      ; the time in the menu stirs the seed
        eor frame_counter
        eor seed
        ora #1
        sta seed
        jmp game_new
_notplay
        cmp #MI_LEVELS
        bne +
        jmp start_code
+       cmp #MI_SCORES
        beq scores_enter
        jsr toggle_music                ; SOUND
        lda #MI_SOUND
        jmp draw_plate
_r      rts

; -----------------------------------------------------------------------------
; SCORES: pages of 20 levels in two columns - level, best points, stars.
; Left/right a page, fire / RUN/STOP back to the menu.
; -----------------------------------------------------------------------------
SCORES_ROW0     = 7
SCORES_PER_PAGE = 20
SCORES_PAGES    = (NLEVELS + SCORES_PER_PAGE - 1) / SCORES_PER_PAGE
SCORES_COL_A    = 5
SCORES_COL_B    = 22

scores_enter
        lda #0
        sta scores_pg
        lda #S_SCORES
        sta state
scores_draw
        lda #$0b
        sta VIC_CTRL1
        jsr draw_frame
        ldx #5                          ; "SCORES 1/3"
-       lda txt_scores,x
        sta menu_buf,x
        dex
        bpl -
        lda #$fe
        sta menu_buf+6
        lda scores_pg
        clc
        adc #GL_DIGIT+1
        sta menu_buf+7
        lda #GL_SLASH
        sta menu_buf+8
        lda #GL_DIGIT+SCORES_PAGES
        sta menu_buf+9
        lda #$ff
        sta menu_buf+10
        lda #<menu_buf
        sta ptr
        lda #>menu_buf
        sta ptr+1
        ldx #15
        ldy #5*8
        jsr draw_text
        jsr _first
        sta menu_tmp
_lv     lda menu_tmp                    ; the place on the page, 0-19
        sec
        sbc sd_first
        ldx #SCORES_COL_A
        cmp #10
        bcc +
        sbc #10
        ldx #SCORES_COL_B
+       stx sd_x
        clc
        adc #SCORES_ROW0
        asl a
        asl a
        asl a
        sta sd_l
        lda menu_tmp                    ; "NN"
        clc
        adc #1
        jsr bin2bcd
        ldx sd_x
        ldy sd_l
        jsr draw_bcd1
        inx
        lda menu_tmp                    ; the points
        asl a
        asl a
        clc
        adc #<best
        sta ptr
        lda #>best
        adc #0
        sta ptr+1
        lda sd_l
        sta db_l
        ldy #3
        jsr draw_bcd
        inx
        ldy #3                          ; the stars
        lda (ptr),y
        sta t4
        lda #3
        sta t3
-       lda #GL_STAR_ON
        dec t4
        bpl +
        lda #GL_DASH                    ; (not earned)
+       ldy sd_l
        jsr glyph_at
        inx
        dec t3
        bne -
        lda sd_first                    ; the page's last
        clc
        adc #SCORES_PER_PAGE-1
        cmp menu_tmp
        beq _done
        inc menu_tmp
        lda menu_tmp
        cmp #NLEVELS
        bcc _lv
_done   lda #$3b
        sta VIC_CTRL1
        rts
_first  lda scores_pg                   ; * 20
        asl a
        asl a
        sta t0
        asl a
        asl a
        adc t0
        sta sd_first
        rts

sd_first .byte 0
sd_x    .byte 0
sd_l    .byte 0

st_scores
        lda joy_edge
        and #J_FIRE|J_ESC
        beq +
        jmp menu_enter
+       jsr get_dir
        sta t3
        ldx scores_pg
        lda t3
        and #J_LEFT
        beq +
        cpx #0
        beq +
        dex
+       lda t3
        and #J_RIGHT
        beq +
        cpx #SCORES_PAGES-1
        bcs +
        inx
+       cpx scores_pg
        beq +
        stx scores_pg
        jmp scores_draw
+       rts

; -----------------------------------------------------------------------------
; At a win: the level's points and stars, if they are the best so far
; -----------------------------------------------------------------------------
record_best
        lda cur_level
        asl a
        asl a
        tax
        lda score                       ; BCD, MSB first: byte by byte
        cmp best,x
        bcc _stars
        bne _copy
        lda score+1
        cmp best+1,x
        bcc _stars
        bne _copy
        lda score+2
        cmp best+2,x
        bcc _stars
_copy   lda score
        sta best,x
        lda score+1
        sta best+1,x
        lda score+2
        sta best+2,x
_stars  lda win_n
        cmp best+3,x
        bcc +
        sta best+3,x
+       rts

; the menu's title: every letter takes the next hue, every 8 frames
; (tools/mkgfx64.py: 6 sets of the title's colours)
title_tick
        lda title_on
        beq _r
        lda frame_counter
        and #7
        bne _r
        ldx title_t
        inx
        cpx #6
        bcc +
        ldx #0
+       stx title_t
        lda tc_lo,x
        sta ptr
        lda tc_hi,x
        sta ptr+1
        ldy #159
-       lda (ptr),y
        sta SCREEN,y
        dey
        cpy #$ff
        bne -
        lda ptr
        clc
        adc #160
        sta ptr
        bcc +
        inc ptr+1
+       ldy #159
-       lda (ptr),y
        sta COLOR_RAM,y
        dey
        cpy #$ff
        bne -
_r      rts

tc_lo   .byte <(title_cycle + range(6) * 320)
tc_hi   .byte >(title_cycle + range(6) * 320)
