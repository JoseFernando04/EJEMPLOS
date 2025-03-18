;************************************************************  
; Universidad del Valle de Guatemala  
; IE2023: Programación de Microcontroladores  
;  
; Author  : José Fernando Gordillo Flores 
; Proyecto: RELOJ
; Hardware: ATmega328P  
;************************************************************

.include "m328Pdef.inc"

.cseg
.org 0x0000
    JMP     START

.org OVF0addr
    JMP     TMR0_ISR

.org 0x000A        ; Dirección correcta para PCINT1 (PCINT[8:14])
    JMP     PCINT1_ISR

; Tabla de valores para display de 7 segmentos
.org 0x0030        ; Dirección segura para el resto del código
DISPLAY:
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F

; Definición de registros
.def    temp = r16        ; Registro temporal
.def    flags = r23       ; Registro para flags 
                          ; bit 0: parpadeo
                          ; bit 1: alarma activa
                          ; bit 2: estado parpadeo alarma
                          ; bit 3: alarma silenciada temporalmente
.def    temp2 = r18       ; Registro temporal adicional
.def    modo = r19        ; Registro para modo 
                          ; 0 = reloj
                          ; 1 = fecha
                          ; 2 = config hora
                          ; 3 = config fecha
                          ; 4 = config alarma

; Variables en .dseg
.dseg
cont_sec:    .byte 1    ; Contador de segundos
cont_min_u:  .byte 1    ; Unidades de minutos
cont_min_d:  .byte 1    ; Decenas de minutos
cont_hr_u:   .byte 1    ; Unidades de horas
cont_hr_d:   .byte 1    ; Decenas de horas
contador:    .byte 1    ; Contador para timer
led_timer:   .byte 1    ; Contador para LED
dia_u:       .byte 1    ; Unidades de día
dia_d:       .byte 1    ; Decenas de día
mes_u:       .byte 1    ; Unidades de mes
mes_d:       .byte 1    ; Decenas de mes
alarm_min_u: .byte 1    ; Unidades de minutos de alarma
alarm_min_d: .byte 1    ; Decenas de minutos de alarma
alarm_hr_u:  .byte 1    ; Unidades de horas de alarma
alarm_hr_d:  .byte 1    ; Decenas de horas de alarma
alarm_timer: .byte 1    ; Contador para apagar alarma automáticamente
alarm_blink: .byte 1    ; Contador para parpadeo de alarma
alarm_silenced: .byte 1 ; Flag para indicar si la alarma fue silenciada

.cseg
START:
    LDI     temp, LOW(RAMEND)
    OUT     SPL, temp
    LDI     temp, HIGH(RAMEND)
    OUT     SPH, temp

SETUP:
    CLI

    ; Configuración del prescaler del reloj
    LDI     temp, (1<<CS02)|(1<<CS00)    ; Prescaler de 1024
    OUT     TCCR0B, temp
    LDI     temp, 0              ; Valor inicial para timer
    OUT     TCNT0, temp
    
    ; Habilitar interrupción de Timer 0
    LDI     temp, (1<<TOIE0)
    STS     TIMSK0, temp

    ; Configuración de puertos
    LDI     temp, 0x3F           ; PB0-PB5 como salidas
    OUT     DDRB, temp       
    LDI     temp, 0xFF
    OUT     DDRD, temp       ; Puerto D como salida
    LDI     temp, 0x20       ; PC0-PC3 como entradas, PC5 como salida
    OUT     DDRC, temp
    LDI     temp, (1<<PC0)|(1<<PC1)|(1<<PC2)|(1<<PC3)   ; Pull-up en PC0, PC1, PC2, PC3
    OUT     PORTC, temp
    
    ; Configurar PC5 como salida (LED de alarma)
    SBI     DDRC, PC5
    CBI     PORTC, PC5       ; LED de alarma apagado inicialmente

    ; Configuración de interrupciones pin change
    LDI     temp, (1<<PCIE1)     ; Habilitar PCINT grupo 1 (PORTC)
    STS     PCICR, temp
    LDI     temp, (1<<PCINT8)|(1<<PCINT9)|(1<<PCINT10)|(1<<PCINT11)    ; Habilitar PCINT8-11 (PC0-PC3)
    STS     PCMSK1, temp

    ; Inicialización de variables
    LDI     temp, 0
    STS     cont_sec, temp
    STS     cont_min_u, temp
    STS     cont_min_d, temp
    STS     cont_hr_u, temp
    STS     cont_hr_d, temp
    STS     contador, temp
    STS     led_timer, temp
    STS     alarm_min_u, temp
    STS     alarm_min_d, temp
    STS     alarm_hr_u, temp
    STS     alarm_hr_d, temp
    STS     alarm_timer, temp
    STS     alarm_blink, temp
    STS     alarm_silenced, temp
    
    ; Inicializar fecha (01/01)
    LDI     temp, 1
    STS     dia_u, temp
    LDI     temp, 0
    STS     dia_d, temp
    LDI     temp, 1
    STS     mes_u, temp
    LDI     temp, 0
    STS     mes_d, temp
    
    CLR     flags            ; Inicializar flags (alarma desactivada)
    CLR     modo

    ; Inicializar LED de modo hora (PB4)
    SBI     PORTB, PB4
    CBI     PORTB, PB5

    SEI

MAIN_LOOP:
    CALL    MOSTRAR_DISPLAYS
    JMP     MAIN_LOOP        

