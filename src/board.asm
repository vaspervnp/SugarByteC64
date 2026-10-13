; =============================================================================
; board.asm - the board's logic: random numbers, matches, gravity
; =============================================================================

; xorshift 16 (7, 9, 8). A = a random byte. Keeps X, Y.
rand
        lda seed+1
        lsr a
        lda seed
        ror a
        eor seed+1
        sta seed+1
        ror a
        eor seed
        sta seed
        eor seed+1
        sta seed+1
        rts

; A = a random colour 0 .. ncolours-1. Keeps X, Y.
rand_colour
-       jsr rand
        and #7
        cmp ncolours
        bcs -
        rts

; A = board[] -> A = the colour it matches with (0-5), or >= 6 if it matches
; nothing (empty, bomb, ingredient). Keeps X, Y.
mcol
        cmp #INGREDIENT
        bcs _no                         ; (bit 5: >= $20)
        and #7
        rts
_no     lda #$ff
        rts

; fills the board with no matches ready and at least one move
fill_board
        ldx #0
_cell   lda board,x                     ; the ingredients stay where they are
        cmp #EMPTY
        beq _free
        cmp #INGREDIENT
        bcs _ok
_free   lda cell,x
        and #7
        beq +
        lda #EMPTY                      ; a hole or a blocker: empty
        bne _ok
+       jsr rand_colour
        sta t0
        txa                             ; two the same on the left?
        and #7
        cmp #2
        bcc _above
        lda board-1,x
        cmp t0
        bne _above
        lda board-2,x
        cmp t0
        beq _cell
_above  cpx #2*COLS                     ; two the same above?
        bcc _ok0
        lda board-COLS,x
        cmp t0
        bne _ok0
        lda board-2*COLS,x
        cmp t0
        beq _cell
_ok0    lda t0
_ok     sta board,x
        inx
        cpx #COLS*ROWS
        bcc _cell
        jsr has_move
        bcc fill_board
        rts

; -----------------------------------------------------------------------------
; Matches
; -----------------------------------------------------------------------------

; Marks in matched[] what pops, plans the specials that are born and fires the
; specials that pop. A = how many runs were found, Z if none.
find_matches
        jsr clear_matched
        lda #1                          ; rows: bit 0
        sta scan_bit
        lda #0
-       pha
        tax
        lda #1
        jsr scan_line
        pla
        clc
        adc #COLS
        cmp #COLS*ROWS
        bcc -
        lda #2                          ; columns: bit 1
        sta scan_bit
        lda #0
-       pha
        tax
        lda #COLS
        jsr scan_line
        pla
        clc
        adc #1
        cmp #COLS
        bcc -
        lda nmatch
        beq +
        jsr plan_specials
        jsr expand_specials
        jsr mark_blocker_damage
        lda nmatch
+       rts

; matched[] = 0, no runs, no specials to be born, no beams
clear_matched
        ldx #COLS*ROWS-1
        lda #0
-       sta matched,x
        dex
        bpl -
        sta nmatch
        sta nruns
        sta nspawn
        sta nbeams
        sta boom
        rts

; X = the first cell, A = the step (1 a row, 8 a column): scans 8 cells
sl_step = t2
sl_col  = t3
sl_len  = t4
scan_line
        sta sl_step
        lda board,x
        jsr mcol
        sta sl_col
        lda #1
        sta sl_len
        ldy #7
_next   txa
        clc
        adc sl_step
        tax
        lda board,x
        jsr mcol
        cmp #6
        bcs _brk
        cmp sl_col
        bne _brk
        inc sl_len
        jmp _loop
_brk    pha
        jsr end_run
        pla
        sta sl_col
        lda #1
        sta sl_len
_loop   dey
        bne _next
        txa                             ; the sentinel: a step past the end
        clc
        adc sl_step
        tax
; sl_len = the length of a run that ends just before cell X, sl_step = step.
; If >= 3, marks it and counts it. Keeps X, Y.
end_run
        lda sl_len
        cmp #3
        bcs +
        rts
+       stx er_x
        sty er_y
        ldy sl_len                      ; mark it
        txa
-       sec
        sbc sl_step
        tax
        lda matched,x
        ora scan_bit
        sta matched,x
        txa
        dey
        bne -
        sta er_first                    ; the run's first cell
        jsr record_run
        inc nmatch
        lda sl_len                      ; points: 3 -> 60, 4 -> 120, 5+ -> 200
        cmp #4
        bcs +
        lda #$60
        ldx #$00
        beq _add
+       bne +
        lda #$20
        ldx #$01
        bne _add
+       lda #$00
        ldx #$02
_add    jsr add_score_chain
        ldx er_x
        ldy er_y
        rts

er_x    .byte 0
er_y    .byte 0
er_first .byte 0

