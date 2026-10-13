; =============================================================================
; game.asm - a new game and the state machine
; =============================================================================

game_new
        lda #0                          ; every variable 0 (not the seed, the level)
        ldx #G_END-G_START-1
-       sta G_START,x
        dex
        bpl -
        ldx #A_END-A_START-1
-       sta A_START,x
        dex
        bpl -
        ldx #0
-       sta BOARD,x
        inx
        bne -
        lda #7
        sta ingr_odds
        lda #$ff
        sta sel
        lda #3*COLS+3
        sta cursor
        lda #TUNE_GAME
        sta snd_want
        lda #0
        sta title_on
        sta VIC_SPR_ENA
        lda cur_level
        jsr load_level
        jsr fill_board
        ; the screen, built with the display off
        lda #$0b
        sta VIC_CTRL1
        lda #BOARD_BG
        sta VIC_BG0
        lda #BLACK
        sta VIC_BORDER
        jsr clear_screen
        jsr hud_init
        jsr draw_board_all
        jsr foot_draw
        lda #1
        sta foot_on
        lda #$3b
        sta VIC_CTRL1
        rts                             ; (S_IDLE = 0 from the clearing)

step_state
        lda state
        asl a
        tax
        lda state_tab+1,x
        pha
        lda state_tab,x
        pha
        rts

state_tab
        .word st_idle-1, st_swap-1, st_swap-1, st_clear-1, st_fall-1, st_over-1, st_beam-1, st_win-1
        .word st_code-1, st_menu-1, st_scores-1, st_crush-1, st_slide-1

; -----------------------------------------------------------------------------
; IDLE: the cursor moves and blinks, fire selects and swaps
; -----------------------------------------------------------------------------
st_idle
        lda joy_edge
        and #J_ESC
        beq +
        jsr hint_reset
        jmp menu_enter
+       jsr hint_tick
        inc blink_t
        jsr get_dir
        beq _fire
        sta t3
        lda cursor
        sta t4                          ; the old cell
        lda t3
        and #J_UP
        beq +
        lda cursor
        cmp #COLS
        bcc +
        sbc #COLS
        sta cursor
+       lda t3
        and #J_DOWN
        beq +
        lda cursor
        cmp #COLS*(ROWS-1)
        bcs +
        adc #COLS
        sta cursor
+       lda t3
        and #J_LEFT
        beq +
        lda cursor
        and #7
        beq +
        dec cursor
+       lda t3
        and #J_RIGHT
        beq +
        lda cursor
        and #7
        cmp #7
        beq +
        inc cursor
+       lda #0                          ; the cursor shows at once when it moves
        sta blink_t
_fire   lda joy_edge
        and #J_FIRE
        beq _r
        ldx cursor                      ; on an empty cell or a blocker: nothing
        lda board,x
        cmp #EMPTY
        beq _r
        lda sel
        cmp #$ff
        bne _has_sel
        stx sel                         ; the first selection
        jmp _select
_has_sel
        cmp cursor
        bne _other
        lda #$ff                        ; the same again: cancelled
        sta sel
        jmp _select
_other  ldx sel
        ldy cursor
        jsr adjacent
        bcs _swap
        lda cursor                      ; far away: the selection moves
        sta sel
_select lda #SFX_SELECT
        sta sfx_request
_r      rts
_swap   lda #0
        sta choc_broken
        lda sel
        sta swap_a
        lda cursor
        sta swap_b
        lda #$ff
        sta sel
        lda #0
        sta anim_k
        lda #S_SWAP
        sta state
        lda #SFX_SWAP
        sta sfx_request
        rts

; X, Y = two cells. C set if they are next to each other.
adjacent
        sty t0
        txa
        sec
        sbc t0                          ; X - Y
        cmp #COLS
        beq _yes
        cmp #256-COLS
        beq _yes
        cmp #1                          ; X is right of Y
        beq _xr
        cmp #$ff                        ; X is left of Y
        beq _xl
        clc
        rts
_xr     txa                             ; X not in the first column
        and #7
        beq _no
_yes    sec
        rts
_xl     txa
        and #7
        cmp #7
        beq _no
        sec
        rts
_no     clc
        rts

; -----------------------------------------------------------------------------
; SWAP / UNSWAP: the two candies (sprites) slide into each other's place
; -----------------------------------------------------------------------------
st_swap
        inc anim_k
        lda anim_k
        jsr swap_draw_k
        lda anim_k
        cmp #SWAP_FRAMES
        bcs +
        rts
