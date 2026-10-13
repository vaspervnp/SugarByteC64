; =============================================================================
; video.asm - the multicolour bitmap: tables, characters, blocks, the cells,
; the list of dirty cells, the sprites, the foot.
;
; Everything is drawn a character (4x8 pixels) at a time from records made by
; tools/mkgfx64.py: opaque records (10 bytes: bitmap[8], screen, colour) are
; copied; masked ones (11 bytes: bitmap[8], screen, keep, colour) go over
; what is there: their pixel pairs 00 let it show through, and only the
; colours they use change (keep: the screen nibbles that stay; colour $ff:
; the colour RAM stays).
; =============================================================================

; --- tables --------------------------------------------------------------------
bm_lo   .byte <(BITMAP + range(25) * 320)
bm_hi   .byte >(BITMAP + range(25) * 320)
sc_lo   .byte <(SCREEN + range(25) * 40)
sc_hi   .byte >(SCREEN + range(25) * 40)
x8_lo   .byte <(range(40) * 8)
x8_hi   .byte >(range(40) * 8)
mul10   .byte range(0, 90, 10)
mul9    .byte range(0, 27*9, 9)
mul11   .byte range(0, 99, 11)

; pixel pairs that are 00 -> 11 (the screen under them stays), others -> 00
mask_tab
        .for b = 0, b < 256, b += 1
        .byte ((b & $c0) == 0 ? $c0 : 0) | ((b & $30) == 0 ? $30 : 0) | ((b & $0c) == 0 ? $0c : 0) | ((b & $03) == 0 ? $03 : 0)
        .endfor

; -----------------------------------------------------------------------------
video_init
        lda #0
        sta VIC_CTRL1                   ; off while it is set up
        sta VIC_SPR_ENA
        sta VIC_BORDER
        lda CIA2_DDRA
        ora #3
        sta CIA2_DDRA
        lda CIA2_PRA                    ; VIC bank 3: $c000-$ffff
        and #$fc
        sta CIA2_PRA
        lda #$08                        ; screen $c000, bitmap $e000
        sta VIC_MEM
        lda #$18                        ; multicolour, 40 columns
        sta VIC_CTRL2
        jsr clear_screen
        lda #$3b                        ; bitmap, on, 25 rows
        sta VIC_CTRL1

        ldx #63                         ; the cursor and the selection
-       lda cursor_spr,x
        sta SPR_BLOCKS + (SPR_CURSOR - $10) * 64,x
        lda cursor_spr+64,x
        sta SPR_BLOCKS + (SPR_SELECT - $10) * 64,x
        dex
        bpl -
        lda #SPR_CANDY_A
        sta SPR_PTRS
        lda #SPR_CANDY_A+1
        sta SPR_PTRS+1
        lda #SPR_CANDY_B
        sta SPR_PTRS+2
        lda #SPR_CANDY_B+1
        sta SPR_PTRS+3
        lda #SPR_CURSOR
        sta SPR_PTRS+4
        lda #SPR_SELECT
        sta SPR_PTRS+5
        lda #%00000101                  ; the candies' main sprites: multicolour
        sta VIC_SPR_MC
        lda #%00110000                  ; cursor, selection: Y-expanded
        sta VIC_SPR_YEXP
        lda #0
        sta VIC_SPR_XEXP
        sta VIC_SPR_PRIO
        sta VIC_SPR_XMSB
        lda #WHITE
        sta VIC_SPR_MC0
        sta VIC_SPR_COL+4
        lda #GREY
        sta VIC_SPR_MC1
        lda #CYAN
        sta VIC_SPR_COL+5
        rts

; the whole screen: bitmap 0, colours 0 (everything shows $d021)
clear_screen
        lda #<BITMAP
        sta ptr
        lda #>BITMAP
        sta ptr+1
        lda #0
        ldx #31                         ; 31 pages ...
        ldy #0
-       sta (ptr),y
        iny
        bne -
        inc ptr+1
        dex
        bne -
-       sta (ptr),y                     ; ... and $ff00-$ff3f
        iny
        cpy #$40
        bne -
        ldx #0
-       sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$2e8,x
        sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        sta COLOR_RAM+$200,x
        sta COLOR_RAM+$2e8,x
        inx
        bne -
        rts

