;						CURSO: "Microcontroladores PIC: Nivel I"
;									SEPTIEMBRE 2014
;							Autor: Mikel Etxebarria Isuskiza
;						Ingenier�a de Microsistemas Programados S.L.
;							wwww.microcontroladores.com	
;
;								
;Ejemplo 9-5: El TMR1 como contador
;
;Mediante el generador de onda cuadrada del laboratorio  se aplican pulsos por la 
;l�nea RC0/T1CKI. La pantalla LCD visualizar�, en binario, el contenido del TMR1
;
;Si se selecciona una muy baja frecuencia en el generador (1H aprox.), se puede apreciar 
;claramente que los incrementos del contador se producen en los flancos ascendentes de la
;se�al de onda cuadrada.

		List	p=16F886			;Tipo de procesador
		include	"P16F886.INC"		;Definiciones de registros internos

;Ajusta los valores de las palabras de configuraci�n durante el ensamblado.Los bits no empleados
;adquieren el valor por defecto.Estos y otros valores se pueden modificar seg�n las necesidades

		__config	_CONFIG1, _LVP_OFF&_PWRTE_ON&_WDT_OFF&_EC_OSC&_FCMEN_OFF&_BOR_OFF	;Palabra 1 de configuraci�n
		__config	_CONFIG2, _WRT_OFF&_BOR40V									;Palabra 2 de configuraci�n

Temporal_1	equ	0x20		;Variable temporal
Temporal_2	equ	0x21		;variable temporal
Lcd_var		equ	0x70		;Inicio de variables de las rutinas LCD

			org	0x00				;Vector de RESET	
			goto	Inicio
			org	0x05

			include	"LCD4bitsPIC16.inc"	;Incluir rutinas de manejo del LCD

;Visualiza: Esta rutina coge el octeto presente en la variable Temporal_1, lo convierte
;a 8 caracteres ASCII (0 o 1) y los visualiza sobre el LCD

Visualiza:		movlw	.8
				movwf	Temporal_2		;N� de caracteres a visualizar
Visual_loop		rlf		Temporal_1,F
				btfsc	STATUS,C		;Testea el bit a visualizar
				goto	Bit_1			;Est� a 1
				movlw	'0'
				goto	Visu_1
Bit_1			movlw	'1'
Visu_1			call	LCD_DATO		;Visualiza el "0" o el "1" sobre el LCD
				decfsz	Temporal_2,F	;Siguiente bit/car�cter
				goto	Visual_loop
				return
		
;Programa principal
Inicio	      	bsf		STATUS,RP0
				bsf		STATUS,RP1		;Banco 3
				clrf	ANSEL			;Puerta A digital
				clrf	ANSELH			;Puerta B digital
				bcf		STATUS,RP1		;Banco 1
				movlw	b'11111111'	
				movwf	TRISC			;Puerta C como entrada
				bcf		STATUS,RP0		;Selecciona banco 0

;El TMR1 act�a como contador externo as�ncrono y con un preescaler de 1:1
				clrf	TMR1L
				clrf	TMR1H			;Puesta a 0 del TMR1
				movlw	b'00000011'
				movwf	T1CON			;Configura TMR1 en modo contador

;Inicio de la pantalla LCD
				call	UP_LCD			;Configura puerto para el LCD
				call	LCD_INI			;Inicia el LCD
				movlw	b'00001100'
				call	LCD_REG			;LCD On, cursor y blink Off
	
Loop			movlw	0x80
				call	LCD_REG			;Cursor home
				movf	TMR1H,W
				movwf	Temporal_1		;Lee byte alto del TMR1
				call	Visualiza		;Visualiza en binario
				movf	TMR1L,W
				movwf	Temporal_1		;Lee byte bajo del TMR1
				call	Visualiza		;Visualiza en binario

				goto	Loop			;Bucle infinito		

				end						;Fin del programa fuente
