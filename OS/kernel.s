; minimOS generic Kernel
; v0.5b1
; (c) 2012-2016 Carlos J. Santisteban
; last modified 20160401-0909

; avoid standalone definitions
#define		KERNEL	_KERNEL

; uncomment in case of separate, downloadable jump & boot files
; should assume standalone assembly!!! (will get drivers anyway)
;#define		DOWNLOAD	_DOWNLOAD

; in case of standalone assembly
#ifndef		ROM
#include "options.h"
#include "macros.h"
#include "abi.h"
.zero
#include "zeropage.h"
.bss
#include "firmware/ARCH.h"
#ifdef		DOWNLOAD
* = $0400				; safe address for patchable 2 kiB systems, change if required
#else
#include "sysvars.h"
#include "drivers/config/DRIVER_PACK.h"
user_sram = *
#include "drivers/config/DRIVER_PACK.s"	; don't assemble actual code, just labels
* = ROM_BASE			; just a placeholder, no standardised address
#endif
.text
#endif

; **************************************************
; *** kernel begins here, much like a warm reset ***
; **************************************************

warm:
-kernel:			; defined also into ROM file, just in case is needed by firmware
	SEI				; shouldn't use macro, really
#ifdef	NMOS
	CLD				; not needed for CMOS
#endif

; install kernel jump table if not previously loaded, NOT for 128-byte systems
#ifndef	LOWRAM
#ifndef		DOWNLOAD
	LDY #<k_vec		; get table address, nicer way (2+2)
	LDA #>k_vec
	STY zpar		; store parameter (3+3)
	STA zpar+1
	_ADMIN(INSTALL)	; copy jump table (14...)
#endif
#endif

; install ISR code (as defined in "isr/irq.s" below)
	LDY #<k_isr		; get address, nicer way (2+2)
	LDA #>k_isr
	STY zpar		; no need to know about actual vector location (3)
	STA zpar+1
	_ADMIN(SET_ISR)	; install routine (14...)

; Kernel no longer supplies default NMI, but could install it otherwise

; *****************************
; *** memory initialisation ***
; *****************************
; should be revised ASAP

#ifndef		LOWRAM
	LDA #UNAS_RAM		; unassigned space (2) should be defined somewhere (2)
	LDX #MAX_LIST		; depending on RAM size, corrected 20150326 (2)
mreset:
		STA ram_stat, X		; set entry as unassigned, essential (4)
		DEX					; previous byte (2)
		BNE mreset			; leaves first entry alone (3/2, is this OK?)
	LDA #<user_sram		; get first entry LSB (2)
	STA ram_tab			; create entry (4)
	LDA #>user_sram		; same for MSB (2+4)
	STA ram_tab+1
;	LDA #FREE_RAM		; no longer needed if free is zero
	_STZA ram_stat		; set free entry (4)
	LDA #0				; compute free RAM (2+2)
	SEC
	SBC #<user_sram		; substract LSB (2+4)
	STA ram_siz
	LDA himem			; get ram size MSB (4)
	SBC #>user_sram		; substract MSB (2)
	STA ram_siz+1		; entry is OK (4)
#endif

; ******************************************************
; intialise drivers from their jump tables! new 20150206
; optimised code with self-generated ID list 20150220
; new code disabling failed drivers 20150318
; ******************************************************
; systems with enough ram should create direct table!!!!!!!!!!!

; set some labels, much neater this way
da_ptr	= locpt2		; pointer for indirect addressing, new CIN/COUT compatible 20150619
drv_aix = local3		; address index for, not necessarily PROPOSED, driver list, new 20150318, shifted 20150619

; driver full install is new 20150208
	_STZA dpoll_mx		; reset indexes, sorry for NMOS (4x4)
	_STZA dreq_mx
	_STZA dsec_mx
#ifdef LOWRAM
	_STZA drv_num		; single index of, not necessarily SUCCESSFULLY, installed drivers, updated 20150318
#else
	LDX #0				; reset index of direct table (2)
	TXA					; value to be stored (2)
dr_clear:
		STA drivers_pt+1, X		; clear MSB, since no driver is allowed in zeropage (4)
		INX						; next pointer (2+2)
		INX
		BNE dr_clear			; finish page (3/2)
#endif
	_STZA drv_aix
