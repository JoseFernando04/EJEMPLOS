;
; Antirebote.asm
;
; Created: 31/01/2025 18:18:34
; Author : Lenovo IdeaPad 3
;

//Encabezado
.include "M328PDEF.inc"
.cseg
.org 0x0000

//Configuracion de pila //0x08ff
LDI		R16, LOW(RAMEND) //Cargar 0xff a r16
OUT		SPL, R16		 //Cargar oxff a SPL
LDI		R16, HIGH(RAMEND) //Cargar 0x08 a r16
OUT		SPH, R16		  //Cargar 0x08	

//Configuracion de MCU
SETUP:
	//DDRx, PORTx y PINx
	// configurar Puerto D como entrada con pull-up habilitado
	LDI		R16, 0x00
	OUT		DDRD, R16
	LDI		R16, 0xFF
	OUT		PORTD, R16

	//Configurar Puerto B como salida y con PB0 encendida
	LDI		R16, 0xFF
	OUT		DDRB, R16
	LDI		R16, 0b00000001
	OUT		PORTB, R16

	//Guardar estado actual de los botones en R17
	LDI R17, 0xFF

//Loop principal
LOOP:
	IN		R16, PIND	//leer puerto D
	CP		R17, R16	//Comparar estado viejo con actual
	BREQ	LOOP
	CALL	DELAY
	//volver a leer
	MOV		R17, R16	//Guardo estado actual de botones en r17
	SBRC	R16, 2		//revisando si el bit esta presionado = 0 lógico
	RJMP	LOOP
	SBI		PINB, 0		//Hace toogle de PB0
	RJMP	LOOP

//SUBRUTINAS (NO INTERRUPCION)
DELAY:
	LDI		R18, 0
SUBDELAY1:
	INC		R18
	CPI		R18, 0
	BRNE	SUBDELAY1
	RET

//SUBRUTINAS (INTERRUPCION)