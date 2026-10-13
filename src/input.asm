; =============================================================================
; input.asm - joysticks (ports 2 and 1) and the keyboard -> joy / joy_edge
;
;   up/down/left/right   joystick, cursor keys (up/left with a shift), W A S D
;   fire                 joystick fire, SPACE, RETURN
;   music on/off         M
;   back (ESC)           RUN/STOP, <- (the arrow left of 1)
; A test sets test_mode and writes test_keys instead.
; =============================================================================

read_input
        lda test_mode
        beq +
        lda test_keys
        jmp _done
+       lda #$ff                        ; no keyboard column: the joysticks alone
        sta CIA1_PRA
        lda CIA1_PRA                    ; port 2
        and CIA1_PRB                    ; port 1
        eor #$ff
        and #$1f
        sta t0
        bne _done0                      ; a joystick in use: its lines would show up
                                        ; as keys, skip the keyboard
        ldx #KEYMAP_LEN-1
-       lda keymap_col,x
        sta CIA1_PRA
        lda CIA1_PRB
        and keymap_row,x
        bne +
        lda t0
        ora keymap_bits,x
        sta t0
+       dex
        bpl -
        lda #%11111110                  ; cursor keys: left/up with a shift
        sta CIA1_PRA
        lda CIA1_PRB
        eor #$ff
        sta t1
        lda #%11111101                  ; left shift
        sta CIA1_PRA
        lda CIA1_PRB
        and #$80
        beq _shift
        lda #%10111111                  ; right shift
        sta CIA1_PRA
        lda CIA1_PRB
        and #$10
_shift  sta t2                          ; 0: a shift is down
        lda t1
        and #$04                        ; CRSR left/right
        beq _vert
        ldx #J_RIGHT
        lda t2
        bne +
        ldx #J_LEFT
+       txa
        ora t0
        sta t0
_vert   lda t1
        and #$80                        ; CRSR up/down
        beq _cdone
        ldx #J_DOWN
        lda t2
        bne +
        ldx #J_UP
+       txa
        ora t0
        sta t0
_cdone  lda #$ff
        sta CIA1_PRA
_done0  lda t0                          ; (the joystick bits are J_UP .. J_FIRE)
_done   sta t0                          ; pressed = now and not before
        lda joy
        eor #$ff
        and t0
        sta joy_edge
        lda t0
        sta joy
        rts

; keyboard matrix: column select ($dc00), row bit ($dc01), J_*
keymap_col      .byte %11111101, %11111101, %11111101, %11111011, %01111111, %11111110, %11101111, %01111111, %01111111
keymap_row      .byte %00000010, %00000100, %00100000, %00000100, %00010000, %00000010, %00010000, %10000000, %00000010
keymap_bits     .byte J_UP, J_LEFT, J_DOWN, J_RIGHT, J_FIRE, J_FIRE, J_MUSIC, J_ESC, J_ESC
KEYMAP_LEN      = 9                     ; W, A, S, D, SPACE, RETURN, M, RUN/STOP, <-

; A = the directions to act on in this frame: at once on the press, after
; REP_FIRST frames if held, then every REP_NEXT
get_dir
        lda joy
        and #J_UP|J_DOWN|J_LEFT|J_RIGHT
        bne _held
        sta rep_cnt
        rts
_held   tax
        lda joy_edge
        and #J_UP|J_DOWN|J_LEFT|J_RIGHT
        beq _rep
        lda #REP_FIRST
        sta rep_cnt
        txa
        rts
_rep    dec rep_cnt
        beq +
        lda #0
        rts
+       lda #REP_NEXT
        sta rep_cnt
        txa
        rts
