; =============================================================================
; codes.asm - progress by level codes
;
; Every level has a 4-digit code: CODE_FIRST + level * CODE_STEP, in BCD mod
; 10,000 (tools/levels.py). The HUD always shows the current level's code,
; and at a win the next one's. In the menu, LEVEL: "CODE 0000" - left/right
; a digit, up/down changes it, fire accepts, RUN/STOP cancels.
; =============================================================================

; A = level (from 0) -> lc_hi, lc_lo = its code in BCD. Keeps X, Y.
level_code
        sty lc_y
        tay
        lda #<CODE_FIRST
        sta lc_lo
        lda #>CODE_FIRST
        sta lc_hi
        cpy #0
        beq _r
        sed
-       clc
        lda lc_lo
        adc #<CODE_STEP
        sta lc_lo
        lda lc_hi
        adc #>CODE_STEP
        sta lc_hi
        dey
        bne -
        cld
_r      ldy lc_y
        rts

lc_lo   .byte 0
lc_hi   .byte 0
lc_y    .byte 0

; from the menu: the entry starts at 0000, on the LEVEL plate
start_code
        lda #0
        sta code_pos
        sta anim_k
        sta code_dig
        sta code_dig+1
        sta code_dig+2
        sta code_dig+3
        lda #S_CODE
        sta state
        lda #SFX_SELECT
        sta sfx_request
        jmp draw_code_entry

st_code
        inc anim_k
        lda anim_k
        and #7
        bne +
        jsr draw_code_entry             ; the digit blinks
+       lda joy_edge
        and #J_ESC
        bne _cancel
        lda joy_edge
        and #J_FIRE
        bne _enter
        jsr get_dir
        bne +
        rts
+       sta t3
        ldx code_pos
        lda t3
        and #J_LEFT
        beq +
        dex
+       lda t3
        and #J_RIGHT
        beq +
        inx
+       txa
        and #3
        sta code_pos
        tax
        lda t3
        and #J_UP                       ; +1
        beq +
        inc code_dig,x
        lda code_dig,x
        cmp #10
        bcc +
        lda #0
        sta code_dig,x
+       lda t3
        and #J_DOWN                     ; -1
        beq +
        dec code_dig,x
        bpl +
        lda #9
        sta code_dig,x
+       lda #0                          ; the digit shows at once
        sta anim_k
        jmp draw_code_entry
_cancel lda #S_MENU
        sta state
        jmp draw_code_entry
_enter  lda code_dig                    ; the 4 digits into 2 bytes of BCD
        asl a
        asl a
        asl a
        asl a
        ora code_dig+1
        sta ce_hi
        lda code_dig+2
        asl a
        asl a
        asl a
        asl a
        ora code_dig+3
        sta ce_lo
        ldx #0
-       txa
        jsr level_code
        lda lc_hi
        cmp ce_hi
        bne +
        lda lc_lo
        cmp ce_lo
        beq _found
+       inx
        cpx #NLEVELS
        bcc -
        lda #SFX_BAD                    ; no such code
        sta sfx_request
        rts
_found  stx cur_level
        lda #S_MENU
        sta state
        lda #SFX_COLLECT
        sta sfx_request
        ; (on: the plate says "LEVEL NN" again)

; the LEVEL plate: "CODE dddd" while it is typed, "LEVEL NN" otherwise
draw_code_entry
        lda #MI_LEVELS
        jmp draw_plate

ce_hi   .byte 0
ce_lo   .byte 0
