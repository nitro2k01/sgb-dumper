include "incs/hardware.inc"

SECTION "SGB graphics", ROM0

INIT_SGB_GFX::
	; Do one round of delay to make sure the current screen is registered before sending the mask command.
	call	SGB_PACKETDELAY
	ld	A,1
	ld	HL,MASK_FREEZE
	call	SGB_SEND_PACKET
	call	SGB_PACKETDELAY

	; Transfer block 0 of tile data.
	rst	WAIT_VBL

	xor	A
	ld	[rLCDC],A

	; Use the second BG map.
	ld	HL,$9C00
	call	INIT_MAP_SGBTRANSFER

	ld	HL,TILES_SGB1
	ld	DE,$8000
	ld	BC,TILES_SGB1.end-TILES_SGB1
	call	COPY

	ld	A,LCDCF_ON|LCDCF_BG8000|LCDCF_BG9C00|LCDCF_BGON
	ldh	[rLCDC],A
	rst	WAIT_VBL

	ld	A,1
	ld	HL,CHR_TRN_0
	call	SGB_SEND_PACKET

	; Transfer block 1 of tile data.
	rst	WAIT_VBL

	xor	A
	ld	[rLCDC],A

	; Use the second BG map.
	ld	HL,$9C00
	call	INIT_MAP_SGBTRANSFER

	ld	HL,TILES_SGB2
	ld	DE,$8000
	ld	BC,TILES_SGB2.end-TILES_SGB2
	call	COPY

	ld	A,LCDCF_ON|LCDCF_BG8000|LCDCF_BG9C00|LCDCF_BGON
	ldh	[rLCDC],A
	rst	WAIT_VBL

	ld	A,1
	ld	HL,CHR_TRN_1
	call	SGB_SEND_PACKET

	; Transfer map data.
	rst	WAIT_VBL

	xor	A
	ld	[rLCDC],A

	; Use the second BG map.
	ld	HL,$9C00
	call	INIT_MAP_SGBTRANSFER

	ld	HL,MAP_SGB
	ld	DE,$8000
	ld	BC,MAP_SGB.end-MAP_SGB
	call	COPY

	ld	A,LCDCF_ON|LCDCF_BG8000|LCDCF_BG9C00|LCDCF_BGON
	ldh	[rLCDC],A
	rst	WAIT_VBL

	ld	A,1
	ld	HL,PCT_TRN
	call	SGB_SEND_PACKET

	ld	A,1
	ld	HL,PAL_01
	call	SGB_SEND_PACKET

	; Do some cleanup afterwards.
	rst	WAIT_VBL

	xor	A
	ldh	[rLCDC],A


	; Clear the map junk from the second map.
	ld	HL,$9C00
	ld	B,$A0			; Top byte of end address
	ld	E,L			; L==0
	call	FASTCLEAR

	; Clear the tile junk in tiles 00-1F.
	ld	HL,$8000
	ld	B,$82			; Top byte of end address
	ld	E,L			; L==0
	call	FASTCLEAR

	; Clear a couple of other tile gaps. (Not strictly necessary.)
	ld	HL,$8580
	ld	B,$86			; Top byte of end address
	ld	E,0
	call	FASTCLEAR

	ld	HL,$8D80
	ld	B,$90			; Top byte of end address
	ld	E,0
	call	FASTCLEAR

	; Reinitialize the tileset that we want to use after the SGB transfer.
	call	INIT_TILESET


	; Re-enable LCDC with the right settings.
	ld	A,LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON
	ldh	[rLCDC],A

	rst	WAIT_VBL


;:	jr	:-

	ld	A,1
	ld	HL,MASK_DISABLE
	call	SGB_SEND_PACKET

	ret

INIT_MAP_SGBTRANSFER::
	xor	A
	ld	DE,32-20
:	ld	C,20
:	ld	[HL+],A
	inc	A
	ret	z
	dec	C
	jr	nz,:-
	add	HL,DE
	jr	:--

TILES_SGB1:
	incbin "sgb_border_tiles.bin",0,4096
.end
TILES_SGB2:
	incbin "sgb_border_tiles.bin",4096
.end

MAP_SGB:
	incbin "sgb_border_map.bin"
	ds 64,0
	ds 3*64,0
	incbin "sgb_border_palettes.bin"
.end

; Emit GBC palette entry.
; The color components are 5 bit. (0-31)
; PAL_ENTRY R,G,B
PAL_ENTRY:	MACRO
	assert (\1)==(\1)&%11111
	assert (\2)==(\2)&%11111
	assert (\3)==(\3)&%11111
	dw	(\1) | (\2)<<5| (\3)<<10
ENDM


PAL_01:
	db $01
	PAL_ENTRY 31,31,31
	PAL_ENTRY 24,24,24
	PAL_ENTRY 12,12,12
	PAL_ENTRY 0,0,0

	; Status
	PAL_ENTRY 0,24,0
	PAL_ENTRY 31,0,0
	PAL_ENTRY 0,0,0


MASK_FREEZE:
	DB $B9,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
MASK_DISABLE:
	DB $B9,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

CHR_TRN_0:
	db $99,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
CHR_TRN_1:
	db $99,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

PCT_TRN:
	db $A1,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

ATTR_BLK_STATUS::
	db 4*8+1
	db $01			; Number of datasets
	db $03			; Change inside
	db $05			; Which palette. (Bits 0-1)
	db 11,2,14,17		; X1 (left) Y1 (upper) X2 (right) Y2 (lower)