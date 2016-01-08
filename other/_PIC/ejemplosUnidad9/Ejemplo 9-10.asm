;						CURSO: "Microcontroladores PIC: Nivel I"
;									SEPTIEMBRE 2014
;							Autor: Mikel Etxebarria Isuskiza
;						Ingenier�a de Microsistemas Programados S.L.
;							wwww.microcontroladores.com	
;
;								
;Ejemplo 9-9: ADIVINA EL NUMERO: Ejemplo de entretenimiento consistente en adivinar un n�mero
;aleatorio generado por el PIC. Se emplea la pantalla LCD y el teclado y se dispone
;de una serie de oportunidades.

		List	p=16F886		;Tipo de procesador
		include	"P16F886.INC"	;Definiciones de registros internos

;Ajusta los valores de las palabras de configuraci�n durante el ensamblado.Los bits no empleados
;adquieren el valor por defecto.Estos y otros valores se pueden modificar seg�n las necesidades

		__config	_CONFIG1, _LVP_OFF&_PWRTE_ON&_WDT_OFF&_EC_OSC&_FCMEN_OFF&_BOR_OFF	;Palabra 1 de configuraci�n
		__config	_CONFIG2, _WRT_OFF&_BOR40V									;Palabra 2 de configuraci�n
  
		#define Fosc 4000000			;Velocidad de trabajo

			cblock 0x20
				Temporal_1	
				Temporal_2			;Variables temporales de prop�sito general
				Delay_var			;Variable de temporizaci�n
				BCD_L				;Parte baja del n�mero decimal aleatorio
				BCD_H				;Parte baja del n�mero decimal aleatorio
				N_tecleado			;N�mero tecleado
				Intentos			;Variable con el n�mero de intentos
				N_minimo	
				N_maximo			;Variables con los l�mites m�nimo y m�ximo del N�
			endc

Lcd_var		equ	0x70		;Variables (3) empleadas por las rutinas de manejo del LCD
Key_var		equ 0x73		;Inicio de las 6 variables empleadas por las rutinas de manejo del teclado
MSE_Delay_V	equ	0x79		;Variables (3) empleadas por las macros de temporizaci�n

				org	0x00		;Vector de RESET	
				goto	Inicio
				org	0x05
	
;*********************************************************************************************
;Tabla_Mensajes: Seg�n el valor contenido en el registro W, se devuelve el car�cter a visualizar

Tabla_Mensajes	movwf	PCL		;Calcula el desplazamiento sobre la tabla

;La directiva dt genera tantas instrucciones RETLW como bytes o caracteres contenga

Mens_1		equ	$		;Mens_1 apunta al 1er. car�cter del mensaje 1
			dt	" ADIVINA El N",0xdf,0x00
Mens_2		equ	$		
			dt	" (",0x7E,") Continuar",0x00
Mens_3		equ	$
			dt	"Entre ",0x00
Mens_4		equ	$
			dt	"Teclea N",0xdf," ",0x00
Mens_5		equ	$
			dt	"Error, es menor",0x00
Mens_6		equ	$
			dt	"Error, es mayor",0x00
Mens_7		equ	$
			dt	"!oooh! GAME OVER",0x00
Mens_8		equ	$
			dt	"!! ACERTASTE !!",0x00

		include "TECLADO.INC"			;Incluye rutinas de manejo del teclado
		include	"LCD4bitsPIC16.inc"		;Incluir rutinas de manejo del LCD
		include	"MSE_Delay.inc"			;Incluir rutinas de temporizaci�n

;*********************************************************************************************
;Mensaje: Esta rutina env�a a la pantalla LCD una cadena de caracteres. El inicio de dicha 
;cadena debe estar indicado en el reg. W. Toda cadena debe finalizar con el c�digo 0x00

Mensaje		movwf	Temporal_1		;Salva el �ndice que apunta a la tabla de caracteres
Mensaje_1	movf	Temporal_1,W	;Recupera el �ndice
			call	Tabla_Mensajes	;Busca el car�cter a visualizar
			movwf	Temporal_2		;Salva el car�cter a visualizar
			movf	Temporal_2,F
			btfss	STATUS,Z		;Mira si es el �ltimo (0x00)
			goto	Mensaje_2		;No
			return					;Si
Mensaje_2	call	LCD_DATO		;Visualiza el car�cter sobre el LCD
			incf	Temporal_1,F	;Incrementa el �ndice para buscar el siguiente car�cter
			goto	Mensaje_1