+       ldx swap_a                      ; the swap on board[]
        ldy swap_b
        lda board,x
        pha
        lda board,y
        sta board,x
        pla
        sta board,y
        lda swap_a
        jsr draw_cell
        lda swap_b
        jsr draw_cell
        jsr hide_candy_sprites
        lda state
        cmp #S_UNSWAP
        beq _back
        lda #1                          ; RESOLVE
        sta chain
        jsr combo_swap
        bcs _valid
        jsr find_matches
        beq _invalid
_valid  sed
        lda moves
        sec
        sbc #1
        sta moves
        cld
        lda #1
        sta hud_dirty
        jmp start_clear
_invalid
        lda #0
        sta anim_k
        lda #S_UNSWAP
        sta state
        lda #SFX_BAD
        sta sfx_request
        rts
_back   lda #S_IDLE
        sta state
        rts

; A = steps: the two candies of swap_a / swap_b as sprites, each moved that
; many steps (4 pixels or 4 lines) towards the other. On the first step the
; two cells lose their candies on the bitmap.
swap_draw_k
        sta sw_k
        cmp #1
        bne +
        lda swap_a
        jsr draw_bg
        lda swap_b
        jsr draw_bg
        ldx swap_a
        lda board,x
        ldx #0
        jsr candy_sprite
        sta spr_on
        ldx swap_b
        lda board,x
        ldx #1
        jsr candy_sprite
        asl a
        ora spr_on
        sta spr_on
+       lda #0                          ; the step: sw_dx pixels, sw_dy lines
        sta sw_dx
        sta sw_dy
        lda swap_b
        sec
        sbc swap_a
        cmp #1
        bne +
        lda #4
        sta sw_dx
+       cmp #$ff
        bne +
        lda #256-4
        sta sw_dx
+       cmp #COLS
        bne +
        lda #4
        sta sw_dy
+       cmp #256-COLS
        bne +
        lda #256-4
        sta sw_dy
+       lda #0                          ; times the steps
        sta sw_ox
        sta sw_oy
        ldx sw_k
-       lda sw_ox
        clc
        adc sw_dx
        sta sw_ox
        lda sw_oy
        clc
        adc sw_dy
        sta sw_oy
        dex
        bne -
        lda swap_a                      ; A towards B
        jsr cell_spr_xy
        lda t0
        clc
        adc sw_ox
        sta t0
        lda t1
        clc
        adc sw_oy
        sta t1
        ldx #0
        jsr candy_sprite_at
        lda swap_b                      ; B towards A
        jsr cell_spr_xy
        lda t0
        sec
        sbc sw_ox
        sta t0
        lda t1
        sec
        sbc sw_oy
        sta t1
        ldx #1
        jmp candy_sprite_at

sw_k    .byte 0
sw_dx   .byte 0
sw_dy   .byte 0
sw_ox   .byte 0
sw_oy   .byte 0

; -----------------------------------------------------------------------------
; The hint: after HINT_WAIT frames with no key, the two candies of a move
; lean towards each other, four times, then rest for a while.
; -----------------------------------------------------------------------------
hint_tick
        lda joy
        bne hint_reset
        lda hint_t
        cmp #HINT_WAIT
        bcs +
        inc hint_t
        rts
+       lda hint_ph
        inc hint_ph
        cmp #0
        bne _phase
        jsr has_move                    ; the first time: which move
        lda hm_a
        sta hint_a
        lda hm_b
        sta hint_b
        lda #0
_phase  sta t3
        and #3
        bne _r
        lda t3
        and #32+4                       ; 4 times in 32 frames, then 32 quiet
        cmp #4
        bne hint_back
        lda #1
        sta hint_on
        lda hint_a
        sta swap_a
        lda hint_b
        sta swap_b
        lda #1
        jmp swap_draw_k
_r      rts

hint_reset
        lda #0
        sta hint_t
        sta hint_ph
hint_back                               ; the candies back in place
        lda hint_on
        beq _r
        lda #0
        sta hint_on
        lda hint_a
        jsr draw_cell
        lda hint_b
        jsr draw_cell
        jmp hide_candy_sprites
_r      rts

; -----------------------------------------------------------------------------
; CLEAR: the marked cells pop in 4 phases of 2 frames, then empty.
; First the striped candies' beams, if any, then the pop.
; -----------------------------------------------------------------------------
start_clear
        lda #0
        sta anim_k
        ldx #COLS*ROWS-1                ; how many pop
        ldy #0
-       lda matched,x
        beq +
        iny
+       dex
        bpl -
        sty clear_n
        lda nbeams
        beq _pop
        lda #S_BEAM
        sta state
        lda #SFX_BEAM
        sta sfx_request
        rts
_pop    lda #S_CLEAR
        sta state
        jmp play_clear_sfx

