; =============================================================================
; voice.asm - speech from the SID: "Sugar Byte!", "Sweet!", "Delicious!",
; "Sugar Crush!"
;
; The samples (tools/voice64.py) are 4-bit, two a byte, 5,500 a second,
; written to the SID's volume ($d418). The three voices hold a constant level
; (test bit + pulse, sustain 15) so that the 8580 speaks as loud as the 6581.
; say keeps the machine while it talks (0.5-1 s, interrupts off): the music
; stops for that while, as on the CPC.
; =============================================================================

VOICE_D1        = 31                    ; delay loops between the two samples of a byte
VOICE_D2        = 23                    ; ... and after the second (the loop costs more)

voice_init
        rts

; A = the phrase (VOICE_*)
say
        tax
        lda voice_lo,x
        sta ptr
        lda voice_hi,x
        sta ptr+1
        lda voice_len_lo,x
        sta ptr2
        lda voice_len_hi,x
        sta ptr2+1
        sei
        lda #1
        sta speaking
        ldx #14                         ; the voices: a constant level
-       lda #0
        sta SID+5,x                     ; attack/decay 0
        lda #$f0
        sta SID+6,x                     ; sustain 15
        lda #$08
        sta SID+3,x
        lda #$49                        ; pulse, test, gate
        sta SID+4,x
        txa
        sec
        sbc #7
        tax
        bpl -
        lda #0
        sta SID_ROUTE
        ldy #0
_byte   lda (ptr),y                     ; the high nibble
        lsr a
        lsr a
        lsr a
        lsr a
        sta SID_VOLUME
        ldx #VOICE_D1
-       dex
        bne -
        lda (ptr),y                     ; the low one
        and #$0f
        sta SID_VOLUME
        inc ptr
        bne +
        inc ptr+1
+       lda ptr2
        bne +
        dec ptr2+1
+       dec ptr2
        ldx #VOICE_D2
-       dex
        bne -
        lda ptr2
        ora ptr2+1
        bne _byte
        ldx #14                         ; the voices back to silence
-       lda #0
        sta SID+4,x
        txa
        sec
        sbc #7
        tax
        bpl -
        lda #0
        sta speaking                    ; the next sound_tick writes everything
        cli
        rts

; the praise at the end of a move: the longer the chain, the sweeter.
; chain counts the resolves: 2 = no chain.
say_praise
        lda chain
        cmp #6
        bcc +
        lda #VOICE_DELICIOUS
        jmp say
+       cmp #4
        bcc +
        lda #VOICE_SWEET
        jmp say
+       rts
