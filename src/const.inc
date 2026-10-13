; Constants of the game and the memory map (planc64.md)

; --- memory --------------------------------------------------------------------
; $0200-$02ff  board, matched, cell, dirty_q (64 each)
; $0300-$03ff  the game's arrays (cleared by game_new)
; $0400-$04ff  best[]: points (3 BCD) and stars of every level
; $0500-$05ff  the sound player
; $0801-$bfff  program and data
; $c000-$c3e7  screen RAM (the bitmap's colours), $c3f8 the sprite pointers
; $c400-$c5ff  sprite blocks (copied in when needed)
; $d800        colour RAM
; $e000-$ff3f  the bitmap (under the KERNAL: all ROMs are out, $01 = $35)
BOARD           = $0200
ARRAYS          = $0300
BEST            = $0400
SSTATE          = $0500
SCREEN          = $c000
SPR_PTRS        = SCREEN + $3f8
SPR_BLOCKS      = $c400
BITMAP          = $e000

; sprite blocks (pointer = (address - $c000) / 64)
SPR_CANDY_A     = $10           ; candy A: main, shade
SPR_CANDY_B     = $12           ; candy B: main, shade
SPR_CURSOR      = $14           ; white
SPR_SELECT      = $15           ; cyan
; sprite numbers: 0/1 candy A, 2/3 candy B, 4 the cursor, 5 the selection

; --- the screen ----------------------------------------------------------------
; multicolour bitmap, 40x25 characters of 4x8 pixels
;   columns  0-23  the board: 8x8 cells of 3x3 characters
;   columns 24-39  the HUD
;   row 24         the foot (a candy cane that runs)
COLS            = 8
ROWS            = 8
HUD_X           = 24
FOOT_ROW        = 24
BOARD_BG        = BLUE          ; $d021 in the game: the board and the HUD
MENU_BG         = BLACK

; --- the board -----------------------------------------------------------------
EMPTY           = 7             ; board[]: colour 7 = an empty cell
BOMB            = 6             ; board[]: colour 6 = the colour bomb
INGREDIENT      = $20           ; board[] bit 5: ingredient; bit 0: 0 cherry, 1 nut
F_STRIPED_H     = 1 << 3        ; board[] bits 3-4: the form
F_STRIPED_V     = 2 << 3
F_WRAPPED       = 3 << 3
FORM_SHIFT      = 3
G_SCORE         = 0             ; the level's goal
G_JELLY         = 1
G_INGREDIENTS   = 2
G_BOTH          = 3
G_ENDLESS       = $ff           ; no goal (tests)
MAX_RUNS        = 24
MAX_SPAWN       = 16
MAX_BEAMS       = 16
MAX_LEVELS      = 64            ; best[]: 4 bytes a level

; cell[]: the kind in bits 0-2
C_NORMAL        = 0
C_HOLE          = 1
C_ICING         = 2
C_CHOCOLATE     = 3
C_LICORICE      = 4
ICING_SHIFT     = 3
ICING_MASK      = 3 << ICING_SHIFT
JELLY_SHIFT     = 5
JELLY_MASK      = 3 << JELLY_SHIFT
DIRTY           = $80           ; cell[] bit 7: queued for a redraw

; matched[]: bit 0 row, 1 column, 2 "taken" (a special is born there),
; 3 hit by a special, 4 a blocker that takes damage, 7 already fired
M_BLOCKER       = $10

; --- time ----------------------------------------------------------------------
DRAW_BUDGET     = 4             ; dirty cells drawn a frame
SWAP_FRAMES     = 6             ; 4 pixels or 4 lines a frame (sprites)
FALL_STEPS      = 3             ; a cell of fall in 3 steps of 8 lines
SLIDE_STEPS     = 4             ; the diagonal slide (a sprite)
HINT_WAIT       = 250           ; 5 seconds idle: the hint
REP_FIRST       = 12            ; the cursor's key repeat: first ...
REP_NEXT        = 3             ; ... and then
CRUSH_FRAMES    = 5             ; frames for every move that turns striped
BIG_CLEAR       = 24            ; more cells than this: the pop in 2 phases, not 4

; --- input ---------------------------------------------------------------------
J_UP            = 1
J_DOWN          = 2
J_LEFT          = 4
J_RIGHT         = 8
J_FIRE          = 16
J_MUSIC         = 32
J_ESC           = 64

; --- states --------------------------------------------------------------------
S_IDLE          = 0
S_SWAP          = 1
S_UNSWAP        = 2
S_CLEAR         = 3
S_FALL          = 4
S_OVER          = 5
S_BEAM          = 6
S_WIN           = 7
S_CODE          = 8
S_MENU          = 9
S_SCORES        = 10
S_CRUSH         = 11
S_SLIDE         = 12
