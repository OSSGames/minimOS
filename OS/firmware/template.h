; generic firmware variables for minimOS·65
; v0.6a2
; (c) 2015-2018 Carlos J. Santisteban
; last modified 20180116-1025

-sysram:
#ifndef	LOWRAM
fw_table	.dsb	LAST_API, $0	; more efficient usage 171114, NOT available in 128-byte systems
fw_lastk	.word	0				; address of last installed kernel jump table! new 20180116
#endif
fw_isr		.word	0				; ISR vector
fw_nmi		.word	0				; NMI vector, fortunately checks for integrity
fw_warm		.word	0				; start of kernel, new 20150220
fw_cpu		.byt	'B'				; CPU type ('B'=generic 65C02...)
himem		.byt	0				; number of available 'kernel-RAM' pages, 0 means 128-byte RAM
; should add some high ram and rom shadowing info
irq_freq	.word	200				; jiffys per second