; ptr = RLE runs (count, byte; count 0 ends), ptr2 = destination
unrle
        ldy #0
_run    lda (ptr),y
        beq _end
        tax
        iny
        lda (ptr),y
        ldy #0
-       sta (ptr2),y
        inc ptr2
        bne +
        inc ptr2+1
+       dex
        bne -
        lda ptr
        clc
        adc #2
        sta ptr
        bcc _run
        inc ptr+1
        bne _run                        ; (always)
_end    rts

; the menu's frame: title, candy canes, foot
draw_frame
        lda #<frame_bm
        sta ptr
        lda #>frame_bm
        sta ptr+1
        lda #<BITMAP
        sta ptr2
        lda #>BITMAP
        sta ptr2+1
        jsr unrle
        lda #<frame_scr
        sta ptr
        lda #>frame_scr
        sta ptr+1
        lda #<SCREEN
        sta ptr2
        lda #>SCREEN
        sta ptr2+1
        jsr unrle
        lda #<frame_col
        sta ptr
        lda #>frame_col
        sta ptr+1
        lda #<COLOR_RAM
        sta ptr2
        lda #>COLOR_RAM
        sta ptr2+1
        jmp unrle

; -----------------------------------------------------------------------------
; Characters
; -----------------------------------------------------------------------------

; X = column, Y = row -> bmp, scrp, colp. Keeps X, Y.
set_char
        lda bm_lo,y
        clc
        adc x8_lo,x
        sta bmp
        lda bm_hi,y
        adc x8_hi,x
        sta bmp+1
        txa
        clc
        adc sc_lo,y
        sta scrp
        sta colp
        lda sc_hi,y
        adc #0
        sta scrp+1
        adc #>(COLOR_RAM - SCREEN)
        sta colp+1
        rts

; the opaque record at src -> the character
put_opaque
        ldy #7
-       lda (src),y
        sta (bmp),y
        dey
        bpl -
        ldy #8
        lda (src),y
        ldy #0
        sta (scrp),y
        ldy #9
        lda (src),y
        ldy #0
        sta (colp),y
        rts

; the masked record at src -> over the character
put_masked
        ldy #7
_px     lda (src),y
        beq _next
        tax
        lda (bmp),y
        and mask_tab,x
        sta t5
        txa
        ora t5
        sta (bmp),y
_next   dey
        bpl _px
        ldy #9
        lda (src),y                     ; keep
        cmp #$ff
        beq _col
        ldy #0
        and (scrp),y
        ldy #8
        ora (src),y
        ldy #0
        sta (scrp),y
_col    ldy #10
        lda (src),y
        cmp #$ff
        beq +
        ldy #0
        sta (colp),y
+       rts

; the character: bitmap 0, colours 0 ($d021 everywhere)
put_blank
        lda #0
        ldy #7
-       sta (bmp),y
        dey
        bpl -
        iny
        sta (scrp),y
        sta (colp),y
        rts

; src = records (blk_rec bytes each, row by row), blk_x/blk_y = the first
; character, blk_w x blk_h characters
draw_block
        lda blk_y
        sta by
        lda blk_h
        sta bh
_row    lda blk_x
        sta bx
        lda blk_w
        sta bw
_ch     ldx bx
        ldy by
        jsr set_char
        lda blk_rec
        cmp #11
        beq +
        jsr put_opaque
        jmp _adv
+       jsr put_masked
_adv    lda src
        clc
        adc blk_rec
        sta src
        bcc +
        inc src+1
+       inc bx
        dec bw
        bne _ch
        inc by
        dec bh
        bne _row
        rts

; blank characters: blk_x/blk_y, blk_w x blk_h
blank_block
        lda blk_y
        sta by
        lda blk_h
        sta bh
_row    lda blk_x
        sta bx
        lda blk_w
        sta bw
-       ldx bx
        ldy by
        jsr set_char
        jsr put_blank
        inc bx
        dec bw
        bne -
        inc by
        dec bh
        bne _row
        rts

; -----------------------------------------------------------------------------
; The cells: 3x3 characters each
; -----------------------------------------------------------------------------

