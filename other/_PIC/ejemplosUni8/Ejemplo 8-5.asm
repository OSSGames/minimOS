;						CURSO: "Microcontroladores PIC: Nivel I"
;									SEPTIEMBRE 2014
;							Autor: Mikel Etxebarria Isuskiza
;						Ingenier�a de Microsistemas Programados S.L.
;							wwww.microcontroladores.com	
;
;								
;Ejemplo 8-5: La memoria EEPROM; Control de accesos.
;Mediante el teclado el usuario pulsa la tecla D (<-) de apertura, e introduce una clave de 
;4 d�gitos. Si es correcta se activa un led de salida conectado a la l�nea RA4 durante un segundo, 
;simulando as� la apertura de una puerta. Se dan tres oportunidades para introducir la clave correcta.
;
;En RA5 se conecta un led de salida que simula un piezo el�ctrico que emite un beep cada vez
;que se pulsa una tecla.

;La tecla C (->) permite realizar el cambio de clave pidiendo una nueva y la correspondiente 
;confirmaci�n.
;
;La pantalla LCD ir� presentando los oportunos mensajes.
;
;En la memoria EEPROM de datos disponible en los dispositivos 16F88X quedar� registrada, de 
;forma permanente, aunque modificable, la clave actual.
;
;                                               
		List	p=16F886		;Tipo de procesador
		include	"P16F886.INC"	;Definiciones de registros internos

;Ajusta los valores de las palabras de configuraci�n durante el ensamblado.Los bits no empleados
;adquieren el valor por defecto.Estos y otros valores se pueden modificar seg�n las necesidades

		__config	_CONFIG1, _LVP_OFF&_PWRTE_ON&_WDT_OFF&_EC_OSC&_FCMEN_OFF&_BOR_OFF	;Palabra 1 de configuraci�n
		__config	_CONFIG2, _WRT_OFF&_BOR40V									;Palabra 2 de configuraci�n

		#define Fosc 4000000			;Velocidad de trabajo

			cblock  0x20		;Hace una reserva en el �rea RAM de datos para las siguientes variables						
				digito_1
				digito_2
				digito_3
				digito_4        ;Variables para los d�gitos clave                       
				di_tem_1	
				di_tem_2
				di_tem_3
				di_tem_4        ;Temporales para los d�gitos
				cont_err        ;Contador de fallos
				cont_tecla      ;Contador de teclas pulsadas
				Temporal_1
				Temporal_2      ;Variables temporales
				Delay_var                        
                endc			;Fin de la reserva

Lcd_var			equ	0x70		;Variables (3) empleadas por las rutinas de manejo del LCD
Key_var			equ 0x73		;Inicio de las 6 variables empleadas por las rutinas de manejo del teclado
MSE_Delay_V		equ	0x79		;Variables (3) empleadas por las macros de temporizaci�n

				org	0x2100  
				de	0x01,0x02,0x03,0x04	;Esta directiva graba la clave por defecto (1234) 
										;en la 1� posici�n de la EEPROM tr�s el ensamblado. 

				org	0x00		;Vector de RESET	
				goto	Inicio
				org	0x05

;*********************************************************************************************
;Tabla_Mensajes: Seg�n el valor contenido en el registro W, se devuelve el car�cter a visualizar

Tabla_Mensajes	movwf	PCL		;Calcula el desplazamiento sobre la tabla

;La directiva dt genera tantas instrucciones RETLW como bytes o caracteres contenga                                                                

Mens_1          equ     $		;Inicio del 1er. car�cter del mensaje 1	
                dt	"(",0x7f,") Apertura",0x00
	
Mens_1_1        equ     $
				dt	"(",0x7e,") Cambio Clave",0x00

Mens_2          equ     $
                dt	"Clave ? ",0x00

Mens_2_1        equ     $
                dt	"(",0x7e,") Cancelar",0x00
	
Mens_3          equ     $
                dt	"Nueva Clave ",0x00
		
Mens_4          equ     $
                dt	"Confirmar ",0x00
	
Mens_5          equ     $
                dt	"Puede pasar",0x00
	
Mens_6          equ     $
                dt	"ACCESO DENEGADO",0x00
		
 		include "TECLADO.INC"			;Incluye rutinas de manejo del teclado
		include	"LCD4bitsPIC16.inc"		;Incluir rutinas de manejo del LCD
		include	"MSE_Delay.inc"			;Incluir rutinas de temporizaci�n

;*************************************************************************************
;Key_Off: Esta rutina genera un Beep y espera que la tecla reci�n pulsada se suelte. 
;Debe usarse justo despu�s de llamar a la rutina Key_Scan
;
Key_Off         movf    Tecla,W
                movwf   Temporal_1      ;Guarda temporalmente la tecla pulsada
                call	Beep			;Emite se�al ac�stica
