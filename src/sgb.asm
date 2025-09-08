; Slightly customized sgb.asm for SGB Dumper.

SECTION "SGB util", ROM0

SGB_SEND_PACKET::
	ld	B,A
	ld	C,$00
.nextpacket
	push	BC
	ld	A,$00
	ld	[$ff00+C],A
	ld	A,$30
	ld	[$ff00+C],A
	ld	B,$10
.nextbyte
	ld	E,$08
	ld	A,[HL+]
	ld	D,A
.nextbit
	bit	0,D
	ld	A,$10
	jr	nz,.is1
	ld	A,$20
.is1
	ld	[$ff00+C],A
	ld	A,$30
	ld	[$ff00+C],A
	rr	D
	dec	E
	jr	nz,.nextbit
	dec	B
	jr	nz,.nextbyte
	ld	A,$20
	ld	[$ff00+C],A
	ld	A,$30
	ld	[$ff00+C],A

	ld	A,[skip_sgb_delay]
	or	A
	call	z,SGB_PACKETDELAY

	pop	BC
	dec	B
	ret	z

	jr	.nextpacket

SGB_PACKETDELAY::
	ld	DE,$1B58
.delayloop
	nop  
	nop  
	nop  
	dec	DE
	ld	A,D
	or	E
	jr	nz,.delayloop
	ret  

; Returns A=0 if not SGB, or A=1 if SGB.
SGB_TEST::
	ld	A,1
	ld	HL,MLT_REQ
	call	SGB_SEND_PACKET

	ldh	A,[$FF00]
	and	$03
	cp	$03
	jr	nz,.sgb_detected

	ld	A,$20
	ldh	[$FF00],A
	push	AF
	pop	AF
	ld	A,$30
	ldh	[$FF00],A
	ld	A,$10
	ldh	[$FF00],A
	push	AF
	pop	AF
	push	AF
	pop	AF
	ld	A,$30
	ldh	[$FF00],A
	push	AF
	pop	AF
	push	AF
	pop	AF
	ldh	A,[$FF00]
	and	$03
	sub	$03
	jr	nz,.sgb_detected

	ret
.sgb_detected
	ld	A,1
	ld	HL,MLT_REQ_DISABLE
	call	SGB_SEND_PACKET
	ld	A,1
	ret

MLT_REQ::
	DB $89,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

MLT_REQ_DISABLE::
	DB $89,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
