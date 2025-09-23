include "incs/hardware.inc"

; Default: 1. Change to 0 to knock out all checks for valid SGB LLE for debugging the menu.
DEF CHECK_SGB_ACE = 1
; Default: 0. Change to 1 to show the LY value after the menu is done printing each frame.
DEF MENU_SHOW_LY = 0

; Load a r16 with a pointer to map at coordinate x,y
; LDXY r16, x, y
LDXY:	MACRO
	ld	\1,($9800+(\2)+32*(\3))
	ENDM

LDXY2:	MACRO
	ld	\1,($9C00+(\2)+32*(\3))
	ENDM

STXY:	MACRO
	ld	[($9800+(\1)+32*(\2))],A
	ENDM

; Emit GBC palette entry.
; The color components are 5 bit. (0-31)
; PAL_ENTRY R,G,B
PAL_ENTRY:	MACRO
	assert (\1)==(\1)&%11111
	assert (\2)==(\2)&%11111
	assert (\3)==(\3)&%11111
	dw	(\1) | (\2)<<5| (\3)<<10
ENDM

DEF charlist EQUS "\" !\\\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ\""
DEF charlist_alpha EQUS "\" ABCDEFGHIJKLMNOPQRSTUVWXYZ\""
; Empty charmap for use with the reference string in the SGB header.
NEWCHARMAP default_raw
; Prepare default charmap for general strings.
NEWCHARMAP default
DEF charnum = 0
REPT STRLEN(charlist)
	CHARMAP STRSUB(charlist,charnum+1,1),charnum+$20
	DEF charnum += 1
ENDR
CHARMAP "\n",10

; Prepare deafult charmap for shaded strings.
NEWCHARMAP shaded
DEF charnum = 0
REPT STRLEN(charlist)
	CHARMAP STRSUB(charlist,charnum+1,1),charnum+$60
	DEF charnum += 1
ENDR
PURGE charnum
CHARMAP "\n",10

; Prepare deafult charmap for dark shaded strings.
NEWCHARMAP shaded_dark
DEF charnum = 0
REPT STRLEN(charlist_alpha)
	CHARMAP STRSUB(charlist_alpha,charnum+1,1),charnum+$E0
	DEF charnum += 1
ENDR
PURGE charnum
CHARMAP "\n",10

; Prepare deafult charmap for inverted strings.
NEWCHARMAP inverted
DEF charnum = 0
REPT STRLEN(charlist)
	CHARMAP STRSUB(charlist,charnum+1,1),charnum+$A0
	DEF charnum += 1
ENDR
PURGE charnum
CHARMAP "\n",10


SETCHARMAP default


;	CHARMAP strsub("ABC",1,1),$42



SECTION "Rst00", ROM0[$0]
	ret

SECTION "Rst08", ROM0[$8]
	ldh	A,[rBGP]
	cpl
	ldh	[rBGP],A

:	di
	jr	:-
	;ret
SECTION "Rst10", ROM0[$10]
	ret
SECTION "Rst18", ROM0[$18]
	ret
SECTION "Rst20", ROM0[$20]
WAIT_VRAM_ACCESSIBLE::
	push	AF
:	ldh	A,[rSTAT]
	and	STATF_BUSY
	jr	nz,:-
	pop	AF
;	ret			; Fallthrough into rst $28
SECTION "Rst28", ROM0[$28]
	ret


SECTION "Rst30", ROM0[$30]
WAIT_VBL::
.waitvbl
	ldh	A,[rLY]
	cp	$90
	jr	nz,.waitvbl
	ret
SECTION "Rst38", ROM0[$38]
:
	ld	b,b
	jr	:-

SECTION "int_vbl", ROM0[$40]
	reti

SECTION "int_lcd", ROM0[$48]
	reti
SECTION "int_timer", ROM0[$50]
	reti
SECTION "int_serial", ROM0[$58]
	reti
SECTION "int_joy", ROM0[$60]
	reti

SECTION "intret", ROM0
default_intret:
	pop	HL
	pop	DE
	pop	BC
	pop	AF
	reti


