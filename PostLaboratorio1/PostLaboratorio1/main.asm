;************************************************************  
; Universidad del Valle de Guatemala  
; IE2023: Programación de Microcontroladores  
; Sumador_4bits_con_antirrebote.asm  
;  
; Author  : José Fernando Gordillo Flores  
; Proyecto: PreLab1  
; Hardware: ATmega328P (Arduino Nano)  
; Creado  : 04/02/2025  
;************************************************************  

; Encabezado  
.include "M328PDEF.inc"  
.cseg  
.org 0x0000  

; Configuración de pila  
LDI     R16, LOW(RAMEND)  
OUT     SPL, R16  
LDI     R16, HIGH(RAMEND)  
OUT     SPH, R16  

; Configuración de MCU  
SETUP:  
    ; Configurar Puerto D como entrada con pull-up habilitado (botones en PD2, PD3, PD4, PD5, PD6)  
    LDI     R16, 0xFF      ; Todos los pines como entrada con pull-up  
    OUT     PORTD, R16     ; Habilitar resistencias pull-up en PD2-PD6  
    LDI     R16, 0x80      ; PD7 como salida (10000000)  
    OUT     DDRD, R16  

    ; Configurar Puerto B como salida (primer contador en PB0-PB3 y suma en PB4-PB5)  
    LDI     R16, 0x3F      ; PB0-PB5 como salidas (00111111)  
    OUT     DDRB, R16  
    LDI     R16, 0x00  
    OUT     PORTB, R16  

    ; Configurar Puerto C como salida (segundo contador en PC0-PC3)  
    LDI     R16, 0xFF  
    OUT     DDRC, R16  
    LDI     R16, 0x00  
    OUT     PORTC, R16  

; Inicializar ambos contadores  
    LDI     R18, 0x00  
    OUT     PORTB, R18    ; Contador 1  
    LDI     R19, 0x00  
    OUT     PORTC, R19    ; Contador 2  

; Loop principal  
LOOP:  
    IN      R16, PIND    ; Leer estado de los botones  
    ; Comprobar si se presionó el botón de incremento para el primer contador (PD2)  
    SBRC    R16, 2       ; Si PD2 no está presionado, saltar  
    CALL    INCREMENTAR_1 ; Llamar a incrementar el primer contador  

    ; Comprobar si se presionó el botón de decremento para el primer contador (PD3)  
    SBRC    R16, 3       ; Si PD3 no está presionado, saltar  
    CALL    DECREMENTAR_1 ; Llamar a decrementar el primer contador  

    ; Comprobar si se presionó el botón de incremento para el segundo contador (PD4)  
    SBRC    R16, 4       ; Si PD4 no está presionado, saltar  
    CALL    INCREMENTAR_2 ; Llamar a incrementar el segundo contador  

    ; Comprobar si se presionó el botón de decremento para el segundo contador (PD5)  
    SBRC    R16, 5       ; Si PD5 no está presionado, saltar  
    CALL    DECREMENTAR_2 ; Llamar a decrementar el segundo contador  

    ; Comprobar si se presionó el botón de suma (PD6)  
    SBRC    R16, 6       ; Si PD6 no está presionado, saltar  
    CALL    SUMAR_CONTADORES ; Llamar a la subrutina de suma  

    RJMP    LOOP           ; Volver al inicio del bucle  

; Subrutina para incrementar el contador 1 (PB0-PB3)  
INCREMENTAR_1:  
    RCALL   ANTIRREBOTE    ; Llama al antirrebote  
    SBIC    PIND, 2        ; Verificar nuevamente: Si PD2=1 (se soltó), retornar  
    RET  
    IN      R18, PORTB     ; Leer valor actual del contador 1  
    ANDI    R18, 0x0F      ; Asegurar que solo afectan los 4 bits  
    CPI     R18, 15        ; Si el valor es 15, no incrementar más  
    BREQ    FIN_INC_1  
    INC     R18            ; Incrementar contador  
    OUT     PORTB, R18     ; Actualizar el puerto B  
FIN_INC_1:  
    RET  