; first get the pointer to each driver table
dr_loop:
; get address index
		LDX drv_aix			; get address index (4)
		LDA drivers_ad+1, X	; get address MSB (4)
		BNE dr_inst			; not in zeropage, in case is too far for BEQ dr_ok (3/2)
			JMP dr_ok			; all done otherwise (0/4)
dr_inst:
		STA da_ptr+1		; store pointer (3)
		LDA drivers_ad, X	; same for LSB (4+3)
		STA da_ptr
; create entry on IDs table ** new 20150219
		LDY #D_ID			; offset for ID (2)
		LDA (da_ptr), Y		; get ID code (5)
			BPL dr_abort		; reject logical devices (2/3)

#ifndef	LOWRAM
; new faster driver list 20151014
		ASL					; use retrieved ID as index (2+2)
		TAY
		LDA drivers_pt+1, Y		; check whether in use (5?)
			BNE dr_abort			; already in use, don't register! (2/3)
		LDA da_ptr				; get driver table LSB (3)
		STA drivers_pt, Y		; store in table (5?)
		LDA da_ptr+1			; same for MSB (3+5?)
		STA drivers_pt+1, Y
#else
#ifdef	SAFE
; ** let's check whether the ID is in already in use **
		LDX #0			; reset index (2)
		BEQ dr_limit	; check whether has something to check, no need for BRA (3)
dr_scan:
			CMP drivers_id, X	; compare with list entry (4)
				BEQ dr_abort		; already in use, don't register! (2/3)
			INX					; go for next (2)
dr_limit:	CPX drv_num			; all done? (4)
			BNE dr_scan			; go for next (3/2)
; ** end of check **
#else
		LDX drv_num			; retrieve single offset (4) *** already set because of the previous check, if done
#endif
		STA drivers_id, X	; store in list, now in RAM (4)
#endif

; register interrupt routines (as usual)
		LDY #D_AUTH			; offset for feature code (2)
		LDA (da_ptr), Y		; get auth code (5)
		AND #A_POLL			; check whether D_POLL routine is avaliable (2)
			BEQ dr_nopoll		; no D_POLL installed (2/3)
		LDY #D_POLL			; get offset for periodic vector (2)
		LDX dpoll_mx		; get destination index (4)
		CPX #MAX_QUEUE		; compare against limit (2)
			BCS dr_abort		; error registering driver! (2/3) eek
dr_ploop:
			LDA (da_ptr), Y		; get one byte (5)
			STA drv_poll, X		; store in RAM (4)
			INY					; increase indexes (2+2)
			INX
			CPY #D_POLL+2		; both bytes done? (2)
			BCC dr_ploop		; if not, go for MSB (3/2) eek
		STX dpoll_mx		; save updated index (4)
		LDY #D_AUTH			; offset for feature code (2)
dr_nopoll:

		LDA (da_ptr), Y		; get auth code (5)
		AND #A_REQ			; check D_REQ presence (2)
			BEQ dr_noreq		; no D_REQ installed (2/3)
		LDY #D_REQ			; get offset for async vector (2)
		LDX dreq_mx			; get destination index (4)
		CPX #MAX_QUEUE		; compare against limit (2)
			BCS dr_abort		; error registering driver! (2/3) eek
dr_aloop:
			LDA (da_ptr), Y		; get its LSB (5)
			STA drv_async, X	; store in RAM (4)
			INY					; increase indexes (2+2)
			INX
			CPY #D_REQ+2		; both bytes done? (2)
			BCC dr_aloop		; if not, go for MSB (3/2) eek
		STX dreq_mx			; save updated index  (4)
		LDY #D_AUTH			; offset for feature code (2)
dr_noreq:

		LDA (da_ptr), Y		; get auth code (5)
		AND #A_SEC			; check D_SEC (2)
			BEQ dr_nosec		; no D_SEC installed (2/3)
		LDY #D_SEC			; get offset for 1-sec vector (2)
		LDX dsec_mx			; get destination index (4)
		CPX #MAX_QUEUE		; compare against limit (2)
			BCS dr_abort		; error registering driver! (2/3) eek