ACTUALIZAR_LEDS_MODO:
    PUSH    temp
    IN      temp, PORTB
    ANDI    temp, 0xCF   ; Limpiar PB4 y PB5
    
    CPI     modo, 0
    BRNE    CHECK_MODO_1
    ORI     temp, (1<<PB4)   ; Modo 0 (hora): Encender PB4
    JMP     SET_LEDS         
    
CHECK_MODO_1:
    CPI     modo, 1
    BRNE    CHECK_MODO_2
    ORI     temp, (1<<PB5)   ; Modo 1 (fecha): Encender PB5
    JMP     SET_LEDS         
    
CHECK_MODO_2:
    CPI     modo, 2
    BRNE    CHECK_MODO_3
    ; Modo 2 (config hora): PB4 parpadeará en TMR0_ISR
    JMP     SET_LEDS         
    
CHECK_MODO_3:
    CPI     modo, 3
    BRNE    CHECK_MODO_4
    ; Modo 3 (config fecha): PB5 parpadeará en TMR0_ISR
    JMP     SET_LEDS         
    
CHECK_MODO_4:
    CPI     modo, 4
    BRNE    SET_LEDS
    ; Modo 4 (config alarma): Ambos LEDs parpadearán en TMR0_ISR
    
SET_LEDS:
    OUT     PORTB, temp
    POP     temp
    RET

MOSTRAR_DISPLAYS:
    CPI     modo, 1           ; Verificar modo
    BRNE    CHECK_MODO_2_DISPLAY
    JMP     MOSTRAR_FECHA     ; Si modo = 1, mostrar fecha
    
CHECK_MODO_2_DISPLAY:
    CPI     modo, 2           ; Verificar modo
    BRNE    CHECK_MODO_3_DISPLAY
    JMP     MOSTRAR_CONFIG_HORA ; Si modo = 2, mostrar config hora
    
CHECK_MODO_3_DISPLAY:
    CPI     modo, 3           ; Verificar modo
    BRNE    CHECK_MODO_4_DISPLAY
    JMP     MOSTRAR_CONFIG_FECHA ; Si modo = 3, mostrar config fecha
    
CHECK_MODO_4_DISPLAY:
    CPI     modo, 4           ; Verificar modo
    BRNE    MOSTRAR_RELOJ
    JMP     MOSTRAR_CONFIG_ALARMA ; Si modo = 4, mostrar config alarma

MOSTRAR_RELOJ:
    ; Display 4 (PB3) - Decenas de horas
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, cont_hr_d
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB3
    CALL    RETARDO

    ; Display 3 (PB2) - Unidades de horas
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, cont_hr_u
    ADD     ZL, temp
    LPM     temp, Z
    SBRC    flags, 0
    ORI     temp, 0x80
    OUT     PORTD, temp
    SBI     PORTB, PB2
    CALL    RETARDO

    ; Display 2 (PB1) - Decenas de minutos
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, cont_min_d
    ADD     ZL, temp
    LPM     temp, Z
    SBRC    flags, 0
    ORI     temp, 0x80
    OUT     PORTD, temp
    SBI     PORTB, PB1
    CALL    RETARDO

    ; Display 1 (PB0) - Unidades de minutos
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, cont_min_u
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB0
    CALL    RETARDO
    RET

MOSTRAR_FECHA:
    ; Display 4 (PB3) - Decenas de día
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, dia_d
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB3
    CALL    RETARDO

    ; Display 3 (PB2) - Unidades de día
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, dia_u
    ADD     ZL, temp
    LPM     temp, Z
    ORI     temp, 0x80        ; Punto decimal para separador
    OUT     PORTD, temp
    SBI     PORTB, PB2
    CALL    RETARDO

    ; Display 2 (PB1) - Decenas de mes
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, mes_d
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB1
    CALL    RETARDO

    ; Display 1 (PB0) - Unidades de mes
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, mes_u
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB0
    CALL    RETARDO
    RET

MOSTRAR_CONFIG_HORA:
    ; Display 4 (PB3) - Decenas de horas
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, cont_hr_d
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB3
    CALL    RETARDO

    ; Display 3 (PB2) - Unidades de horas
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, cont_hr_u
    ADD     ZL, temp
    LPM     temp, Z
    SBRC    flags, 0
    ORI     temp, 0x80
    OUT     PORTD, temp
    SBI     PORTB, PB2
    CALL    RETARDO

    ; Display 2 (PB1) - Decenas de minutos
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, cont_min_d
    ADD     ZL, temp
    LPM     temp, Z
    SBRC    flags, 0
    ORI     temp, 0x80
    OUT     PORTD, temp
    SBI     PORTB, PB1
    CALL    RETARDO

    ; Display 1 (PB0) - Unidades de minutos
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, cont_min_u
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB0
    CALL    RETARDO
    RET

MOSTRAR_CONFIG_FECHA:
    ; Display 4 (PB3) - Decenas de día
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, dia_d
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB3
    CALL    RETARDO

    ; Display 3 (PB2) - Unidades de día
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, dia_u
    ADD     ZL, temp
    LPM     temp, Z
    ORI     temp, 0x80        ; Punto decimal para separador
    OUT     PORTD, temp
    SBI     PORTB, PB2
    CALL    RETARDO

    ; Display 2 (PB1) - Decenas de mes
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, mes_d
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB1
    CALL    RETARDO

    ; Display 1 (PB0) - Unidades de mes
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, mes_u
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB0
    CALL    RETARDO
    RET

