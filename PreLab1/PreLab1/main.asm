;************************************************************  
; Universidad del Valle de Guatemala  
; IE2023: Programación de Microcontroladores  
; Sumador_4bits_con_antirrebote.asm  
;  
; Author  : José Fernando Gordillo Flores  
; Proyecto: PreLab1  
; Hardware: ATmega328P  
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
    ; Configurar Puerto D como entrada con pull-up habilitado (botones en PD2 y PD3)  
    LDI     R16, 0x00  
    OUT     DDRD, R16  
    LDI     R16, 0xFF  
    OUT     PORTD, R16  

    ; Configurar Puerto B como salida (contador en PB0-PB3)  
    LDI     R16, 0xFF  
    OUT     DDRB, R16  
    LDI     R16, 0x00  
    OUT     PORTB, R16  

    ; Inicializar el contador en 0  
    LDI     R18, 0x00  
    OUT     PORTB, R18  

; Loop principal  
LOOP:  
    CALL    LEER_BOTONES   ; Leer estado de los botones  
    OUT     PORTB, R18      ; Actualiza LEDs en cada iteración  
    RJMP    LOOP             ; Volver al inicio del bucle  

; --- Subrutina para leer botones con antirrebote ---  
LEER_BOTONES:  
    ; *Incrementar (PD2)*  
    SBIS    PIND, 2          ; Salta si PD2 está en 1 (no presionado)  
    RCALL   PROC_INCREMENTAR ; Si está en 0 (presionado), procesar  

    ; *Decrementar (PD3)*  
    SBIS    PIND, 3          ; Salta si PD3 está en 1 (no presionado)  
    RCALL   PROC_DECREMENTAR ; Si está en 0 (presionado), procesar  

    RET  

; --- Procesar incremento ---  
PROC_INCREMENTAR:  
    RCALL   ANTIRREBOTE      ; Llama al antirrebote  
    SBIC    PIND, 2          ; Verificar nuevamente: Si PD2=1 (se soltó), retornar  
    RET  
    INC     R18              ; Incrementar  
    ANDI    R18, 0x0F        ; Limitar a 4 bits (0-15)  
    RET  

; --- Procesar decremento ---  
PROC_DECREMENTAR:  
    RCALL   ANTIRREBOTE      ; Llama al antirrebote  
    SBIC    PIND, 3          ; Verificar nuevamente, si PD3=1, retornar  
    RET  
    CPI     R18, 0x00        ; ¿Contador es 0?  
    BRNE    DEC_CONTADOR      
    LDI     R18, 0x0F        ; Si es 0, recargar a 15  
    RET  
DEC_CONTADOR:  
    DEC     R18  
    ANDI    R18, 0x0F        ; Asegurar que solo afectan los 4 bits  
    RET  

; --- Antirrebote ---  
ANTIRREBOTE:  
    LDI     R19, 210          ; Ajusta este valor según el tiempo deseado  
BUCLE1:  
    LDI     R20, 255          ; Cuenta hacia abajo para un retardo  
BUCLE2:  
    LDI     R21, 25           ; Ajusta para el retardo necesario  
BUCLE3:  
    DEC     R21               ; Decrementa el contador interno  
    BRNE    BUCLE3            ; Si no es cero, repetir  
    DEC     R20               ; Decrementa el contador de ciclos del retardo  
    BRNE    BUCLE2            ; Repite hasta que el ciclo externo termine  
    DEC     R19               ; Decrementa el contador de tiempos del antirrebote  
    BRNE    BUCLE1            ; Repetir hasta que se complete el tiempo  
    RET