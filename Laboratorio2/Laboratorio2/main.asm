;************************************************************  
; Universidad del Valle de Guatemala  
; IE2023: Programación de Microcontroladores  
;  
; Author  : José Fernando Gordillo Flores 
; Proyecto: Laboratorio 2
; Hardware: ATmega328P  
; Creado  : 11/02/2025  
;************************************************************   

.include "m328pdef.inc"  

//  
// Definiciones y variables  
.cseg  
.org 0x0000                 ; Dirección de Reset (inicio del programa)  
.def    TEMP    = R16       ; Registro temporal  
.def    COUNTER = R17       ; Contador para incrementar cada 100 ms  
.def    BINARY_COUNT = R18  ; Registro para contador binario automático
.def    HEX_COUNT = R19     ; Registro para contador hexadecimal con botones
.def    BUTTON_STATE = R20  ; Estado actual de los botones

// Tabla de conversión para display de 7 segmentos (cátodo común)
SEGMENT_TABLE:
    .db 0b00111111, 0b00000110, 0b01011011, 0b01001111  ; 0, 1, 2, 3
    .db 0b01100110, 0b01101101, 0b01111101, 0b00000111  ; 4, 5, 6, 7
    .db 0b01111111, 0b01101111, 0b01110111, 0b01111100  ; 8, 9, A, B
    .db 0b00111001, 0b01011110, 0b01111001, 0b01110001  ; C, D, E, F

//  
// Configuración del Stack  
LDI     TEMP, LOW(RAMEND)   
OUT     SPL, TEMP           
LDI     TEMP, HIGH(RAMEND)  
OUT     SPH, TEMP           

//  
// Configuración del microcontrolador  
SETUP:  
    ; Configurar el reloj -> Prescaler a 16 (1 MHz)  
    LDI     TEMP, (1 << CLKPCE)    
    STS     CLKPR, TEMP  
    LDI     TEMP, 0b00000100       
    STS     CLKPR, TEMP  

    ; Configurar Timer 0 -> Prescaler a 64  
    LDI     TEMP, (1 << CS01) | (1 << CS00)  
    OUT     TCCR0B, TEMP           
    
    ; Inicializar registros  
    LDI     TEMP, 100              
    OUT     TCNT0, TEMP  
    CLR     COUNTER                
    CLR     BINARY_COUNT           
    CLR     HEX_COUNT              
    CLR     BUTTON_STATE           

    ; Configurar PB0-PB3 como salidas para el contador binario  
    LDI     TEMP, 0b00001111  
    OUT     DDRB, TEMP             
    OUT     PORTB, BINARY_COUNT    

    ; Configurar PC0 y PC1 como entradas para los botones con pull-up
    CBI     DDRC, PC0              ; PC0 como entrada
    CBI     DDRC, PC1              ; PC1 como entrada
    SBI     PORTC, PC0             ; Habilitar pull-up en PC0
    SBI     PORTC, PC1             ; Habilitar pull-up en PC1

    ; Configurar PD0-PD7 como salidas para el display de 7 segmentos  
    LDI     TEMP, 0b11111111  
    OUT     DDRD, TEMP             

    ; Mostrar valor inicial en display
    RCALL   UPDATE_DISPLAY

//  
// Loop principal  
MAIN_LOOP:  
    RCALL   CHECK_TIMER            ; Verificar Timer0
    RCALL   CHECK_BUTTONS          ; Verificar botones
    RJMP    MAIN_LOOP

//
// Subrutina para verificar Timer0
CHECK_TIMER:
    ; Verificar desbordamiento del Timer 0  
    IN      TEMP, TIFR0            
    SBRS    TEMP, TOV0             
    RET                            ; Retornar si no hay desbordamiento

    ; Limpiar bandera y recargar Timer 0
    SBI     TIFR0, TOV0            
    LDI     TEMP, 100              
    OUT     TCNT0, TEMP  

    ; Incrementar contador cada 10 ms  
    INC     COUNTER                
    CPI     COUNTER, 10            ; ¿Hemos llegado a 100 ms?  
    BRNE    TIMER_END              ; Si no, retornar

    ; Actualizar contador binario cada 100ms
    CLR     COUNTER                
    INC     BINARY_COUNT           
    ANDI    BINARY_COUNT, 0x0F     
    OUT     PORTB, BINARY_COUNT    

TIMER_END:
    RET

//
// Subrutina para verificar botones
CHECK_BUTTONS:
    ; Verificar botón de incremento (PC0)
    SBIC    PINC, PC0              ; Saltar si PC0 está en bajo (presionado)
    RJMP    CHECK_DEC              ; Si no está presionado, verificar decremento
    
    RCALL   DEBOUNCE               ; Esperar debounce
    SBIC    PINC, PC0              ; Verificar si sigue presionado
    RJMP    CHECK_DEC
    
    INC     HEX_COUNT              ; Incrementar contador
    ANDI    HEX_COUNT, 0x0F        ; Mantener en rango 0-F
    RCALL   UPDATE_DISPLAY
    
    ; Esperar que se suelte el botón mientras se mantiene el Timer
WAIT_INC:
    RCALL   CHECK_TIMER            ; Seguir verificando Timer mientras esperamos
    SBIS    PINC, PC0              ; Verificar si el botón sigue presionado
    RJMP    WAIT_INC               ; Si sigue presionado, seguir esperando

CHECK_DEC:
    ; Verificar botón de decremento (PC1)
    SBIC    PINC, PC1              ; Saltar si PC1 está en bajo (presionado)
    RET                            ; Si no está presionado, retornar
    
    RCALL   DEBOUNCE               ; Esperar debounce
    SBIC    PINC, PC1              ; Verificar si sigue presionado
    RET
    
    DEC     HEX_COUNT              ; Decrementar contador
    ANDI    HEX_COUNT, 0x0F        ; Mantener en rango 0-F
    RCALL   UPDATE_DISPLAY
    
    ; Esperar que se suelte el botón mientras se mantiene el Timer
WAIT_DEC:
    RCALL   CHECK_TIMER            ; Seguir verificando Timer mientras esperamos
    SBIS    PINC, PC1              ; Verificar si el botón sigue presionado
    RJMP    WAIT_DEC               ; Si sigue presionado, seguir esperando
    
    RET

//  
// Subrutina para actualizar display
UPDATE_DISPLAY:
    ; Convertir valor a 7 segmentos
    MOV     ZL, HEX_COUNT
    LDI     ZH, HIGH(SEGMENT_TABLE << 1)
    LDI     ZL, LOW(SEGMENT_TABLE << 1)
    ADD     ZL, HEX_COUNT
    LPM     TEMP, Z
    OUT     PORTD, TEMP
    RET

//
// Subrutina de debounce
DEBOUNCE:
    LDI     TEMP, 100
DEBOUNCE_LOOP:
    DEC     TEMP
    BRNE    DEBOUNCE_LOOP
    RET