; includes for minimOS drivers
; Chihuahua PLUS specific configuration!
; v0.6b2
; (c) 2015-2017 Carlos J. Santisteban
; last modified 20171220-1340

#define		DRIVERS		1

; in case of standalone assembly
#ifndef		HEADERS
#include "usual.h"
.bss
#include "drivers/config/chihuahua_plus_std.h"
.text
#endif

; *** load appropriate drivers here ***
; place them between generic labels

driver0:
; optional multitasking as a driver!!! new 20150324
; next driver's address would repeat on list... current (0.5a9) kernel would reject duplicates anyway
#ifdef	MULTITASK
#include	"drivers/multitask.s"
#endif

; *** standard drivers ***
driver1:
; LED keypad
#include "drivers/drv_led.s"

driver2:
; SS-22 link
;#include "drivers/drv_ss22.s"

driver3:
; ASCII keyboard with LCD
;#include "drivers/drv_ascii_lcd.s"

driver4:
; optional filesystem as a driver! new 20150309
#ifdef	FILESYSTEM
#include	"drivers/filesystem.s"
#endif

; *** driver list in ROM ***
; only the addresses, in no particular order (watch out undefined drivers!)
; this might be generated in RAM in the future, allowing on-the-fly driver install
; since non LOWRAM systems call directly I/O routines, this is only used during registration

drvrs_ad:
	.word	driver0		; generic list
	.word	driver1		; generic list
	.word	driver2		; generic list
	.word	driver3		; generic list
	.word	driver4		; generic list

	.word	0		; ***** TERMINATE LIST ***** (essential since 0.5a2)