MOSTRAR_CONFIG_ALARMA:
    ; Similar a mostrar hora pero mostrando la hora de la alarma
    ; Display 4 (PB3) - Decenas de horas de alarma
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, alarm_hr_d
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB3
    CALL    RETARDO

    ; Display 3 (PB2) - Unidades de horas de alarma
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, alarm_hr_u
    ADD     ZL, temp
    LPM     temp, Z
    SBRC    flags, 0
    ORI     temp, 0x80
    OUT     PORTD, temp
    SBI     PORTB, PB2
    CALL    RETARDO

    ; Display 2 (PB1) - Decenas de minutos de alarma
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, alarm_min_d
    ADD     ZL, temp
    LPM     temp, Z
    SBRC    flags, 0
    ORI     temp, 0x80
    OUT     PORTD, temp
    SBI     PORTB, PB1
    CALL    RETARDO

    ; Display 1 (PB0) - Unidades de minutos de alarma
    CALL    APAGAR_DISPLAYS
    LDI     ZL, LOW(DISPLAY*2)
    LDI     ZH, HIGH(DISPLAY*2)
    LDS     temp, alarm_min_u
    ADD     ZL, temp
    LPM     temp, Z
    OUT     PORTD, temp
    SBI     PORTB, PB0
    CALL    RETARDO
    RET

APAGAR_DISPLAYS:
    CBI     PORTB, PB0
    CBI     PORTB, PB1
    CBI     PORTB, PB2
    CBI     PORTB, PB3
    RET

RETARDO:
    PUSH    r17
    LDI     r17, 10
LOOP_RETARDO:
    DEC     r17
    BRNE    LOOP_RETARDO
    POP     r17
    RET

INCREMENTAR_TIEMPO:
    ; Incrementar segundos (no se muestran)
    LDS     temp, cont_sec
    INC     temp
    CPI     temp, 60
    
    BREQ    SEGUNDOS_60
    JMP     GUARDAR_SEC
    
SEGUNDOS_60:
    ; Si segundos llega a 60, reiniciar y incrementar minutos
    LDI     temp, 0
    STS     cont_sec, temp
    
    ; Incrementar unidades de minutos
    LDS     temp, cont_min_u
    INC     temp
    CPI     temp, 10
    BREQ    MINUTOS_U_10
    JMP     GUARDAR_MIN_U
    
MINUTOS_U_10:
    ; Si unidades de minutos llega a 10, reiniciar e incrementar decenas
    LDI     temp, 0
    STS     cont_min_u, temp
    
    ; Incrementar decenas de minutos
    LDS     temp, cont_min_d
    INC     temp
    CPI     temp, 6
    BREQ    MINUTOS_D_6
    JMP     GUARDAR_MIN_D
    
MINUTOS_D_6:
    ; Si decenas de minutos llega a 6, reiniciar e incrementar horas
    LDI     temp, 0
    STS     cont_min_d, temp
    
    ; Incrementar unidades de horas
    LDS     temp, cont_hr_u
    INC     temp
    
    ; Verificar si estamos en 24 horas (23:59 -> 00:00)
    LDS     temp2, cont_hr_d
    CPI     temp2, 2
    BRNE    CHECK_HR_U_NORMAL
    CPI     temp, 4
    BRNE    CHECK_HR_U_NORMAL
    
    ; Si llegamos a 24 horas, reiniciar a 00:00 e incrementar día
    LDI     temp, 0
    STS     cont_hr_u, temp
    LDI     temp, 0
    STS     cont_hr_d, temp
    
    ; Incrementar día
    PUSH    temp
    PUSH    temp2
    CALL    INCREMENTAR_DIA_AUTOMATICO
    POP     temp2
    POP     temp
    RET
    
CHECK_HR_U_NORMAL:
    ; Verificar si unidades de hora llega a 10
    CPI     temp, 10
    BREQ    HORAS_U_10
    JMP     GUARDAR_HR_U
    
HORAS_U_10:
    ; Si unidades de hora llega a 10, reiniciar e incrementar decenas
    LDI     temp, 0
    STS     cont_hr_u, temp
    
    ; Incrementar decenas de horas
    LDS     temp, cont_hr_d
    INC     temp
    STS     cont_hr_d, temp
    RET
    
GUARDAR_HR_U:
    STS     cont_hr_u, temp
    RET
    
GUARDAR_MIN_D:
    STS     cont_min_d, temp
    RET
    
GUARDAR_MIN_U:
    STS     cont_min_u, temp
    
    ; Verificar si la alarma está activa y si coincide con la hora actual
    SBRS    flags, 1          ; Si la alarma no está activa, saltar
    JMP     FIN_VERIFICAR_ALARMA
    
    ; Verificar si la alarma fue silenciada para este ciclo
    LDS     temp, alarm_silenced
    CPI     temp, 1
    BREQ    FIN_VERIFICAR_ALARMA  ; Si fue silenciada, no verificar
    
    ; Verificar si la hora actual coincide con la hora de la alarma
    CALL    VERIFICAR_ALARMA
    
FIN_VERIFICAR_ALARMA:
    RET
    
GUARDAR_SEC:
    STS     cont_sec, temp
    RET

; Función para activar/desactivar la alarma (botón PC3)
TOGGLE_ALARMA:
    PUSH    temp
    
    ; Verificar si estamos en modo configuración de alarma
    CPI     modo, 4
    BRNE    SOLO_DETENER_ALARMA
    
    ; En modo configuración de alarma, toggle bit de alarma activa (bit 1 de flags)
    LDI     temp, 0x02
    EOR     flags, temp
    
    ; Actualizar LED de alarma activa (PC5)
    SBRC    flags, 1
    SBI     PORTC, PC5       ; Encender LED si alarma activa
    SBRS    flags, 1
    CBI     PORTC, PC5       ; Apagar LED si alarma inactiva
    
    JMP     FIN_TOGGLE_ALARMA
    
