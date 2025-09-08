; The old payloads used for simple testing of code execution. Included for posterity. 
; Enable the thing you want to assemble by changing .if 0 to .if 1.
.if 0
	lda #%10000001		; Run, one controller, 4 MHz
	sta	$6003
testloop:
	lda #0
	tax
waitloop:
	nop
	nop
	nop
	nop
	dex
	bne waitloop

	sta	$6004			; Store data iun controller register data
	ina
	bne	waitloop
	rts
.endproc
.endif

.if 0
.proc irq_handler
	clc
testloop:
	lda #0
	inx
	stx	BG1HOFS
	sta	BG1HOFS
	stx	BG2HOFS
	sta	BG2HOFS
	stx	BG3HOFS
	sta	BG3HOFS
	stx	BG3HOFS
	sta	BG3HOFS


	bra testloop
  rti
.endproc	
.endif