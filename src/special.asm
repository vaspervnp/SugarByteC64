; =============================================================================
; special.asm - the special candies: how they are born, what they do
; =============================================================================

; er_first = the first cell, sl_len = the length, sl_step = the step: into
; runs[]. Keeps X, Y.
record_run
        lda nruns
        cmp #MAX_RUNS
        bcs _full
        stx rr_x
        inc nruns
        asl a
        adc nruns                       ; (nruns - 1) * 3: 2 * old + new = 3 * old + 1
        tax
        lda er_first
        sta runs-1,x
        lda sl_len
        sta runs,x
        lda sl_step
        sta runs+1,x
        ldx rr_x
_full   rts

rr_x    .byte 0

; A = a cell, as_v = board[] of the special to be born there after CLEAR.
; Keeps X, Y.
add_spawn
        stx asp_x
        pha
        lda nspawn
        cmp #MAX_SPAWN
        bcs _full
        inc nspawn
        asl a
        tax
        pla
        sta spawns,x
        lda as_v
        sta spawns+1,x
        ldx asp_x
        rts
_full   pla
        ldx asp_x
        rts

as_v    .byte 0
asp_x   .byte 0

; -----------------------------------------------------------------------------
; What is born: 5 in a row -> a bomb, L or T -> wrapped, 4 -> striped along
; the match. In this order: a cell that has given a special gives no other.
; -----------------------------------------------------------------------------
plan_specials
        lda nruns
        bne +
        rts
+       ldx #0                          ; X = runs offset
_five   lda runs+1,x
        cmp #5
        bcc _n5
        stx ps_ix
        jsr run_consume
        jsr run_pick
        ldx #BOMB
        stx as_v
        jsr add_spawn
        ldx ps_ix
_n5     inx
        inx
        inx
        jsr runs_done
        bcc _five

        ldx #0                          ; cells in a row AND a column
_cross  lda matched,x
        and #7
        cmp #3
        bne _ncross
        lda matched,x
        ora #4
        sta matched,x
        lda board,x
        jsr mcol
        ora #F_WRAPPED
        sta as_v
        txa
        jsr add_spawn
_ncross inx
        cpx #COLS*ROWS
        bcc _cross

        ldx #0
_four   lda runs+1,x
        cmp #4
        bne _n4
        stx ps_ix
        jsr run_clean
        bne _skip4
        jsr run_pick
        pha
        ldx ps_ix
        ldy runs,x
        lda board,y
        jsr mcol
        sta as_v
        lda runs+2,x                    ; a row's run: striped across
        cmp #1
        bne +
        lda #F_STRIPED_H
        bne ++
+       lda #F_STRIPED_V
+       ora as_v
        sta as_v
        pla
        jsr add_spawn
_skip4  ldx ps_ix
_n4     inx
        inx
        inx
        jsr runs_done
        bcc _four
        rts

ps_ix   .byte 0

; X = an offset into runs[] -> C set if it is past the last run. Keeps X.
runs_done
        stx t0
        lda nruns
        asl a
        adc nruns
        cmp t0
        beq +
        bcc +
        clc
        rts
+       sec
        rts

; X = runs offset: its cells are marked "taken" (bit 2). Keeps X.
run_consume
        stx rc_x
        lda runs+1,x
        sta t0
        lda runs+2,x
        sta t1
        lda runs,x
-       tay
        lda matched,y
        ora #4
        sta matched,y
        tya
        clc
        adc t1
        dec t0
        bne -
        ldx rc_x
        rts

rc_x    .byte 0

; X = runs offset -> Z clear if one of its cells is taken or a crossing. Keeps X.
run_clean
        stx rc_x
        lda runs+1,x
        sta t0
        lda runs+2,x
        sta t1
        lda runs,x
-       tay
        lda matched,y
        and #4
        bne _no
        lda matched,y
        and #3
        cmp #3
        beq _cross
        tya
        clc
        adc t1
        dec t0
        bne -
        ldx rc_x
        lda #0
        rts
_cross  lda #1
_no     ldx rc_x
        rts

; X = runs offset -> A = the cell where the special is born: where the
; player's candy went, if the run came from a swap; the middle otherwise.
; Keeps X.
run_pick
        stx rc_x
        lda chain
        cmp #1
        bne _mid
        lda runs+1,x
        sta t0
        lda runs+2,x
        sta t1
        lda runs,x
-       cmp swap_b
        beq _got
        cmp swap_a
        beq _got
        clc
        adc t1
        dec t0
        bne -
_mid    lda runs+1,x                    ; first + (length / 2) * step
        lsr a
        sta t0
        lda runs,x
-       clc
        adc runs+2,x
        dec t0
        bne -
_got    ldx rc_x
        rts

