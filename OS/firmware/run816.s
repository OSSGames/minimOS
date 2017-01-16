; firmware for minimOS on run65816 BBC simulator
; v0.9b1
; (c)2017 Carlos J. Santisteban
; last modified 20170116-0959

#define		FIRMWARE	_FIRMWARE

; in case of standalone assembly
#include "usual.h"

; *** first some ROM identification *** new 20150612
fw_start:
	.asc	0, "m", CPU_TYPE, "****", CR	; standard system file wrapper, new 20160309
	.asc	"boot", 0						; mandatory filename for firmware
fw_splash:
	.asc	"0.9b1 firmware for "
; at least, put machine name as needed by firmware!
fw_mname:
	.asc	MACHINE_NAME, 0

; advance to end of header
	.dsb	fw_start + $F8 - *, $FF	; for ready-to-blow ROM, advance to time/date field

; *** date & time in MS-DOS format at byte 248 ($F8) ***
	.word	$4800			; time, 9.00
	.word	$4A30			; date, 2017/	SEC					; emulation mode for a moment (2+2)

fwSize	=	$10000 - fw_start -256	; compute size NOT including header!

; filesize in top 32 bits NOT including header, new 20161216
	.word	fwSize			; filesize
	.word	0				; 64K space does not use upper 16-bit
; *** end of standard header ***

; ********************
; *** cold restart ***
; ********************
; basic init
reset:
	SEI				; cold boot (2) not needed for simulator?
	CLD				; just in case, a must for NMOS (2)
; * this is in case a 65816 is being used, but still compatible with all *
	SEC				; would set back emulation mode on C816
	.byt	$FB		; XCE on 816, NOP on C02, but illegal 'ISC $0005, Y' on NMOS!
	ORA $0			; the above would increment some random address in zeropage (NMOS) but this one is inocuous on all CMOS
; * end of 65816 specific code *
	LDX #SPTR		; initial stack pointer, machine-dependent, must be done in emulation for '816 (2)
	TXS				; initialise stack (2)

; as this firmware should be 65816-only, check for its presence or nothing!
; derived from the work of David Empson, Oct. '94
#ifdef	SAFE
	SED					; decimal mode
	LDA #$99			; load highest BCD number (sets N too)
	CLC					; prepare to add
	ADC #$02			; will wrap around in Decimal mode (should clear N)
	CLD					; back to binary
		BMI cpu_bad			; NMOS, N flag not affected by decimal add
	TAY					; let us preload Y with 1 from above
	LDX #$00			; sets Z temporarily
	TYX					; TYX, 65802 instruction will clear Z, NOP on all 65C02s will not
	BNE fw_cpuOK		; Branch only on 65802/816
cpu_bad:
		JMP lock			; cannot handle BRK, alas
fw_cpuOK:
#endif

; it can be assumed 65816 from this point on

; *** optional firmware modules ***
post:

; might check ROM integrity here
;#include "firmware/modules/romcheck.s"

; SRAM test
;#include "firmware/modules/ramtest.s"

; *** set default CPU type ***
	LDA #'V'			; 65816 only (2)
	STA fw_cpu			; store variable (4)
; *** preset kernel start address (standard label from ROM file) ***
	.al: REP #$20		; ** 16-bit memory ** (3)
	LDA #kernel			; get full address (3)
	STA fw_warm			; store in sysvars (5)

	LDA #IRQ_FREQ	; interrupts per second
	STA irq_freq	; store speed... 

	LDX #4				; max WORD offset in uptime seconds AND ticks, assume contiguous (2)
res_sec:
		STZ ticks, X		; reset word (5)
		DEX					; next word backwards (2+2)
		DEX
		BPL res_sec			; zero is included
;	LDX #$C0			; enable T1 (jiffy) interrupt only, this in 8-bit (2+4)
;	STX VIA_J + IER

	.as: .xs: SEP #$30	; all back to 8-bit, just in case, might be removed if no remote boot is used (3)

; ** just before booting, print an exclamation mark for testing! **
	LDA #'!'
	JSR $FFEE			; direct print!

; *** firmware ends, jump into the kernel ***
start_kernel:
	SEC					; emulation mode for a moment (2+2)
	XCE
	JMP (fw_warm)		; (6)