; X:A = points in BCD (X the hundreds, A the units), times the chain
add_score_chain
        sta asc_lo
        stx asc_hi
        lda chain
        bne +
        lda #1
+       tay
        sed
-       clc
        lda score+2
        adc asc_lo
        sta score+2
        lda score+1
        adc asc_hi
        sta score+1
        lda score
        adc #0
        sta score
        dey
        bne -
        cld
        lda #1
        sta hud_dirty
        rts

asc_lo  .byte 0
asc_hi  .byte 0

; -----------------------------------------------------------------------------
; Deadlock: is there a swap that makes a match? C set if there is.
; -----------------------------------------------------------------------------
has_move
        ldx #0
_cell   stx hm_e
        txa
        and #7
        cmp #7
        beq _down
        ldy hm_e
        iny
        jsr try_swap
        bcs _yes
_down   lda hm_e
        cmp #COLS*(ROWS-1)
        bcs _next
        adc #COLS
        tay
        ldx hm_e
        jsr try_swap
        bcs _yes
_next   ldx hm_e
        inx
        cpx #COLS*ROWS
        bcc _cell
        clc
        rts
_yes    lda hm_e                        ; E = hm_e, D = Y (the hint)
        sta hm_a
        sty hm_b
        sec
        rts

hm_e    .byte 0
hm_a    .byte 0                         ; the move found (the hint)
hm_b    .byte 0

; X, Y = two cells next to each other. C set if swapping them makes a match.
; Keeps X, Y; the board stays as it was.
try_swap
        stx ts_e
        sty ts_d
        lda board,x
        sta ts_b
        cmp #EMPTY                      ; empty or a blocker: no swap
        beq _no
        lda board,y
        sta ts_c
        cmp #EMPTY
        beq _no
        lda ts_b                        ; a bomb next to a candy: a move
        cmp #BOMB
        beq _bomb_b
        lda ts_c
        cmp #BOMB
        beq _bomb_c
        lda ts_c                        ; swap
        sta board,x
        lda ts_b
        sta board,y
        lda ts_e
        jsr line_at
        bcs _undo
        lda ts_d
        jsr line_at
_undo   php
        ldx ts_e
        ldy ts_d
        lda ts_b
        sta board,x
        lda ts_c
        sta board,y
        plp
        rts
_bomb_b lda ts_c                        ; ... not next to an ingredient
        jmp +
_bomb_c lda ts_b
+       ldx ts_e
        ldy ts_d
        cmp #INGREDIENT
        bcs _no
        sec
        rts
_no     ldx ts_e
        ldy ts_d
        clc
        rts

ts_e    .byte 0
ts_d    .byte 0
ts_b    .byte 0
ts_c    .byte 0

; A = a cell. C set if its candy is part of a match. Keeps nothing.
line_at
        sta la_e
        tax
        lda board,x
        jsr mcol
        cmp #6
        bcs _no
        sta la_c
        lda #1
        sta la_n
_left   txa
        and #7
        beq _lend
        dex
        lda board,x
        jsr mcol
        cmp la_c
        bne _lend
        inc la_n
        bne _left
_lend   ldx la_e
_right  txa
        and #7
        cmp #7
        beq _rend
        inx
        lda board,x
        jsr mcol
        cmp la_c
        bne _rend
        inc la_n
        bne _right
_rend   lda la_n
        cmp #3
        bcs _yes
        lda #1
        sta la_n
        ldx la_e
_up     cpx #COLS
        bcc _uend
        txa
        sbc #COLS                       ; (C set)
        tax
        lda board,x
        jsr mcol
        cmp la_c
        bne _uend
        inc la_n
        bne _up
_uend   ldx la_e
_dn     cpx #COLS*(ROWS-1)
        bcs _dend
        txa
        adc #COLS                       ; (C clear)
        tax
        lda board,x
        jsr mcol
        cmp la_c
        bne _dend
        inc la_n
        bne _dn
_dend   lda la_n
        cmp #3
        bcs _yes
_no     clc
        rts
_yes    sec
        rts

la_e    .byte 0
la_c    .byte 0
la_n    .byte 0

; -----------------------------------------------------------------------------
; Gravity, a cell at a time. In every column: the lowest gapr that can be
; filled, and the segment above it up to the first blocker (or the top).
; Everything in the segment comes down one place; if the segment starts at the
; top, a new candy drops in. Nothing goes through a blocker.
; -----------------------------------------------------------------------------

; X = a cell -> Z clear if the cell is a blocker or a hole. Keeps X, Y.
blocked
        lda cell,x
        and #7
        rts

; X = a cell -> Z set if it and everything above it in its column are holes.
; Keeps X, Y.
holes_above
        stx ha_x
