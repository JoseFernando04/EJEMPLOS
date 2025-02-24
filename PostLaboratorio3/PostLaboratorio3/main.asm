;************************************************************  
; Universidad del Valle de Guatemala  
; IE2023: Programación de Microcontroladores  
;  
; Author  : José Fernando Gordillo Flores 
; Proyecto: Post Laboratorio 3
; Hardware: ATmega328P  
; Creado  : 18/02/2025  
;************************************************************
.include "m328Pdef.inc"  

; Definir registros utilizados
.def contador_bin = r16       ; Contador binario (botones)
.def contador_hex = r18       ; Contador hexadecimal (TMR0)
.def temp = r17               ; Registro temporal
.def cont_int = r19           ; Contador para la interrupción TMR0
.def decenas = r20            ; Contador de decenas de segundos

; Definiciones para el display de 7 segmentos (cátodo común)
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

.dseg
tabla_7seg: .byte 16         ; Tabla de conversión
display_toggle: .byte 1       ; 0: Unidades, 1: Decenas

.cseg
.org 0x0000                  
    rjmp START                
.org PCI1addr                
    rjmp ISR_BUTTON           
.org OVF0addr                
    rjmp ISR_TIMER0           

START:  
    ldi temp, LOW(RAMEND)      
    out SPL, temp  
    ldi temp, HIGH(RAMEND)     
    out SPH, temp  
    
    rcall INIT_TABLA_7SEG
    
    cli                       
    
    ; Configurar pull-ups en PC0 y PC1
    ldi temp, (1 << PC0) | (1 << PC1)  
    out PORTC, temp            
    
    ; Habilitar interrupciones en PC0 y PC1
    ldi temp, (1 << PCIE1)     
    sts PCICR, temp  
    ldi temp, (1 << PCINT8) | (1 << PCINT9) 
    sts PCMSK1, temp  
    
    ; Configurar PC2 y PC3 como salidas (enable de displays)
    ldi temp, (1 << PC2) | (1 << PC3)            
    out DDRC, temp
    
    ; Configurar PORTD como salida (segmentos de displays)
    ldi temp, 0xFF
    out DDRD, temp             
    
    ; Timer0 con prescaler 1024
    ldi temp, (1 << CS02) | (1 << CS00)  
    out TCCR0B, temp           
    
    ldi temp, 1 << TOIE0       
    sts TIMSK0, temp
    
    ; Inicializar contadores y display_toggle
    clr contador_bin          
    out PORTB, contador_bin   
    clr contador_hex          
    clr cont_int              
    clr decenas               
    ldi temp, 0
    sts display_toggle, temp  
    
    rcall ACTUALIZAR_DISPLAY
    
    sei                       

MAIN_LOOP:  
    rjmp MAIN_LOOP            

ISR_BUTTON:  
    in temp, SREG             
    push temp                 
    in temp, PINC              
    
    sbrs temp, PC0            
    inc contador_bin          
    sbrs temp, PC1            
    dec contador_bin          
    
    andi contador_bin, 0x0F           
    out PORTB, contador_bin           
    
    pop temp                  
    out SREG, temp            
    reti                     

ISR_TIMER0:
    in temp, SREG
    push temp
    
    inc cont_int
    
    ; Verificar si han pasado 61 interrupciones (1 segundo)
    cpi cont_int, 61
    brne SKIP_SECOND
    
    ; Actualizar contadores cada 1 segundo
    clr cont_int
    inc contador_hex
    cpi contador_hex, 10
    brne CHECK_RESET
    clr contador_hex
    inc decenas
    
CHECK_RESET:
    cpi decenas, 6
    brne SKIP_RESET
    clr decenas
    clr contador_hex
    
SKIP_RESET:
SKIP_SECOND:
    ; --- Multiplexar displays CADA 5ms (no esperar 1 segundo) ---
    rcall ACTUALIZAR_DISPLAY ; Llamar SIEMPRE
    
    pop temp
    out SREG, temp
    reti

; --- Rutina de actualización de displays (multiplexación rápida) ---
ACTUALIZAR_DISPLAY:
    push ZL
    push ZH
    push temp
    push r0
    in r0, SREG
    push r0
    
    lds r20, display_toggle
    cpi r20, 0
    breq MOSTRAR_UNIDADES
    
MOSTRAR_DECENAS:
    mov temp, decenas
    rjmp CARGAR_TABLA
    
MOSTRAR_UNIDADES:
    mov temp, contador_hex
    
CARGAR_TABLA:
    ldi ZL, LOW(tabla_7seg)
    ldi ZH, HIGH(tabla_7seg)
    add ZL, temp
    adc ZH, r1          
    ld temp, Z
    
    out PORTD, temp       ; Cargar segmentos
    
    ; Apagar ambos displays antes de activar uno
    in r21, PORTC
    andi r21, ~((1 << PC2) | (1 << PC3)) 
    
    cpi r20, 0
    breq ACTIVAR_UNIDADES
    
    ori r21, (1 << PC3)   ; Encender decenas (PC3)
    rjmp ACTUALIZAR_PORTC
    
ACTIVAR_UNIDADES:
    ori r21, (1 << PC2)   ; Encender unidades (PC2)
    
ACTUALIZAR_PORTC:
    out PORTC, r21        ; Actualizar enable
    
    ; Alternar display para la próxima iteración
    lds r20, display_toggle
    ldi r21, 1
    eor r20, r21
    sts display_toggle, r20
    
    pop r0
    out SREG, r0
    pop r0
    pop ZH
    pop ZL
    pop temp
    ret

; --- Inicializar tabla de 7 segmentos ---
INIT_TABLA_7SEG:
    push ZL
    push ZH
    push temp
    
    ldi ZL, LOW(tabla_7seg)
    ldi ZH, HIGH(tabla_7seg)
    
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
    
    pop temp
    pop ZH
    pop ZL
    ret