SOLO_DETENER_ALARMA:
    ; En otros modos, detener la alarma si está sonando
    LDS     temp, alarm_timer
    CPI     temp, 0
    BREQ    FIN_TOGGLE_ALARMA  ; Si no está sonando, no hacer nada
    
    ; Detener alarma si está sonando
    LDI     temp, 0
    STS     alarm_timer, temp
    CBI     PORTC, PC5       ; Apagar LED de alarma
    
    ; Marcar la alarma como silenciada para este ciclo
    LDI     temp, 1
    STS     alarm_silenced, temp
    
FIN_TOGGLE_ALARMA:
    POP     temp
    RET

; Función para verificar si la hora actual coincide con la hora de la alarma
VERIFICAR_ALARMA:
    PUSH    temp
    PUSH    temp2
    
    ; Verificar si la alarma está activa
    SBRS    flags, 1          ; Si la alarma no está activa, saltar
    JMP     NO_COINCIDE_ALARMA
    
    ; Verificar si la alarma fue silenciada para este ciclo
    LDS     temp, alarm_silenced
    CPI     temp, 1
    BREQ    NO_COINCIDE_ALARMA  ; Si fue silenciada, no activar
    
    ; Verificar horas
    LDS     temp, cont_hr_d
    LDS     temp2, alarm_hr_d
    CP      temp, temp2
    BRNE    NO_COINCIDE_ALARMA
    
    LDS     temp, cont_hr_u
    LDS     temp2, alarm_hr_u
    CP      temp, temp2
    BRNE    NO_COINCIDE_ALARMA
    
    ; Verificar minutos
    LDS     temp, cont_min_d
    LDS     temp2, alarm_min_d
    CP      temp, temp2
    BRNE    NO_COINCIDE_ALARMA
    
    LDS     temp, cont_min_u
    LDS     temp2, alarm_min_u
    CP      temp, temp2
    BRNE    NO_COINCIDE_ALARMA
    
    ; Si llegamos aquí, la hora coincide con la alarma
    ; Activar contador de alarma solo si no está ya activado
    LDS     temp, alarm_timer
    CPI     temp, 0
    BRNE    NO_COINCIDE_ALARMA  ; Si ya está sonando, no hacer nada
    
    ; Activar la alarma
    LDI     temp, 1
    STS     alarm_timer, temp
    
    ; Encender el LED de alarma sonando inmediatamente
    SBI     PORTC, PC5
    
    POP     temp2
    POP     temp
    RET
    
NO_COINCIDE_ALARMA:
    POP     temp2
    POP     temp
    RET

; Función para incrementar horas (para botón PC1)
INCREMENTAR_HORAS:
    ; Verificar si estamos en modo configuración de alarma
    CPI     modo, 4
    BRNE    INCREMENTAR_HORAS_NORMAL
    
    ; Incrementar horas de alarma
    LDS     temp, alarm_hr_u
    INC     temp
    
    ; Verificar si estamos en 24 horas (23:59 -> 00:00)
    LDS     temp2, alarm_hr_d
    CPI     temp2, 2
    BRNE    INC_ALARM_HR_CHECK_U
    CPI     temp, 4
    BRNE    INC_ALARM_HR_CHECK_U
    
    ; Si llegamos a 24 horas, reiniciar a 00:00
    LDI     temp, 0
    STS     alarm_hr_u, temp
    LDI     temp, 0
    STS     alarm_hr_d, temp
    RET
    
INC_ALARM_HR_CHECK_U:
    ; Verificar si unidades de hora llega a 10
    CPI     temp, 10
    BREQ    INC_ALARM_HR_U_10
    JMP     INC_ALARM_HR_SAVE_U
    
INC_ALARM_HR_U_10:
    ; Si unidades de hora llega a 10, reiniciar e incrementar decenas
    LDI     temp, 0
    STS     alarm_hr_u, temp
    
    ; Incrementar decenas de horas
    LDS     temp, alarm_hr_d
    INC     temp
    STS     alarm_hr_d, temp
    RET
    
INC_ALARM_HR_SAVE_U:
    STS     alarm_hr_u, temp
    RET
    
INCREMENTAR_HORAS_NORMAL:
    ; Incrementar unidades de horas
    LDS     temp, cont_hr_u
    INC     temp
    
    ; Verificar si estamos en 24 horas (23:59 -> 00:00)
    LDS     temp2, cont_hr_d
    CPI     temp2, 2
    BRNE    INC_HR_CHECK_U
    CPI     temp, 4
    BRNE    INC_HR_CHECK_U
    
    ; Si llegamos a 24 horas, reiniciar a 00:00
    LDI     temp, 0
    STS     cont_hr_u, temp
    LDI     temp, 0
    STS     cont_hr_d, temp
    RET
    
INC_HR_CHECK_U:
    ; Verificar si unidades de hora llega a 10
    CPI     temp, 10
    BREQ    INC_HR_U_10
    JMP     INC_HR_SAVE_U
    
INC_HR_U_10:
    ; Si unidades de hora llega a 10, reiniciar e incrementar decenas
    LDI     temp, 0
    STS     cont_hr_u, temp
    
    ; Incrementar decenas de horas
    LDS     temp, cont_hr_d
    INC     temp
    STS     cont_hr_d, temp
    RET
    
