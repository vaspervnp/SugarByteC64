; Sugar Byte - Commodore 64 (PAL)
; A match-3 game, the C64 version of the Amstrad CPC game.
; Entry point, the raster IRQ and the main loop.
;
;   64tass src/main.asm -> build/sugar.prg (make)

        .include "hw.inc"
        .include "const.inc"
        .include "vars.inc"
        .include "data/gfx.inc"

IRQ_LINE        = 251                   ; under the picture: the frame's work starts here

; ---------------------------------------------------------------------------
; BASIC stub: 10 SYS <start>
; ---------------------------------------------------------------------------
        * = $0801
        .word (+), 10
        .null $9e, format("%d", start)
+       .word 0

; ---------------------------------------------------------------------------
start
        sei
        cld
        ldx #$ff
        txs
        lda #$7f                        ; no CIA interrupts: the raster IRQ is the clock
        sta CIA1_ICR
        sta CIA2_ICR
        lda CIA1_ICR
        lda CIA2_ICR
        lda #$35                        ; all ROMs out, I/O in
        sta $01
        lda #<nmi
        sta NMI_VEC
        lda #>nmi
        sta NMI_VEC+1
        lda #<irq
        sta IRQ_VEC
        lda #>irq
        sta IRQ_VEC+1

        lda $dc04                       ; a seed from the timer (never 0)
        eor $d012
        ora #1
        sta seed
        lda $dc05
        sta seed+1

        ldx #2                          ; clear the zero page ($02-$8f)
        lda #0
-       sta 0,x
        inx
        cpx #$90
        bne -
        lda seed                        ; (cleared with the rest)
        ora #1
        sta seed

        jsr video_init
        jsr sound_init
        jsr voice_init

        lda #IRQ_LINE                   ; the raster IRQ: once a frame
        sta VIC_RASTER
        lda VIC_CTRL1
        and #$7f
        sta VIC_CTRL1
        lda #1
        sta VIC_IRQ_MASK
        sta VIC_IRQ
        cli

        jsr menu_start
        ; (on to the main loop)

; ---------------------------------------------------------------------------
; The main loop: one pass a frame, released by the IRQ. A pass may take longer
; (a full board's fall): the next one starts at once.
; ---------------------------------------------------------------------------
main_loop
-       lda frame_flag
        beq -
        lda #0
        sta frame_flag
        jsr read_input
        lda joy_edge
        and #J_MUSIC
        beq +
        jsr toggle_music
+       jsr render_dirty
        jsr step_state
        jsr hud_update
        jsr update_sprites
        jsr foot_tick
        jsr title_tick
frame_done                              ; tests put a checkpoint here
        jmp main_loop

toggle_music
        lda mus_on
        eor #1
        sta mus_on
        rts

; ---------------------------------------------------------------------------
; The raster IRQ (the vectors at $fffe: no KERNAL)
; ---------------------------------------------------------------------------
irq
        pha
        cld                             ; (the IRQ may come during a BCD sum)
        txa
        pha
        tya
        pha
        lda #1
        sta VIC_IRQ
        inc frame_counter
        bne +
        inc frame_counter+1
+       inc frame_flag
        jsr sound_tick
        pla
        tay
        pla
        tax
        pla
nmi     rti

; ---------------------------------------------------------------------------
        .include "video.asm"
        .include "input.asm"
        .include "board.asm"
        .include "special.asm"
        .include "cells.asm"
        .include "ingred.asm"
        .include "level.asm"
        .include "codes.asm"
        .include "game.asm"
        .include "hud.asm"
        .include "menu.asm"
        .include "sound.asm"
        .include "voice.asm"
code_end

; --- data ----------------------------------------------------------------------
        .include "data/gfx.asm"
        .include "data/levels.asm"
        .include "data/music.asm"
        .include "data/voice.asm"
data_end
        .cerror data_end > SCREEN, "the program runs into the screen at $c000"
        .cerror NLEVELS > MAX_LEVELS, "too many levels"
