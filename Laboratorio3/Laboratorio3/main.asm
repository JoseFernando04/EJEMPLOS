;************************************************************  
; Universidad del Valle de Guatemala  
; IE2023: Programaci�n de Microcontroladores  
;  
; Author  : Jos� Fernando Gordillo Flores 
; Proyecto: Laboratorio 3
; Hardware: ATmega328P  
; Creado  : 18/02/2025  
;************************************************************
.include "m328Pdef.inc"  

; Definir registros utilizados
.def contador_bin = r16       ; Contador binario (botones)
.def contador_hex = r18       ; Contador hexadecimal (TMR0)
.def temp = r17               ; Registro temporal
.def cont_int = r19           ; Contador para la interrupci�n TMR0
.def decenas = r20            ; Contador de decenas de segundos

; Definiciones para el display de 7 segmentos (c�todo com�n)
; Mapeo: PGFEDCBA (los bits en 1 encienden los segmentos)
.equ SEG_0 = 0b00111111
.equ SEG_1 = 0b00000110
.equ SEG_2 = 0b01011011
.equ SEG_3 = 0b01001111
.equ SEG_4 = 0b01100110
.equ SEG_5 = 0b01101101
.equ SEG_6 = 0b01111101
.equ SEG_7 = 0b00000111
.equ SEG_8 = 0b01111111
.equ SEG_9 = 0b01101111
.equ SEG_A = 0b01110111
.equ SEG_B = 0b01111100
.equ SEG_C = 0b00111001
.equ SEG_D = 0b01011110
.equ SEG_E = 0b01111001
.equ SEG_F = 0b01110001

; Tabla de 7 segmentos para convertir de hexadecimal a 7 segmentos
.dseg
tabla_7seg: .byte 16         ; Reserva espacio para tabla de conversi�n

.cseg
; Vector de interrupciones
.org 0x0000                  ; Direcci�n de reset  
    rjmp START                ; Salto a la rutina de inicio  
.org PCI1addr                ; Direcci�n de interrupci�n PCINT1 (Puerto C)  
    rjmp ISR_BUTTON           ; Salto a la rutina de interrupci�n
.org OVF0addr                ; Direcci�n de interrupci�n del Timer 0
    rjmp ISR_TIMER0           ; Salto a la rutina de interrupci�n del Timer 0

START:  
    ; Inicializar pila  
    ldi temp, LOW(RAMEND)      
    out SPL, temp  
    ldi temp, HIGH(RAMEND)     
    out SPH, temp  
    
    ; Inicializar tabla de conversi�n de 7 segmentos
    rcall INIT_TABLA_7SEG
    
    ; Configuraci�n del MCU  
    cli                       ; Deshabilitar interrupciones globales  
    
    ; Configurar pull-ups en botones (PC0 y PC1 como entradas con pull-up)  
    ldi temp, (1 << PC0) | (1 << PC1)  
    out PORTC, temp            ; Habilitar pull-ups en PC0 y PC1  
    
    ; Configurar interrupciones de cambio en PC0 y PC1  
    ldi temp, (1 << PCIE1)     ; Habilitar PCINT1 (Puerto C)  
    sts PCICR, temp  
    
    ldi temp, (1 << PCINT8) | (1 << PCINT9) ; Habilitar PC0 y PC1  
    sts PCMSK1, temp  
    
    ; Configurar LEDs como salida (PB0-PB3)  
    ldi temp, 0x0F            
    out DDRB, temp
    
    ; Configurar PORTD como salida para displays 7 segmentos
    ldi temp, 0xFF
    out DDRD, temp             ; Todos los pines de PORTD como salida
    
    ; Configurar Timer 0 para generar interrupci�n cada ~10ms
    ldi temp, (1 << CS02) | (0 << CS01) | (1 << CS00)  ; Prescaler 1024
    out TCCR0B, temp           ; Configurar Timer 0 con prescaler 1024
    
    ldi temp, 1 << TOIE0       ; Habilitar interrupci�n de overflow
    sts TIMSK0, temp
    
    ; Inicializar contadores  
    clr contador_bin          ; Contador binario en 0  
    out PORTB, contador_bin   ; Apagar LEDs
    clr contador_hex          ; Contador hexadecimal en 0
    clr cont_int              ; Contador de interrupciones en 0
    clr decenas               ; Contador de decenas en 0
    
    ; Mostrar valor inicial en 7 segmentos
    rcall ACTUALIZAR_DISPLAY
    
    sei                       ; Habilitar interrupciones globales  