; *** vectored NMI handler with magic number ***
nmi:
; save registers AND system pointers
	.al: .xl: REP #$30	; ** whole register size, just in case **
	PHA					; save registers (3x4)
	PHX
	PHY
; make NMI reentrant, new 65816 specific code
; assume all registers in 16-bit size, this is 6+2 bytes, 16+2 clocks! (was 10b, 38c)
	LDY sysptr			; get original word (4+4)
	LDA systmp			; this will get sys_sp also!
	PHY					; store them in similar order (4+4)
	PHA
; prepare for next routine while regs are still 16-bit!
	LDA fw_nmi			; copy vector to zeropage (5+4)
	STA sysptr
	.as: .xs: SEP #$30	; ** back to 8-bit size! **
; check whether user NMI pointer is valid
	LDX #3				; offset for (reversed) magic string, no longer preloaded (2)
	LDY #0				; offset for NMI code pointer (2)
nmi_chkmag:
		LDA (sysptr), Y		; get code byte (5)
		CMP fw_magic, X		; compare with string (4)
			BNE rst_nmi			; not a valid routine (2/3)
		INY					; another byte (2)
		DEX					; internal string is read backwards (2)
		BPL nmi_chkmag		; down to zero (3/2)
do_nmi:
	LDX #0				; null offset
	JSR (fw_nmi, X)		; call actual code, ending in RTS (6)
; *** here goes the former nmi_end routine ***
nmi_end:
	.al: .xl: REP #$30	; ** whole register size to restore **
	PLA					; retrieve saved vars (5+5)
	PLY
	STA systmp			; I suppose is safe to alter sys_sp too (4+4)
	STY sysptr
	PLY					; restore regular registers (3x5)
	PLX
	PLA
	RTI					; resume normal execution and register size, hopefully

fw_magic:
	.asc	"*jNU"		; reversed magic string

; *** execute standard NMI handler ***
rst_nmi:
	PEA nmi_end-1		; prepare return address
; ...will continue thru subsequent standard handler, its RTS will get back to ISR exit

; *** default code for NMI handler, if not installed or invalid, should end in RTS ***
std_nmi:
#include "firmware/modules/std_nmi.s"


; *** administrative functions ***
; A0, install jump table
; kerntab <- address of supplied jump table
fw_install:
	LDY #0				; reset index (2)
	_ENTER_CS			; disable interrupts! (5)
	.al: REP #$20		; ** 16-bit memory ** (3)
fwi_loop:
		LDA (kerntab), Y	; get word from table as supplied (6)
		STA fw_table, Y		; copy where the firmware expects it (5)
		INY					; advance two bytes (2+2)
		INY
		BNE fwi_loop		; until whole page is done (3/2)
	_EXIT_CS			; restore interrupts if needed, will restore size too (4)
	_DR_OK				; all done (8)


; A2, set IRQ vector
; kerntab <- address of ISR
fw_s_isr:
	_ENTER_CS				; disable interrupts and save sizes! (5)
	.al: REP #$20			; ** 16-bit memory ** (3)
	LDA kerntab				; get pointer (4)
	STY fw_isr				; store for firmware (5)
	_EXIT_CS				; restore interrupts if needed, sizes too (4)
	_DR_OK					; done (8)


; A4, set NMI vector
; kerntab <- address of NMI code (including magic string)
; might check whether the pointed code starts with the magic string
; no need to disable interrupts as a partially set pointer would be rejected
fw_s_nmi:
#ifdef	SAFE
	LDX #3					; offset to reversed magic string
	LDY #0					; reset supplied pointer
fw_sn_chk:
		LDA (kerntab), Y		; get pointed handler string char
		CMP fw_magic, X			; compare against reversed string
		BEQ fw_sn_ok			; no problem this far...
			_DR_ERR(CORRUPT)		; ...or invalid NMI handler
fw_sn_ok:
		INY						; try next one
		DEX
		BPL fw_sn_chk			; until all done
#endif
; transfer supplied pointer to firmware vector
; not worth going 16-bit as will by 9b/19c instead of 10b/14c
	LDY kerntab				; get LSB (3)
	LDA kerntab+1			; get MSB (3)
	STY fw_nmi				; store for firmware (4+4)
	STA fw_nmi+1
	_DR_OK					; done (8)

