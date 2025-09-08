include "incs/hardware.inc"

; Slightly customized util.asm for SGB Dumper.

SECTION "Util", ROM0
; Simple, slow memcopy.
; HL=Source.
; DE=Destination.
; BC=Length.
COPY::
	ld	A,[HL+]
	ld	[DE],A
	inc	DE
	dec	BC
	ld	A,B
	or	C
	jr	nz,COPY
	ret

; Compares up to 256 bytes of memory.
; HL=String 1
; DE=String 2
; B =Length
; Return values: 
; A==0, z if the strings are equal or A!=0, nz if not equal.
; HL and DE point to the first non-matching bytes.
MEMCMP_SMALL::
:	ld	A,[DE]
	sub	[HL]
	ret	nz
	inc	DE
	inc	HL
	dec	B
	jr	nz,:-
	ret

; Clears memory in 256 byte chunks up to a page boundary.
; E=Value to clear with.
; HL=Start address.
; B=End address (Exclusive.)
; Example: To clear WRAM:
; E=0 HL=$C000 B=$E0
FASTCLEAR::
	ld	A,E
	;xor	A
	ld	C,64
.loop::
	ld	[HL+],A
	ld	[HL+],A
	ld	[HL+],A
	ld	[HL+],A
	dec	C
	jr	nz,.loop
	ld	A,H
	cp	B
	ret	z
	jr	FASTCLEAR

; Minimal print function
MPRINT::
	ld	A,[HL+]
	or	A
	ret	z
	cp	"\n"
	jr	z,.nextrow
	ld	[DE],A
	inc	DE
	jr	MPRINT
.nextrow
	ld	A,E
	and	$E0
	add	$20
	ld	E,A
	jr	nc,MPRINT
	inc	D
	jr	MPRINT

; Print one hexadecimal byte.
PRINTHEX::
	push	BC
	ld	B,HIGH(SCRUBBER)
	ld	C,A
	ld	A,[BC]
	pop	BC
PRINTHEX_GBI_UNSAFE::
	ld	E,A
	swap	A
	call	PRINTHEX_DIGIT
	ld	A,E
PRINTHEX_DIGIT::
	and	$0F
	add	$70
	cp	$7A
	jr	c,.noupper
	add	7
.noupper
	ld	[HL+],A
	ret

; Print one hexadecimal byte, using "nitrocopy".
PRINTHEX_FORCE::
	push	BC
	ld	B,HIGH(SCRUBBER)
	ld	C,A
	ld	A,[BC]
	pop	BC
	ld	E,A
	swap	A
	call	PRINTHEX_DIGIT_FORCE
	ld	A,E
PRINTHEX_DIGIT_FORCE::
	and	$0F
	add	$70
	cp	$7A
	jr	c,.noupper
	add	7
.noupper
.confirm
	ld	[HL],A
	cp	[HL]
	jr	nz,.confirm
	inc	HL
	ret


READ_JOYPAD::
	ld	A,P1F_GET_DPAD
	ldh	[rP1],A
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	cpl
	and	$0F
	swap	A
	ld	B,A
	ld	A,P1F_GET_BTN
	ldh	[rP1],A
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	ldh	A,[rP1]
	cpl
	and	$0F
	or	B
	ld	C,A
	ld	A,[joypad_held]
	xor	C
	and	C
	ld	[joypad_pressed],A
	ld	A,C
	ld	[joypad_held],A
	ld	A,P1F_GET_NONE
	ldh	[rP1],A
	ret