;**********************************************************************************************
;BIN_BCD: Convierte un valor binario presente en el acumulador (W) en tres d�gitos BCD. El 
;d�gito de m�s peso se deja en la variable BCD_H y los dos de menos peso en BCD_L.

BIN_BCD		clrf	BCD_H
			clrf	BCD_L			;Borra resultados anteriores
BIN_BCD_1	addlw	0xf6			;Resta 10 mediante suma de complemento a 2
			btfss	STATUS,C		;Hay carry ?
			goto	BIN_BCD_3		;No
			movwf	Temporal_1		;Si, guarda el resultado remporalmente
			incf	BCD_L,F			;Ajustar el valor de BCD_L
			movf	BCD_L,W
			xorlw	0x0a
			btfss	STATUS,Z		;BCD_L mayor de 9 ??
			goto	BIN_BCD_2		;No
			clrf	BCD_L			;Si pone a 0 BCD_L
			incf	BCD_H,F			;Ajusta el valor de BCD_H
BIN_BCD_2	movf	Temporal_1,W	;Recupera resultado temporal
			goto	BIN_BCD_1
BIN_BCD_3	addlw	0x0a
			swapf	BCD_L,F
			iorwf	BCD_L,F
			return

;**********************************************************************************************
;BCD_ASCII: Esta rutina convierte el c�dogo BCD de la tecla pulsada y presente en la variable
;"Tecla", en su correspondiente c�digo ASCII, para visualizarlo sobre el LCD.

BCD_ASCII	movf	Tecla,W		;Lee el c�digo BCD de la tecla pulsada
			sublw	.9
			btfss	STATUS,C	;Es mayor que 9 (A, B, C, D, E, F) ?
			goto	BCD_ASCII_1	;Si
			movf	Tecla,W		;No
			addlw	0x30		;Ajuste ASCII de los caracteres del 0 al 9
			goto	BCD_ASCII_2
BCD_ASCII_1	movf	Tecla,W
			addlw	0x37		;Ajuste ASCII de los caracteres de la A a la F
BCD_ASCII_2	call	LCD_DATO	;Visualiza sobre la posici�n actual del cursor del LCD
			return

;**************************************************************************************
;BIN_ASCII:Convierte un valor de 8 bits presente en W, en dos caracteres ASCII
;para visualizarlos sobre la posici�n actual del cursor del LCD

BIN_ASCII	movwf	Temporal_1	;Salva el n�mero binario
			swapf	Temporal_1,W
			andlw	0x0f
			iorlw	0x30		;Convierte a ASCII el nible de m�s peso	
			call	LCD_DATO	;Visualiza
			movf	Temporal_1,W
			andlw	0x0f
			iorlw	0x30		;Convierte a ASCII el nible de menos peso
			call	LCD_DATO	;Visualiza
			return

;*******************************************************************************************
;Wait_tecla: Espera a que se pulse (y suelte) una tecla v�lida del 0 al 9 y se visualiza
		
Wait_tecla		call	Key_Scan	;Explora el teclado
				btfsc	Tecla,7		;Hay alguna pulsada ?
				goto	Wait_tecla	;No
				movlw	0x0a		;Si
				subwf	Tecla,w
				btfsc	STATUS,C	;Mayor de 9 ??
				goto	Wait_tecla	;Si, no vale
				movf	Tecla,W
				movwf	Temporal_1	;Salva la tecla pulsada
				call	BCD_ASCII	;No, visualiza la pulsaci�n
	
Wait_tecla_1	clrwdt
				call	Key_Scan	;Explora el teclado
				btfss	Tecla,7		;Se ha soltado ??
				goto	Wait_tecla_1	;Todav�a no
				return

;Programa principal. Iniciar E/S y pantalla LCD

Inicio	   	bsf		STATUS,RP0
			bsf		STATUS,RP1	;Banco 3
			clrf	ANSEL		;Puerta A digital
			clrf	ANSELH		;Puerta B digital
			bcf		STATUS,RP1	;Banco 1
			movlw	b'000000111'	
			movwf	OPTION_REG	;Preescaler de 256 para el TMR0 y Pull-Up ON
			bcf		STATUS,RP0	;Selecciona banco 0

			call	UP_LCD		;Configura puerto para el LCD
			call	LCD_INI		;Inicia el LCD
			movlw	b'00001100'
			call	LCD_REG		;LCD On, cursor y blink Off