; A = cell -> blk_x, blk_y = its first character, a 3x3 block. Keeps X.
cell_pos
        pha
        and #7
        sta t0
        asl a
        adc t0
        sta blk_x
        pla
        pha
        lsr a
        lsr a
        lsr a
        sta t0
        asl a
        adc t0
        sta blk_y
        lda #3
        sta blk_w
        sta blk_h
        pla
        rts

; X = cell -> A = its frame of cells_gfx. Keeps X.
cell_frame
        lda cell,x
        and #7
        bne _special
        lda cell,x
        and #JELLY_MASK
        beq _plain
        cmp #2 << JELLY_SHIFT
        lda #CELLS_JELLY
        bcc +
        lda #CELLS_JELLY+1
+       rts
_plain  txa                             ; a chequerboard: (cx ^ cy) & 1
        lsr a
        lsr a
        lsr a
        sta t0
        txa
        eor t0
        and #1
        rts
_special
        cmp #C_HOLE
        bne +
        lda #CELLS_BOARD+2
        rts
+       cmp #C_ICING
        bne _blocker
        lda cell,x                      ; icing: 3 layers -> icing3 (the first) ...
        lsr a
        lsr a
        lsr a
        and #3
        eor #$ff
        sec
        adc #CELLS_ICING+3
        rts
_blocker
        sec                             ; 0 chocolate, 1 licorice
        sbc #C_CHOCOLATE
        clc
        adc #CELLS_BLOCKER
        rts

; A = board[] -> A = its frame of candy_gfx; C set: nothing to draw
candy_frame
        cmp #EMPTY
        beq _none
        sta t1
        and #INGREDIENT
        bne _ingr
        lda t1
        and #7
        cmp #BOMB
        beq _bomb
        sta t2                          ; colour
        lda t1
        lsr a
        lsr a
        lsr a
        and #3                          ; form
        sta t1
        asl a
        adc t1
        asl a                           ; form * 6
        adc t2
        clc
        rts
_bomb   lda #CANDY_BOMB
        clc
        rts
_ingr   lda t1
        and #1
        clc
        adc #CANDY_INGREDIENT
        rts
_none   sec
        rts

; A = cell: its background (opaque)
draw_bg
        jsr cell_pos
        tax
        jsr cell_frame
        sta rc_bf
        lda #$ff
        sta rc_cf
        jmp cell_chars

; A = cell: background and candy, a character at a time in one pass
draw_cell
        jsr cell_pos
        tax
        jsr cell_frame
        sta rc_bf
        lda board,x
        jsr candy_frame
        bcc +
        lda #$ff
+       sta rc_cf
; the 3x3 characters at blk_x/blk_y: rc_bf's background, rc_cf's candy
cell_chars
        lda #0
        sta rc_bp
        sta rc_cp
        lda blk_y
        sta by
-       ldx blk_x
        ldy by
        jsr set_char
        jsr row_chars
        lda rc_bp
        clc
        adc #3
        sta rc_bp
        sta rc_cp
        cmp #9
        bcs +
        inc by
        bne -                           ; (always)
+       rts

; bmp, scrp, colp -> the character on the right. Keeps X, Y.
next_char
        lda bmp
        clc
        adc #8
        sta bmp
        bcc +
        inc bmp+1
+       inc scrp
        inc colp
        bne +
        inc scrp+1
        inc colp+1
+       rts

; Three characters from bmp/scrp/colp on: a row of a cell, the background
; rc_bf (its parts rc_bp..+2) with the candy rc_cf ($ff: none; its parts
; rc_cp..+2) over it.
row_chars
        ldx rc_bf
        ldy rc_bp
        lda cells_lo,x
        clc
        adc mul10,y
        sta src
        lda cells_hi,x
        adc #0
        sta src+1
        lda mul9,x
        adc rc_bp                       ; (C clear)
        sta rc_bz                       ; the index of its "empty" flags
        lda #3
        sta rc_n
        ldx rc_cf
        bpl +
        ; no candy: the background alone
-       jsr put_opaque
        dec rc_n
        beq _r
        jsr next_char
        lda src
        clc
        adc #10
        sta src
        bcc -
        inc src+1
        bcs -                           ; (always)
_r      rts
+       ldy rc_cp
        lda candy_lo,x
        clc
        adc mul11,y
        sta ptr2
        lda candy_hi,x
        adc #0
        sta ptr2+1
        lda mul9,x
        adc rc_cp
        sta rc_cz
        lda rc_bf                       ; a plain cell: its grid lines are never
        cmp #CELLS_BOARD+2              ; under a candy's pixels, OR is enough
        lda #0
        rol a
        sta rc_mask
