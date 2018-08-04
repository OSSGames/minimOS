; 64-key ASCII keyboard for minimOS!
; v0.6a1
; (c) 2012-2018 Carlos J. Santisteban
; last modified 20180804-1234

; VIA bit functions
; PA0...3	= input from selected column
; PA4...7	= output (selected column)
; PB3		= caps lock LED (hopefully respected!)

; new VIA-connected device ID is $A5/AD, $25/2D with PB7 off (%x010x101)

; ** driver variables description **
; ak_fi, first free element in FIFO
; ak_fo, element ready for exit in FIFO
; ak_mk, pointer to appropriate table
; ak_ddra, old port config
; ak_iorb, old command **needed?**
; ak_rmod, last detected raw modifier combo
;	d0 = caps lock
;	d1 = alt
;	d2 = control
;	d3 = shift
; ak_cmod, modifier status (like ak_rmod with toggling caps lock)
; ak_scod, last detected scancode

; ***********************
; *** minimOS headers ***
; ***********************
#include "../usual.h"

.(
; *** begins with sub-function addresses table ***
	.byt	145		; physical driver number D_ID (TBD)
	.byt	A_BLIN|A_POLL	; input driver, periodic interrupt-driven
	.word	ak_read		; read from input buffer
	.word	ak_err		; no output
	.word	ak_init		; initialise 'device', called by POST only
	.word	ak_poll		; periodic interrupt...
	.word	4		; 20ms scan seems fast enough
	.word	ak_nreq		; D_ASYN does nothing
	.word	ak_err		; no config
	.word	ak_err		; no status
	.word	ak_exit		; shutdown procedure, leave VIA as it was...
	.word	ak_info		; points to descriptor string
	.word	0		; non-relocatable, D_MEM

; *** driver description ***
ak_info:
	.asc	"ASCII keyboard v0.6", 0

; *** some definitions ***
AF_SIZ		= 16		; buffer size (only 15 useable) no need to be power of two

PA_MASK		= %11110000	; PA0-3 as input, PA4-7 as output
PB_KEEP		= %10000000	; keep PB7
PB_MASK		= %00100101	; VIAport address

; ****************************************
; *** read from buffer to output block ***
; ****************************************
ak_read:
	LDA bl_ptr+1			; save pointer MSB
	PHA
	LDY #0				; reset index
ak_rloop:
		LDA bl_siz			; check remaining
		ORA bl_siz+1
			BEQ blck_end			; nothing to do
		JSR ak_get			; *** get one byte from buffer***
			BCS blck_end		; any error ends transfer!
		STA (bl_ptr),Y			; ...goes into buffer
		INY					; next byte, check carry
		BNE ak_nw
			INC bl_ptr+1
ak_nw:
		DEC bl_siz			; one less to go
		LDA bl_siz			; check whether wrapped
		CMP #$FF
		BNE blck_end			; no wrap, all done
			LDA bl_siz+1			; any page remaining?
		BEQ blck_end			; no, exit
			DEC bl_siz+1			; ...or one page less
		_BRA ak_rloop
blck_end:
	PLA					; restore MSB
	STA bl_ptr+1
	RTS					; respect whatever error code

ak_err:
	_DR_ERR(NO_RSRC)		; cannot do this

; ************************
; *** initialise stuff ***
; ************************
ak_init:
; reset FIFO
	_STZA ak_fi
	_STZA ak_fo
; clear previous scancodes
	_STZA ak_rmod
	_STZA ak_cmod
	_STZA ak_scod

	_DR_OK				; succeeded


; *******************************
; *** read one byte from FIFO *** A -> char, C = empty, uses X
; *******************************
ak_get:
	LDX ak_fo			; get output position
	CPX ak_fi			; is it empty?
	BNE ak_some			; no, do extract
		_DR_ERR(EMPTY)			; yes, do nothing
ak_some:
	LDA ak_buff, X		; extract char
	INX					; this is no more
	CPX #AF_SIZ			; wrapped?
	BNE ak_rnw				; no
		LDX #0					; or yes, back to zero
ak_rnw:
	STX ak_fo			; eeeeeeeeeek
	_DR_OK

; *******************************
; *** push one byte into FIFO *** A <- char, uses X
; *******************************
ak_push:
	LDX ak_fi			; get input position
	STA ak_buff, X		; insert char
	INX					; go for first free position
	CPX #AF_SIZ			; wrapped?
	BNE ak_wnw				; no
		LDX #0					; or yes, back to zero
ak_wnw:
	STX ak_fi			; update pointer
	CPX ak_fo			; is it full?
	BNE ak_room			; no, all OK
		INC ak_fo			; yes, simply discard oldest byte
		LDA ak_fo			; but check for wrap, too
		CMP #AF_SIZ
	BNE ak_room			; did not, all done
		_STZA ak_fo			; or go back to zero
ak_room:
	RTS					; no errors here

; ******************************************************
; *** scan matrix and put char on FIFO, if available *** D_POLL task
; ******************************************************
ak_poll:
; must setup VIA first!!
	LDA VIA_U+IORB		; set control port
	AND #PB_KEEP		; keep desired bits
	ORA #PB_MASK		; set accordingly
	STA VIA_U+IORB
	LDA VIA_U+DDRA		; save older port config
	STA ak_ddra
	LDA #PA_MASK		; prepare for this device
	STA VIA_U+DDRA
; scan modifier column
	LDX #15			; maximum column index (modifiers)
	JSR ap_scol		; scan this column
	CMP ak_rmod		; any change on these?
	BNE ap_eqm		; no, just scan the rest
		STA ak_rmod		; update modifier combo
; update status of caps lock LED...
		AND #1			; caps lock=bit 0
		TAY			; keep for status
		ASL
		ASL
		ASL			; now is bit 3, ready for PB3
		EOR VIA_U+IORB		; TOGGLE PB3, thus caps lock LED
		STA VIA_U+IORB
; ...and toggle caps lock status bit
		LSR ak_cmod		; clear caps lock bit...
		TYA			; is caps lock on?
		BEQ ap_lowc		; nope...
			SEC
			ROL ak_cmod		; ...or set this bit
ap_lowc:
; get table address for this modifier combo
		LDA ak_cmod		; retrieve modifier status
		ASL				; table offsets need 9 bits!
		TAX				; index for modifier combos
		LDY ak_mods, X	; get pointer on main table for these modifiers
		LDA ak_mods+1, X
		STY ak_mk		; save for later!
		STA ak_mk+1
ap_eqm:
	LDX #14			; last regular column
ap_sloop:
		JSR ap_scol		; scan this one
			BNE ap_kpr		; some key pressed
		DEX				; next column
		BPL ap_sloop
ap_end:
	_STZA ak_scod		; clear previous scancode! eeeeeeeek
	RTS				; none pressed, all done
; must check whether scancode is different from last poll
ap_kpr:
	ORA col16, X		; include column index!
	CMP ak_scod		; any changes?
	BNE ap_char		; yes, get ASCII and put into buffer
; no changes, but could implement repeat here...
		BEQ ap_end		; do nothing...
; get ASCII from compound scancode
ap_char:
	TAY				; use scancode as post-index
	LDA (ak_mk), Y		; this is the ASCII code
	JMP ak_push		; goes into FIFO... ans return to ISR

; **************************
; *** auxiliary routines ***
; **************************

; get rows in A as selected in column X
ap_scol:
	LDA col16, X		; column times 16
	STA VIA_U+IORA		; place output bits (select column)
; fastest machines may need some delay here
	LDA VIA_U+IORA		; get row values back
	AND #$0F		; just the low nibble
	RTS

; *** misc ***
ak_nreq:
	_NXT_ISR		; in case gets called, exit ASAP

; *******************************
; *** diverse data and tables ***
; *******************************

; column index times 16 for compound scancodes
col16:
	.byt	  0,  16,  32,  48,  64,  80,  96, 112
	.byt	128, 144, 160, 176, 192, 208, 224, 240

.)
