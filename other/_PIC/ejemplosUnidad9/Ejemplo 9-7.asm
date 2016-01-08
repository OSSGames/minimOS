;						CURSO: "Microcontroladores PIC: Nivel I"
;									SEPTIEMBRE 2014
;							Autor: Mikel Etxebarria Isuskiza
;						Ingenier�a de Microsistemas Programados S.L.
;							wwww.microcontroladores.com	
;
;								
;Ejemplo 9-7: El TMR1 como divisor de frecuencias
;
;Mediante el generador de onda cuadrada del laboratorio se aplican pulsos por la 
;l�nea RC0/T1CKI. El contador cuenta N eventos procedentes del generador y a una frecuencia
;conocida (Fg). Al llegar a 0, la l�nea de salida RB0 cambia de estado. La frecuencia de salida
;en esta l�nea ser�: Fg/2*N
		
		List	p=16F886			;Tipo de procesador
		include	"P16F886.INC"		;Definiciones de registros internos

;Ajusta los valores de las palabras de configuraci�n durante el ensamblado.Los bits no empleados
;adquieren el valor por defecto.Estos y otros valores se pueden modificar seg�n las necesidades

		__config	_CONFIG1, _LVP_OFF&_PWRTE_ON&_WDT_OFF&_EC_OSC&_FCMEN_OFF&_BOR_OFF	;Palabra 1 de configuraci�n
		__config	_CONFIG2, _WRT_OFF&_BOR40V									;Palabra 2 de configuraci�n

Valor_N		equ	.10					;Valor por el que se divide la frecuencia

		
			org	0x00				;Vector de RESET	
			goto	Inicio
			org	0x04				;Vector de interrupci�n
			goto	Inter
			org	0x05

;Tratamiento de la interrupci�n. Cada vez que el TMR1 alcanza el valor prefijado, la salida
;RB0 cambia de estado		
Inter		movlw	low ~Valor_N+1
			movwf	TMR1L
			movlw	high ~Valor_N
			movwf	TMR1H			;Restaura el TMR1 con el valor a dividir
			bcf		PIR1,TMR1IF		;Repone el flag del TMR1
			movlw	b'00000001'
			xorwf	PORTB,F			;RB0 cambia de estado
			retfie		
		
;Programa principal
Inicio	    clrf 	PORTB			;Borra los latch de salida
			bsf		STATUS,RP0
			bsf		STATUS,RP1		;Banco 3
			clrf	ANSEL			;Puerta A digital
			clrf	ANSELH			;Puerta B digital
			bcf		STATUS,RP1		;Banco 1
			movlw	b'11111110'
			movwf	TRISB			;RB0 se configura como salida
			movlw	b'11111111'		
			movwf	TRISC			;Puerta C como entrada
			bsf		PIE1,TMR1IE		;Habilita interrupci�n del TMR1
			bcf		STATUS,RP0		;Selecciona banco 0

;El TMR1 act�a como contador externo as�ncrono y con un preescaler de 1:1

			movlw	b'00000111'
			movwf	T1CON
			movlw	low ~Valor_N+1
			movwf	TMR1L
			movlw	high ~Valor_N
			movwf	TMR1H			;Carga el TMR1 con el valor a dividir		
			movlw	b'11000000'
			movwf	INTCON			;Habilita interrupciones

Loop		sleep					;Modo de bajo consumo
			nop
			goto	Loop			;Bucle infinito		

			end						;Fin del programa fuente
