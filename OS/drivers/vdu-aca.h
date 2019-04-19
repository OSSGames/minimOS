; minimOS driver for Acapulco built-in VDU
; variables for v0.6
; last modified 20190419-1217

va_xor		.byt	0		; mask to be EORed with glyph data
va_sch		.word	0		; limit address for scroll triggering
va_ba		.word	0		; CRTC start address, little-endian
va_cur		.word	0		; current position, little-endian
va_attr		.byt	0		; current attributes, %ppppiiii
va_col		.byt	0		; flag 0=normal, 16=binary mode, 18=wait for ink, 20=wait for paper, 23=wait for Y, 24=wait for X
