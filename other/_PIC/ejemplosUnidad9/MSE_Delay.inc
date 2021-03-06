;************************************************************************************************************************
;												MSE_Delay.inc
;											Autor: Mikel Etxebarria
;								(c) Ingenier�a de Microsistemas Programados S.L.
;											www.microcontroladores.com
;											 PIC16/18FXXX	Bilbao 2010
;
;Macro y rutina de temporizaci�n que se ajustan en funci�n de la frecuencia de trabajo Fosc. En el programa principal 
;se debe definir:
;a)	La frecuencia de trabajo (en hz) mediante ... "#define Fosc xxxxxxxx"
;b)	Inicio de las variables de temporizaci�n " MSE_Delay_V	equ	0xXX "
;
;El usuario llama a la macro desde su programa principal mediante ... "Delay xxxx Milis"
;
;Se obtiene una precisi�n razonable con valores de temporizaci�n desde 1 hasta 2000 mS y a frecuencias Fosc 
;que van desde 1MHz hasta 48MHz

#define         Milis			* D'1000000'

				CBLOCK	MSE_Delay_V		;Inicio de las variables. Ser� la primera						
					MSE_Delay_1			;direcc�n libre disponible
					MSE_Delay_2
					MSE_Delay_3
				ENDC

Delay	macro	tiempo_ns	;tiempo_ns expresa en ns el tiempo de temporizaci�n deseado
	
	ifndef Fosc			;En el programa principal se ha definir la frecuencia de trabajo en Hz								
	messg "ERROR !! - Establecer la frecuencia de trabajo (p.e. #define	Fosc 4000000)"
	exitm
	endif

	radix dec												;Operaciones en base decimal
	variable ciclo_instruc_ns =  (( 1000000000 ) / (Fosc / 4 ))	;Calcula ciclo de instrucci�n en funci�n de la frecuencia Fosc
	variable ciclos = (tiempo_ns / ciclo_instruc_ns)		;Calcula el n� de ciclos necesarios para la temporizaci�n deseada

  
				movlw	upper (ciclos/4)+1
				movwf	MSE_Delay_1
				movlw	high (ciclos/4)+1
				movwf	MSE_Delay_2
				movlw	low (ciclos/4)
				movwf	MSE_Delay_3		;Carga las variables de temporizaci�n con el n� de ciclos calculado
				call	MSE_Delay
 
 endm

MSE_Delay		clrwdt					;Bucles de temporizaci�n
				decfsz	MSE_Delay_3,f
				goto	MSE_Delay
				decfsz	MSE_Delay_2,f
				goto	MSE_Delay
				decfsz	MSE_Delay_1,f
				goto	MSE_Delay
				return

