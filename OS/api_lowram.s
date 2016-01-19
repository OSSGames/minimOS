; minimOS generic Kernel API for LOWRAM systems
; v0.5a8
; (c) 2012-2016 Carlos J. Santisteban
; last modified 20160119

#ifndef		FINAL
	.asc	"<kern>"		; *** just for easier debugging *** no markup to skip
#endif

; *** dummy function, non implemented ***
unimplemented:		; placeholder here, not currently used
	_ERR(UNAVAIL)	; go away!


; *** K0, output a character *** revamped 20150208
; Y <- dev, zpar <- char
; destroys X, A... plus driver
; uses local2

dt_ptr = local2		; could be called by STRING
cio_of = dt_ptr + 2	; parameter switching between cin and cout

cout:
	LDA #D_COUT		; only difference from cin (2)
	STA cio_of		; store for further indexing (3)
	TYA				; for indexed comparisons (2)
	BNE k0_port		; not default (3/2)
		LDA default_out	; default output device (4)
k0_port:
	BMI k02_phys	; not a logic device (3/2)
; no need to check for windows or filesystem
; investigate rest of logical devices
		CMP #DEV_NULL	; lastly, ignore output
			BNE k02_nfound	; final error otherwise
		_EXIT_OK		; "/dev/null" is always OK
; optimised backwards loop 20150318, 13 bytes (+1), 5+11*n if not found, 13 if the LAST one
; old forward loop was 16 bytes, 9+17*n if not found, 15 if the first one
k02_phys:
	LDX drv_num		; number of drivers (4)
		BEQ k02_nfound	; no drivers at all! (2/3)
k02_loop:
		CMP drivers_id-1, X	; get ID from list, notice trick (4)
			BEQ k02_dev		; device found! (2/3)
		DEX				; go back one (2)
		BNE k02_loop	; repeat until end, will reach not_found otherwise (3/2)
k02_nfound:
	_ERR(N_FOUND)	; unknown device, needed before k02_dev in case of optimized loop
k02_dev:
	DEX				; needed because of backwards optimized loop (2)
	TXA				; get index in list (2)
	ASL				; two times (2)
	TAX				; index for address table!
; version 1 takes 27 clocks and 18 bytes ********
	CLC				; (2)
	LDA drivers_ad, X	; take table LSB (4)
	ADC cio_of			; compute final address, generic (3)
	STA dt_ptr			; store pointer (3)
	LDA drivers_ad+1, X	; same for LSB (4)
	ADC #0				; take carry into account (2+3)
	STA dt_ptr+1
	JMP (dt_ptr)		; go for it! (6?)

;version 2 takes 45 clocks and 21 bytes, although saves one routine
;	LDA drivers_ad, X	; take table LSB (4)
;	STA dt_ptr			; store driver base pointer (3)
;	LDA drivers_ad+1, X	; same for LSB (4)
;	STA dt_ptr+1		; (3)
;	LDY cio_of			; offset for table (3)
;dr_call:				; *** generic driver call, pointer set at locpt2, Y holds table offset+1 *** new 20150610
;	LDA (dt_ptr), Y		; destination pointer (5)
;	PHA					; put it on stack (3)
;	DEY					; go for LSB (2)
;	LDA (dt_ptr), Y		; repeat procedure (5+3)
;	PHA
;	PHP					; complete for RTI (3)
;	RTI					; the actual jump (7)


; *** K2, get a character *** revamped 20150209
; Y <- dev, zpar -> char, C = not available
; destroys X, A... plus driver
; uses locals[1-3]
; ** shares code with cout **

cin:
	LDA #D_CIN		; only difference from cout
	STA cio_of		; store for further addition
	TYA				; for indexed comparisons
	BNE k2_port		; specified
		LDA default_in	; default input device
k2_port:
	BPL k2_nph		; logic device
		JSR k02_phys	; check physical devices... but come back for events! new 20150617
			BCS k2_exit		; some error, send it back
; ** EVENT management **
; this might be revised, or supressed altogether!
		LDA zpar		; get received character
		CMP #' '		; printable?
			BCC k2_manage	; if not, might be an event
k2_exit:
		_EXIT_OK		; above comparison would set carry
; ** continue event management **
k2_manage:
; check for binary mode
	LDY cin_mode	; get flag, new sysvar 20150617
	BEQ k2_event	; should process possible event
		_STZY cin_mode	; back to normal mode
		_BRA k2_exit	; and return whatever was received
k2_event:
	CMP #16			; is it DLE?
	BNE k2_notdle	; otherwise check next
		INC cin_mode	; set binary mode!
		BNE k2_abort	; and supress received character, no need for BRA