Key_Off_No     	call    Key_Scan		;Explora el teclado
                btfss	Tecla,7			;Se ha soltado la tecla ?
				goto    Key_Off_No      ;Todavia no
                movf    Temporal_1,W    ;Ahora si
                movwf   Tecla	 		;Repone la tecla pulsada
                return

;*********************************************************************************************
;Beep: Activando la salida RA5 durante 0.1" se simula el beep de un piezo el�ctrico

Beep			bsf	PORTA,5				;Activa se�al ac�stica conectada a RA5
				Delay	100 Milis		;Temporizaci�n 0.1"
				bcf	PORTA,5				;Desconecta se�al ac�stica
				return

;*********************************************************************************************
;Mensaje: Esta rutina env�a a la pantalla LCD una cadena de caracteres. El inicio de dicha 
;cadena debe estar indicado en el reg. W. Toda cadena debe finalizar con el c�digo 0x00

Mensaje			movwf	Temporal_1		;Salva el �ndice que apunta a la tabla de caracteres
Mensaje_1		movf	Temporal_1,W	;Recupera el �ndice
				call	Tabla_Mensajes	;Busca el car�cter a visualizar
				movwf	Temporal_2		;Salva el car�cter a visualizar
				movf	Temporal_2,F
				btfss	STATUS,Z		;Mira si es el �ltimo (0x00)
				goto	Mensaje_2		;No
				return					;Si
Mensaje_2		call	LCD_DATO		;Visualiza el car�cter sobre el LCD
				incf	Temporal_1,F	;Incrementa el �ndice para buscar el siguiente car�cter
				goto	Mensaje_1

;*******************************************************************************************
;Control: Espera que se tecleen los cuatro d�gitos de la clave, los almacena en digito_1 .. 
;digito_4 y visualiza **** en LCD. La tecla C (->) permite cancelar en cualquier momento

Control         movlw   4
                movwf   cont_tecla      ;Inicia contador de pulsaciones
                movlw   digito_1
                movwf   FSR             ;Apunta al inicio del buffer de tecla
Otra_tecla		call    Key_Scan        ;Explora el teclado
                btfsc	Tecla,7			;Hay alguna pulsada ??
				goto    Otra_tecla      ;NO
                movlw   '*'
                call    LCD_DATO        ;Visualiza el *
                call    Key_Off         ;Genera Beep y espera se libere
                movlw   0x0c
                subwf   Tecla,W
                btfss   STATUS,Z        ;Mira si es tecla C (Cancelar)
                goto    No_cancela		;No
Cancela         bsf     Temporal_1,1    ;Si, activa Flag de cancelaci�n
                return

No_cancela      bcf     Temporal_1,1    ;Desactiva Flag de cancelaci�n
                movf    Tecla,W
                movwf   INDF            ;Almacena la tecla en el buffer
                incf    FSR,F           ;Siguiente posici�n del buffer
                decfsz  cont_tecla,F    ;Actualiza contador de tecla
                goto    Otra_tecla      ;Repite el proceso
                return

;*******************************************************************************************
;Okey: Comprueba si la clave introducida en el buffer coincide con la de la EEPROM. En caso 
;afirmativo el bit 0 de Temporal_1 se pone a "0", de lo contrario a "1".
;
Okey            bcf     Temporal_1,0    ;Borra flag de error
                movlw   4
                movwf   cont_tecla      ;N�mero de bytes a comprobar
                movlw   digito_1
                movwf   FSR             ;Primer d�gito
                bsf		STATUS,RP1		;Selecciona p�gina 2
				clrf    EEADR         	;Primera posici�n de la EEPROM
				bcf		STATUS,RP1		;Selecciona p�gina 0
Okey_1          call    EE_Read         ;Lee byte de la EEPROM
                bsf		STATUS,RP1		;Selecciona p�gina 2
				movf    EEDAT,W        	;Lee byte de la EEPROM
                bcf		STATUS,RP1		;Selecciona p�gina 0
				andlw   0x0f            
                subwf   INDF,W          ;Lo compara con el del buffer
                btfss   STATUS,Z        ;Mira si es igual
                bsf     Temporal_1,0    ;NO, activa flag de error
                bsf		STATUS,RP1		;Selecciona p�gina 2
				incf    EEADR,F         ;Siguiente posici�n de la EEPROM
                bcf		STATUS,RP1		;Selecciona p�gina 0
				incf    FSR,F           ;Siguiente d�gito
                decfsz  cont_tecla,F    ;Repite la comprobaci�n
                goto    Okey_1
                return                                                                        