_ch     ldx rc_cz
        lda candy_z,x
        beq +
        jsr put_opaque                  ; nothing of the candy here
        jmp _next
+       ldx rc_bz
        lda cells_z,x
        beq +
        jsr put_candy                   ; nothing of the background here
        jmp _next
+       lda rc_mask
        bne +
        .for i = 7, i >= 0, i -= 1
        ldy #i
        lda (src),y
        ora (ptr2),y
        sta (bmp),y
        .endfor
        jmp _attr
+       .for i = 7, i >= 0, i -= 1
        ldy #i
        lda (ptr2),y
        tax
        lda (src),y
        and mask_tab,x
        ora (ptr2),y
        sta (bmp),y
        .endfor
_attr   ldy #9                          ; the screen: the background's nibbles that stay
        lda (ptr2),y
        ldy #8
        and (src),y
        ora (ptr2),y
        ldy #0
        sta (scrp),y
        ldy #10                         ; the colour RAM: the candy's, if it uses it
        lda (ptr2),y
        cmp #$ff
        bne +
        ldy #9
        lda (src),y
+       ldy #0
        sta (colp),y
_next   dec rc_n
        beq _done
        jsr next_char
        inc rc_bz
        inc rc_cz
        lda src
        clc
        adc #10
        sta src
        bcc +
        inc src+1
+       lda ptr2
        clc
        adc #11
        sta ptr2
        bcc _ch
        inc ptr2+1
        bcs _ch                         ; (always)
_done   rts

; the candy record at ptr2 alone (the background under it is empty)
put_candy
        .for i = 7, i >= 0, i -= 1
        ldy #i
        lda (ptr2),y
        sta (bmp),y
        .endfor
        ldy #8
        lda (ptr2),y
        ldy #0
        sta (scrp),y
        ldy #10
        lda (ptr2),y
        ldy #0
        sta (colp),y
        rts

rc_bf   .byte 0
rc_bp   .byte 0
rc_cf   .byte 0
rc_cp   .byte 0
rc_bz   .byte 0
rc_cz   .byte 0
rc_n    .byte 0
rc_mask .byte 0

; A = cell: its candy, over what is there
draw_candy_cell
        jsr cell_pos
        tax
        lda board,x
; A = board[], blk_x/blk_y set: the candy there
draw_candy_at
        jsr candy_frame
        bcs +
        tay
        lda candy_lo,y
        sta src
        lda candy_hi,y
        sta src+1
        lda #11
        sta blk_rec
        lda #3
        sta blk_w
        sta blk_h
        jmp draw_block
+       rts

; A = cell, X = frame of overlay_gfx: over the cell
draw_overlay
        jsr cell_pos
        lda overlay_lo,x
        sta src
        lda overlay_hi,x
        sta src+1
        lda #11
        sta blk_rec
        jmp draw_block

; the whole board (about a second: only at the start)
draw_board_all
        lda #0
-       pha
        jsr draw_cell
        pla
        clc
        adc #1
        cmp #COLS*ROWS
        bcc -
        rts

; -----------------------------------------------------------------------------
; The list of dirty cells: drawn DRAW_BUDGET a frame
; -----------------------------------------------------------------------------

; A = cell: to be drawn again. Keeps A, X, Y.
mark_dirty
        stx t3
        tax
        lda cell,x
        bmi _already
        ora #DIRTY
        sta cell,x
        txa
        ldx dq_tail
        sta dirty_q,x
        inx
        txa
        and #63
        sta dq_tail
        inc dq_n
        lda dirty_q-1,x                 ; (A back: the cell)
        ldx t3
        rts
_already
        txa
        ldx t3
        rts

render_dirty
        lda #DRAW_BUDGET
        sta t4
-       lda dq_n
        beq _done
        dec dq_n
        ldx dq_head
        lda dirty_q,x
        inx
        txa
        and #63
        sta dq_head
        lda dirty_q-1,x
        tax
        lda cell,x
        and #$ff-DIRTY
        sta cell,x
        txa
        jsr draw_cell
        dec t4
        bne -