INC_HR_SAVE_U:
    STS     cont_hr_u, temp
    RET

; Función para incrementar minutos (para botón PC2)
INCREMENTAR_MINUTOS:
    ; Verificar si estamos en modo configuración de alarma
    CPI     modo, 4
    BRNE    INCREMENTAR_MINUTOS_NORMAL
    
    ; Incrementar minutos de alarma
    LDS     temp, alarm_min_u
    INC     temp
    CPI     temp, 10
    BREQ    INC_ALARM_MIN_U_10
    JMP     INC_ALARM_MIN_SAVE_U
    
INC_ALARM_MIN_U_10:
    ; Si unidades de minutos llega a 10, reiniciar e incrementar decenas
    LDI     temp, 0
    STS     alarm_min_u, temp
    
    ; Incrementar decenas de minutos
    LDS     temp, alarm_min_d
    INC     temp
    CPI     temp, 6
    BREQ    INC_ALARM_MIN_D_6
    JMP     INC_ALARM_MIN_SAVE_D
    
INC_ALARM_MIN_D_6:
    ; Si decenas de minutos llega a 6, reiniciar
    LDI     temp, 0
    
INC_ALARM_MIN_SAVE_D:
    STS     alarm_min_d, temp
    RET
    
INC_ALARM_MIN_SAVE_U:
    STS     alarm_min_u, temp
    RET
    
INCREMENTAR_MINUTOS_NORMAL:
    ; Incrementar unidades de minutos
    LDS     temp, cont_min_u
    INC     temp
    CPI     temp, 10
    BREQ    INC_MIN_U_10
    JMP     INC_MIN_SAVE_U
    
INC_MIN_U_10:
    ; Si unidades de minutos llega a 10, reiniciar e incrementar decenas
    LDI     temp, 0
    STS     cont_min_u, temp
    
    ; Incrementar decenas de minutos
    LDS     temp, cont_min_d
    INC     temp
    CPI     temp, 6
    BREQ    INC_MIN_D_6
    JMP     INC_MIN_SAVE_D
    
INC_MIN_D_6:
    ; Si decenas de minutos llega a 6, reiniciar
    LDI     temp, 0
    
INC_MIN_SAVE_D:
    STS     cont_min_d, temp
    RET
    
INC_MIN_SAVE_U:
    STS     cont_min_u, temp
    RET

; Función para incrementar el día automáticamente (cuando cambia de 23:59 a 00:00)
INCREMENTAR_DIA_AUTOMATICO:
    PUSH    temp
    PUSH    temp2
    
    ; Obtener días máximos del mes actual
    CALL    OBTENER_DIAS_MES
    MOV     temp2, temp         ; temp2 = días máximos
    
    ; Calcular el día actual (decenas*10 + unidades)
    LDS     temp, dia_d
    LDI     r17, 10
    MUL     temp, r17
    MOV     temp, r0
    
    ; Añadir unidades
    LDS     r17, dia_u
    ADD     temp, r17        ; temp = día completo
    
    ; Incrementar día
    INC     temp
    
    ; Verificar si hemos superado el máximo de días del mes
    CP      temp, temp2
    BRLO    NO_CAMBIO_MES     ; Si es menor, no hay cambio de mes
    
    ; Si hemos superado el máximo, reiniciar a día 1 e incrementar mes
    LDI     temp, 1
    STS     dia_u, temp
    LDI     temp, 0
    STS     dia_d, temp
    
    ; Incrementar mes
    CALL    INCREMENTAR_MES_AUTOMATICO
    
    POP     temp2
    POP     temp
    RET
    
NO_CAMBIO_MES:
    ; Si no hemos superado el máximo, actualizar día normalmente
    LDI     temp2, 10
    CALL    DIV               ; temp = decenas, r0 = unidades
    STS     dia_d, temp
    MOV     temp, r0
    STS     dia_u, temp
    
    POP     temp2
    POP     temp
    RET

; Función para incrementar el mes automáticamente
INCREMENTAR_MES_AUTOMATICO:
    PUSH    temp
    PUSH    r17
    
    ; Incrementar unidades de mes
    LDS     temp, mes_u
    INC     temp
    
    ; Verificar si llegamos a mes 13
    LDS     r17, mes_d
    CPI     r17, 1
    BRNE    CHECK_MES_U_AUTO
    CPI     temp, 3
    BRNE    CHECK_MES_U_AUTO
    
    ; Si llegamos a mes 13, reiniciar a mes 1
    LDI     temp, 1
    STS     mes_u, temp
    LDI     temp, 0
    STS     mes_d, temp
    
    ; Verificar si el día actual es válido para el nuevo mes
    CALL    VALIDAR_DIA_ACTUAL
    
    POP     r17
    POP     temp
    RET
    
CHECK_MES_U_AUTO:
    ; Verificar si unidades de mes llega a 10
    CPI     temp, 10
    BREQ    MES_U_AUTO_10
    JMP     SAVE_MES_U_AUTO
    
MES_U_AUTO_10:
    ; Si unidades de mes llega a 10, reiniciar e incrementar decenas
    LDI     temp, 0
    STS     mes_u, temp
    
    ; Incrementar decenas de mes
    LDS     temp, mes_d
    INC     temp
    STS     mes_d, temp
    
    ; Verificar si el día actual es válido para el nuevo mes
    CALL    VALIDAR_DIA_ACTUAL
    
    POP     r17
    POP     temp
    RET
    
