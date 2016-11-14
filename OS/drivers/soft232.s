; software serial port emulator for minimOS!
; v0.5a2, for generic 65C02 (65816-savvy)
; (c) 2016 Carlos J. Santisteban
; last modified 20161114-1106

; VIA bit functions
; Tx	= PA0 (any 0...5, set masks accordingly)
; Rx	= PA7 (or PA6 for easy checking)
; /CTS	= PA6 (or PA7 for easy checking)
; /RTS	= PA1 (or any 0...5)

; initially designed for 9600,n,1 on 1 MHz systems (Chihuahua)
; 104.167 clocks/bit!!!
; would be EXACTLY 192 cycles at 1.8432 MHz

; ***********************
; *** minimOS headers ***
; ***********************
#ifndef		HEADERS
#include "usual.h"
#endif

; *** begins with sub-function addresses table ***
	.byt	232			; physical driver number D_ID (TBD)
	.byt	A_COUT+A_CIN	; basic I/O driver, non-interrupt-driven
	.word	srs_init	; initialize 'device', called by POST only
	.word	srs_exit	; no periodinc interrupt
	.word	srs_nreq	; D_REQ does nothing
	.word	srs_rcv		; read one byte from 'serial'
	.word	srs_send	; output one byte to 'serial'
	.word	srs_exit	; no need for 1-second interrupt
	.word	srs_nreq	; no block input
	.word	srs_nreq	; no block output
	.word	srs_exit	; shutdown procedure, leave VIA as it was...
	.word	srs_info	; points to descriptor string
	.byt	0			; reserved, D_MEM

; *** driver description ***
mm_info:
	.asc	"Serial-port emulation v0.5a2", 0

; *** single local variable, could be elsewhere in zeropage ***
zsr_vote	= sys_sp

; ************************
; *** initialise stuff ***
; ************************
srs_init:
	LDA VIA1+IORA		; previous data
	ORA #3				; set Tx (idle) and negate RTS (disable reception)
	STA VIA1+IORA		; set initial status
	LDA VIA1+DDRA		; get I/O config
	AND #%00111111		; PA6-7 as input
	ORA #%00000011		; PA0-1 as output
	STA VIA1+DDRA		; set config
	_DR_OK				; succeeded

; *****************************
; *** send one byte in io_c ***
; *****************************
srs_send:
	_ENTER_CS			; disable interrupts
	LDX #30				; timeout counter ~1.5 mS
; wait until receiver is available
srss_wait:
		BIT VIA1+IORA		; check input bits (4)
			BVC srss_cts		; exit loop if clear to send (2/3)
		JSR srs_41us		; half bit wait (41 incl JSR/RTS)
		DEX					; keep waiting (2)
		BNE srss_wait		; until timeout (3/2)
	_EXIT_CS			; restore interrupts if needed
	_DR_ERR(TIMEOUT)	; could not send in a timely fashion
srss_cts:
; ready to go, prepare some values
	LDX #9				; bits per byte incl. stop
	SEC					; this will be the stop bit!
; now put the start bit
	LDA #1				; mask for Tx, will be used anywhere (2)
	TRB VIA1+IORA1		; REset it! EEEEEEK (6)
	PHA: PLA			; 7 extra clocks delay!
	JSR srs_83us		; delay (83)
; still on until next bit is read
srss_bit:
		ROR io_c			; put bit to send in C (5)
		BCC srss_nzero		; was one (3/2)
			TRB VIA1+IORA		; otherwise put 0 (0/6) one clock early from start, but was 0 anyway
			BRA srss_sent		; this is done (0/3)
srss_nzero:
		TSB VIA1+IORA		; it is a one (6/0) accurate from start
		NOP					; this should equalise paths! (2/0)
srss_sent:
		JSR srs_83us		; delay (83)
		DEX					; next bit (2)
		BNE ssrs_bit		; until done (3/2)
	_EXIT_CS			; restore interrupts
	_DR_OK				; succeeded

; ** delay for a bit (83us incl JSR/RTS) **
srs_83us:
	INC sys_sp			; for timing (5)
	LDY #13				; delay constant (2)
srs83_loop:
		DEY					; update countdown (2)
		BNE srs83_loop		; until done (3/2) total 64 for 13 iterations
srs_exit:
	RTS					; done (6)

; ** half-bit delay (41us incl JSR/RTS) **
srs_41us:
	LDY #5				; delay constant (2)
	BRA srs82_loop		; continue with accurate timing (3)

; ************************
; *** receive one byte ***
; ************************
srs_rcv:
	_ENTER_CS			; disable interrupts
	LDA #2				; mask for RTS
	TRB VIA1+IORA		; enable reception!
	LDX #136			; timeout counter ~1.5 mS
; wait until data is available
srsr_wait:
		BIT VIA1+IORA		; check input bits (4)
			BPL srsr_start		; exit loop upon start bit reception (2/3)
;		JSR srs_41us		; half bit wait (41)
		DEX					; keep waiting (2)
		BNE srsr_wait		; until timeout (3/2)
	_EXIT_CS			; restore previous interrupt state
; nreq for unexpected interrupt tasks! meaningless error, instead of NEXT_ISR
srs_nreq:
	_DR_ERR(EMPTY)		; could not receive anything within time frame
srsr_start:
; wait for the start bit to finish ** a bit of a kludge
	JSR srs_83us		; long wait (83)
	JSR srs_exit		; another (12)
	PHA: NOP: PLA		; remaining delay (9)
; let us read one byte
	LDX #8				; bits per byte (2)
	STZ io_c			; clear received value (3)
srsr_bit:
		STZ zsr_vote		; clear sample counter (3)
		LDY #3				; samples per bit (2)
srsr_sample:
			BIT VIA1+IORA		; check Rx (4)
			BPL srsr_zero		; was clear (3/2)
				INC zsr_vote		; otherwise vote for 1 (0/5)
				BRA srsr_took		; just took this (0/3)
srsr_zero:
			DEC zsr_vote		; vote for 0 (5/0)
			NOP					; equalise paths (2/0)
srsr_took:
			LDA $0100			; minimal delay! (8)
			LDA $0100
			DEY					; next sample (2)
			BNE srsr_sample		; vote again (3/2)
; three samples should take 79t, this takes 80 anyway
		BIT zsr_vote		; check sign (3)
		BPL srsr_one		; was set (3/2)
			CLC					; otherwise clear bit (0/2)
			BRA srsr_carry		; insert it (0/3)
srsr_one:
		SEC					; set bit (2/0)
		NOP					; equal lengths (2/0)
srsr_carry:
		ROR io_c			; insert into result (5)
		DEX					; go for next bit (2)
		BNE srsr_bit		; until complete (3/2)
; vote computed & bit set in 20 clocks (minus last one)
; should wait a bit for the stop bit!
	JSR srs_41us		; wait half a bit
	BIT VIA1+IORA		; check Rx line
	BMI srsr_stop		; looks like a stop bit
		JSR srsr_rts		; otherwise something went wrong
		_DR_ERR(CORRUPT)	; notify error
; disable receiver and finish
srsr_stop:
	JSR srs_41us		; wait a bit more (!)
	JSR srsr_rts		; disable receiver
	_DR_OK

; ** disable receiver and enable interrupts **
srsr_rts:
	_EXIT_CS			; no longer in a hurry
	LDA #2				; mask for /RTS
	TSB VIA1+IORA		; disable reception!
	RTS