;*************************************************************************
;EE_Read: Lee, desde la posici�n actual de EEADR, un byte de la EEPROM 
;
EE_Read         bsf     STATUS,RP0
				bsf		STATUS,RP1		;Selecciona el banco 3
                bcf		EECON1,EEPGD	;Selecciona EEPROM de datos
				bsf		EECON1,RD		;Inicia el ciclo de lectura
                bcf     STATUS,RP0
				bcf		STATUS,RP1		;Selecciona banco 0
                return

;*************************************************************************
;EE_Write: Graba un byte en la EEPROM
;
EE_Write        bsf     STATUS,RP0
				bsf		STATUS,RP1		;Selecciona banco 3
				bcf		EECON1,EEPGD	;Selecciona EEPROM de datos
                bsf     EECON1,WREN	    ;Permiso de escritura
                movlw   0x55
                movwf   EECON2
                movlw   0xaa
                movwf   EECON2          ;Secuencia seg�n Microchip
                bsf     EECON1,WR		;Inicia el ciclo de escritura
				bcf		STATUS,RP0
				bcf		STATUS,RP1		;Selecciona el banco 0
Wait            btfss 	PIR2,EEIF 		;Ha finalizado el ciclo de escritura ??
                goto    Wait			;No	
                bcf     PIR2,EEIF       ;Si, reponer flag de fin de escritura
                return

;***********************************************************************************
;Programa principal
Inicio          clrf 	PORTB			;Borra los latch de salida
				clrf	PORTA			;Borra los latch de salida
				bsf		STATUS,RP0
				bsf		STATUS,RP1		;Banco 3
				clrf	ANSEL			;Puerta A digital
				clrf	ANSELH			;Puerta B digital
				bcf		STATUS,RP1		;Banco 1
				clrf	TRISB			;Puerta B se configura como salida
				clrf	TRISA			;Puerta A se configura como salida
				movlw	b'00001001'	
				movwf	OPTION_REG		;Preescaler de 2 para el WDT, Pull-UP ON
				bcf		STATUS,RP0		;Selecciona banco 0

;Configura la pantalla LCD
				call	UP_LCD			;Configura puerto para el LCD
				call	LCD_INI			;Inicia el LCD
				movlw	b'00001100'
				call	LCD_REG			;LCD On, cursor y blink Off

;Visualiza Mensajes iniciales
Loop 			movlw	b'00000001'
				call    LCD_REG			;Borra el LCD e inicia el cursor
                movlw   Mens_1          
                call    Mensaje         ;Visualiza "Apertura (->)"
                movlw   0xc0
                call    LCD_REG         ;Ajusta posici�n del mensaje
                movlw   Mens_1_1        
                call    Mensaje         ;Visualiza "Cambio Clave (<-)"

;Espera que se pulse la de apertura <- (D) o la de cambio de clave -> (C)
No_Tecla        call    Key_Scan        ;Explora el teclado
                btfsc	Tecla,7			;Se ha pulsado alguna tecla ??
				goto    No_Tecla		;No
                call    Key_Off         ;Si, genera beep y espera se libere
                movlw   0x0D
                subwf   Tecla,W
                btfsc   STATUS,Z        ;Es la tecla D (Apertura) ?
                goto    Apertura		;Si
No_es_D         movlw   0x0C			;No
                subwf   Tecla,W
                btfss   STATUS,Z        ;Es la tecla C (Cambio clave) ?
                goto    No_Tecla		;No, pulsaci�n incorrecta. No se hace ni caso

;Cambio de la clave. Primero se pide la clave actual
Cambio			movlw	b'000000001'
				call	LCD_REG			;Borra LCD e inicia cursor
                movlw   Mens_2_1        ;
                call    Mensaje         ;Visualiza "Cancelar (->)"
                movlw   0xc0
                call    LCD_REG         ;Posiciona cursor del LCD
                movlw   Mens_2          
                call    Mensaje         ;Visualiza "Clave ?"
                call    Control         ;Espera se introduza clave actual
                btfsc   Temporal_1,1    ;Hubo cancelaci�n ??
                goto    Loop			;Si.

;Comprobar si es correcta la clave reci�n introducida
                call    Okey            ;Comprueba si es correcta
                btfsc   Temporal_1,0    ;Es correcta ?
                goto    Loop			;No, vuelta al principio 

;Si es correcta se pide la nueva clave                
				movlw	b'00000001'
				call	LCD_REG			;Borra LCD e inicia el cursor
                movlw   Mens_2_1        
                call    Mensaje         ;Visualiza "(->) Cancelar"
                movlw   0xc0            ;Posiciona el LCD
                call    LCD_REG
                movlw   Mens_3          
                call    Mensaje         ;Visualiza "Nueva clave"
                call    Control         ;Espera que se pulse la nueva clave
                btfsc   Temporal_1,1    ;Hubo cancelaci�n ??
                goto    Loop			;Si.