; A6, patch single function
; kerntab <- address of code
; Y <- function to be patched
fw_patch:
#ifdef		LOWRAM
	_DR_ERR(UNAVAIL)		; no way to patch on 128-byte systems
#else
; worth going 16-bit as status was saved, 10b/21c , was 13b/23c
	_ENTER_CS				; disable interrupts and save sizes! (5)
	.al: REP #$20			; ** 16-bit memory ** (3)
	LDA kerntab				; get full pointer (4)
	STA fw_table, Y			; store into firmware (5)
	_EXIT_CS				; restore interrupts and sizes (4)
	_DR_OK					; done (8)
#endif


; A8, get system info, API TBD
; zpar -> available pages of (kernel) SRAM
; zpar+2.W -> available BANKS of RAM
; zpar2.B -> speedcode
; zpar2+2.B -> CPU type
; zpar3.W/L -> points to a string with machine name
; *** WILL change ABI/API ***
fw_gestalt:
	LDA himem		; get pages of kernel SRAM (4)
	STA zpar		; store output (3)
	PHP				; keep sizes (3)
	REP #$20		; ** 16-bit memory **
	STZ zpar+2		; no bankswitched RAM yet (4)
	STZ zpar3+2		; same for string address (4)
	LDA #fw_mname	; get string pointer (3)
	STA zpar3		; put it outside (4)
	PLP				; restore sizes (4)
	LDA #SPEED_CODE	; speed code as determined in options.h (2+3)
	STA zpar2
	LDA fw_cpu		; get kind of CPU (previoulsy stored or determined) (4+3)
	STA zpar2+2
	_DR_OK			; done (8)

; A10, poweroff etc
; Y <- mode (0 = suspend, 2 = warmboot, 4 = coldboot, 6 = poweroff)
; C -> not implemented
fw_power:
	TYA					; get subfunction offset
	TAX					; use as index
	_JMPX(fwp_func)		; select from jump table

fwp_off:
	_PANIC("{OFF}")		; just in case is handled

fwp_susp:
	_DR_OK				; just continue execution

fwp_cold:
	JMP ($FFFC)			; call 6502 vector, not really needed here but...

; sub-function jump table (eeeek)
fwp_func:
	.word	fwp_susp	; suspend	+FW_STAT
	.word	kernel		; shouldn't use this, just in case
	.word	fwp_cold	; coldboot	+FW_COLD
	.word	fwp_off		; poweroff	+FW_OFF

; *** administrative jump table ***
; PLEASE CHANGE ORDER ASAP
fw_admin:
	.word	fw_install
	.word	fw_s_isr
	.word	fw_s_nmi
	.word	fw_patch	; new order 20150409
	.word	fw_gestalt
	.word	fw_power

; filling for ready-to-blow ROM
#ifdef		ROM
	.dsb	kernel_call-*, $FF
#endif

; *** minimOS function call primitive ($FFC0) ***
* = kernel_call
	_JMPX(fw_table)	; macro for NMOS compatibility (6)

; filling for ready-to-blow ROM
#ifdef		ROM
	.dsb	admin_call-*, $FF
#endif

; *** administrative meta-kernel call primitive ($FFD8) ***
* = admin_call
	_JMPX(fw_admin)		; takes 6 clocks with CMOS

; filling for ready-to-blow ROM
#ifdef	ROM
	.dsb	lock-*, $FF
#endif

; *** panic routine, locks at very obvious address ($FFE1-$FFE2) ***
* = lock
	SEC					; unified procedure 20150410, was CLV
panic_loop:
	BCS panic_loop		; no problem if /SO is used, new 20150410, was BVC

; no 65816 vectors on simulator!

; *** vectored IRQ handler ***
irq:
	JMP (fw_isr)	; vectored ISR (6)

; filling for ready-to-blow ROM
#ifdef	ROM
	.dsb	$FFFA-*, $FF
#endif

; *** 65(C)02 ROM vectors ***
* = $FFFA				; just in case
	.word	nmi			; (emulated) NMI	@ $FFFA
	.word	reset		; (emulated) RST	@ $FFFC
	.word	irq			; (emulated) IRQ	@ $FFFE
