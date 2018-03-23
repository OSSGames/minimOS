; ISR for minimOS on LOWRAM systems
; v0.6a1, should match kernel.s
; features TBD
; (c) 2015-2018 Carlos J. Santisteban
; last modified 20180323-0926

#define		ISR		_ISR

#include "usual.h"

; **** the ISR code **** (initial tasks take 11t)
#ifdef	NMOS
	CLD						; NMOS only, 20150316, conditioned 20151029 (2)
#endif
	PHA						; save registers (3x3)
	_PHX
	_PHY

; *** place here HIGH priority async tasks, if required ***

; check whether from VIA, BRK... (7 if periodic, 6 if async)

;	ADMIN(IRQ_SRC)			; check source, **generic way**
;	JMPX(irq_tab)			; do as appropriate
;irq_tab:
;	.word periodic			; standard jiffy
;	.word asyncronous		; async otherwise

; alternative way, best for NMOS
;	ADMIN(IRQ_SRC)			; check source, **generic way**
;	TXA						; check offset at X
;	BNE periodic			; jump if required...
; ...and the fall into async, perhaps will exchange them for lower async latency!

; optimised, non-portable code
	BIT VIA+IFR				; much better than LDA + ASL + BPL! (4)
		BVS periodic		; from T1 (3/2)

; *********************************
; *** async interrupt otherwise *** (arrives here in 17 cycles if optimised)
; *********************************
; execute D_REQ in drivers
asynchronous:
; *** alternative way with fixed-size arrays (no queue_mx) *** 24 bytes, 18 if left for the whole queue
; *** isr_done if queue is empty in 14t (if EOQ-optimised!)
; *** 'first' async in 23t (total 40t)!!!
; *** skip each disabled in 18t (14t if NOT EOQ-opt)
; *** cycle between enabled (but not satisfied) in 37t+...
	LDX #MX_QUEUE	; get max queue size (2)
i_req:
		LDA drv_a_en-2, X	; *** check whether enabled, note offset, new in 0.6 *** (4)
		BPL i_rnx			; *** if disabled, skip this task *** (2/3)
			_PHX				; keep index! (3)
			JSR ir_call			; call from table (12...)
			_PLX				; restore index (4)
			BCC isr_done		; driver satisfied, thus go away NOW, BCC instead of BCS 20150320 (2/3)
			_BRA i_anx			; --- otherwise check next --- optional if optimised as below (3)
i_rnx:
		CMP #IQ_FREE		; is there a free entry? Should be the FIRST one, id est, the LAST one to be scanned (2)
			BEQ isr_done		; yes, we are done (2/3)
i_anx:
		DEX					; go backwards to be faster! (2+2)
		DEX					; decrease after processing, negative offset on call, less latency, 20151029
		BNE i_req			; until zero is done (3/2)

ir_done:
; lastly, check for BRK (11 if spurious, 13+BRK handler if requested)
	TSX					; get stack pointer (2)
	LDA $0104, X		; get saved PSR (4)
	AND #$10			; mask out B bit (2)
	BEQ isr_done		; spurious interrupt! (2/3)
		LDY #PW_SOFT		; BRK otherwise (firmware interface)
		_ADMIN(POWEROFF)
; *** continue after all interrupts dispatched ***
isr_done:
	_PLY	; restore registers (3x4 + 6)
	_PLX
	PLA
	RTI

; routines for indexed driver calling
ir_call:
	_JMPX(drv_asyn-2)	; address already computed, no return here, new offset 20151029
ip_call:
	_JMPX(drv_poll-2)

; *** here goes the periodic interrupt code *** (4)
periodic:
	LDA VIA+T1CL		; acknowledge periodic interrupt!!! (4)

; *** scheduler no longer here, just an optional driver! But could be placed here for maximum performance ***

; execute D_POLL code in drivers
	LDX #MX_QUEUE		; maximum valid index plus 2 (2)
i_poll:
		LDA drv_p_en-2 , X	; *** check whether enabled, new in 0.6 ***
		BPL i_rnx2			; *** if disabled, skip this task ***
			DEC drv_cnt-2, X	; otherwise continue with countdown
				BNE i_pnx			; did not expire, do not execute yet
			LDA drv_freq-2, X	; ...or pick original value...
			STA drv_cnt-2, X	; ...and reset it!
			_PHX				; keep index! (3)
			JSR ip_call			; call from table (12...)
; *** here is the return point needed for B_EXEC in order to create the stack frame ***
isr_schd:				; *** take this standard address!!! ***
			_PLX				; restore index (4)
			_BRA i_pnx			; --- check next --- optional if optimised as below
i_rnx2:
; --- try not to scan the whole queue, if no more entries --- optional
		CMP #IQ_FREE		; is there a free entry? Should be the FIRST one, id est, the LAST one to be scanned (2)
			BEQ ip_done			; yes, we are done (2/3)
i_pnx:
		DEX					; go backwards to be faster! (2+2)
		DEX					; no improvement with offset, all of them will be called anyway
		BNE i_poll			; until zero is done (3/2)
; *** continue after all interrupts dispatched ***
ip_done:
; update uptime, much faster new format
	INC ticks			; increment uptime count (6)
		BNE isr_done			; did not wrap (3/2)
	INC ticks+1			; otherwise carry (6)
		BNE isr_done			; did not wrap (3/2)
	INC ticks+2			; otherwise carry (6)
		BNE isr_done			; did not wrap (3/2)
	INC ticks+3			; otherwise carry (6)
	_BRA isr_done		; go away (3)

; *******************
; *** BRK handler ***
; *******************
; will be called via firmware interface, should be moved to kernel or rom.s

supplied_brk:			; should end in RTS anyway, 20160310
#include "isr/brk.s"