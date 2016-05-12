; line editor for minimOS!
; v0.5b1
; (c) 2016 Carlos J. Santisteban
; last modified 20160512-1013

#ifndef	ROM
#include "options.h"
#include "macros.h"
#include "abi.h"
.zero
#include "zeropage.h"
.bss
#include "firmware/ARCH.h"
#include "sysvars.h"
.text
user_sram	= $0400
#endif

; *** constants declaration ***
#define	LBUFSIZ		80

#define	CR			13
#define	SHOW		$14
#define	EDIT		5
#define	DELETE		$18
#define	DOWN		$12
#define	UP			$17
#define	GOTO		7
#define	BACKSPACE	8
#define	TAB			9
#define	ESCAPE		27

; ##### include minimOS headers and some other stuff #####

; *** declare zeropage variables ***
; ##### uz is first available zeropage byte #####
	ptr		=	uz		; current address ponter
	src		=	ptr+2	; temporary storage & source
	tmp=src
	dest	=	src+2	; temporary storage & destination
	cur		=	dest+2	; current line number
	start	=	cur+2	; start of loaded text
	top		=	start+2	; end of text (NULL terminated)
	key		=	top+2	; read key, really needed?
	edit	=	key+1	; flag for EDIT mode
	l_buff	=	edit+2	; temporary input buffer
	iodev	=	l_buff+LBUFSIZ	; standard I/O ##### minimOS specific #####

	__last	= iodev+1	; ##### just for easier size check #####

; *** initialise the editor ***

; ##### minimOS specific stuff #####
	LDA #__last-uz		; zeropage space needed
; check whether has enough zeropage space
#ifdef	SAFE
	CMP z_used			; check available zeropage space
	BCC go_lined		; enough space
	BEQ go_lined		; just enough!
		_ERR(FULL)			; not enough memory otherwise (rare)
go_lined:
#endif
	STA z_used			; set needed ZP space as required by minimOS
	_STZA w_rect		; no screen size required
	_STZA w_rect+1		; neither MSB
	LDY #<le_title		; LSB of window title
	LDA #>le_title		; MSB of window title
	STY str_pt			; set parameter
	STA str_pt+1
	_KERNEL(OPEN_W)		; ask for a character I/O device
	BCC open_ed			; no errors
		_ERR(NO_RSRC)		; abort otherwise! proper error code
open_ed:
	STY iodev			; store device!!!
; ##### end of minimOS specific stuff #####

; *** ask for text address (could be after loading) ***
	LDA #'$'			; hex radix as prompt
	JSR prnChar			; print it!
	JSR hexIn			; read line asking for address, will set at tmp
; this could be the load() routine
	LDA tmp+1			; get start address
	LDY tmp
	STA start+1			; store
	STY start
	BNE le_nw			; will not wrap
		_DEC				; decrease MSB
le_nw:
	DEY					; one less for leading terminator
	STY ptr				; store pointer
	STA ptr+1
	LDA #0				; NULL value
	_STAY(ptr)			; store just before text!
	LDY ptr				; initial value LSB
	_STZA ptr			; clear pointer LSB
	INY					; correct value
	BNE le_nw2			; did not wrap
		INC ptr+1			; carry otherwise
le_nw2:
; scan the 'document' until the end
	LDA #1				; default number of lines
	STA cur				; set initial value
ll_scan:
		LDA (ptr), Y		; get stored char
			BEQ ll_end			; already at the end
		CMP #CR				; is it newline?
		BNE ll_next			; otherwise continue
			INC cur				; count another line
			BNE ll_next			; did not wrap
				INC cur+1			; or increase MSB!
ll_next:
		INY					; increase LSB
		BNE ll_scan			; no page boundary crossing
			INC ptr+1			; otherwise next page
		BNE ll_scan			; no need for BRA