_done   rts

; empties the list without drawing (after the whole board)
clear_dirty
        lda #0
        sta dq_n
        sta dq_head
        sta dq_tail
        ldx #COLS*ROWS-1
-       lda cell,x
        and #$ff-DIRTY
        sta cell,x
        dex
        bpl -
        rts

; -----------------------------------------------------------------------------
; Sprites: the candies that move (swap, hint, slide), the cursor, the selection
; -----------------------------------------------------------------------------

; A = cell -> t0 = sprite X, t1 = sprite Y of its top left corner
cell_spr_xy
        pha
        and #7
        sta t0
        asl a
        adc t0                          ; * 3
        asl a
        asl a
        asl a                           ; * 24
        adc #24
        sta t0
        pla
        pha
        and #$38                        ; row * 8
        sta t1
        asl a
        adc t1                          ; row * 24
        adc #50
        sta t1
        pla
        rts

; X = 0 (candy A) / 1 (candy B), A = board[]: its sprites' picture and
; colours. A = 0: nothing to show (empty), 1: shown. Keeps X.
candy_sprite
        stx t2
        jsr candy_frame
        bcc +
        lda #0
        ldx t2
        rts
+       tay
        lda candy_spr_main,y
        pha
        lda candy_spr_shade,y
        pha
        tya                             ; candy_spr + frame * 128
        lsr a
        sta ptr+1
        lda #0
        ror a
        clc
        adc #<candy_spr
        sta ptr
        lda ptr+1
        adc #>candy_spr
        sta ptr+1
        lda #<SPR_BLOCKS                ; block A ($c400) or B ($c480)
        ldx t2
        beq +
        lda #<(SPR_BLOCKS+$80)
+       sta ptr2
        lda #>SPR_BLOCKS
        sta ptr2+1
        ldy #127
-       lda (ptr),y
        sta (ptr2),y
        dey
        bpl -
        lda t2
        asl a
        tax
        pla
        sta VIC_SPR_COL+1,x             ; the shade
        pla
        sta VIC_SPR_COL,x               ; the main one
        ldx t2
        lda #1
        rts

; X = 0 / 1: candy A / B's sprites at t0 (X), t1 (Y + 1: the candy's line 1)
candy_sprite_at
        txa
        asl a
        asl a
        tay                             ; Y = 4 * n: sprite 2n's registers
        lda t0
        sta VIC_SPR_X,y
        sta VIC_SPR_X+2,y
        ldx t1
        inx
        txa
        sta VIC_SPR_Y,y
        sta VIC_SPR_Y+2,y
        tya
        lsr a
        lsr a
        tax
        rts

hide_candy_sprites
        lda #0
        sta spr_on
        rts

; every frame: what is shown
update_sprites
        lda #0
        sta t3
        lda spr_on
        lsr a
        bcc +
        lda #%0011
        sta t3
+       lda spr_on
        and #2
        beq +
        lda t3
        ora #%1100
        sta t3
+       lda state
        bne _set                        ; the cursor and the selection: IDLE only
        lda blink_t
        and #16
        bne _sel
        lda cursor
        jsr cell_spr_xy
        lda t0
        sta VIC_SPR_X+8
        lda t1
        sta VIC_SPR_Y+8
        lda t3
        ora #%010000
        sta t3
_sel    lda sel
        cmp #$ff
        beq _set
        jsr cell_spr_xy
        lda t0
        sta VIC_SPR_X+10
        lda t1
        sta VIC_SPR_Y+10
        lda t3
        ora #%100000
        sta t3
_set    lda t3
        sta VIC_SPR_ENA
        rts

; -----------------------------------------------------------------------------
; The game's foot: a candy cane whose stripes run (every 4 frames)
; -----------------------------------------------------------------------------
foot_tick
        lda foot_on
        beq +
        lda frame_counter
        and #3
        beq ++
+       rts
+
        inc foot_phase
foot_draw
        lda foot_phase
        and #3
        tax
        lda mul10,x
        clc
        adc #<foot_gfx
        sta src
        lda #0
        adc #>foot_gfx
        sta src+1
        ldx #0
-       ldy #FOOT_ROW
        stx bx
        jsr set_char
        jsr put_opaque
        ldx bx
        inx
        cpx #40
        bne -
        rts
