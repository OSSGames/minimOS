; default options for minimOS and other modules
; set for CMOS SDm
; copy or link as options.h in root dir
; (c) 2015-2016 Carlos J. Santisteban
; last modified 20160121

; *** set conditional assembly ***
; uncomment to remove debugging markup
;#define	FINAL	_FINAL

; comment for optimized code without optional checks
#define		SAFE	_SAFE

; uncomment for macros replacing new opcodes
;#define	NMOS	_NMOS
;#define	C816	_C816

; select type as on executable headers, B=generic 65C02, V=C816, N=NMOS 6502, R=Rockwell 65C02
#define		_CPU_TYPE	'B'

; limit features for 128-byte systems!
;#define		LOWRAM		_LOWRAM

; enables filesystem feature
; might be deprecated since it will be an optional driver
;#define		FILESYSTEM		_FILESYSTEM

; enables multitasking kernel, as long as there is enough memory
; might be deprecated since it is an optional driver
#ifndef	LOWRAM
#define		MULTITASK	_MULTITASK
#endif

; enables hardware-assisted bankswitching, esp. the autobank feature
; ** original idea DEPRECATED **
; bankswitching may remain for context switching, either for the 02 or 816
;#define		AUTOBANK	_AUTOBANK

; *** machine hardware definitions ***
; Machine-specific ID strings, new 20150122, renamed 20150128, 20160120
#define		MACHINE_NAME	"Jalapa/SDm"
#define		MACHINE_ID		"sdm"

;ROM_BASE	=	$F400	; special case for MTE (3 kiB out of 4k full 6503 space)
;ROM_BASE	=	$F000	; 4 kiB ROM SDd/Chihuahua
;ROM_BASE	=	$C000	; Tijuana, maybe Veracruz?
ROM_BASE	=	$8000	; SDm/Jalapa, Chihuahua PLUS, might become the generic case

; VIA 65(C)22 Base address, machine dependent
; generic address declaration
VIA1	=	$DFF0		; for SDm and most machines
;VIA1	=	$6FF0		; SDd, Chihuahua, Chihuahua PLUS

VIA2	=	$DFF0		; SDm is a single-VIA machine, others may change

; *** new separate VIAs in some machines ***
; VIA_J is the one which does the jiffy IRQ, most likely the main one
; VIA_FG is the one for audio generation (/PB7 & CB2)
; VIA_SS is the one for SS-22 interface
; VIA_SP is the one for SPI interface (TBD)
VIA_J	=	VIA1		; the only one in SDm, though
VIA_FG	=	VIA1
VIA_SS	=	VIA1
VIA_SP	=	VIA1

; for compatibility with older code
VIA		=	VIA1		; valid for SDm and most


; ACIA/UART address, machine dependent
ACIA1	=	$DFD0		; ACIA address on SDm and most other (no longer $DFE0 for easier decoding 688+138)

; *** RAM size ***
; uncomment this for 128-byte systems!
;#define	LOWRAM		_LOWRAM

; * some pointers and addresses * renamed 20150220

; * highest SRAM page, just in case of mirroring/bus error * NOT YET USED
; uncomment for MTE, needs mirroring for the stack, but it has just 128 bytes!
; SRAM =	1

; uncomment this for SDd/CHIHUAHUA (2 KiB RAM)
;SRAM =	7

; page 127 (32 kiB) is the new generic case
SRAM =	127

#ifdef	LOWRAM
; initial stack pointer, renamed as label 20150603
SP		=	$63		; (previously $75) MTE and other 128-byte RAM systems!

; system RAM location, where firmware and system variables start, renamed as label 20150603
SYSRAM	=	$28		; for 128-byte systems, reduced value 20150210

; user-zp available space, new 20150128, updated 20150210, renamed as label 20150603
; 128-byte systems leave 37(+2+1+1) bytes for user ($03-$27) assuming 60-byte stack AND sysvars space ($28-$63)
; unless a 6510 is used, the two first bytes are available
; without multitasking, $02 (z_used) is free, and so is $FF/$7F (sys_sp)
ZP_AVAIL	=	$25

#else
SP			=	$FF		; general case stack pointer
SYSRAM		=	$0200	; after zeropage and stack, most systems with at least 1 kiB RAM
;SYSRAM		=	$4000	; special case for bankswitched SDm/Jalapa
ZP_AVAIL	=	$E1		; as long as locals start at $E4, not counting used_zp

#endif

; *** speed definitions ***
; interrupt counter value
;T1_DIV	=	198			; (200-2) 5 kHz @ 1 MHz (200µs quantum) for MTE!
T1_DIV	=	4998		; (5000-2) 200Hz ints @ 1 MHz (5 ms quantum) general case
;IRQ_FREQ =	5000		; for MTE
IRQ_FREQ =	200			; general case

; initial speed for SS-22 link
SS_SPEED =	30		; 15625 bps @ 1 MHz
;SS_SPEED = 62		; 15625 bps @ 2 MHz
;SS_SPEED =	126		; 15625 bps @ 4 MHz
;SS_SPEED =	254		; 15625 bps @ 8 MHz

; speed code in fixed-point format, new 20150129
SPEED_CODE =	$10		; 1 MHz system
;SPEED_CODE =	$20		; 2 MHz system (SDx)
