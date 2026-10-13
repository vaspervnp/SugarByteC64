; Sugar Byte - the tape's boot file: a turbo loader.
;
; LOAD (the KERNAL loads this small file at the normal speed), RUN: the loader
; moves itself to LOADER, turns the motor on and reads the game in turbo
; (tools/mktap.py): pulses read on the cassette line (CIA 1 FLAG), a short one
; (216 cycles) a 0, a long one (432) a 1, told apart by a one-shot timer of
; THRESHOLD cycles started at every pulse. Most significant bit first.
;
;   pilot: $aa ..., sync: $a5 $5a, then: load address, end address (past the
;   last byte), entry, the bytes, an XOR checksum.
;
; The screen is off while it loads; the border flickers with the bits.

LOADER          = $cf00
THRESHOLD       = 324
PTR             = $fb                   ; the load address (moves on)

        * = $0801
        .word (+), 10
        .null $9e, format("%d", boot)
+       .word 0

boot
        sei
        ldx #0
-       lda loader_src,x
        sta LOADER,x
        inx
        bne -
        jmp LOADER

loader_src
        .logical LOADER
        sei
        lda #$7f                        ; no CIA interrupts
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda #0
        sta $d01a
        lda #$0b                        ; the screen off: no bad lines
        sta $d011
        lda $00                         ; the motor on
        ora #$20
        sta $00
        lda $01
        and #$df
        sta $01
        lda #<THRESHOLD
        sta $dc04
        lda #>THRESHOLD
        sta $dc05
_sync   jsr get_bit                     ; bit by bit until $a5
        lda shift
        cmp #$a5
        bne _sync
        jsr get_byte
        cmp #$5a
        bne _sync
        ldx #0                          ; the header: 6 bytes
-       jsr get_byte
        sta head,x
        inx
        cpx #6
        bne -
        lda head
        sta PTR
        lda head+1
        sta PTR+1
        lda #0
        sta sum
        ldy #0
_data   jsr get_byte
        sta (PTR),y
        eor sum
        sta sum
        inc PTR
        bne +
        inc PTR+1
+       lda PTR
        cmp head+2
        lda PTR+1
        sbc head+3
        bcc _data
        jsr get_byte                    ; the checksum
        cmp sum
        bne _error
        lda $01                         ; the motor off
        ora #$20
        sta $01
        lda #0
        sta $d020
        jmp (head+4)
_error  lda #2                          ; a red border: load again
        sta $d020
        jmp _error

; -> A = the next byte
get_byte
        lda #1                          ; a marker bit: 8 shifts and it falls out
        sta shift
-       jsr get_bit
        bcc -
        lda shift
        rts

; one bit into shift (C = the bit that falls out)
get_bit
        lda #$10
-       bit $dc0d                       ; a pulse
        beq -
        lda $dc0e                       ; the timer still running: a short pulse, 0
        eor #1
        lsr a
        rol shift
        lda #$19                        ; one-shot, loaded again, started
        sta $dc0e
        lda shift
        sta $d020
        rts

shift   .byte 0
sum     .byte 0
head    .fill 6
        .here
        .cerror * - loader_src > 256, "the loader is longer than a page"
