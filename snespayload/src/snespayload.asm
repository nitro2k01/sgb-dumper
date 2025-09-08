.include "snes.inc"

SOURCE_BUFFER  = $600               ; Base address for where the SGB firmware stores the last received index 0 SGB packet.
PARAM_OP       = SOURCE_BUFFER + $7 ; 1 byte
PARAM_DELAY    = SOURCE_BUFFER + $8 ; 2 bytes
PARAM_ADDR     = SOURCE_BUFFER + $A ; 2 bytes
PARAM_BANK     = SOURCE_BUFFER + $C ; 1 byte
PARAM_LENGTH   = SOURCE_BUFFER + $D ; 2 bytes
PARAM_SPEED    = SOURCE_BUFFER + $F ; 1 byte

SGB_RMS        = $6003              ; Reset/multiplayer/speed. (Is there an official name for this register?)
SGB_CONTROLLER = $6004              ; Controller data.
SGB_ICD2REV    = $600F              ; ICD2 chip revision.

.smart +
.segment "code"
.proc irq_handler
zero:
        php

        ; Modify code to set base read address bank.
        lda PARAM_BANK
        sta send_loop_lda+3
        sta checksum_loop_lda+3

        ; Temporarily set 16 bit A to copy a 16 bit value.
        SetM16

        ; Modify code to set base read address.
        lda PARAM_ADDR
        sta send_loop_lda+1
        sta checksum_loop_lda+1

        SetM8
        SetXY16

        lda #%11111111          ; Pre-sync (inactive)
        sta SGB_CONTROLLER
        jsr wait_some_time

        ; Send data.
        lda PARAM_SPEED         ; Overclock the GB CPU?
        and #1                  ; Filter out only bit 0 to ensure the GB CPU isn't reset and number of controllers is 1.
        eor #%10000001          ; Bit 7=run. Bit 0 is inverted so 0=no overclock, 1=overclock.
        sta SGB_RMS

        lda PARAM_OP
        dea                     ; ==1?
        beq calc_checksum

        lda #%11111000          ; Sync 1
        sta SGB_CONTROLLER

        jsr wait_some_time


        lda #%11111111          ; Sync 2
        sta SGB_CONTROLLER

        ldx #$0                 ; Index for the read address.

send_loop:
        .a8
        .i16
        jsr wait_some_time
send_loop_lda:                  ; Label used for code modification.
        lda $108000,x
        jsr send_and_wait       ; Send bits 210
        jsr send_and_wait       ; Send bits 543
        jsr send_and_wait       ; Send bits x76

        inx
        cpx PARAM_LENGTH

        bne send_loop

cleanup_and_exit:
        ; Clean up and return.
        plp                     ; Restore XY and A mode to 8 bit.
        lda #%11111111          ; Inactive.
        sta SGB_CONTROLLER

        lda #%10000001          ; Run, one controller, 4 MHz
        sta SGB_RMS
        lda TIMEUP              ; Acknowledge the IRQ that's inevitably pending. (Not mandatory but prevents an ugly 1 frame glitch.)
        cli                     ; Enable interrupts.
        rts

; Send one byte fragment and wait the specified amount.
send_and_wait:
        .a8
        .i16
        pha
        and #%00000111
        sta SGB_CONTROLLER
        jsr wait_some_time
        lda #$ff
        sta SGB_CONTROLLER
        jsr wait_some_time
        pla
        lsr a
        lsr a
        lsr a
        rts

wait_some_time:
        .a8
        .i16
        phx
        ldx PARAM_DELAY
        beq wait_zero
wait_loop:
        dex
        bne wait_loop
wait_zero:
        plx
        rts

calc_checksum:
        lda #%11111000          ; Signal busy calculating checksum.
        sta SGB_CONTROLLER

        SetXY16

        lda #0
        ldx #0
        txy
checksum_loop:
        clc                     ; Clear carry because 65xx only has add *with* carry.
checksum_loop_lda:              ; Label used for code modification.
        adc $108000,x
        bcc skip
        iny
skip:
        inx
        cpx PARAM_LENGTH
        bne checksum_loop
checksum_end:
        sta $1A00               ; \ Save the calculated checksum somewhere in RAM well clear of the code.
        sty $1A01               ; /

        jmp cleanup_and_exit


.endproc

