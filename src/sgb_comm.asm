include "incs/hardware.inc"

; Set bits 4 and 5 high, to match what is read back from P1.
DEF P1F_GET_DPAD_STUFFED EQU (P1F_GET_DPAD|$C0)
DEF DUMP_TARGET = $C000

SECTION "SGB communication", ROM0
WAIT_CHECKSUM_BUSY::
	ld	A,P1F_GET_DPAD
	ld	[rP1],A
:	ldh	A,[rP1]
	and	$0F
	cp	$08
	jr	nz,:-
	ret

WAIT_CHECKSUM_NOT_BUSY::
	ld	A,P1F_GET_DPAD
	ld	[rP1],A
:	ldh	A,[rP1]
	and	$0F
	cp	$08
	jr	z,:-
	ret

GET_HEADER::
	; Set up the end condition for receiving data.
	ld	A,L
	add	32
	ldh	[end_addr],A
	ld	A,H
	adc	0
	ldh	[end_addr+1],A

	push	HL
	ld	A,1			; Number of packets AND skip delay flag
	ldh	[skip_sgb_delay],A
	ld	HL,SGB_DATA_JUMP_GET_HEADER
	call	SGB_SEND_PACKET
	pop	HL
	jr	RECEIVE_DATA_FROM_SGB

GET_CHECKSUM::
	; Set up the end condition for receiving data.
	push	HL
	inc	HL
	inc	HL
	ld	A,L
	ldh	[end_addr],A
	ld	A,H
	ldh	[end_addr+1],A

	ld	A,1			; Number of packets AND skip delay flag
	ldh	[skip_sgb_delay],A
	ld	HL,SGB_DATA_JUMP_GET_CHECKSUM
	call	SGB_SEND_PACKET
	pop	HL
	jr	RECEIVE_DATA_FROM_SGB

GET_ICD::
	; Set up the end condition for receiving data.
	push	HL
	inc	HL
	ld	A,L
	ldh	[end_addr],A
	ld	A,H
	ldh	[end_addr+1],A

	ld	A,1			; Number of packets AND skip delay flag
	ldh	[skip_sgb_delay],A
	ld	HL,SGB_DATA_JUMP_GET_ICD
	call	SGB_SEND_PACKET
	pop	HL
	jr	RECEIVE_DATA_FROM_SGB

GET_ROM::
	; Set up the end condition for receiving data.
	ld	A,L
	ldh	[end_addr],A
	ld	A,H
	add	$20
	ldh	[end_addr+1],A

	push	HL
	ld	A,1			; Number of packets AND skip delay flag
	ldh	[skip_sgb_delay],A
	ld	HL,sgb_cmd
	call	SGB_SEND_PACKET
	pop	HL
	jr	RECEIVE_DATA_FROM_SGB


RECEIVE_DATA_FROM_SGB::
	di
	ld	C,LOW(rP1)
	ld	A,P1F_GET_DPAD
	ld	[$FF00+C],A

;	ld	HL,DUMP_TARGET

; Wait for neutral/no buttons pressed.
	ld	DE,$4000
:	dec	DE
	ld	A,E
	or	D
	jr	z,.timeout
	ld	A,[$FF00+C]
	cp	P1F_GET_DPAD_STUFFED|%1111
	jr	nz,:-

; Wait for sync value.
	ld	DE,$4000
:	dec	DE
	ld	A,E
	or	D
	jr	z,.timeout
	ld	A,[$FF00+C]
	cp	P1F_GET_DPAD_STUFFED|%1000
	jr	nz,:-

	; D=Sync mask. E=Data mask.
	ld	DE,%00001000_00000111		

.rcv_loop

; Receive first fragment of the byte, .....xxx
; Wait for neutral/no buttons pressed.
:	ld	A,[$FF00+C]
	cp	P1F_GET_DPAD_STUFFED|%1111
	jr	nz,:-

; Wait for sync bit, D3=0.
:	ld	A,[$FF00+C]
	and	D
	jr	nz,:-
	ld	A,[$FF00+C]
	; 11100xxx
	and	E		; %0000111
	ld	B,A		; 00000xxx

; Receive second fragment of the byte, ..yyy...
; Wait for neutral/no buttons pressed.
:	ld	A,[$FF00+C]
	cp	P1F_GET_DPAD_STUFFED|%1111
	jr	nz,:-

; Wait for sync bit, D3=0.
:	ld	A,[$FF00+C]
	and	D
	jr	nz,:-
	ld	A,[$FF00+C]
	
	; Shift bits into place
	; 11100yyy
	add	A		; 1100yyy0
	add	A		; 100yyy00
	add	A		; 00yyy000
	or	B		; 00yyyxxx
	ld	B,A

; Receive third fragment of the byte, xx......
; Wait for neutral/no buttons pressed.
:	ld	A,[$FF00+C]
	cp	P1F_GET_DPAD_STUFFED|%1111
	jr	nz,:-