-       lda cell,x
        and #7
        cmp #C_HOLE
        bne _no
        txa
        sec
        sbc #COLS
        tax
        bcs -
        ldx ha_x
        lda #0
        rts
_no     ldx ha_x
        lda #1
        rts

ha_x    .byte 0

; gapr[x] = the row of the gapr that fills ($ff none), segtop[x] = the first
; row of the segment, spawn[x] = 1 if it fills from the top, nextc[x] = the
; candy that drops in. Z clear if something falls.
fs_any  = t3
fs_d    = t4
fs_e    = t5
fall_scan
        lda #0
        sta fs_any
        sta fs_c
_col    lda #ROWS-1                     ; fs_d = the candidate gapr
        sta fs_d
_try    lda fs_d
        asl a
        asl a
        asl a
        ora fs_c
        tax
        lda board,x
        cmp #EMPTY
        bne _up
        jsr blocked
        bne _up
        lda fs_d
        sta fs_e
_scan   dec fs_e                        ; above: gaps up to the top, or a candy?
        bmi _top
        txa
        sec
        sbc #COLS
        tax
        jsr blocked
        bne _wall                       ; a blocker before a candy: only if holes above it
        lda board,x
        cmp #EMPTY
        beq _scan
        lda #0
        sta fs_sp
_seg    dec fs_e                        ; a candy: where does the segment start?
        bmi _top
        txa
        sec
        sbc #COLS
        tax
        jsr blocked
        beq _seg
        jsr holes_above                 ; only holes above: new ones come in there
        bne _inner
        lda #1
        sta fs_sp
_inner  inc fs_e
        lda fs_e
        jmp _store
_wall   jsr holes_above
        bne _up
        inc fs_e
        lda #1
        sta fs_sp
        lda fs_e
        jmp _store
_top    lda #1
        sta fs_sp
        lda #0
_store  ldx fs_c
        sta segtop,x
        lda fs_sp
        sta spawn,x
        lda #1
        sta fs_any
        lda fs_d
        jmp _gap
_up     dec fs_d
        bpl _try
        lda #$ff
_gap    ldx fs_c
        sta gapr,x
        pha
        jsr rand_colour
        sta nextc,x
        pla
        cmp #$ff                        ; fills from the top? maybe an ingredient
        beq _nofill
        lda spawn,x
        beq _nofill
        jsr try_ingredient
_nofill inc fs_c
        lda fs_c
        cmp #COLS
        bcc _col
        lda fs_any
        rts

fs_c    .byte 0
fs_sp   .byte 0

; Every falling segment comes down one place.
fall_commit
        ldx #0
_col    stx fc_c
        lda gapr,x
        cmp #$ff
        beq _next
        sta fc_row                      ; from the gapr up to the top of the segment
        asl a
        asl a
        asl a
        ora fc_c
        tay                             ; Y = the gapr
_shift  lda fc_row
        cmp segtop,x
        beq _top
        lda board-COLS,y                ; the one above comes down
        sta board,y
        tya
        sec
        sbc #COLS
        tay
        dec fc_row
        jmp _shift
_top    lda #EMPTY                      ; the top of the segment: new or empty
        ldx fc_c
        ldy spawn,x
        beq +
        lda nextc,x
+       pha
        lda fc_row
        asl a
        asl a
        asl a
        ora fc_c
        tay
        pla
        sta board,y
_next   ldx fc_c
        inx
        cpx #COLS
        bcc _col
        rts

fc_c    .byte 0
fc_row  .byte 0

; -----------------------------------------------------------------------------
; The fall's picture: fall_k = 1..FALL_STEPS characters (8 lines) down.
; Every falling column is drawn character by character from the top of its
; segment to its gapr: the cell's background, and over it the candy that is
; there now (each candy is exactly three characters tall: no two share one).
; -----------------------------------------------------------------------------
fd_c    = t3                            ; the column
fall_draw
        lda #0
        sta fd_c
_col    ldx fd_c
        lda gapr,x
        cmp #$ff
        bne +
        jmp _next
+       sta fd_last                     ; the last character row: gapr * 3 + 2
        asl a
        adc fd_last
        adc #2
        sta fd_last
        lda segtop,x
        sta fd_srow                     ; the source row: starts at segtop - 1
        dec fd_srow
        asl a
        adc segtop,x
        sta fd_y                        ; the first character row: segtop * 3
        lda segtop,x
        sta fd_brow                     ; the background's cell row and part
        lda #0
        sta fd_bpart
        lda #3                          ; the candy's part: 3 - fall_k
        sec
        sbc fall_k
        sta fd_part
_row    ; the candy in this character row, and the one a step before: if
        ; both are none the row has not changed
        lda fd_part
        cmp #2
        lda fd_srow
        bcc +
        clc
        adc #1
