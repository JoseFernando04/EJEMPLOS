;
; Ejemplo1.asm
;
; Created: 24/01/2025 18:36:32
; Author : Lenovo IdeaPad 3
;

LDI	R16, 0xF0
OUT	PORTD, R16
; Replace with your application code
START:
    INC		R16
	OUT		PORTD, R16
	RJMP	START