MAIN_LOOP:  
    rjmp MAIN_LOOP            ; Bucle principal  

; Rutina de interrupci�n para los botones
ISR_BUTTON:  
    ; Guardar estado de SREG  
    in temp, SREG             
    push temp                 
    
    ; Leer estado actual de PINC  
    in temp, PINC              
    
    ; Verificar bot�n de incremento (PC0 presionado = bajo)  
    sbrs temp, PC0            ; Salta si PC0 est� alto (no presionado)  
    inc contador_bin          ; Incrementa si est� bajo (presionado)  
    
    ; Verificar bot�n de decremento (PC1 presionado = bajo)  
    sbrs temp, PC1            ; Salta si PC1 est� alto (no presionado)  
    dec contador_bin          ; Decrementa si est� bajo (presionado)  
    
    ; Aplicar m�scara de 4 bits y actualizar LEDs  
    andi contador_bin, 0x0F           
    out PORTB, contador_bin           
    
    ; Restaurar SREG  
    pop temp                  
    out SREG, temp            
    reti                     ; Retornar de interrupci�n

; Rutina de interrupci�n para el Timer 0 (cada ~10ms)
ISR_TIMER0:
    ; Guardar estado de SREG
    in temp, SREG
    push temp
    
    ; Incrementar contador de interrupciones
    inc cont_int
    
    ; Verificar si han pasado 506 interrupciones
    cpi cont_int, 50
    brne ISR_TIMER0_EXIT
    
    ; Ha pasado 1 segundo, actualizar contador hexadecimal
    clr cont_int
    inc contador_hex
    
    ; Verificar si el contador ha llegado a 10 (decimal)
    cpi contador_hex, 10
    brne CHECK_RESET
    
    ; Ha llegado a 10, reiniciar contador y actualizar decenas
    clr contador_hex
    inc decenas
    
CHECK_RESET:
    ; Verificar si han pasado 60 segundos
    cpi decenas, 6
    brne ACTUALIZAR_DISPLAY_INT
    
    ; Han pasado 60 segundos, reiniciar ambos contadores
    clr decenas
    clr contador_hex
    
ACTUALIZAR_DISPLAY_INT:
    ; Actualizar display de 7 segmentos
    rcall ACTUALIZAR_DISPLAY
    
ISR_TIMER0_EXIT:
    ; Restaurar SREG
    pop temp
    out SREG, temp
    reti

; Rutina para actualizar display de 7 segmentos
ACTUALIZAR_DISPLAY:
    push ZL
    push ZH
    push temp
    
    ; Cargar direcci�n de la tabla
    ldi ZL, LOW(tabla_7seg)
    ldi ZH, HIGH(tabla_7seg)
    
    ; Sumar el offset para obtener el d�gito unidades
    mov temp, contador_hex
    add ZL, temp
    adc ZH, r1          ; r1 siempre es 0
    
    ; Cargar el valor correspondiente desde la tabla
    ld temp, Z
    
    ; Mostrar en display conectado a PORTD
    out PORTD, temp
    
    pop temp
    pop ZH
    pop ZL
    ret

; Rutina para inicializar la tabla de conversi�n
INIT_TABLA_7SEG:
    push ZL
    push ZH
    push temp
    push r0
    
    ; Cargar direcci�n de inicio de la tabla
    ldi ZL, LOW(tabla_7seg)
    ldi ZH, HIGH(tabla_7seg)
    
    ; Cargar los valores en la tabla
    ldi temp, SEG_0
    st Z+, temp
    ldi temp, SEG_1
    st Z+, temp
    ldi temp, SEG_2
    st Z+, temp
    ldi temp, SEG_3
    st Z+, temp
    ldi temp, SEG_4
    st Z+, temp
    ldi temp, SEG_5
    st Z+, temp
    ldi temp, SEG_6
    st Z+, temp
    ldi temp, SEG_7
    st Z+, temp
    ldi temp, SEG_8
    st Z+, temp
    ldi temp, SEG_9
    st Z+, temp
    ldi temp, SEG_A
    st Z+, temp
    ldi temp, SEG_B
    st Z+, temp
    ldi temp, SEG_C
    st Z+, temp
    ldi temp, SEG_D
    st Z+, temp
    ldi temp, SEG_E
    st Z+, temp
    ldi temp, SEG_F
    st Z+, temp
    
    pop r0
    pop temp
    pop ZH
    pop ZL
    ret