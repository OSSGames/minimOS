; nanoBoot-SO NMI handler for 6502
; (c) 2018 Carlos J. Santisteban
; last modified 20180823-1503

nb_nmi:
	CLV					; allow zero by default eeeeek (2)
	CLC					; if no overflow... (2)
	BVC nn_vc			; ...let new bit as 0... (3/4)
		SEC					; ...otherwise set it
nn_vc:
	ROL nb_rcv			; inject new bit (5)
	ROR nb_flag			; this will set bit 7 accordingly (5)
	RTI					; (6) total 23/24 clocks plus 7 of NMI