+       jsr fd_value
        sta fd_prev
        lda fd_srow
        jsr fd_value
        cmp #EMPTY
        bne _have
        cmp fd_prev
        bne _have
        jmp _skip
_have   jsr candy_frame
        bcc +
        lda #$ff
+       sta rc_cf
        lda fd_brow                     ; the background: the cell under this row
        asl a
        asl a
        asl a
        ora fd_c
        tax
        jsr cell_frame
        sta rc_bf
        lda fd_c                        ; three characters
        asl a
        adc fd_c
        sta fd_x
        lda fd_bpart
        asl a
        adc fd_bpart
        sta rc_bp
        lda fd_part
        asl a
        adc fd_part
        sta rc_cp
        ldx fd_x
        ldy fd_y
        jsr set_char
        jsr row_chars
        ; the next character row
_skip   inc fd_part
        lda fd_part
        cmp #3
        bcc +
        lda #0
        sta fd_part
        inc fd_srow
+       inc fd_bpart
        lda fd_bpart
        cmp #3
        bcc +
        lda #0
        sta fd_bpart
        inc fd_brow
+       lda fd_y
        cmp fd_last
        inc fd_y
        bcs _next
        jmp _row
_next   inc fd_c
        lda fd_c
        cmp #COLS
        bcs +
        jmp _col
+       rts

fd_last  .byte 0
fd_prev  .byte 0

; A = a source row of the falling column fd_c (segtop - 1: the new candy)
; -> A = board[] there
fd_value
        ldx fd_c
        cmp segtop,x
        bcc _new                        ; (also the row -1: $ff >= segtop, below)
        cmp #ROWS
        bcs _new
        asl a
        asl a
        asl a
        ora fd_c
        tay
        lda board,y
        rts
_new    lda #EMPTY
        ldy spawn,x
        beq +
        lda nextc,x
+       rts

fd_srow  .byte 0
fd_y     .byte 0
fd_brow  .byte 0
fd_bpart .byte 0
fd_part  .byte 0
fd_x     .byte 0
fd_n     .byte 0

; -----------------------------------------------------------------------------
; The diagonal slide: when nothing falls straight down, a gapr that does not
; fill from above (under a blocker or a hole) takes the candy above-left or
; above-right. One at a time, from the bottom up; then gravity again.
; C set if one was found: slide_s = from, slide_t = to.
; -----------------------------------------------------------------------------
diag_scan
        ldx #COLS*ROWS-1
_cell   lda board,x
        cmp #EMPTY
        bne _next
        jsr blocked
        bne _next
        stx ds_e                        ; the gapr
        txa
        and #7
        beq _right
        txa                             ; above-left
        sec
        sbc #COLS+1
        jsr _src
        bcs _yes
_right  lda ds_e
        and #7
        cmp #7
        beq _back
        lda ds_e                        ; above-right
        sec
        sbc #COLS-1
        jsr _src
        bcs _yes
_back   ldx ds_e
_next   dex
        cpx #COLS
        bcs _cell
        clc
_yes    rts
; A = the source, ds_e = the gapr. C set if the source has something that moves.
_src    tax
        jsr blocked
        bne _no
        lda board,x
        cmp #EMPTY
        beq _no
        stx slide_s
        lda ds_e
        sta slide_t
        sec
        rts
_no     clc
        rts

ds_e    .byte 0

; A = step 1..SLIDE_STEPS: the candy (a sprite) between the two cells
slide_draw
        sta sd_k
        cmp #1
        bne +
        lda slide_s                     ; the first step: off the bitmap, on a sprite
        jsr draw_bg
        ldx slide_s
        lda board,x
        ldx #0
        jsr candy_sprite
        sta spr_on
+       lda slide_s
        jsr cell_spr_xy
        lda sd_k                        ; lines: k * 24 / SLIDE_STEPS = k * 6
        asl a
        adc sd_k
        asl a
        adc t1
        sta t1
        lda sd_k                        ; pixels: k * 6 (hires), to the gapr
        asl a
        adc sd_k
        asl a
        sta t2
        lda slide_t
        sec
        sbc slide_s
        cmp #COLS+1
        lda t0
        bcc +                           ; COLS-1: to the left
        adc t2                          ; (C set: +1)
        sec
        sbc #1
        jmp ++
+       sec
        sbc t2
+       sta t0
        ldx #0
        jmp candy_sprite_at

sd_k    .byte 0

; the candy changes cell: drawn there, the sprite goes
slide_commit
        ldx slide_s
        lda board,x
        pha
        lda #EMPTY
        sta board,x
        ldx slide_t
        pla
        sta board,x
        lda slide_t
        jsr draw_cell
        jmp hide_candy_sprites