k2_notdle:
	CMP #3			; is it ^C? (TERM)
	BNE k2_exit		; otherwise there's no more to check -- only signal for single-task systems!
		LDA #SIGTERM
		STA zpar2		; set signal as parameter
		LDY #0			; ***self-sent signal***
		_KERNEL(B_SIGNAL)	; send signal
k2_abort:
		_ERR(EMPTY)		; no character was received

k2_nph:
; only logical devs, no need to check for windows or filesystem
	CMP #DEV_RND	; getting a random number?
		BEQ k2_rnd		; compute it!
	CMP #DEV_NULL	; lastly, ignore input
		BNE k02_nfound	; final error otherwise
	_EXIT_OK		; "/dev/null" is always OK

k2_rnd:
; *** generate random number (TO DO) ***
	LDY ticks		; simple placeholder
	_EXIT_OK

; *** K4, reserve memory ***
; *** K6, release memory ***
; *** K48, get taskswitching info for multitasking driver ***
; not for 128-byte systems

malloc:
free:
ts_info:
	_ERR(UNAVAIL)	; not for 128-byte systems


; *** K8, get I/O port or window *** interface revised 20150208
; Y -> dev, zpar.l <- size+pos*64K, zpar3 <- pointer to window title!
; destroys A

open_w:
	LDA zpar			; asking for some size?
	ORA zpar+1
	BEQ k8_no_window	; wouldn't do it
		_ERR(NO_RSRC)
k8_no_window:
	LDY #0				; constant default device
	_EXIT_OK


; *** K10, close window ***
; *** K12, release window, will be closed by kernel ***
; Y <- dev

close_w:
free_w:
	_EXIT_OK		; doesn't do much, either


; *** K14, get approximate uptime, NEW in 0.4.1 *** revised 20150208, corrected 20150318
; zpar.W -> fr-ticks
; zpar2.L -> 24-bit uptime in seconds
; destroys X, A

uptime:
	LDX #1			; first go for remaining ticks (2 bytes) (2)
	_SEI			; don't change while copying (2)
k14_loop:
		LDA ticks, X	; get system variable byte (not uptime, corrected 20150125) (4)
		STA zpar, X		; and store them in output parameter (3)
		DEX				; go for next (2+3/2)
		BPL k14_loop
	LDX #2			; now for the uptime in seconds (3 bytes) (2)
k14_upt:
		LDA ticks+2, X	; get system variable uptime, new 20150318 (4)
		STA zpar2, X	; and store it in output parameter (3) corrected 150610
		DEX				; go for next (2+3/2)
		BPL k14_upt
	_CLI			; disabled for 62 clocks, not 53...
	_EXIT_OK


; *** K16, get available PID *** properly interfaced 20150417
; Y -> PID

b_fork:
	LDY #0			; no multitasking, system reserved PID
	_EXIT_OK

; *** K18, launch new loaded process *** properly interfaced 20150417 with changed API!
; API still subject to change... (default I/O, rendez-vous mode TBD)
; Y <- PID, zpar2.W <- addr (was z2L)
b_exec:
; non-multitasking version
	CPY #0			; should be system reserved PID
	BEQ k18_st		; OK for single-task system
		_ERR(NO_RSRC)	; no way without multitasking
k18_st:
	JSR k18_jmp		; call supplied address
	_EXIT_OK		; back to shell?
k18_jmp:
	LDA zpar2+1		; get address MSB first
	PHA				; put it on stack
	LDA zpar2		; same for LSB
	PHA
	PHP				; ready for RTI
	RTI				; actual jump, won't return here


; *** K20, get address once in RAM/ROM (kludge!) *** TO_DO TO_DO TO_DO *******************
; z2L -> addr, z10L <- *path
load_link:
; *** assume path points to filename in header, code begins +248
	CLC				; ready to add
	LDA z10			; get LSB
	ADC #248		; offset to actual code!
	STA z2			; store address LSB
	LDA z10+1		; get MSB so far
	ADC #0			; propagate carry!
	STA z2+1		; store address MSB
	LDA #0			; NMOS only
	STA z2+2		; STZ, invalidate bank...
	STA z2+3		; ...just in case
	BCS k20_wrap	; really unexpected error
	_EXIT_OK
k20_wrap:
	_ERR(INVALID)	; something was wrong


; *** K22, write to protected addresses *** revised 20150208
; Y <- value, zpar <- addr
; destroys A (and X for NMOS)

su_poke:
	TYA				; transfer value
	_STAX(zpar)		; store value, macro for NMOS
	_EXIT_OK


; *** K24, read from protected addresses *** revised 20150208
; Y -> value, zpar <- addr
; destroys A (and X for NMOS)