SAVE_MES_U_AUTO:
    STS     mes_u, temp
    
    ; Verificar si el día actual es válido para el nuevo mes
    CALL    VALIDAR_DIA_ACTUAL
    
    POP     r17
    POP     temp
    RET

; Función para obtener el número máximo de días para el mes actual
OBTENER_DIAS_MES:
    PUSH    r17
    PUSH    r18
    
    ; Calcular el mes actual (decenas*10 + unidades)
    LDS     r17, mes_d
    LDI     r18, 10
    MUL     r17, r18
    MOV     temp, r0
    
    ; Añadir unidades
    LDS     r17, mes_u
    ADD     temp, r17         ; temp = mes completo
    
    ; Verificar el mes y asignar días
    CPI     temp, 2           ; Febrero
    BRNE    CHECK_MES_30
    LDI     temp, 28          ; Febrero tiene 28 días (no consideramos años bisiestos)
    JMP     FIN_OBTENER_DIAS
    
CHECK_MES_30:
    CPI     temp, 4           ; Abril
    BREQ    MES_30
    CPI     temp, 6           ; Junio
    BREQ    MES_30
    CPI     temp, 9           ; Septiembre
    BREQ    MES_30
    CPI     temp, 11          ; Noviembre
    BREQ    MES_30
    
    ; Si no es mes de 30 días, asumimos 31 días
    LDI     temp, 31
    JMP     FIN_OBTENER_DIAS
    
MES_30:
    LDI     temp, 30
    
FIN_OBTENER_DIAS:
    POP     r18
    POP     r17
    RET

; Función para validar que el día actual sea válido para el mes actual
VALIDAR_DIA_ACTUAL:
    PUSH    r17
    PUSH    r18
    PUSH    temp2
    
    ; Obtener días máximos del mes actual
    CALL    OBTENER_DIAS_MES
    MOV     r17, temp         ; r17 = días máximos
    
    ; Calcular el día actual (decenas*10 + unidades)
    LDS     r18, dia_d
    LDI     temp, 10
    MUL     r18, temp
    MOV     temp, r0
    
    ; Añadir unidades
    LDS     r18, dia_u
    ADD     temp, r18         ; temp = día completo
    
    ; Si el día actual es mayor que el máximo, ajustar al máximo
    CP      temp, r17
    BRLO    DIA_VALIDO
    
    ; Ajustar al último día del mes
    MOV     temp, r17
    
    ; Calcular decenas y unidades
    LDI     temp2, 10
    CALL    DIV               ; temp = decenas, r0 = unidades
    STS     dia_d, temp
    MOV     temp, r0
    STS     dia_u, temp
    
DIA_VALIDO:
    POP     temp2
    POP     r18
    POP     r17
    RET

; Función auxiliar para división
DIV:
    ; Divide temp entre temp2, resultado en temp, resto en r0
    PUSH    r17
    CLR     r17        ; r17 será nuestro contador (cociente)
    
DIV_LOOP:
    CP      temp, temp2
    BRLO    DIV_END    ; Si temp < temp2, terminamos
    SUB     temp, temp2 ; temp = temp - temp2
    INC     r17        ; Incrementar cociente
    JMP     DIV_LOOP
    
DIV_END:
    MOV     r0, temp   ; Guardar resto en r0
    MOV     temp, r17  ; Poner cociente en temp
    POP     r17
    RET

BOTON_HORAS:
    ; Verificar en qué modo estamos
    CPI     modo, 2
    BRNE    CHECK_MODO_FECHA_DIAS
    
    ; Modo configuración hora: incrementar horas
    CALL    INCREMENTAR_HORAS
    RET
    
CHECK_MODO_FECHA_DIAS:
    CPI     modo, 3
    BRNE    CHECK_MODO_ALARMA_HORAS
    
    ; Modo configuración fecha: incrementar días
    PUSH    temp
    PUSH    temp2
    
    ; Obtener días máximos del mes actual
    CALL    OBTENER_DIAS_MES
    MOV     temp2, temp         ; temp2 = días máximos
    
    ; Calcular el día actual (decenas*10 + unidades)
    LDS     temp, dia_d
    LDI     r17, 10
    MUL     temp, r17
    MOV     temp, r0
    
    ; Añadir unidades
    LDS     r17, dia_u
    ADD     temp, r17        ; temp = día completo
    
    ; Incrementar día
    INC     temp
    
    ; Verificar si hemos superado el máximo de días del mes
    CP      temp, temp2
    BRLO    NO_OVERFLOW_DIA   ; Si es menor, no hay overflow
    
    ; Si hemos superado el máximo, reiniciar a día 1
    LDI     temp, 1
    STS     dia_u, temp
    LDI     temp, 0
    STS     dia_d, temp
    
    POP     temp2
    POP     temp
    RET
    
NO_OVERFLOW_DIA:
    ; Si no hemos superado el máximo, actualizar día normalmente
    LDI     temp2, 10
    CALL    DIV               ; temp = decenas, r0 = unidades
    STS     dia_d, temp
    MOV     temp, r0
    STS     dia_u, temp
    
    POP     temp2
    POP     temp
    RET
    
CHECK_MODO_ALARMA_HORAS:
    CPI     modo, 4
    BRNE    FIN_BOTON_HORAS
    
    ; Modo configuración alarma: incrementar horas de alarma
    CALL    INCREMENTAR_HORAS
    