ll_end:
	STY ptr				; update pointer LSB
	LDA ptr+1			; let us see MSB
	CMP start+1			; compare against start address
		BNE ll_some			; not empty
	CPY start			; check LSB too
	BNE ll_some			; was not empty
		_STZA l_buff		; clear buffer otherwise
		BEQ le_pr1			; and go for prompt, no need for BRA
ll_some:
	JSR l_prev			; back to previous (last) line
	JSR l_indent		; get leading whitespace
	JSR l_show			; display this line!
	DEC cur				; correct value!!!
le_pr1:
	_STZA edit			; reset EDIT flag (false)

; *** main loop ***
le_loop:
		LDY iodev			; get standard device ###
		_KERNEL(CIN)		; non-locking input ###
			BCS le_loop			; wait for something ###
		LDA #SHOW			; code for 'show all' command (currently ^T)
		CMP io_c			; was that the key?
		BNE le_sw1			; check next otherwise
			JSR l_all			; show all
			JSR l_prompt		; ask for current line
			_BRA le_loop		; and continue
le_sw1:
		LDA #EDIT			; code for 'edit' command (^E)
		CMP io_c			; was that the key?
		BNE le_sw2			; check next otherwise
			
			JSR l_prompt		; ask for current line
			_BRA le_loop
le_sw2:
		LDA #DELETE			; code for 'delete' command (^X)
		CMP io_c			; was that the key?
		BNE le_sw3			; check next otherwise
			
			JSR l_prompt		; ask for current line
			_BRA le_loop
le_sw3:
		LDA #CR				; code for Return key
		CMP io_c			; was that the key?
		BNE le_sw4			; check next otherwise
			
			JSR l_push			; copy buffer into memory
			JSR l_prev			; back to previous line
			JSR l_indent		; get leading whitespace
			JSR l_next			; advance to next line
			JSR l_prompt		; ask for current line
			_BRA le_loop
le_sw4:
		LDA #UP				; code for 'up' key (^W)
		CMP io_c			; was that the key?
		BNE le_sw5			; check next otherwise
			
			_BRA le_loop
le_sw5:
		LDA #DOWN			; code for 'down' command (^R)
		CMP io_c			; was that the key?
		BNE le_sw6			; check next otherwise
			
			_BRA le_loop2
le_sw6:
		LDA #GOTO			; code for 'go to' command (^G)
		CMP io_c			; was that the key?
		BNE le_sw7			; check next otherwise
			
			_BRA le_loop2
le_sw7:
		LDA #ESCAPE			; code for 'esc' key
		CMP io_c			; was that the key?
		BNE le_sw8			; check next otherwise
			
			_BRA le_loop2
le_sw8:
		LDA #BACKSPACE		; code for 'backspace' key
		CMP io_c			; was that the key?
		BEQ le_def			; check default otherwise
le_loop2:
			JMP	le_loop			; continue forever
le_def:
		
		_BRA le_loop2		; and continue

; *** useful routines ***
; * basic output and hexadecimal handling *
#include "libs/hexio.s"

; TO DO TO DO
l_prev:					; back to previous (last) line
l_indent:				; get leading whitespace
l_show:					; display this line!
l_all					; show all
l_prompt				; ask for current line
l_push					; copy buffer into memory
l_next					; advance to next line

; * hexadecimal input *
hexIn:					; read line asking for address, will set at tmp
	LDX #0				; reset cursor
hxi_loop:
		LDY iodev			; get device
		_PHX				; save cursor!
hxi_in:
			_KERNEL(CIN)		; get non locking char
			BCS hxi_in			; until something arrived
		LDA io_c			; get char
		CMP #8				; is it backspace?
		BNE hxi_nbs			; skip otherwise
			DEX		; *****placeholder******
gnc_do:	; ******placeholder*******
hxi_nbs:
		_PLX				; retrieve cursor
		STA l_buff, X		; store char
		INX
		_BRA hxi_loop
; ** process hex and save result at tmp ** TO DO TO DO TO DO
	RTS

; *** strings and data ***
le_title:
	.asc	"Line Editor", 0