SECTION "Header", ROM0[$100]
	di				; 1
	jp	ENTRY			; 4

	ds	$150 - @, 0		; Fill up the header area and let rgbfix deal with it.

SECTION "Main", ROM0
ENTRY::
	; Save the boot registers.
	ld	SP,boot_regs.top
	push	AF
	push	BC
	push	DE
	push	HL

	ld	SP,Stack.top

	; Prevent the logo from being visible.
	xor	A
	ldh	[rBGP],A

	; Turn off LCD.
	ldh	A,[rLCDC]
	add	A
	jr	nc,.alreadyoff
.waitvbl
	ldh	A,[rLY]
	cp	$90
	jr	c,.waitvbl

.alreadyoff
	xor	A
	ldh	[rLCDC],A
	inc	A
	ld	[rROMB0],A

	; Clear WRAM.
	ld	HL,$C000
	ld	B,$E0			; Top byte of end address
	ld	E,L			; L==0
	call	FASTCLEAR

	; Clear OAM.
	ld	HL,$FEFF
	ld	A,$c0
:	dec	L
	ld	[HL],A
	jr	nz,:-

	; Clear HRAM plus IF. (This also overwrites the stack but that's fine since nothing is on the stack atm.)
	xor	A
	ld	C,LOW(clear_after_here)
:	ld	[$FF00+C],A
	inc	C
	jr	nz,:-

	; Clear the tiles/map.
	ld	HL,$9800
	ld	B,$9C			; Top byte of end address
	ld	E,L			; L==0
	call	FASTCLEAR

	ld	A,%11100100
	ldh	[rBGP],A

	call	INIT_TILESET

	; Print the main screen contents.
	ld	HL,S_ALL
	LDXY	DE,0,0
	call	MPRINT

	; Analyze system type based on the boot ROM regs.
	ld	HL,boot_regs
	ld	DE,BOOTREGS_SGB1
	ld	B,8
	call	MEMCMP_SMALL
	ld	HL,S_SGB1
	jr	z,.print_boot_type

	ld	HL,boot_regs
	ld	DE,BOOTREGS_SGB2
	ld	B,8
	call	MEMCMP_SMALL
	ld	HL,S_SGB2
	jr	z,.print_boot_type

	ld	HL,S_NOSGB

.print_boot_type
	LDXY	DE,5,1
	call	MPRINT

	xor	A
	ldh	[rSCX],A
	ldh	[rSCY],A

	ld	A,LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON
	ldh	[rLCDC],A

	; TODO: needed?
	xor	A
	ldh	[rIF],A
	inc	A
	ldh	[rIE],A
	ei
	halt
	nop

PUSHC
SETCHARMAP shaded
	; Detect presence of SGB through MLT_REQ
	;jp	SGB_FAIL		; debug
	call	SGB_TEST		; A == $01 if SGB or $00 is no SGB.
	dec	A			; A == $00 if SGB or $FF is no SGB.
	and	"N"-"Y"			; A == $00 if SGB or "N"-"Y" is no SGB.
	add	"Y"			; A == "Y" if SGB or "N" is no SGB.

	rst	WAIT_VRAM_ACCESSIBLE

	; Print whether MLT_REQ succeeded.
	STXY	$13,1

	; This is the value we have...
	sub	"N"
POPC
	jp	z,SGB_FAIL

	rst	WAIT_VBL
	ld	DE,$9880
	ld	HL,S_SENDING_BORDER
	call	MPRINT

	call	INIT_SGB_GFX		; Send border

	rst	WAIT_VBL
	ld	DE,$9880
	ld	HL,S_SENDING_PAYLOAD
	call	MPRINT

	call	SEND_SGB_PAYLOAD

if CHECK_SGB_ACE	; Change to 0 to knock out all checks for valid SGB LLE for debugging the menu.
	ld	HL,DATA_BUFFER
	call	GET_HEADER	

	ld	HL,DATA_BUFFER
	ld	DE,REF_SGB_HEADER_TITLE
	ld	B,8
	call	MEMCMP_SMALL
	ld	HL,S_OK
	jr	z,.print_header
	ld	HL,S_QMARKS
.print_header
	LDXY	DE,$d,$2
	; debug
;	jr	:+
	rst	WAIT_VBL
;	db	0
;	rst	$08
;	nop
;	db 0,0
;	jp	CRASH_MII
	call	MPRINT

:
	; Print ACE:Y

	LDXY	DE,$4,$2
PUSHC
SETCHARMAP shaded
	ld	A,"Y"
POPC
	ld	[DE],A

	; Get ROM size from SNES header
	ld	A,[DATA_BUFFER+$17]
	cp	$08				; 128k?
	ld	A,$20
	jr	z,:+
	add	A
:	ldh	[transfer_rom_total_size],A

	; Get revision byte
	ld	A,[DATA_BUFFER+$1B]

	ld	HL,S_SGB2
	cp	$10
	jr	z,.print_rev

	ld	HL,S_UNKN
	cp	3
	jr	nc,.print_rev
	LDXY	DE,$6,$3
	add	$70
	ld	[DE],A
	ld	HL,S_V1_
.print_rev
	LDXY	DE,$3,$3
	;rst	WAIT_VBL
	call	MPRINT

	rst	WAIT_VBL
	LDXY	DE,$12,4
	ld	HL,S_OK
	call	MPRINT

	ld	HL,DATA_BUFFER+$20
	call	GET_ICD

	rst	WAIT_VBL
	ld	A,[DATA_BUFFER+$20]
	ldh	[sstat_icd],A

	LDXY	HL,$C,$3
	call	PRINTHEX

else
	; If we're not checking for ACE, at least fill in a default size value to allow the size setting to function.
	ld	A,$20
	ldh	[transfer_rom_total_size],A
endc
	call	SHOW_MENU
	call	DO_DUMP


	jr	@

	; Init the standard tileset used by the test ROM.
INIT_TILESET::
	; Load a font into tile RAM.
	ld	HL,basetiles
	ld	DE,$8200
	ld	BC,basetiles.end-basetiles
	call	COPY

	; Load a second copy of font into tile RAM for use with menu highlighting.
	ld	HL,basetiles
	ld	DE,$8600
	ld	BC,basetiles.end-basetiles
	call	COPY

	; Apply shading to the second charset.
	ld	HL,$8600
	ld	B,$8A			; End tile
:	ld	[HL],$FF
	inc	L
	inc	HL
	ld	A,H
	cp	B
	jr	nz,:-

	; Load a third copy of font into tile RAM to be inverted for the caption.
	ld	HL,basetiles
	ld	DE,$8A00
	ld	BC,basetiles.end-basetiles
	call	COPY

	; Invert the third charset.
	ld	HL,$8A00
	ld	B,$8E			; End tile
:	ld	A,[HL]
	cpl
	ld	[HL+],A
	ld	A,H
	cp	B
	jr	nz,:-

	; Dark gray shaded, only alpha.
	ld	HL,basetiles+$200
	ld	DE,$8E00
	ld	BC,basetiles.end-basetiles-$200
	call	COPY

	; Apply dark shading to the second charset.
	ld	HL,$8E00
	ld	B,$90			; End tile
:	inc	L
	ld	[HL],$FF
	inc	HL
	ld	A,H
	cp	B
	jr	nz,:-


	ret

DO_DUMP:
	;
	ld	A,1
	ld	HL,ATTR_BLK_STATUS
	call	SGB_SEND_PACKET

	rst	WAIT_VBL

	ld	A,LCDCF_ON|LCDCF_BG8000|LCDCF_BG9800|LCDCF_BGON|LCDCF_WINON|LCDCF_WIN9C00
	ldh	[rLCDC],A

	xor	A				; One row below top of screen. (Keep title visible.)
	ldh	[rWY],A
	ld	A,7				; Left side of screen.
	ldh	[rWX],A


	LDXY2	DE,0,0
	ld	HL,S_DUMPING
	call	MPRINT

	; Calculate number of banks that exist in SRAM from the size setting.
	ldh	A,[transfer_size]
	; 0 = 8k (1 bank)
	; 1 = 32k (4 banks)
	; 2 = 64k (8 banks)
	; 3 = 128k (16 banks)
	or	A
	ld	B,A
	ld	A,1
	jr	z,:++
	add	A
:	add	A
	dec	B
	jr	nz,:-
:
	
	; Calculate transfer_size_banks*transfer_part
	; This is the offset into the SNES ROM that we're currently dumping.
	ldh	[transfer_size_banks],A
	ld	B,A

	ldh	A,[transfer_part]
	ld	C,A
	inc	C
	xor	A
:	add	B
	dec	C
	jr	nz,:-
	sub	B

	ld	[source_snes_rom_offset],A

	; Prepare VRAM for dumping. Print some info and the bank number on the left side.
	rst	WAIT_VBL

	; Print some info from the main screen that might be helpful to the user. (SRAM size and which part is being copied.)
	LDXY2	DE,$F,2
	ld	HL,S_DUMPSCREEN_INFO
	call	MPRINT

	ldh	A,[transfer_size]
	ld	D,0
	ld	E,A
	ld	HL,S_8K
rept 5
	add	HL,DE
endr
	LDXY2	DE,$F,3
	call	MPRINT	

	ldh	A,[transfer_part]
	LDXY2	HL,$F,5
	call	PRINTHEX
	inc	L
	ldh	A,[transfer_num_parts]
	call	PRINTHEX

	; Show bank column based on the setting
	ldh	A,[transfer_size_banks]
	ld	B,A				; Number of banks, countdown.
	ld	DE,32				; Next column in map.
	LDXY2	HL,0,2

	rst	WAIT_VBL

	; A little improvised print hex digit for speed.
	ld	A,"0"
:	ld	[HL],A
	add	HL,DE
	inc	A
	cp	"9"+1				; Hex 9->A transition.
	jr	nz,:+
	ld	A,"A"
:	dec	B
	jr	nz,:--

	; Copy base command to HRAM buffer.
	ld	HL,SGB_DATA_JUMP_GET_ROM
	ld	DE,sgb_cmd
	ld	BC,16
	call	COPY

	; Load the delay and overclock settings from the user settings to the SGB command.
	ldh	A,[transfer_delay]
	ldh	[sgb_cmd_jump.delay],A
	ldh	A,[transfer_overclock]
	ldh	[sgb_cmd_jump.overclock],A

	rst	WAIT_VBL

	ld	A,CART_SRAM_ENABLE
	ld	[rRAMG],A
	xor	A
	ldh	[target_ram_bank],A
.bank_loop
	call	CALC_SGB_EFFECTIVE_ADDRESS

	ldh	A,[target_ram_bank]		; Get current RAM bank again.
	ld	[rRAMB],A

	swap	A				; *16 when A in the range 0-F which should always be true here.
	LDXY2	HL,1,2
	ld	D,0
	ld	E,A
	add	HL,DE				; *16
	add	HL,DE				; *32

	ld	[HL],"<"

	push	HL
	call	WAIT_5_FRAMES		; Wait some frames before starting the next transfer to allow data to be drawn to the screen.
	ld	HL,$A000
	call	GET_ROM
	rst	WAIT_VBL
	pop	HL
	ld	[HL],"."	


	ld	A,[transfer_size_banks]
	ld	B,A
	ldh	A,[target_ram_bank]
	inc	A
	ldh	[target_ram_bank],A
	cp	B

	jr	nz,.bank_loop

	rst	WAIT_VBL

	; Dump finished. Check checksums both on the SNES side and locally.

	ld	HL,S_CHECKING_CHECKSUMS
	LDXY2	DE,0,0
	call	MPRINT

	call	WAIT_5_FRAMES		; Wait some frames before starting the next transfer to allow data to be drawn to the screen.


	xor	A
	ldh	[target_ram_bank],A
.bank_loop_checksum
	; Change parameters in the SGB packet to calculate the checksum.
	; The length should be filled in and always be the same.
	call	CALC_SGB_EFFECTIVE_ADDRESS	; Calculate and write the effective target address.

	ld	A,1
	ld	[sgb_cmd_jump.operation],A

	ld	A,1			; Number of packets AND skip delay flag
	ldh	[skip_sgb_delay],A
	ld	HL,sgb_cmd
	call	SGB_SEND_PACKET

	call	WAIT_CHECKSUM_BUSY	; Make sure we have a busy signal from the SNES.

	; Calculate the SRAM checksum while the SNES is doing its thing.
	ldh	A,[target_ram_bank]		; Get current RAM bank again.
	ld	[rRAMB],A

	call	CALC_CHECKSUM_SRAM
	ld	A,L
	ldh	[rom_checksum_gb],A
	ld	A,H
	ldh	[rom_checksum_gb+1],A


	call	WAIT_CHECKSUM_NOT_BUSY		; Make sure the SNES is done calculating the checksum.

	ld	HL,rom_checksum_snes
	call	GET_CHECKSUM			; Read the two bytes in SNES memory where the calculated checksum is stored.

	ldh	A,[target_ram_bank]		; Get current RAM bank again.
	swap	A				; *16 when A in the range 0-F which should always be true here.
	LDXY2	HL,2,2
	ld	D,0
	ld	E,A
	add	HL,DE				; *16
	add	HL,DE				; *32

	rst	WAIT_VBL

	ldh	A,[rom_checksum_snes+1]
	call	PRINTHEX
	ldh	A,[rom_checksum_snes]
	call	PRINTHEX

	inc	HL

	ldh	A,[rom_checksum_gb+1]
	call	PRINTHEX
	ldh	A,[rom_checksum_gb]
	call	PRINTHEX

	inc	HL
	ld	D,H				; MPRINT use DE as destination.
	ld	E,L

	ld	HL,S_BAD
	ldh	A,[rom_checksum_gb]
	ld	B,A
	ldh	A,[rom_checksum_snes]
	cp	B
	jr	nz,:+

	ldh	A,[rom_checksum_gb+1]
	ld	B,A
	ldh	A,[rom_checksum_snes+1]
	cp	B
	jr	nz,:+

	ld	HL,S_OK
:	call	MPRINT

	call	WAIT_3_FRAMES		; Wait some frames before starting the next transfer to allow data to be drawn to the screen.

	ld	A,[transfer_size_banks]
	ld	B,A
	ldh	A,[target_ram_bank]
	inc	A
	ldh	[target_ram_bank],A
	cp	B

	jr	nz,.bank_loop_checksum

	; Protect SRAM after the transfer is finished.
	xor	A
	ld	[rRAMG],A


	ld	HL,S_FINISHED
	LDXY2	DE,0,0
	call	MPRINT

	call	ENDLESS_HALT

	; Clamp the part and max part values based on the transfer size.
UPDATE_PART_LIMIT:
	ldh	A,[transfer_rom_total_size]
	ld	B,A
	ldh	A,[transfer_size]
	or	A
	jr	z,.is_8k
	sra	B
:	sra	B
	dec	A
	jr	nz,:-
.is_8k




	ldh	A,[transfer_part]
	cp	B
	jr	c,.no_clamp
	ld	A,B
	dec	A
	ldh	[transfer_part],A
.no_clamp
	ld	A,B
	ldh	[transfer_num_parts],A

	ret

	; Calculate and set the read address in the SGB packet
	; Input: [target_ram_bank] Index to a 8k bank of SRAM.
	; Output: [sgb_cmd_jump.bank]:[sgb_cmd_jump.address] The effective address to read in SNES ROM space, given as bank:address.
CALC_SGB_EFFECTIVE_ADDRESS:
	xor	A				; Lower byte is always zero
	ld	[sgb_cmd_jump.address],A

	ldh	A,[source_snes_rom_offset]
	ld	B,A
	ldh	A,[target_ram_bank]		; Get current RAM bank again.
	add	B

	; 0-3 -> $8000-$E000
	swap	A				; *16
	and	$F0				; mask
	add	A
	or	$80
	ld	[sgb_cmd_jump.address+1],A

	; 0,4,8,C->0,1,2,3
	ldh	A,[source_snes_rom_offset]
	ld	B,A
	ldh	A,[target_ram_bank]		; Get current RAM bank again.
	add	B
	rrca
	rrca
	and	$0F
	ld	[sgb_cmd_jump.bank],A
	ret

SHOW_MENU:
	xor	A
	ldh	[menu_pos],A
	ldh	[transfer_part],A

	; Don't allow the transfer to be started for about a second, because the border transfer is still fading in.
	; Menu movement is still allowed during this time to make the software as responsive as possible though.
	ld	A,60
	ldh	[warmup_delay],A
	
	; Check if ICD==00, meaning we're (probably) running in bsnes. If so, set longer delay.
	ldh	A,[sstat_icd]
	or	A
	ld	A,$20
	jr	z,:+
	ld	A,$2
:	ldh	[transfer_delay],A
	;ld	A,$1
	xor	A
	ldh	[transfer_overclock],A
	ld	A,$3
	ldh	[transfer_size],A

	rst	WAIT_VBL
	LDXY	DE,0,5
	ld	HL,S_MENU
	call	MPRINT

.wait_for_input
	call	UPDATE_PART_LIMIT

	xor	A
	ldh	[rIF],A
	inc	A
	ldh	[rIE],A
	halt
	nop

	; Draw menu pointer and erase any old pointers.
	ldh	A,[menu_pos]
	ld	C,A
	xor	A
	ld	DE,32
	LDXY	HL,0,5
.menuloop
	ld	[HL],0
	cp	C
	jr	nz,:+
	ld	[HL],">"
:	add	HL,DE
	inc	A
	cp	6
	jr	c,.menuloop

	; Print delay setting.
	ldh	A,[transfer_delay]
	LDXY	HL,7,5
	call	PRINTHEX

	; Print overclock setting.
	ld	HL,S_NO
	ldh	A,[transfer_overclock]
	or	A
	jr	z,:+
	ld	HL,S_YES
:
	LDXY	DE,11,6
	call	MPRINT

	; Print transfer size. 
	ldh	A,[transfer_size]

	; Assert the string lengths so the length calculation works out.
	assert	(S_32K-S_8K)==5
	assert	(S_64K-S_32K)==5
	assert	(S_128K-S_64K)==5
	assert	(S_128K.end-S_128K)==5

	ld	D,0
	ld	E,A
	ld	HL,S_8K
rept 5
	add	HL,DE
endr
	LDXY	DE,6,8
	call	MPRINT

	;LDXY	HL,0,7
	;inc	[HL]
	;res	7,[HL]

	; Print menu selection for which part to transfer.
	ldh	A,[transfer_part]
	LDXY	HL,6,9
	call	PRINTHEX

	ld	A,"/"
	ld	[HL+],A

	ldh	A,[transfer_num_parts]
	call	PRINTHEX

if MENU_SHOW_LY
	; Print the current value of LY for debugging, first unsafely for GB Interceptor, then GBI scrubbed.
	ldh	A,[rLY]
	push	AF
	LDXY	HL,8,16
	call	PRINTHEX_GBI_UNSAFE
	pop	AF

	inc	HL
	call	PRINTHEX
endc

	; Decremment the warmup delay evbery frame until it hits 0.
	ldh	A,[warmup_delay]
	sub	1			; sub instead of dec to get access to the carry flag.
	jr	c,:+			; c=1 -> counter was already 0.
	ldh	[warmup_delay],A
:

	call	READ_JOYPAD
	ldh	A,[joypad_pressed]
	ld	B,A
	bit	PADB_START,B		; Pressing start anywhere starts the transfer.
	jr	nz,.try_start

	; Menu movement.
	ldh	A,[menu_pos]
	cp	5
	jr	nz,:+
	bit	PADB_A,B		; Pressing A on the start menu item starts the transfer.
	jr	nz,.try_start
:	bit	PADB_DOWN,B
	jr	z,:+
	inc	A
	cp	6
	jr	nc,.no_update_menu_pos
:
	bit	PADB_UP,B
	jr	z,:+
	sub	1
	jr	c,.no_update_menu_pos
:

	ldh	[menu_pos],A
.no_update_menu_pos
	ldh	A,[menu_pos]
	cp	5
	jp	z,.wait_for_input	; Don't allow the "start transfer" option to be adjusted.
	add	A			; *2
	add	A			; *4
	add	LOW(MENU_DEFS)
	ld	L,A
	ld	H,HIGH(MENU_DEFS)
	jr	nc,:+
	inc	H
:
	; Load pointer to value in the menu that we're editing.
	ld	A,[HL+]
	ld	E,A
	ld	A,[HL+]
	ld	D,A

	ld	A,[DE]

	bit	PADB_RIGHT,B
	jr	z,:+
	inc	A
:
	bit	PADB_LEFT,B
	jr	z,:+
	dec	A
:
	; Skip update if value reached min-1.
	cp	[HL]
	jp	z,.wait_for_input
	inc	HL
	; Skip update if value reached max+1.
	cp	[HL]
	jp	z,.wait_for_input
	ld	[DE],A

	jp	.wait_for_input
.try_start
	ldh	A,[warmup_delay]
	or	A
	ret	z
	jp	.wait_for_input


; Memory address and Limits for the settings in the menu.
MENU_DEFS:
.delay
if 1
	dw	transfer_delay		; Address
	db	-1,$40			; Min-1, Max+1.

	dw	transfer_overclock	; Address
	db	-1,2			; Min-1, Max+1.

	dw	transfer_target		; Address
	db	-1,1			; Min-1, Max+1.

	dw	transfer_size		; Address
	db	-1,4			; Min-1, Max+1.

	dw	transfer_part		; Address
	db	-1,$40			; Min-1, Max+1. (This is further clamped elsewhere.)
endc

WAIT_3_FRAMES:
	ld	B,3
	jr	WAIT_5_FRAMES.wait_b_frames
WAIT_5_FRAMES:
;	ld	A,8
;	ldh	[$fffe],A
	ld	B,5
.wait_b_frames
	xor	A
	ldh	[rIF],A
	inc	A
	ldh	[rIE],A
	;jr	check1
;.acheck1
	halt
	nop
	;jr	check2
;.acheck2
	dec	B
	jr	nz,.wait_b_frames

;	ld	A,6
;	ldh	[$fffe],A

	ret

SGB_FAIL::
	rst	WAIT_VBL
	LDXY	DE,4,2
	ld	HL,S_SGBFAIL
	call	MPRINT
ENDLESS_HALT::
	di
	; Endless loop of halt
:	call	WAIT_5_FRAMES
	jr	:-

CALC_CHECKSUM_SRAM:
	ld	DE,$A000
	ld	HL,0
	ld	B,0
:	ld	A,[DE]
	ld	C,A
	add	HL,BC
	inc	E
	jr	nz,:-
	inc	D
	bit	6,D
	jr	z,:-
	ret
if 0
check1:
	ldh	A,[$fffe]
	cp	8
	jr	z,WAIT_5_FRAMES.acheck1
	ld	A,1
	ld	[$fff5],A
	jp	CRASH_MII

check2:
	ldh	A,[$fffe]
	cp	8
	jr	z,WAIT_5_FRAMES.acheck2
	ld	A,2
	ld	[$fff5],A
	jp	CRASH_MII
endc
SECTION "Sys reference values", ROM0
BOOTREGS_SGB1:
	db	$60,$c0,$00,$00,$14,$00,$00,$01
BOOTREGS_SGB2:
	db	$60,$c0,$00,$00,$14,$00,$00,$FF
SETCHARMAP default_raw		; Set the unmodified charmap to encode a raw ASCII string.
REF_SGB_HEADER_TITLE:
	db	"Super GAMEBOY"
	ds	9,$20
SETCHARMAP default


SECTION "Scrubber", ROM0, ALIGN[8]
; This is an aligned table of every possible byte value in order. It can be used to input byte value and read back the same byte value.
; This exists for the benefit of the GB Interceptor. In all normal circumstances, this is a no-op. However, for the GB Interceptor,
; this allows the value to be shown on the external bus such that the GB Interceptor can see it and know the right value.
SCRUBBER::
for iter,0,256
	db	iter
endr



SECTION "Tiles", ROM0
basetiles:
	incbin "graphics/font0.2bpp"
.end

SECTION "Strings", ROM0
S_ALL:
PUSHC
SETCHARMAP inverted
	db "UNIVERSAL SGB DUMPER\n"
SETCHARMAP default
CHARMAP "-",$6D
	db "BOOT:       MLTREQ:-\n"
	db "ACE:- HEADER:--\n"
	db "FW:---- ICD:--\n"
	db "\n\n\n\n\n\n\n\n\n\n\n\n\n"
	db "              V1.0.1"
	db 0
POPC

S_MENU:
	db " DELAY:\n"
	db " OVERCLOCK:\n"
	db " TARGET:"

PUSHC
SETCHARMAP shaded
	db "SRAM\n"
POPC
	db " SIZE:\n"
	db " PART:\n"
	db " START TRANSFER!\n"

	db 0


S_SENDING_PAYLOAD:
	db "SENDING PAYLOAD...",0
S_SENDING_BORDER:
	db "SENDING BORDER...",0


S_SGBFAIL:
PUSHC
SETCHARMAP shaded
	db "N\n\n"
POPC
	db "NO SGB DETECTED.\n\n"
	db "WRONG SYSTEM, HLE,\n",
	db "OR BAD FLASHCART.\n\n"
	db "HALTING.",0



S_DUMPING:
	;db $aa
PUSHC
SETCHARMAP inverted
	db "DUMPING...          \n"
POPC
	db "# SSUM GSUM",0

S_DUMPSCREEN_INFO:
	db "SIZE:\n\n"
	db "               PART:\n"
	db "                 /\n\n"

	db 0


PUSHC
SETCHARMAP inverted
S_CHECKING_CHECKSUMS:
	db "CHECKING CHECKSUM...",0
S_FINISHED:
	db "DUMP FINISHED!      ",0
POPC

; Define a non-shaded space character for erasing the extra character(s) when changing settings to a shorter one.
DEF normal_space EQU CHARSUB(" ",1)
SETCHARMAP shaded
S_NO:
	db "NO",normal_space,0
S_YES:
	db "YES",0
SETCHARMAP shaded_dark
S_BAD:
	db "BAD",0
SETCHARMAP shaded
S_OK:
	db "OK",0
S_QMARKS:
	db "??",0

S_NG:
	db "NG",0

S_SGB1:
	db "SGB1",0
S_SGB2:
	db "SGB2",0
S_NOSGB:
	db "NO SGB",0
S_V1_:
	db "V1.",0
S_UNKN:
	db "UNKN",0

; These need to be 5 bytes long each including the null byte. This is checked with an assertion elsewhere.
S_8K:
	db "8K",normal_space,normal_space,0
S_32K:
	db "32K",normal_space,0
S_64K:
	db "64K",normal_space,0
S_128K:
	db "128K",0
.end


SETCHARMAP default

; That's right, all of WRAM is reserved for one big data buffer.
; (Actually not used as such atm, but would be for an SRAM-less scenario.)
SECTION "SGB packet buffer", WRAM0[$C000]
DATA_BUFFER::	ds $2000

SECTION "Hivars", HRAM[$FF80]
boot_rev:	db
	UNION
sgb_cmd::	ds	16
	NEXTU
sgb_cmd_jump::	ds	7	; Preamble
.operation::	db		; Operation
.delay::	dw		; Delay (number of loop iterations)
.address::	dw		; Read address
.bank::		db		; Read address bank
.length::	dw		; Number of bytes
.overclock::	db		; Overclock enable

	NEXTU
boot_regs:
.hl:
.l:	db
.h:	db
.de:
.e:	db
.d:	db
.bc:
.c:	db
.b:	db
.af:
.f:	db
.a:	db
.top:
	ENDU

clear_after_here:
joypad_pressed::	db
joypad_held::		db
skip_sgb_delay::	db
end_addr::		dw
;temp3::			ds 3
target_ram_bank:	db
source_snes_rom_offset:	db
rom_checksum_snes:	dw
rom_checksum_gb:	dw
menu_pos:		db
transfer_rom_total_size:db
transfer_delay:		db
transfer_target:	db
transfer_part:		db
transfer_num_parts:	db
transfer_size:		db
transfer_size_banks:	db
transfer_overclock:	db
sstat_icd:		db
warmup_delay:		db

SECTION "Stack", HRAM[$FFEF]
Stack:
	ds	$10
.top