dr_sloop:
			LDA (da_ptr), Y		; get its LSB (5)
			STA drv_sec, X		; store in RAM (4)
			INY					; increase indexes (2+2)
			INX
			CPY #D_SEC+2		; both bytes done? (2)
			BCC dr_sloop		; if not, go for MSB (3/2) eek
		STX dsec_mx			; save updated index (4)
dr_nosec: 
; continue initing drivers
		JSR dr_icall	; call routine (6+...)
			BCS dr_abort	; failed initialisation, new 20150320
dr_next:
#ifdef	LOWRAM
		INC drv_num		; update SINGLE index (6)
#endif
; in order to keep drivers_ad in ROM, can't just forget unsuccessfully registered drivers...
; in case drivers_ad is *created* in RAM, dr_abort could just be here
		INC drv_aix		; update ADDRESS index, even if unsuccessful (5)
		JMP dr_loop		; go for next (3)
dr_abort:
#ifdef	LOWRAM
		LDX drv_num			; get failed driver index (4)
		LDA #DEV_NULL		; make it unreachable, any positive value (logic device) will do (2)
		STA drivers_id, X	; delete older value (4)
#else
		LDY #D_ID			; offset for ID (2)
		LDA (da_ptr), Y		; get ID code (5)
			BPL dr_next			; nothing to delete (2/3)
		ASL					; use retrieved ID as index (2+2)
		TAX
		_STZA drivers_pt+1, X	; discard it (4)
#endif
		_BRA dr_next			; go for next (3)

dr_icall:
	LDY #D_INIT+1		; get MSB first (2)
dr_call:				; *** generic driver call, pointer set at locpt2, Y holds table offset+1 *** new 20150610
#ifndef	NMOS
	LDA (da_ptr), Y		; destination pointer (5)
	TAX					; store temporarily (2) new '816 compatible code 20151014
	DEY					; go for LSB (2)
	LDA (da_ptr), Y		; repeat procedure (5)
	BNE dr_nowrap		; won't mess with MSB (3/2)
		DEX					; will carry (2) or 
dr_nowrap:
	_DEC				; RTS will go one less (2)
	PHX					; push MSB -- no NMOS macro!!!!! (3)
	PHA					; push LSB (3)
#else
	DEY					; get LSB first
	LDA (da_ptr), Y
	TAX					; store temporarily in X
	INY					; go for MSB in A
	LDA (da_ptr), Y
	CPX #0				; check whether wraps or not
	BNE dr_nowrap
		_DEC
dr_nowrap:
	DEX					; RTS will go one less
	PHA					; push address
	_PHX
#endif
	RTS					; the actual COMPATIBLE jump (6)

dr_ok:					; all drivers init'd
#ifdef	LOWRAM
	LDX drv_num			; retrieve single index (4)
	_STZA drivers_id, X	; terminate list, and we're done! (4)
#endif

; **********************************
; ********* startup code ***********
; **********************************

; reset several remaining flags
	_STZA cin_mode	; reset binary mode flag, new 20150618

; *** set default SIGTERM handler for single-task systems, new 20150514 ***
#ifndef		MULTITASK
	LDY #<sig_kill	; get default routine address LSB
	LDA #>sig_kill	; same for MSB
	STY stt_handler	; store in new system variable
	STA stt_handler+1
#endif

; **********************************
; startup code, revise ASAP
; **********************************

; *** set default I/O device ***
	LDA #DEVICE		; as defined in options.h
	STA default_out	; should check some devices
	STA default_in

; *** interrupt setup no longer here, firmware did it! *** 20150605
	CLI				; enable interrupts

; ******************************
; **** launch monitor/shell ****
; ******************************

	JSR shell			; should be done this way, until a proper EXEC is made!
#ifndef		MULTITASK
	LDY #PW_OFF			; after execution, shut down system (al least)
	_ADMIN(POWEROFF)	; via firmware, will not return
#else
	BRK					; just in case...
	.asc	"{EXIT}", 0	; if managed
#endif

; place here the shell code, must end in RTS
shell:
#include "shell/SHELL"

; *** generic kernel routines, now in separate file 20150924 *** new filenames
#ifndef		LOWRAM
#include "api.s"
#else
#include "api_lowram.s"
#endif

; *** new, sorted out code 20150124 ***
; *** interrupt service routine ***

k_isr:
#include "isr/irq.s"

; default NMI-ISR is on firmware!