su_peek:
	_LDAX(zpar)		; store value, macro for NMOS
	TAY				; transfer value
	_EXIT_OK


; *** K26, prints a C-string *** revised 20150208
; Y <- dev, zpar3 <- *string (.w in current version)
; destroys A, Y (and X for NMOS)
; uses locals[0]
; calls cout (K0)

string:
	STY locals		; save Y in case cout destroys it
k26_loop:
		_LDAX(zpar3)	; get current character, NMOS too
			BEQ k26_end		; NUL = end-of-string
		STA zpar		; ready to go out
		LDY locals		; restore Y
		_KERNEL(COUT)	; call cout
		INC zpar3		; next character
	BNE k26_loop
		INC zpar3+1		; cross page boundary
	BNE k26_loop		; ...or BRA
k26_end:
	_EXIT_OK


; *** K28, disable interrupts *** revised 20150209
; C -> not authorized (?)

su_sei:
	SEI				; disable interrupts
	_EXIT_OK		; no error so far


; *** K30, enable interrupts *** revised 20150209

su_cli:				; not needed for 65xx, even with protection hardware
	CLI				; enable interrupts
	_EXIT_OK		; no error


; *** K32, enable/disable frequency generator (Phi2/n) on VIA *** revised 20150208...
; zpar.W <- dividing factor (times two?), C -> busy
; destroys A, X...

set_fg:
	LDA zpar
	ORA zpar+1
		BEQ k32_dis		; if zero, disable output
	LDA VIA+ACR		; get current configuration
		BMI k32_busy	; already in use
	LDX VIA+T1LL	; get older T1 latch values
	STX old_t1		; save them
	LDX VIA+T1LH
	STX old_t1+1
; *** TO_DO - should compare old and new values in order to adjust quantum size accordingly ***
	LDX zpar			; get new division factor
	STX VIA+T1LL	; store it
	LDX zpar+1
	STX VIA+T1LH
	STX VIA+T1CH	; get it running!
	ORA #$C0		; enable free-run PB7 output
	STA VIA+ACR		; update config
k32_none:
	_EXIT_OK		; finish anyway
k32_dis:
	LDA VIA+ACR		; get current configuration
		BPL k32_none	; it wasn't playing!
	AND #$7F		; disable PB7 only
	STA VIA+ACR		; update config
	LDA old_t1		; older T1L_L
	STA VIA+T1LL	; restore old value
	LDA old_t1+1
	STA VIA+T1LH	; it's supposed to be running already
; *** TO_DO - restore standard quantum ***
		_BRA k32_none
k32_busy:
	_ERR(BUSY)		; couldn't set

; *** K34, launch default shell *** new 20150604
; no interface needed
go_shell:
	JMP shell		; simply... *** SHOULD initialise SP and other things anyway ***

; *** K36, proper shutdown, with or without poweroff ***
; Y <- subfunction code (0=shutdown, 2=suspend, 6=warmboot, 4=coldboot) new API 20150603
; C -> couldn't poweroff or reboot (?)

shutdown:
	CPY #PW_STAT	; is it going to suspend?
		BEQ k36_stat		; don't shutdown system then!
	PHY				; store mode for later, first must do proper system shutdown
; ** the real stuff starts here **
; ask all braids ***but the current one*** to terminate
; then check flags until all braids ***but this one*** are free
; could return just here after some timeout
; now let's disable all drivers
	_SEI			; disable interrupts

#ifdef	SAFE
	_STZA dpoll_mx	; disable interrupt queues, just in case
	_STZA dreq_mx
	_STZA dsec_mx
#endif

; call each driver's shutdown routine
	LDA drv_num		; get number of installed drivers
	ASL				; twice the value as a pointer
	TAX				; use as index
; first get the pointer to each driver table
sd_loop:
; get address index
		DEX					; go back one address
		DEX
		LDA drivers_ad+1, X	; get address MSB (4)
		BEQ sd_done			; not in zeropage
		STA locals+1		; store pointer (3)
		LDA drivers_ad, X	; same for LSB (4+3)
		STA locals
		PHX					; save index for later
			LDY #D_BYE+1		; offset for shutdown routine
			JSR dr_call			; call routine from generic code!
		PLX					; retrieve index
		BNE sd_loop			; repeat until zero
; ** system cleanly shut, time to let the firmware turn-off or reboot **
sd_done:
	PLX				; retrieve mode as index!
	_JMPX(k36_tab)	; do as appropriate


; firmware interface
k36_off:
	LDY #PW_OFF			; poweroff
k36_fw:
	_ADMIN(POWEROFF)	; except for suspend, shouldn't return...
	RTS					; just in case was not implemented!