; Subrutina para decrementar el contador 1 (PB0-PB3)  
DECREMENTAR_1:  
    RCALL   ANTIRREBOTE    ; Llama al antirrebote  
    SBIC    PIND, 3        ; Verificar nuevamente: Si PD3=1 (se soltó), retornar  
    RET  
    IN      R18, PORTB     ; Leer valor actual del contador 1  
    ANDI    R18, 0x0F      ; Asegurar que solo afectan los 4 bits  
    CPI     R18, 0         ; Si el valor es 0, no decrementar más  
    BREQ    FIN_DEC_1  
    DEC     R18            ; Decrementar contador  
    OUT     PORTB, R18     ; Actualizar el puerto B  
FIN_DEC_1:  
    RET  

; Subrutina para incrementar el contador 2 (PC0-PC3)  
INCREMENTAR_2:  
    RCALL   ANTIRREBOTE    ; Llama al antirrebote  
    SBIC    PIND, 4        ; Verificar nuevamente: Si PD4=1 (se soltó), retornar  
    RET  
    IN      R19, PORTC     ; Leer valor actual del contador 2  
    ANDI    R19, 0x0F      ; Asegurar que solo afectan los 4 bits  
    CPI     R19, 15        ; Si el valor es 15, no incrementar más  
    BREQ    FIN_INC_2  
    INC     R19            ; Incrementar contador  
    OUT     PORTC, R19     ; Actualizar el puerto C  
FIN_INC_2:  
    RET  

; Subrutina para decrementar el contador 2 (PC0-PC3)  
DECREMENTAR_2:  
    RCALL   ANTIRREBOTE    ; Llama al antirrebote  
    SBIC    PIND, 5        ; Verificar nuevamente: Si PD5=1 (se soltó), retornar  
    RET  
    IN      R19, PORTC     ; Leer valor actual del contador 2  
    ANDI    R19, 0x0F      ; Asegurar que solo afectan los 4 bits  
    CPI     R19, 0         ; Si el valor es 0, no decrementar más  
    BREQ    FIN_DEC_2  
    DEC     R19            ; Decrementar contador  
    OUT     PORTC, R19     ; Actualizar el puerto C  
FIN_DEC_2:  
    RET  

; --- Antirrebote ---  
ANTIRREBOTE:  
    LDI     R20, 20          ; Ajusta este valor según el tiempo deseado  
AR_LOOP1:  
    LDI     R21, 255         ; Cuenta hacia abajo para un retardo  
AR_LOOP2:  
    DEC     R21              ; Decrementa el contador interno  
    BRNE    AR_LOOP2         ; Si no es cero, repetir  
    DEC     R20              ; Decrementa el contador de ciclos del retardo  
    BRNE    AR_LOOP1         ; Repite hasta que el ciclo externo termine  
    RET  

; --- Subrutina para sumar los contadores ---  
SUMAR_CONTADORES:  
    RCALL   ANTIRREBOTE    ; Llama al antirrebote  
    SBIC    PIND, 6        ; Verificar nuevamente: Si PD6=1 (se soltó), retornar  
    RET  

    ; Leer los valores de los contadores  
    IN      R18, PORTB     ; Leer valor del contador 1  
    ANDI    R18, 0x0F      ; Enmascarar para obtener solo los 4 bits menos significativos  
    IN      R19, PORTC     ; Leer valor del contador 2  
    ANDI    R19, 0x0F      ; Enmascarar para obtener solo los 4 bits menos significativos  

    ; Sumar los valores  
    ADD     R18, R19       ; Sumar R18 y R19, el resultado queda en R18  

    ; Verificar si hay carry (overflow)  
    BRCC    NO_CARRY       ; Si no hay carry, saltar a NO_CARRY  
    ; Si hay carry, encender el LED de carry (PD7)  
    SBI     PORTD, 7       ; Encender el LED de carry  
    RJMP    MOSTRAR_SUMA   ; Saltar a mostrar la suma  

NO_CARRY:  
    CBI     PORTD, 7       ; Apagar el LED de carry  

MOSTRAR_SUMA:  
    ; Mostrar el resultado de la suma en los LEDs (PB4-PB5)  
    MOV     R17, R18       ; Copiar el resultado a R17  
    ANDI    R17, 0x30      ; Asegurar que solo afectan los bits 4 y 5  
    ROR R17  
	ROR R17    ; Desplazar los bits 2 posición a la derecha  
    OUT     PORTB, R17     ; Mostrar el resultado en los LEDs  

    RET