; BEAM: the beam over the row/column, thick then thin, 2 frames each; then
; what does not pop under it (ingredients) is drawn again.
st_beam
        lda anim_k
        inc anim_k
        cmp #4
        beq _restore
        lsr a
        bcc +
        rts
+       and #1
        sta pop_ph
        lda #0
        sta sb_i
_beam   lda sb_i
        cmp nbeams
        bcs _r
        tax
        lda beams,x
        jsr beam_cells
        lda pop_ph
        clc
        adc sb_fr
        sta sb_fr
-       lda sb_c
        ldx sb_fr
        jsr draw_overlay
        lda sb_c
        clc
        adc sb_step
        sta sb_c
        dec sb_n
        bne -
        inc sb_i
        bne _beam
_r      rts
_restore
        lda #0
        sta sb_i
_rbeam  lda sb_i
        cmp nbeams
        bcs _done
        tax
        lda beams,x
        jsr beam_cells
-       ldx sb_c
        lda matched,x
        bne +
        txa
        jsr draw_cell
+       lda sb_c
        clc
        adc sb_step
        sta sb_c
        dec sb_n
        bne -
        inc sb_i
        bne _rbeam
_done   lda #0
        sta anim_k
        lda #S_CLEAR
        sta state
        jmp play_clear_sfx

; A = a beam -> sb_c = the first cell, sb_step, sb_n = 8, sb_fr = its frame
beam_cells
        ldx #8
        stx sb_n
        tax
        bmi _vert
        asl a
        asl a
        asl a
        sta sb_c
        lda #1
        sta sb_step
        lda #OV_BEAM_H
        sta sb_fr
        rts
_vert   and #7
        sta sb_c
        lda #COLS
        sta sb_step
        lda #OV_BEAM_V
        sta sb_fr
        rts

sb_i    .byte 0
sb_c    .byte 0
sb_step .byte 0
sb_n    .byte 0
sb_fr   .byte 0

st_clear
        lda anim_k
        inc anim_k
        cmp #8
        beq _empty
        lsr a
        bcc +
        rts
+       and #3
        sta pop_ph
        beq _go                         ; many at once: only the flash and the dust
        cmp #3
        beq _go
        lda clear_n
        cmp #BIG_CLEAR
        bcc _go
        rts
_go     ldx #0
_cell   lda matched,x
        beq _next
        stx sc_x
        txa
        jsr draw_bg
        lda pop_ph
        bne +
        lda sc_x                        ; the flash over the candy
        jsr draw_candy_cell
        lda #OV_POP
        jmp ++
+       ldx sc_x                        ; where a special is born: a star
        jsr spawn_star
+       tax
        lda sc_x
        jsr draw_overlay
        ldx sc_x
_next   inx
        cpx #COLS*ROWS
        bcc _cell
        rts
_empty  ldx #0
_cell2  lda matched,x
        beq _next2
        pha
        lda #EMPTY
        sta board,x
        pla
        jsr apply_damage                ; the jelly under it, or a blocker that breaks
        stx sc_x
        txa
        jsr draw_bg
        ldx sc_x
_next2  inx
        cpx #COLS*ROWS
        bcc _cell2
        ldx #0                          ; the specials that were born
-       txa
        lsr a
        cmp nspawn
        bcs start_fall
        stx sc_x
        lda spawns+1,x
        ldy spawns,x
        sta board,y
        tya
        jsr draw_candy_cell
        ldx sc_x
        inx
        inx
        bne -
        ; (on)

; -----------------------------------------------------------------------------
; FALL: a cell at a time, in FALL_STEPS frames, until no gap is left
; -----------------------------------------------------------------------------
start_fall
        jsr collect_ingredients
        jsr fall_scan
        bne _fall
        jsr diag_scan                   ; nothing straight down: maybe diagonally
        bcc resolve_fall
        lda #S_SLIDE
        bne _slide
_fall   lda #S_FALL
        sta state
        ; the more that falls, the fewer the steps (a step draws all of it):
        ; up to 12 cells 3 steps, up to 36 2, more 1
        lda #0
        sta t3
        ldx #COLS-1
-       lda gapr,x
        cmp #$ff
        beq +
        sec
        sbc segtop,x
        sec                             ; + 1
        adc t3
        sta t3
+       dex
        bpl -
        ldx #0
        lda t3
        cmp #13
        bcc +
        inx
        cmp #37
        bcc +
        inx
+       stx anim_k
        rts
_slide  sta state
        lda #0
        sta anim_k
        rts

sc_x    .byte 0

st_slide
        inc anim_k
        lda anim_k
        jsr slide_draw
        lda anim_k
        cmp #SLIDE_STEPS
        bcs +
        rts
+       jsr slide_commit
        jmp start_fall

