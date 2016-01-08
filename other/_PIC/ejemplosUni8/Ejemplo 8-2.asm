;						CURSO: "Microcontroladores PIC: Nivel I"
;									SEPTIEMBRE 2014
;							Autor: Mikel Etxebarria Isuskiza
;						Ingenier�a de Microsistemas Programados S.L.
;							wwww.microcontroladores.com	
;
;								
;Ejemplo 8-2: Las interrupciones por cambio de estado.
;
;El ejemplo trata de mostrar la posibilidad de provocar una interrupci�n cada vez que
;cualquiera de las l�neas RB0-RB7, actuando como entradas, cambia de estado l�gico. En este caso
;se emplean las l�neas RB0-RB2. Un cambio de estado en cualquiera de ellas provocar� que las
;salidas RA0-RA2 reflejen, durante 1 segundo, qu� l�nea cambio de estado.
	
		List	p=16F886		;Tipo de procesador
		include	"P16F886.INC"	;Definiciones de registros internos
		#define Fosc 4000000	;Velocidad de trabajo

;Ajusta los valores de las palabras de configuraci�n durante el ensamblado.Los bits no empleados
;adquieren el valor por defecto.Estos y otros valores se pueden modificar seg�n las necesidades

		__config	_CONFIG1, _LVP_OFF&_PWRTE_ON&_WDT_OFF&_EC_OSC&_FCMEN_OFF&_BOR_OFF	;Palabra 1 de configuraci�n
		__config	_CONFIG2, _WRT_OFF&_BOR40V									;Palabra 2 de configuraci�n

A_Estado		equ	0x20			;Memoriza el estado previo de las entradas RB0-RB2
N_Estado		equ	0x21			;Memoriza el nuevo estado de las entradas RB0-RB2
MSE_Delay_V	equ	0x73				;Variables (3) empleadas por las macros de temporizaci�n
                    
				org	0x00			;Vector de RESET
				goto	Inicio
				org	0x04			;Vector de interrupci�n
				goto	Interrupcion
				org	0x05

		include	"MSE_Delay.inc"	;Incluir rutinas de temporizaci�n

Interrupcion   	Delay	40 Milis	;Temporiza 40mS para evitar rebotes

				movf	N_Estado,W
				movwf	A_Estado	;Actualiza el estado anterior de RB2-RB0
				movf	PORTB,W		;Lee el estado de las entradas RB2:RB0
				andlw	b'00000111'
				movwf	N_Estado	;Actualiza el nuevo estado de RB2-RB0	
				xorwf	A_Estado,W	;Determina cu�l ha sido (RB2-RB0)la que ha cambiado
				movwf	PORTA		;Visualiza por RA2-RA0
				Delay	1000 Milis
				clrf	PORTA		;Ha pasado 1 seg., desconectar las salidas

				bcf		INTCON,RBIF	;Repone flag de la interrupci�n por cambio de estado
				retfie				;Retorno de interrupci�n
		
Inicio			clrf 	PORTA		;Borra los latch de salida
				bsf		STATUS,RP0
				bsf		STATUS,RP1	;Selecciona banco 3
				clrf	ANSEL		;Puerta A digital
				clrf	ANSELH		;Puerta B digital
				bcf		STATUS,RP1	;Selecciona banco 1
				movlw	b'11111000'
				movwf	TRISA		;RA2-RA0 salidas
				movlw	b'00000111'
				movwf	TRISB		;RB2-RB0 entradas
				movlw	b'00000111'
				movwf	IOCB		;Habilita interupci�n por cambio de estado para RB2-RB0 
				bcf		STATUS,RP0	;Selecciona banco 0		                                                                         
				movf	PORTB,W
				andlw	b'00000111'
				movwf 	N_Estado	;Lee y salva el estado actual de las entradas RB2-RB0
				movlw	b'10001000'
				movwf	INTCON		;Activa la interrupci�n por cambio de estado RBIE

;Este es el cuerpo del programa principal. Se mantiene en estado SLEEP hasta que 
;se produce interrupci�n

Loop			sleep
				nop
				goto 	Loop

				end					;Fin del programa fuente