; -----------------------------------------------------------------------------
; The specials that pop go off, and those they hit too, until none is left.
; -----------------------------------------------------------------------------
expand_specials
_pass   lda #0
        sta sp_changed
        ldx #0
_cell   lda matched,x
        beq _next
        bmi _next                       ; already fired
        lda board,x
        jsr special_kind
        beq _next
        pha
        lda matched,x
        ora #$80
        sta matched,x
        sta sp_changed
        pla
        stx es_x
        jsr fire_special
        ldx es_x
_next   inx
        cpx #COLS*ROWS
        bcc _cell
        lda sp_changed
        bne _pass
        rts

es_x    .byte 0

; A = board[] -> A = 1 striped across, 2 striped down, 3 wrapped, 4 bomb,
; 0 and Z if not special. Keeps X, Y.
special_kind
        cmp #INGREDIENT
        bcs _none
        cmp #BOMB
        beq _bomb
        and #3 << FORM_SHIFT
        lsr a
        lsr a
        lsr a
        rts
_bomb   lda #4
        rts
_none   lda #0
        rts

; A = the kind (special_kind), X = the cell
fire_special
        cmp #1
        beq _row
        cmp #2
        beq _col
        cmp #3
        beq _wrap
        jsr rand_colour                 ; a bomb hit by another: a random colour
        jmp mark_colour
_row    txa
        lsr a
        lsr a
        lsr a
        jmp hit_row
_col    txa
        and #7
        jmp hit_col
_wrap   stx ha_c
        lda #1
        jmp hit_area

; A = a row (>= 8: nothing): hits the whole row
hit_row
        cmp #ROWS
        bcs _r
        jsr add_beam
        asl a
        asl a
        asl a
        ldy #COLS
-       pha
        jsr hit_cell
        pla
        clc
        adc #1
        dey
        bne -
_r      rts

; A = a column (>= 8: nothing): hits the whole column
hit_col
        cmp #COLS
        bcs _r
        pha
        ora #$80
        jsr add_beam
        pla
        ldy #ROWS
-       pha
        jsr hit_cell
        pla
        clc
        adc #COLS
        dey
        bne -
_r      rts

; ha_c = the centre, A = the radius: hits the square (2A+1)^2, cut by the board
hit_area
        sta ha_r
        lda #1
        sta boom
        lda ha_c
        and #7
        sec
        sbc ha_r
        sta ha_x0                       ; the first column (may be < 0)
        lda ha_c
        lsr a
        lsr a
        lsr a
        sec
        sbc ha_r
        sta ha_y                        ; the first row (may be < 0)
        lda ha_r
        asl a
        adc #1
        sta ha_side
        sta ha_ny
_wy     lda ha_y
        cmp #ROWS                       ; (< 0 is >= 8 unsigned)
        bcs _ny
        lda ha_side
        sta ha_nx
        lda ha_x0
_wx     cmp #COLS
        bcs _nx
        pha
        lda ha_y
        asl a
        asl a
        asl a
        sta t0
        pla
        pha
        ora t0
        jsr hit_cell
        pla
_nx     clc
        adc #1
        dec ha_nx
        bne _wx
_ny     inc ha_y
        dec ha_ny
        bne _wy
        rts

ha_c    .byte 0
ha_r    .byte 0
ha_x0   .byte 0
ha_y    .byte 0
ha_side .byte 0
ha_nx   .byte 0
ha_ny   .byte 0

; A = a colour: every candy of that colour is hit
mark_colour
        sta mc_col
        ldx #0
-       lda board,x
        jsr mcol
        cmp mc_col
        bne +
        txa
        jsr hit_cell
+       inx
        cpx #COLS*ROWS
        bcc -
        rts

mc_col  .byte 0

; A = a cell hit by a special: it pops too, 60 points. Keeps X, Y.
hit_cell
        stx hc_x
        sty hc_y
        tax
        lda board,x
        cmp #EMPTY
        beq _blocker
        cmp #INGREDIENT                 ; the ingredients do not pop
        bcs _out
        lda matched,x
        bne _out
        lda #8
        sta matched,x
        lda #$60
        ldx #0
        jsr add_score_chain
_out    ldx hc_x
        ldy hc_y
        rts
_blocker                                ; a blocker: it takes damage
        txa
        jsr breakable
        beq _out
        lda matched,x
        ora #M_BLOCKER
        sta matched,x
        jmp _out

hc_x    .byte 0
hc_y    .byte 0