k36_stat:
	LDY #PW_STAT		; suspend
	BNE k36_fw			; no need for BRA
k36_cold:
	LDY #PW_COLD		; cold boot
	BNE k36_fw			; will reboot, shared code, no need for BRA
k36_warm:
	JMP kernel			; firmware no longer should take pointer, generic kernel knows anyway

k36_tab:
	.word	k36_off		; shutdown call
	.word	k36_stat	; suspend, shouldn't arrive here anyway
	.word	k36_cold	; cold boot via firmware
	.word	k36_warm	; warm boot direct by kernel


; *** K38, send UNIX-like signal to a braid ***
; zpar2.B <- signal to be sent , Y <- addressed braid
; uses locals[0] too
; don't know of possible errors

signal:
; *** single task interface ***
	TYA				; check correct PID, really needed?
		BNE k38_pid		; strange error?
	LDY zpar2		; get the signal
	CPY #SIGTERM	; clean shutoff
		BEQ k38_term
	CPY #SIGKILL	; suicide
		BEQ k38_kill
k38_pid:			; placeholder...
	_ERR(INVALID)	; unrecognised signal
k38_term:
	JSR k38_call	; call routine, RTS will get back here
k38_kill:
	_EXIT_OK		; *** don't know what to do here ***
k38_call:
	JMP (stt_handler)	; jump to single-word vector, don't forget to init it somewhere!

; *** K40, get execution flags of a braid ***
; Y <- addressed braid
; Y -> flags, TBD
; uses locals[0] too
; don't know of possible errors

status:
; *** single-task interface ***
	LDY #BR_RUN		; single-task systems are always running, or should I make an error instead?
	_EXIT_OK

; *** K42, get current braid PID ***
; Y -> PID, TBD
; uses locals[0] too
; don't know of possible errors

get_pid:
; *** single-task interface ***
	LDY #0			; system-reserved PID for single-task execution
	_EXIT_OK

; *** K44, set SIGTERM handler, default is like SIGKILL ***
; Y <- PID, zpar2.W <- SIGTERM handler routine (ending in RTS)
; uses locals[0] too
; bad PID is probably the only feasible error

set_handler:
; *** single-task interface ***
	LDA zpar2		; get LSB
	STA stt_handler	; store in single variable
	LDA zpar2+1		; same for MSB
	STA stt_handler+1
	_EXIT_OK

; *** K46, Yield CPU time to next braid ***
; supposedly no interface needed, don't think I need to tell if ignored

yield:
	_EXIT_OK		; no one to give CPU time away!

; *** end of kernel functions ***

; jump table, if not in separate 'jump' file
#ifndef		DOWNLOAD
#ifndef		FINAL
	.asc	"<jump>"	; easier extraction for 'jump' file
#endif
#ifdef		LOWRAM
fw_table:				; 128-byte systems' firmware get unpatchable table from here, new 20150318
#endif
k_vec:
	.word	cout		; output a character
	.word	cin			; get a character
	.word	malloc		; reserve memory (kludge!)
	.word	free		; release memory (kludgest!)
	.word	open_w		; get I/O port or window
	.word	close_w		; close window
	.word	free_w		; will be closed by kernel
	.word	uptime		; approximate uptime in ticks (new)
	.word	b_fork		; get available PID
	.word	b_exec		; launch new process
	.word	load_link	; get addr. once in RAM/ROM
	.word	su_poke		; write protected addresses
	.word	su_peek		; read protected addresses
	.word	string		; prints a C-string
	.word	su_sei		; disable interrupts, aka dis_int
	.word	su_cli		; enable interrupts (not needed for 65xx) aka en_int
	.word	set_fg		; enable frequency generator (VIA T1@PB7)
	.word	go_shell	; launch default shell, INSERTED 20150604
	.word	shutdown	; proper shutdown procedure, new 20150409, renumbered 20150604
	.word	signal		; send UNIX-like signal to a braid, new 20150415, renumbered 20150604
	.word	get_pid		; get PID of current braid, new 20150415, renumbered 20150604
	.word	set_handler	; set SIGTERM handler, new 20150417, renumbered 20150604
	.word	yield		; give away CPU time for I/O-bound process, new 20150415, renumbered 20150604
	.word	ts_info		; get taskswitching info, new 20150507-08, renumbered 20150604

#ifndef		FINAL
	.asc	"</jump>"	; easier extraction for 'jump' file
#endif
#else
#include "drivers.s"	; this package will be included with downloadable kernels
.data
#include "sysvars.h"	; donwloadable systems have all vars AND drivers after the kernel itself
#include "drivers.h"
user_sram = *			; the rest of SRAM
#endif