FIN_BOTON_HORAS:
    RET

BOTON_MINUTOS:
    ; Incrementar minutos si estamos en modo configuración de hora
    CPI     modo, 2
    BRNE    CHECK_CONFIG_FECHA_MESES
    CALL    INCREMENTAR_MINUTOS
    RET
    
CHECK_CONFIG_FECHA_MESES:
    ; Incrementar meses si estamos en modo configuración de fecha
    CPI     modo, 3
    BRNE    CHECK_CONFIG_ALARMA_MINUTOS
    CALL    INCREMENTAR_MESES
    RET
    
CHECK_CONFIG_ALARMA_MINUTOS:
    ; Incrementar minutos si estamos en modo configuración de alarma
    CPI     modo, 4
    BRNE    FIN_BOTON_MINUTOS
    CALL    INCREMENTAR_MINUTOS
    
FIN_BOTON_MINUTOS:
    RET

; Función para incrementar meses
INCREMENTAR_MESES:
    PUSH    temp
    PUSH    r17
    
    ; Incrementar unidades de mes
    LDS     temp, mes_u
    INC     temp
    
    ; Verificar si llegamos a mes 13
    LDS     r17, mes_d
    CPI     r17, 1
    BRNE    CHECK_MES_U
    CPI     temp, 3
    BRNE    CHECK_MES_U
    
    ; Si llegamos a mes 13, reiniciar a mes 1
    LDI     temp, 1
    STS     mes_u, temp
    LDI     temp, 0
    STS     mes_d, temp
    
    ; Verificar si el día actual es válido para el nuevo mes
    CALL    VALIDAR_DIA_ACTUAL
    
    POP     r17
    POP     temp
    RET
    
CHECK_MES_U:
    ; Verificar si unidades de mes llega a 10
    CPI     temp, 10
    BREQ    MES_U_10
    JMP     SAVE_MES_U
    
MES_U_10:
    ; Si unidades de mes llega a 10, reiniciar e incrementar decenas
    LDI     temp, 0
    STS     mes_u, temp
    
    ; Incrementar decenas de mes
    LDS     temp, mes_d
    INC     temp
    STS     mes_d, temp
    
    ; Verificar si el día actual es válido para el nuevo mes
    CALL    VALIDAR_DIA_ACTUAL
    
    POP     r17
    POP     temp
    RET
    
SAVE_MES_U:
    STS     mes_u, temp
    
    ; Verificar si el día actual es válido para el nuevo mes
    CALL    VALIDAR_DIA_ACTUAL
    
    POP     r17
    POP     temp
    RET

TMR0_ISR:
    PUSH    temp
    IN      temp, SREG
    PUSH    temp
    PUSH    temp2

    LDI     temp, 0              ; Recargar timer
    OUT     TCNT0, temp
    
    ; Incrementar contador LED
    LDS     temp, led_timer
    INC     temp
    STS     led_timer, temp
    CPI     temp, 30             ; Ajusta este valor para cambiar la velocidad del parpadeo
    BRNE    SKIP_LED
    
    ; Reset contador LED
    LDI     temp, 0
    STS     led_timer, temp
    
    ; Toggle flag de parpadeo para los dos puntos
    LDI     temp, 0x01
    EOR     flags, temp
    
    ; Parpadeo de LEDs según el modo
    CPI     modo, 2              ; Modo configuración hora
    BRNE    CHECK_LED_MODO_3
    
    ; Parpadear PB4 en modo config hora
    IN      temp, PORTB
    LDI     temp2, (1<<PB4)
    EOR     temp, temp2
    OUT     PORTB, temp
    JMP     SKIP_LED
    
CHECK_LED_MODO_3:
    CPI     modo, 3              ; Modo configuración fecha
    BRNE    CHECK_LED_MODO_4
    
    ; Parpadear PB5 en modo config fecha
    IN      temp, PORTB
    LDI     temp2, (1<<PB5)
    EOR     temp, temp2
    OUT     PORTB, temp
    JMP     SKIP_LED
    
CHECK_LED_MODO_4:
    CPI     modo, 4              ; Modo configuración alarma
    BRNE    SKIP_LED
    
    ; Parpadear ambos LEDs en modo config alarma
    IN      temp, PORTB
    LDI     temp2, (1<<PB4)|(1<<PB5)
    EOR     temp, temp2
    OUT     PORTB, temp
    
SKIP_LED:
    ; Verificar si la alarma está activa y sonando
    LDS     temp, alarm_timer
    CPI     temp, 0
    BREQ    SKIP_ALARM_CHECK
    
    ; Incrementar contador de parpadeo de alarma
    LDS     temp, alarm_blink
    INC     temp
    STS     alarm_blink, temp
    
    ; Parpadear LED de alarma sonando cada 15 ciclos (aproximadamente 500ms)
    CPI     temp, 15
    BRNE    CHECK_ALARM_TIMEOUT
    
    ; Reset contador de parpadeo
    LDI     temp, 0
    STS     alarm_blink, temp
    
    ; Toggle LED de alarma sonando (PC5)
    IN      temp, PORTC
    LDI     temp2, (1<<PC5)
    EOR     temp, temp2
    OUT     PORTC, temp
    
