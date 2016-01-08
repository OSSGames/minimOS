;						CURSO: "Microcontroladores PIC: Nivel I"
;									SEPTIEMBRE 2014
;							Autor: Mikel Etxebarria Isuskiza
;						Ingenier�a de Microsistemas Programados S.L.
;							wwww.microcontroladores.com	
;
;								
;Ejemplo 8-1: La interrupci�n externa RBO/INT y el modo sleep.
;
;Se trata de comprobar la interrupci�n externa que se aplica a trav�s del pin RBO/INT
;El programa principal est� en un ciclo cerrado en modo SLEEP (standby de bajo consumo). Cada vez que
;se detecta un flanco descendente en RB0 se provoca una interrupci�n cuyo tratamiento hace iluminar 
;la salida RB3 durante 1 seg, volviendo luego al modo SLEEP.
	
		List	p=16F886		;Tipo de procesador
		include	"P16F886.INC"	;Definiciones de registros internos
		#define Fosc 4000000	;Velocidad de trabajo

;Ajusta los valores de las palabras de configuraci�n durante el ensamblado.Los bits no empleados
;adquieren el valor por defecto.Estos y otros valores se pueden modificar seg�n las necesidades

		__config	_CONFIG1, _LVP_OFF&_PWRTE_ON&_WDT_OFF&_EC_OSC&_FCMEN_OFF&_BOR_OFF	;Palabra 1 de configuraci�n
		__config	_CONFIG2, _WRT_OFF&_BOR40V									;Palabra 2 de configuraci�n

MSE_Delay_V	equ	0x70				;Variables (3) empleadas por las macros de temporizaci�n
                    
				org	0x00			;Vector de RESET
				goto	Inicio
				org	0x04			;Vector de interrupci�n
				goto	Interrupcion
				org	0x05

				include	"MSE_Delay.inc"	;Incluir rutinas de temporizaci�n

;Programa de tratamiento de la interrupci�n externa RB0/INT
Interrupcion 	bsf		PORTB,3		;Activa la salida RB3
				Delay	1000 Milis	;Temporiza 1 segundo
				bcf		PORTB,3		;Ha pasado 1", se desconectar la salida RB3
			  	bcf		INTCON,INTF	;Repone flag de la interrupci�n externa
				retfie				;Retorno de interrupci�n
		
Inicio			clrf 	PORTB		;Borra los latch de salida
				bsf		STATUS,RP0
				bsf		STATUS,RP1	;Selecciona banco 3
				clrf	ANSELH		;Puerta B digital
				bcf		STATUS,RP1	;Selecciona banco 1
				movlw	b'11110111'
				movwf	TRISB		;RB3 salida, RB0/INT entrada
				movlw	b'00000111'
				movwf	OPTION_REG	;RB0/INT sensible a flanco descendente
				bcf		STATUS,RP0	;Selecciona banco 0			                                                                         
				movlw	b'10010000'
				movwf	INTCON		;Activa la interrupci�n externa RB0/INT

;Este es el cuerpo del programa principal. Se mantiene en estado SLEEP hasta que 
;se produce interrupci�n

Loop			sleep
				nop
				goto 	Loop

				end					;Fin del programa fuente

