; The game's variables: zero page and the arrays at BOARD / ARRAYS.

; --- zero page -------------------------------------------------------------------
        .virtual $02
frame_counter   .word ?         ; +1 a frame (IRQ)
frame_flag      .byte ?         ; +1 by the IRQ, cleared by the main loop
src             .word ?         ; graphics: the source record
bmp             .word ?         ; ... the bitmap, screen RAM, colour RAM
scrp            .word ?         ;     of the character being drawn
colp            .word ?
ptr             .word ?         ; general pointers
ptr2            .word ?
t0              .byte ?         ; scratch
t1              .byte ?
t2              .byte ?
t3              .byte ?
t4              .byte ?
t5              .byte ?
blk_x           .byte ?         ; draw_block: the first character,
blk_y           .byte ?
blk_w           .byte ?         ; the size in characters,
blk_h           .byte ?
blk_rec         .byte ?         ; the record size: 10 opaque, 11 masked
bx              .byte ?
by              .byte ?
bw              .byte ?
bh              .byte ?
seed            .word ?         ; the random numbers (never 0)
joy             .byte ?         ; J_* held now
joy_edge        .byte ?         ; J_* pressed this frame
rep_cnt         .byte ?
test_mode       .byte ?         ; tests: the keys come from test_keys
test_keys       .byte ?
cur_level       .byte ?         ; the level, from 0 (game_new keeps it)
menu_sel        .byte ?
mus_on          .byte ?         ; music on (M, SOUND)
snd_want        .byte ?         ; the tune the screen wants (sound.asm)
sfx_request     .byte ?         ; an effect to play (SFX_*), 0: none
snd_ptr         .word ?         ; sound.asm (IRQ only)
ord_ptr         .word ?
foot_phase      .byte ?
foot_on         .byte ?         ; the game's foot runs
title_on        .byte ?         ; the menu's title changes colour
title_t         .byte ?
irq_t           .byte ?         ; the IRQ's scratch
speaking        .byte ?

; cleared by game_new, from here to G_END
G_START
dq_head         .byte ?         ; the ring of dirty cells
dq_tail         .byte ?
dq_n            .byte ?
state           .byte ?
anim_k          .byte ?         ; frame inside the state's animation
cursor          .byte ?         ; the cursor's cell
sel             .byte ?         ; the selected cell, $ff = none
swap_a          .byte ?
swap_b          .byte ?
chain           .byte ?         ; the chain multiplier
nmatch          .byte ?         ; runs find_matches found
moves           .byte ?         ; BCD
score           .fill 3         ; BCD, the most significant byte first
hud_dirty       .byte ?
blink_t         .byte ?
ncolours        .byte ?
choc_broken     .byte ?         ; chocolate was broken in this move
ingr_left       .byte ?         ; BCD: ingredients still to bring down
ingr_spawn      .byte ?         ; ingredients still to drop in at the top
ingr_board      .byte ?         ; ingredients on the board now
ingr_odds       .byte ?         ; mask: 7 = one time in 8
scan_bit        .byte ?         ; 1 = scanning rows, 2 = columns
nruns           .byte ?
nspawn          .byte ?
sp_changed      .byte ?
nbeams          .byte ?
clear_n         .byte ?         ; how many cells pop
beam_fr         .byte ?
beam_step       .byte ?
lv_goal         .byte ?         ; the level's header (tools/levels.py)
lv_star1        .word ?         ; BCD hundreds, the most significant byte first
lv_moves        .byte ?
lv_colours      .byte ?
lv_ingr         .byte ?
lv_star2        .word ?
lv_star3        .word ?
lv_number       .byte ?
win_n           .byte ?
code_pos        .byte ?
menu_tmp        .byte ?
scores_pg       .byte ?
boom            .byte ?         ; a wrapped candy went off in this resolve
pop_ph          .byte ?
fall_k          .byte ?
hint_t          .byte ?         ; idle frames in IDLE, up to HINT_WAIT
hint_ph         .byte ?         ; the wiggle's phase
hint_on         .byte ?         ; 1 = the hint's candies are moved (sprites)
hint_a          .byte ?         ; the move it shows
hint_b          .byte ?
slide_s         .byte ?         ; the diagonal slide: from ...
slide_t         .byte ?         ; ... to
spr_on          .byte ?         ; candy sprites shown: bit 0 A, bit 1 B
over_t          .byte ?
G_END
        .cerror * > $90, "zero page full"
        .endv

; --- the four 64-byte arrays: one page, a cell indexes all of them ------------------
board           = BOARD         ; what sits in the cell (const.inc)
matched         = BOARD + $40   ; it pops (const.inc)
cell            = BOARD + $80   ; what the cell is; bit 7 = dirty
dirty_q         = BOARD + $c0   ; the ring of dirty cells

; --- the arrays (cleared by game_new) ---------------------------------------------
        .virtual ARRAYS
A_START
gapr             .fill COLS      ; by column: the lowest gapr, $ff = none
nextc           .fill COLS      ; by column: the candy that drops in
segtop          .fill COLS      ; by column: the first row of the falling segment
spawn           .fill COLS      ; by column: 1 = the segment fills from the top
nb              .fill 4         ; a cell's neighbours
runs            .fill 3*MAX_RUNS        ; first cell, length, step
spawns          .fill 2*MAX_SPAWN       ; cell, board[] of the special born there
beams           .fill MAX_BEAMS         ; row 0-7, or column | $80
code_dig        .fill 4         ; the code being typed, a digit a byte
menu_buf        .fill 16        ; a label being built
A_END
        .cerror * > BEST, "arrays full"
        .endv

best            = BEST          ; by level: points (3 BCD), stars