CHECK_ALARM_TIMEOUT:
    ; Verificar si ha pasado un minuto desde que se activó la alarma
    LDS     temp, contador
    CPI     temp, 60            ; Aproximadamente 1 segundo
    BRNE    SKIP_ALARM_CHECK
    
    ; Incrementar contador de alarma
    LDS     temp, alarm_timer
    INC     temp
    STS     alarm_timer, temp
    
    ; Si han pasado 60 segundos (1 minuto), apagar la alarma
    CPI     temp, 59
    BRNE    SKIP_ALARM_CHECK
    
    ; Apagar alarma después de 1 minuto
    CBI     PORTC, PC5
    LDI     temp, 0
    STS     alarm_timer, temp
    STS     alarm_blink, temp
    
    ; Marcar la alarma como silenciada para este ciclo
    LDI     temp, 1
    STS     alarm_silenced, temp
    
SKIP_ALARM_CHECK:
    ; Incrementar contador principal
    LDS     temp, contador
    INC     temp
    STS     contador, temp
    CPI     temp, 60             ; Aproximadamente 1 segundo
    BRNE    FIN_ISR
    
    LDI     temp, 0
    STS     contador, temp
    
    ; Solo incrementar tiempo si no estamos en modo configuración
    CPI     modo, 2
    BREQ    FIN_ISR
    CPI     modo, 3
    BREQ    FIN_ISR
    CPI     modo, 4
    BREQ    FIN_ISR
    
    ; Incrementar tiempo
    CALL    INCREMENTAR_TIEMPO
    
    ; Verificar alarma cada segundo (solo si no estamos en modo configuración)
    SBRS    flags, 1          ; Si la alarma no está activa, saltar
    JMP     FIN_ISR
    
    ; Verificar si la alarma fue silenciada para este ciclo
    LDS     temp, alarm_silenced
    CPI     temp, 1
    BREQ    FIN_ISR  ; Si fue silenciada, no verificar
    
    CALL    VERIFICAR_ALARMA
    
FIN_ISR:
    POP     temp2
    POP     temp
    OUT     SREG, temp
    POP     temp
    RETI

PCINT1_ISR:
    PUSH    temp
    IN      temp, SREG
    PUSH    temp
    
    ; Retardo anti-rebote
    CALL    RETARDO_ANTI_REBOTE
    
    ; Verificar botón PC0 (cambio de modo)
    SBIC    PINC, PC0        ; Si el botón está presionado (0)
    JMP     CHECK_PC1        ; Si no está presionado, verificar siguiente botón
    
    ; Cambiar modo
    INC     modo
    CPI     modo, 5
    BRNE    ACTUALIZAR_MODO_ISR
    CLR     modo
    
ACTUALIZAR_MODO_ISR:
    CALL    ACTUALIZAR_MODO
    JMP     FIN_PCINT1_ISR
    
CHECK_PC1:
    ; Verificar botón PC1 (horas/días)
    SBIC    PINC, PC1        ; Si el botón está presionado (0)
    JMP     CHECK_PC2        ; Si no está presionado, verificar siguiente botón
    
    ; Acción según modo
    CALL    BOTON_HORAS
    JMP     FIN_PCINT1_ISR
    
CHECK_PC2:
    ; Verificar botón PC2 (minutos/meses)
    SBIC    PINC, PC2        ; Si el botón está presionado (0)
    JMP     CHECK_PC3        ; Si no está presionado, verificar siguiente botón
    
    ; Acción según modo
    CALL    BOTON_MINUTOS
    JMP     FIN_PCINT1_ISR
    
CHECK_PC3:
    ; Verificar botón PC3 (activar/desactivar alarma)
    SBIC    PINC, PC3        ; Si el botón está presionado (0)
    JMP     FIN_PCINT1_ISR   ; Si no está presionado, salir
    
    ; Activar/desactivar alarma
    CALL    TOGGLE_ALARMA
    
FIN_PCINT1_ISR:
    POP     temp
    OUT     SREG, temp
    POP     temp
    RETI

RETARDO_ANTI_REBOTE:
    PUSH    r17
    PUSH    r18
    
    LDI     r17, 200
LOOP_ANTI_REBOTE_1:
    LDI     r18, 255
LOOP_ANTI_REBOTE_2:
    DEC     r18
    BRNE    LOOP_ANTI_REBOTE_2
    DEC     r17
    BRNE    LOOP_ANTI_REBOTE_1
    
    POP     r18
    POP     r17
    RET

ACTUALIZAR_MODO:
    ; Actualizar LEDs de modo
    CALL    ACTUALIZAR_LEDS_MODO
    
    ; Si cambiamos de modo, actualizar LED de alarma (PC5)
    CPI     modo, 4
    BRNE    MODO_NO_ALARMA
    
    ; En modo alarma, mostrar estado actual de la alarma en PC5
    SBRC    flags, 1
    SBI     PORTC, PC5       ; Encender LED si alarma activa
    SBRS    flags, 1
    CBI     PORTC, PC5       ; Apagar LED si alarma inactiva
    JMP     FIN_ACTUALIZAR_MODO
    
MODO_NO_ALARMA:
    ; En otros modos, apagar LED de alarma (a menos que esté sonando)
    LDS     temp, alarm_timer
    CPI     temp, 0
    BRNE    FIN_ACTUALIZAR_MODO  ; Si la alarma está sonando, no apagar el LED
    
    ; Si la alarma no está sonando, apagar el LED
    CBI     PORTC, PC5
    
FIN_ACTUALIZAR_MODO:
    ; Si estamos en modo fecha, mantener punto decimal encendido
    CPI     modo, 1
    BRNE    FIN_CAMBIAR_MODO
    SBI     PORTD, PD7
    
FIN_CAMBIAR_MODO:
    RET