;Bucle principal, se inician las variables de juego y mensaje de bienvenida

Bucle		movlw	0x01
			call	LCD_REG		;Borra pantalla e inicia el cursor
			movlw	.5
			movwf	Intentos	;Carga el n�mero de intentos posibles
			movlw	0x99
			movwf	N_maximo
			clrf	N_minimo	;Inicia valores m�ximos y m�nimos (00 y 99)
			movlw	Mens_1
			call	Mensaje		;Visualiza mensaje de inicio N� 1
			movlw	0xc0
			call	LCD_REG
			movlw	Mens_2
			call 	Mensaje		;Visualiza mensaje de inicio N� 2

;Espera que se pulse y se suelte la tecla C (->) para capturar un n�mero aleatorio y comenzar la
;partida

Pulsar_C_1	call	Key_Scan	;explora el teclado
			btfsc	Tecla,7		;Hay alguna tecla pulsada ??
			goto	Pulsar_C_1	;No
			movlw	0x0c
			subwf	Tecla,W
			btfss	STATUS,Z	;Ha sido la C de continuar ??
			goto	Pulsar_C_1	;No
			movf	TMR0,W
			call	BIN_BCD		;Si.Captura N� aleatorio y convierte a BCD
Pulsar_C_2	call	Key_Scan	;Explora el teclado
			btfss	Tecla,7		;Se ha soltado ??
			goto	Pulsar_C_2	;Todav�a no

;Presenta la pantalla de juego 

Intento		movlw	0x01
			call	LCD_REG		;Borra pantalla e inicia el cursor
			movlw	Mens_3
			call	Mensaje		;Visualiza mensaje 3
			movf	N_minimo,W
			call	BIN_ASCII	;Visualiza el n�mero m�nimo
			movlw	'-'
			call	LCD_DATO
			movf	N_maximo,W
			call	BIN_ASCII	;Visualiza el n�mero m�ximo
			movlw	0x8e
			call	LCD_REG		;Coloca cursor
			movf	Intentos,W
			call	BIN_ASCII	;Visualiza contador de intentos
			movlw	0xc0
			call	LCD_REG		;Coloca el cursor
			movlw	Mens_4
			call	Mensaje		;Visualiza mensaje 4

;Espera que se pulsen dos teclas BCD, se visualizan y se compone el n�mero teclado por el jugador
			nop
			call	Wait_tecla	;Espera la primera pulsaci�n
			swapf	Temporal_1,W
			movwf	N_tecleado	;Recupera el 1er. d�gito tecleado
			call	Wait_tecla
			movf	Temporal_1,W
			iorwf	N_tecleado,F	;Recupera 2� d�gito y compone el n� tecleado

;Determina si el N� tecleado es mayor, menor o igual al aleatorio
		
			movf	BCD_L,W
			subwf	N_tecleado,W
			btfsc	STATUS,Z	;Es igual ??
			goto	Igual		;Si
			btfss	STATUS,C	;Es mayor ??
			goto	Menor		;No, es menor

Mayor		movf	N_tecleado,W
			movwf	N_maximo	;Ajusta nuevo n� m�ximo
			movlw	0x01
			call	LCD_REG		;Borra pantalla e inicia el cursor
			movlw	Mens_5
			call	Mensaje		;Visualiza mensaje 5	
			goto	Fallo
Menor		movf	N_tecleado,W
			movwf	N_minimo
			movlw	0x01
			call	LCD_REG		;Borra pantalla e inicia el cursor
			movlw	Mens_6
			call	Mensaje		;Visualiza mensaje 6
Fallo		Delay	1000 Milis	;Delay de 1 "
			decfsz	Intentos,F	;Decrementa el contador de intentos
			goto	Intento		;Repite la secuencia con otro nuevo intento

			movlw	0x01
			call	LCD_REG		;Borra la pantalla e inicia el cursor
			movlw	Mens_7
			call	Mensaje		;Visualiza mensaje 7
			Delay	1000 Milis	;Temporizaci�n de 1"
			goto	Bucle		;Nueva partida

Igual		movlw	0x01
			call	LCD_REG		;Borra pantalla e inicia el cursor
			movlw	Mens_8
			call	Mensaje		;Visualiza mensaje 8
			Delay	2000 Milis	;Temporiza 2"
			goto	Bucle	

			end