;Se pide teclear la nueva clave para confirmar
                movlw	b'00000001'
				call	LCD_REG			;Borra LCD e inicia el cursor
                movlw   Mens_2_1        
                call    Mensaje         ;Visualiza "(->) Cancelar"
                movlw   0xc0            ;Posicionar LCD
                call    LCD_REG
                movlw   Mens_4          
                call    Mensaje         ;Visualiza "Confirmar"
                movf    digito_1,w
                movwf   di_tem_1
                movf    digito_2,w
                movwf   di_tem_2
                movf    digito_3,w
                movwf   di_tem_3
                movf    digito_4,w
                movwf   di_tem_4        ;Salva temporalmente 1� clave introducida
                call    Control         ;Lee la segunda clave
                btfsc   Temporal_1,1    ;Hubo cancelaci�n ??
                goto    Loop	        ;Si.

;Se comprueba si la confirmaci�n de la nueva clave es correcta
                movf    digito_1,w
                subwf   di_tem_1,w      ;Compara 1er.d�gito
                btfss   STATUS,Z        ;Igual ?
                goto    Loop		    ;No

                movf    digito_2,w
                subwf   di_tem_2,w      ;Compara 2� d�gito
                btfss   STATUS,Z        ;Igual ?
                goto    Loop		    ;No

                movf    digito_3,w
                subwf   di_tem_3,w      ;Compara 3er.d�gito
                btfss   STATUS,Z        ;Igual ?
                goto    Loop		    ;No

                movf    digito_4,w
                subwf   di_tem_4,w      ;Compara 4� d�gito
                btfss   STATUS,Z        ;Igual ?
                goto    Loop		    ;No

;Graba en la EEPROM la nueva clave
                movlw   4
                movwf   cont_tecla      ;N� de octetos a grabar
                movlw   digito_1
                movwf   FSR             ;Indice de d�gitos
                bsf		STATUS,RP1		;Selecciona p�gina 2
				clrf    EEADR           ;Primera direci�n de EEPROM de datos
				bcf		STATUS,RP1		;Selecciona p�gina 1
Otro_digito     movf    INDF,W          ;Carga d�gito
                bsf		STATUS,RP1		;Selecciona p�gina 2
				movwf   EEDATA
                call    EE_Write        ;Graba en EEPROM
                incf    FSR,F           ;Siguiente d�gito
                bsf		STATUS,RP1		;Selecciona p�gina 2
				incf    EEADR,F         ;Siguiente posici�n EEPROM
				bcf		STATUS,RP1		;Selecciona p�gina 0
                decfsz  cont_tecla,F	;Han sido grabados los 4 d�gitos ??
                goto    Otro_digito		;No
                goto    Loop			;Si

;Para la apertura se permite tres intentos
Apertura        movlw   3
                movwf   cont_err        ;Establece n�mero de intentos
Otro_mas        movlw	b'00000001'
				call	LCD_REG			;Borra LCD e inicia el cursor
                movlw   Mens_2_1        
                call    Mensaje         ;Visualiza "Cancelar (->)"
                movlw   0xc0
                call    LCD_REG         ;Posicionar cursor del LCD
                movlw   Mens_2          
                call    Mensaje         ;Visualiza "Clave ?"
                call    Control         ;Espera que se introduzca la clave

                btfsc   Temporal_1,1    ;Hubo cancelaci�n ??
                goto    Loop	        ;Si.

                call    Okey            ;Comprueba si es correcta
                btfsc   Temporal_1,0    ;Es v�lida ?
                goto    No_Ok           ;No
                movlw	b'00000001'
				call	LCD_REG			;Si, borra LCD e inicia el cursor
                movlw   Mens_5          
                call    Mensaje         ;Visualiza "Puede Pasar"
                bsf     PORTA,4         ;Si, activar salida de apertura
                bsf		PORTA,5			;Emite un tono de apertura
                clrf    cont_err        ;Pone a 0 contador de intentos
                Delay	2000 Milis		;Temporiza 2 "
				bcf		PORTA,4			;Desactiva salida de apertura
				bcf		PORTA,5			;Desactiva tono de apertura
				goto    Loop	        ;Repite el proceso

No_Ok           decfsz  cont_err,F      ;Intento fallido, es el �ltimo posible ??
                goto    Otro_mas        ;No, repite otro intento
                movlw	b'00000001'
				call	LCD_REG			;Si, borra el LCD e inicia el cursor
                movlw   Mens_6          
                call    Mensaje         ;Visualiza "ACCESO DENEGADO"
                Delay	2000 Milis		;Temporiza 2 "
                goto    Loop	        ;Repite el proceso

                end