st_fall
        inc anim_k
        lda anim_k
        sta fall_k
        jsr fall_draw
fall_drawn                              ; (tests: the time of a fall's step)
        lda anim_k
        cmp #FALL_STEPS
        bcs +
        rts
+       jsr fall_commit
        jsr start_fall
fall_next                               ; (tests: the time of a step's end)
        rts

; The board has settled: new matches = a chain, otherwise back to the player.
resolve_fall
        inc chain
        jsr find_matches
        beq +
        jmp start_clear
+       jsr say_praise                  ; "Sweet!" for the long chains
        jsr goal_met
        bcs _win
        lda moves
        beq _over
        jsr spread_chocolate
        jsr has_move
        bcs _idle
        lda #$0b                        ; deadlock: a new board
        sta VIC_CTRL1
        jsr fill_board
        jsr draw_board_all
        jsr clear_dirty
        lda #$3b
        sta VIC_CTRL1
_idle   lda #S_IDLE
        sta state
        rts
_over   lda #0
        sta anim_k
        lda #S_OVER
        sta state
        lda #SFX_OVER
        sta sfx_request
        rts
_win    lda moves                       ; moves left over: the Sugar Crush first
        beq +
        jmp start_crush
+       lda #0
        sta anim_k
        lda #S_WIN
        sta state
        jsr clear_dirty                 ; (nothing may draw over the stars)
        jsr draw_win_stars
        jsr record_best
        ldx cur_level                   ; the next level's code
        inx
        cpx #NLEVELS
        bcc +
        ldx #0
+       txa
        jsr hud_show_code
        lda #SFX_WIN
        sta sfx_request
        rts

; -----------------------------------------------------------------------------
; WIN: the goal is met. The stars on the board; fire = the next level.
; -----------------------------------------------------------------------------
st_win
        lda joy_edge
        and #J_ESC
        beq +
        jmp menu_enter
+       lda joy_edge
        and #J_FIRE
        beq _r
        ldx cur_level
        inx
        cpx #NLEVELS
        bcc +
        ldx #0                          ; after the last one, from the start
+       stx cur_level
        jmp game_new
_r      rts

; -----------------------------------------------------------------------------
; OVER: no moves left. The border blinks; fire = the same level again.
; -----------------------------------------------------------------------------
st_over
        inc anim_k
        lda anim_k
        and #16
        beq +
        lda #BLUE
+       sta VIC_BORDER                  ; (0: black)
        lda joy_edge
        and #J_ESC
        beq +
        lda #BLACK
        sta VIC_BORDER
        jmp menu_enter
+       lda joy_edge
        and #J_FIRE
        beq _r
        lda #BLACK
        sta VIC_BORDER
        jmp game_new
_r      rts

; -----------------------------------------------------------------------------
; SUGAR CRUSH: the goal is met with moves to spare. Every move becomes a
; striped candy on a random plain one; then every special on the board pops
; at once, and their chains count as usual. When the board settles the moves
; are 0 and the win follows.
; -----------------------------------------------------------------------------
start_crush
        lda #0
        sta anim_k
        lda #S_CRUSH
        sta state
        lda #VOICE_CRUSH
        jmp say

st_crush
        lda anim_k
        inc anim_k
        cmp #0
        bne +
        rts                             ; the first frame: only the fanfare
+       cmp #CRUSH_FRAMES
        bcs +
        rts
+       lda #1
        sta anim_k
        lda moves
        beq crush_fire
        sed
        sec
        sbc #1
        sta moves
        cld
        lda #1
        sta hud_dirty
        jsr rand                        ; a random plain candy turns striped
        and #63
        tax
        ldy #COLS*ROWS
_find   lda board,x
        cmp #6                          ; plain: colour 0-5, no form, no ingredient
        bcc _got
        inx
        txa
        and #63
        tax
        dey
        bne _find
        jmp crush_fire                  ; no plain one left
_got    sta t3
        jsr rand
        and #1
        beq +
        lda #F_STRIPED_V
        bne ++
+       lda #F_STRIPED_H
+       ora t3
        sta board,x
        txa
        jsr mark_dirty
        lda #SFX_SELECT
        sta sfx_request
        rts

; every special on the board pops at once
crush_fire
        jsr clear_matched
        lda #1
        sta chain
        ldx #0
_cell   lda board,x
        jsr special_kind
        beq +
        lda #1
        sta matched,x
        inc nmatch
+       inx
        cpx #COLS*ROWS
        bcc _cell
        lda nmatch
        beq _done
        jsr expand_specials
        jsr mark_blocker_damage
        jmp start_clear
_done   jmp resolve_fall                ; nothing to pop: on to the win