; -----------------------------------------------------------------------------
; After the swap: if a bomb took part, or two specials, the combination.
; C set if something happened, with matched[] ready.
;
;   bomb + plain            every candy of that colour
;   bomb + striped/wrapped  every one of that colour turns striped/wrapped, pops
;   bomb + bomb             the whole board
;   striped + striped       a row and a column
;   striped + wrapped       a cross 3 thick
;   wrapped + wrapped       5x5
; -----------------------------------------------------------------------------
combo_swap
        ldx swap_a
        lda board,x
        sta cs_b
        ldx swap_b
        lda board,x
        sta cs_c
        lda cs_b
        cmp #BOMB
        beq _bomb_a
        lda cs_c
        cmp #BOMB
        beq _bomb_b
        lda cs_b                        ; two striped / wrapped?
        jsr special_kind
        bne +
        clc
        rts
+       sta cs_d
        lda cs_c
        jsr special_kind
        bne +
        clc
        rts
+       sta cs_e                        ; cs_d, cs_e = the two kinds (1-3)
        jsr clear_matched
        jsr fire_both                   ; the two pop, without their own effect
        lda swap_b                      ; the centre: where the player's candy went
        sta ha_c
        lda cs_d
        cmp #3
        bne _not_ww
        lda cs_e
        cmp #3
        bne _cross
        lda #2                          ; wrapped + wrapped
        jsr hit_area
        jmp _done
_not_ww lda cs_e
        cmp #3
        beq _cross
        lda ha_c                        ; striped + striped
        lsr a
        lsr a
        lsr a
        jsr hit_row
        lda ha_c
        and #7
        jsr hit_col
        jmp _done
_cross  lda ha_c                        ; striped + wrapped: 3 rows, 3 columns
        lsr a
        lsr a
        lsr a
        sec
        sbc #1
        sta cs_i
        lda #3
        sta cs_n
-       lda cs_i
        jsr hit_row
        inc cs_i
        dec cs_n
        bne -
        lda ha_c
        and #7
        sec
        sbc #1
        sta cs_i
        lda #3
        sta cs_n
-       lda cs_i
        jsr hit_col
        inc cs_i
        dec cs_n
        bne -
        jmp _done

_bomb_b lda swap_b
        sta cs_e
        lda cs_b
        jmp _bomb
_bomb_a lda swap_a
        sta cs_e
        lda cs_c
_bomb   sta cs_d                        ; cs_d = the other, cs_e = the bomb's cell
        cmp #BOMB
        beq _ok
        jsr mcol
        cmp #6
        bcc _ok
        clc                             ; a bomb with an ingredient: nothing
        rts
_ok     jsr clear_matched
        ldx cs_e
        lda #$81                        ; the bomb itself: pops, already fired
        sta matched,x
        inc nmatch
        lda cs_d
        cmp #BOMB
        beq _all
        jsr special_kind
        sta cs_k                        ; the other's kind (0 plain)
        lda cs_d
        jsr mcol
        sta cs_col
        lda cs_k
        beq +
        jsr convert_colour
+       lda cs_col
        jsr mark_colour
        jmp _done
_all    ldx #0
-       txa
        jsr hit_cell
        inx
        cpx #COLS*ROWS
        bcc -
_done   jsr expand_specials
        jsr mark_blocker_damage
        sec
        rts

cs_b    .byte 0
cs_c    .byte 0
cs_d    .byte 0
cs_e    .byte 0
cs_i    .byte 0
cs_n    .byte 0
cs_k    .byte 0
cs_col  .byte 0

; the two cells of the swap: they pop, marked as fired
fire_both
        lda #$81
        ldx swap_a
        sta matched,x
        ldx swap_b
        sta matched,x
        inc nmatch
        rts

; cs_col = a colour, cs_k = a kind (1 striped across, 2 down, 3 wrapped):
; every candy of that colour becomes that special (striped at random)
convert_colour
        ldx #0
_l      lda board,x
        jsr mcol
        cmp cs_col
        bne _n
        lda cs_k
        cmp #3
        beq _form
        jsr rand
        and #1
        clc
        adc #1
_form   asl a
        asl a
        asl a
        ora cs_col
        sta board,x                     ; shows in the CLEAR's flash
_n      inx
        cpx #COLS*ROWS
        bcc _l
        rts

; A = a row (< 8) or a column | $80: a beam will be drawn. Keeps A, X, Y.
add_beam
        stx ab_x
        ldx nbeams
        cpx #MAX_BEAMS
        bcs +
        sta beams,x
        inc nbeams
+       ldx ab_x
        rts

ab_x    .byte 0

; X = a cell, pop_ph = phase 1-3: if a special is born here, A = a star's
; frame (small, big, small); otherwise A = the pop's frame. Keeps X.
spawn_star
        lda pop_ph
        clc
        adc #OV_POP
        sta t0
        ldy nspawn
        beq _r
        ldy #0
-       txa
        cmp spawns,y
        beq _star
        iny
        iny
        tya
        lsr a
        cmp nspawn
        bcc -
_r      lda t0
        rts
_star   lda pop_ph
        and #1
        eor #1
        clc
        adc #OV_STAR
        rts
