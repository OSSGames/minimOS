;****************************************************************************************
;								TECLADO.INC
;						Autor: Mikel Etxebarria
;			(c) Ingenier�a de Microsistemas Programados S.L.
;						www.microcontroladores.com
;								Bilbao 2006
;
;Presenta dos rutinas que permiten la gesti�n de un teclado hexadecimal organi-
;zado en una matriz de 4 x 4 
;
;Este fichero se debe incluir en los futuros programas fuente mediante la directiva INCLUDE.
;
;Key_Scan: 	realiza un barrido del teclado y detecta si hay alguna tecla pulsada. La
;			variable "Tecla" se carga con el c�digo de la tecla pulsada o el 0x80 en caso 
;			de no haber ninguna.
;
;Key_BCD:	Convierte el c�digo de tecla en c�digo BCD (del 0 a F). Antes de llamar a la
;			rutina la variable "Tecla" contiene el c�digo de tecla. Al finalizar, la
;			rutina devuelve el c�digo BCD en la misma variable "Tecla".
;
;El teclado hex. se supone conectado a la puerta B y su disposici�n es la siguiente:
;
;		 		      TECLA	     CODIGO
;                 		      -----	--------------
;			|---|---|---|---|	0	01111101 = 0x7D
;	RB4 <--	| 1 | 2 | 3 | A |	1	11101110 = 0xEE
;			|---|---|---|---|	2	11101101 = 0xED
;	RB5 <--	| 4 | 5 | 6 | B |	3	11101011 = 0xEB
;			|---|---|---|---|	4	11011110 = 0xDE
;	RB6 <--	| 7 | 8 | 9 | C |	5	11011101 = 0xDD
;			|---|---|---|---|	6	11011011 = 0xDB
;	RB7 <--	| * | 0 | # | D |	7	10111110 = 0xBE
;			|---|---|---|---|	8	10111101 = 0xBD
;				      	        9	10111011 = 0xBB
;			^   ^   ^   ^		A	11100111 = 0xE7
;			|   |   |   |      	B	11010111 = 0xD7
;			RB0 RB1 RB2 RB3		C	10110111 = 0xB7
;								D	01110111 = 0x77
;								*	01111110 = 0x7E
;								#	01111011 = 0x7B

		cblock	Key_var   	;Inicio de las variables
		Tecla				;Retorno del c�digo BCD de la tecla
		Key_1				;N� de columnas a explorar
		Key_2               ;Temporal de c�digo
		Key_Delay_1			;Variable de temporizaci�n
		Key_Delay_2			;Variable de temporizaci�n
		TRISB_Temp			;Estado temporal de TRISB
		endc						

;**************************************************************************************
;Key_Scan: Rutina de exploraci�n del teclado. La variable "Tecla" retorna con el c�digo
;de la tecla pulsada o con el c�digo 0x80 si no se pulsa ninguna.

Key_Scan:	bsf		STATUS,RP0	;Seleciona p�gina 1
			movf	TRISB,W
			bcf		STATUS,RP0
			movwf	TRISB_Temp	;Salva estado actual de TRISB prcedente
                                                ; de otros programas
			bsf		STATUS,RP0
			movlw	b'11110000'
			movwf	TRISB		;RB4-RB7 entradas, RB0-RB3 salidas
			bcf		STATUS,RP0	;Selecciona p�gina 0
			movlw	4
			movwf	Key_1		;N� de columnas a explorar
			movlw	b'11110111'
			movwf	Tecla		;1� columna a activar
Key_Scan_1:	movf    Tecla,W
			movwf	PORTB		;Activa columna				
			nop
			nop
			nop
			nop
			nop
			nop

			movf	PORTB,W
			movwf	Key_2
			subwf	Tecla,W		;Lee las filas
			btfss	STATUS,Z	;Hay alguna pulsada ?
			goto	Key_Scan_2	;Si
			bsf		STATUS,C	;No, no hay ninguna en esa columna
			rrf		Tecla,F		;Seleciona siguiente columna
			decfsz	Key_1,F		;Se han explorado todas las columnas ??
			goto	Key_Scan_1	;No, explorar la siguiente
			movlw	0x80
			movwf	Tecla		;Si, retorna c�digo 0x80 (no hay pulsaci�n)
Key_Scan_5:	movf	TRISB_Temp,W
			bsf		STATUS,RP0	;Selecciona p�gina 1
			movwf	TRISB		;Repone TRISB al valor original procedente 
						;de otros programas
			bcf		STATUS,RP0	;Selecciona p�gina 0
			return				;Fin de exploraci�n
				
Key_Scan_2:	movlw	.100		;Bucle de temporizaci�n de unos 200 mS
			movwf	Key_Delay_1	;para evitar el rebote de los pulsado-
Key_Scan_3:	clrf	Key_Delay_2	;res.
Key_Scan_4:	clrwdt
			nop
			nop
			nop
			nop
			decfsz	Key_Delay_2,F
			goto	Key_Scan_4
			decfsz	Key_Delay_1,F
			goto	Key_Scan_3
				
			movf	Key_2,W		;Guardar c�digo de tecla
			movwf	Tecla
			call	Key_BCD		;Convertir c�digo de tecla a BCD
			goto	Key_Scan_5	;Fin de exploraci�n													

;*************************************************************************************
;Key_BCD: Convierte a BCD el c�digo de tecla que haya en la variable "Tecla" 
 
Key_Tabla	movf	Key_1,W
			addwf	PCL,F		;Calcula desplazamiento
			retlw	0x7d		;0
			retlw	0xee		;1
			retlw	0xed		;2
			retlw	0xeb		;3
			retlw	0xde		;4
			retlw	0xdd		;5
			retlw	0xdb		;6
			retlw	0xbe		;7
			retlw	0xbd		;8
			retlw	0xbb		;9
			retlw	0xe7		;A
			retlw	0xd7		;B
			retlw	0xb7		;C
			retlw	0x77		;D
			retlw	0x7e		;*
			retlw	0x7b		;#
				
Key_BCD:	movf	Tecla,W
 			movwf	Key_2		;Almacena el c�digo de tecla temporalmente
 			clrf	Key_1		;Contador BCD a 0
Key_BCD_2	call	Key_Tabla	;Busca c�digo en la tabla
 			subwf	Key_2,W		;Compara con el de la tecla pulsada
 			btfsc	STATUS,Z	;Coincide ??
 			goto	Key_BCD_1	;Si, el valor de Key_1 es el c�digo BCD de la tecla
 			incf	Key_1,F		;No, incrementa contador BCD
 			movlw	0x10
			subwf	Key_1,W
			btfss	STATUS,Z	;Se han comparado los 16 valores posibles (0-F) ?
			goto	Key_BCD_2	;No, a comparar el siguiente
			movlw	0x80		;Si, la pulsaci�n ha sido incorrecta (una o m�s teclas
			movwf	Tecla		;pulsadas). Se retorna el c�digo 0x80
			return	
Key_BCD_1	movf	Key_1,W
			movwf	Tecla		;Carga contador BCD en la variable Tecla de salida
			return
				
