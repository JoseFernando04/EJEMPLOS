;************************************************************  
; Universidad del Valle de Guatemala  
; IE2023: Programación de Microcontroladores  
;  
; Author  : José Fernando Gordillo Flores 
; Proyecto: PostLaboratorio 2
; Hardware: ATmega328P  
; Creado  : 12/02/2025  
;************************************************************   

.include "m328pdef.inc"  
// Definiciones y variables  
.cseg  
.org 0x0000
.def    TEMP    = R16
.def    CONT_100MS = R17
.def    CONT_SEG = R18
.def    CONT_HEX = R19
.def    ESTADO_BTN = R20
.def    ESTADO_LED = R21
.def    DECISEG = R22

// Tabla de conversión para display de 7 segmentos (cátodo común)
TABLA_SEGMENTOS:
    .db 0b00111111, 0b00000110, 0b01011011, 0b01001111  ; 0-3
    .db 0b01100110, 0b01101101, 0b01111101, 0b00000111  ; 4-7
    .db 0b01111111, 0b01101111, 0b01110111, 0b01111100  ; 8-B
    .db 0b00111001, 0b01011110, 0b01111001, 0b01110001  ; C-F

// Configuración del Stack  
LDI     TEMP, LOW(RAMEND)   
OUT     SPL, TEMP           
LDI     TEMP, HIGH(RAMEND)  
OUT     SPH, TEMP           

CONFIGURACION:  
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
    CLR     CONT_100MS
    CLR     CONT_SEG
    CLR     CONT_HEX
    CLR     ESTADO_BTN
    CLR     ESTADO_LED
    CLR     DECISEG
    
    ; Configurar puertos
    LDI     TEMP, 0b00011111  
    OUT     DDRB, TEMP
    OUT     PORTB, CONT_SEG    
    CBI     DDRC, PC0
    CBI     DDRC, PC1
    SBI     PORTC, PC0
    SBI     PORTC, PC1
    LDI     TEMP, 0b11111111  
    OUT     DDRD, TEMP
    RCALL   ACTUALIZAR_DISPLAY

BUCLE_PRINCIPAL:  
    RCALL   REVISAR_TIMER
    RCALL   REVISAR_BOTONES
    RJMP    BUCLE_PRINCIPAL

REVISAR_TIMER:
    IN      TEMP, TIFR0
    SBRS    TEMP, TOV0
    RET
    SBI     TIFR0, TOV0
    LDI     TEMP, 100
    OUT     TCNT0, TEMP  
    INC     CONT_100MS
    CPI     CONT_100MS, 100      ; Cambiar de 10 a 100 para contar cada segundo
    BRNE    FIN_TIMER
    CLR     CONT_100MS
    
    ; Incrementar contador de segundos
    INC     CONT_SEG
    ANDI    CONT_SEG, 0x0F
    
    ; Mostrar contador en PORTB manteniendo estado del LED
    IN      TEMP, PORTB
    ANDI    TEMP, 0b00010000  ; Mantener estado del LED
    MOV     ESTADO_LED, TEMP
    MOV     TEMP, CONT_SEG
    ANDI    TEMP, 0x0F
    OR      TEMP, ESTADO_LED
    OUT     PORTB, TEMP
    
    ; Si CONT_HEX es 0, siempre cambiar LED
    TST     CONT_HEX
    BREQ    CAMBIAR_LED
    ; Si no es 0, comparar normalmente
    CP      CONT_SEG, CONT_HEX
    BRNE    FIN_TIMER

CAMBIAR_LED:
    ; Si CONT_HEX es 0 o CONT_SEG = CONT_HEX
    CLR     CONT_SEG          ; Reiniciar contador
    OUT     PORTB, ESTADO_LED ; Actualizar contador en display
    
    ; Toggle LED
    IN      TEMP, PORTB
    LDI     ESTADO_LED, (1 << PB4)
    EOR     TEMP, ESTADO_LED
    OUT     PORTB, TEMP

FIN_TIMER:
    RET

REVISAR_BOTONES:
    ; Verificar botón de incremento (PC0)
    SBIC    PINC, PC0
    RJMP    REVISAR_DECREMENTO
    
    RCALL   ANTI_REBOTE
    SBIC    PINC, PC0
    RJMP    REVISAR_DECREMENTO
    
    INC     CONT_HEX
    ANDI    CONT_HEX, 0x0F
    RCALL   ACTUALIZAR_DISPLAY
    
ESPERAR_INC:
    RCALL   REVISAR_TIMER
    SBIS    PINC, PC0
    RJMP    ESPERAR_INC

REVISAR_DECREMENTO:
    SBIC    PINC, PC1
    RET
    
    RCALL   ANTI_REBOTE
    SBIC    PINC, PC1
    RET
    
    DEC     CONT_HEX
    ANDI    CONT_HEX, 0x0F
    RCALL   ACTUALIZAR_DISPLAY
    
ESPERAR_DEC:
    RCALL   REVISAR_TIMER
    SBIS    PINC, PC1
    RJMP    ESPERAR_DEC
    
    RET

ACTUALIZAR_DISPLAY:
    MOV     ZL, CONT_HEX
    LDI     ZH, HIGH(TABLA_SEGMENTOS << 1)
    LDI     ZL, LOW(TABLA_SEGMENTOS << 1)
    ADD     ZL, CONT_HEX
    LPM     TEMP, Z
    OUT     PORTD, TEMP
    RET

ANTI_REBOTE:
    LDI     TEMP, 100
BUCLE_ANTI_REBOTE:
    DEC     TEMP
    BRNE    BUCLE_ANTI_REBOTE
    RET