; Wait for sync bit, D3=0.
:	ld	A,[$FF00+C]
	and	D
	jr	nz,:-
	ld	A,[$FF00+C]

	; Shift (rotate) bits into place
	; 111000zz
	and	E			; 000000zz
	rrca				; z000000z
	rrca				; zz000000
	or	B			; zzyyyxxx
	ei
	ld	[HL+],A
	ldh	A,[end_addr]
	di
	cp	L
	jr	nz,.rcv_loop
	ldh	A,[end_addr+1]
	cp	H
	jr	nz,.rcv_loop
	reti
.timeout
	;ret				; Return instead for debugging in BGB.
	jp	SGB_FAIL

SEND_SGB_PAYLOAD::
	xor	A
	ldh	[skip_sgb_delay],A	; 0 = Don't skip delay.
	ld	HL,SGB_DATA_SND_PREAMBLE
	ld	DE,DATA_BUFFER
	ld	BC,SGB_DATA_SND_PREAMBLE.end-SGB_DATA_SND_PREAMBLE
	call	COPY

	ld	HL,SGB_PAYLOAD
	ld	B,(SGB_PAYLOAD.end-SGB_PAYLOAD)/$0B+1

.packetloop
	ld	C,$0B			; Number of bytes in one transfer
	ld	DE,DATA_BUFFER+5	; First data byte.
:	ld	A,[HL+]
	ld	[DE],A
	inc	E
	dec	C
	jr	nz,:-

	push	BC
	push	HL
	ld	A,1
	ld	HL,DATA_BUFFER
	call	SGB_SEND_PACKET

	ld	HL,DATA_BUFFER+1	; Destination
	ld	A,[HL]
	add	$0B			; Adjust destination pointer
	ld	[HL+],A
	jr	nc,:+
	inc	[HL]
:
	pop	HL
	pop	BC



	dec	B
	jr	nz,.packetloop


	ret



SGB_PAYLOAD:
	incbin "../snespayload/build/snespayload.bin"
.end
	ds	16,0	; Fill the spillover with 00, yolo.


SGB_DATA_SND_PREAMBLE::
	db	$0f<<3|1	; DATA_SND, fixed length 1
	dw	$1800		; Destination
	db	0		; Bank
	db	$0B		; Number of bytes
.end

SGB_DATA_JUMP::
	db	$12<<3|1	; JUMP, fixed length 1
	dw	$1800		; Jump address
	db	0		; Jump bank
	dw	$1800		; NMI address
	db	0		; NMI bank
	; Extra data byte
	db	0		; Operation
	dw	$40		; Delay
	dw	$8000		; Address
	db	0		; Bank
	dw	$20		; Number of bytes
	db	0		; Overclock

SGB_DATA_JUMP_GET_ROM::
	db	$12<<3|1	; JUMP, fixed length 1
	dw	$1800		; Jump address
	db	0		; Jump bank
	dw	$1800		; NMI address
	db	0		; NMI bank
	; Extra data byte
	db	0		; Operation
	dw	$40		; Delay
	dw	$8000		; Address
	db	0		; Bank
	dw	$2000		; Number of bytes
	db	0		; Overclock

SGB_DATA_JUMP_CALC_CHECKSUM::
	db	$12<<3|1	; JUMP, fixed length 1
	dw	$1800		; Jump address
	db	0		; Jump bank
	dw	$1800		; NMI address
	db	0		; NMI bank
	; Extra data byte
	db	1		; Operation (calc checksum)
	dw	$40		; Delay
	dw	$8000		; Address
	db	0		; Bank
	dw	$2000		; Number of bytes
	db	0		; Overclock

SGB_DATA_JUMP_GET_CHECKSUM::
	db	$12<<3|1	; JUMP, fixed length 1
	dw	$1800		; Jump address
	db	0		; Jump bank
	dw	$1800		; NMI address
	db	0		; NMI bank
	; Extra data byte
	db	0		; Operation
	dw	$40		; Delay
	dw	$1A00		; Address
	db	0		; Bank
	dw	$2		; Number of bytes
	db	0		; Overclock

SGB_DATA_JUMP_GET_HEADER::
	db	$12<<3|1	; JUMP, fixed length 1
	dw	$1800		; Jump address
	db	0		; Jump bank
	dw	$1800		; NMI address
	db	0		; NMI bank
	; Extra data byte
	db	0		; Operation
	dw	$40		; Delay
	dw	$FFC0		; Address
	db	0		; Bank
	dw	$20		; Number of bytes
	db	0		; Overclock

SGB_DATA_JUMP_GET_ICD::
	db	$12<<3|1	; JUMP, fixed length 1
	dw	$1800		; Jump address
	db	0		; Jump bank
	dw	$1800		; NMI address
	db	0		; NMI bank
	; Extra data byte
	db	0		; Operation
	dw	$40		; Delay
	dw	$600F		; Address
	db	0		; Bank
	dw	$1		; Number of bytes
	db	0		; Overclock
