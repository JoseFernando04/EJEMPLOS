/*
 * LAB 5.c - Modificado para controlar solo 2 servos
 *
 * Created: 08/04/2025
 * Author : JOSÉ GORDILLO
 */ 

#include <avr/io.h>
#include <avr/interrupt.h>
#include "pwm_manual/pwm_manual.h"

// Variables globales
volatile uint16_t adc_values[2]; // Almacena valores ADC para 2 canales
volatile uint8_t current_channel = 0;

void setup() {
    // 1. Inicializar control de servos
    pwm_manual_init();
    
    // 2. Configurar ADC con autoscan de 2 canales (A6, A7)
    ADMUX = (1 << REFS0); // AVcc como referencia
    ADCSRA = (1 << ADEN) | (1 << ADIE) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
    ADCSRB = 0; // Modo libre
    
    // Iniciar primera conversión ADC en canal A6
    ADMUX = (1 << REFS0) | (1 << MUX2) | (1 << MUX1); // Canal A6 (110)
    ADCSRA |= (1 << ADSC);
    
    // Habilitar interrupciones globales
    sei();
}

int main(void) {
    setup();
    
    while (1) {
        // Actualizar servos (si se implementa alguna lógica adicional)
        pwm_manual_update();
    }
}

// Interrupción ADC para lectura de potenciómetros
ISR(ADC_vect) {
    // Guardar valor del canal actual
    adc_values[current_channel] = ADC;
    
    // Cambiar al siguiente canal (0:A6, 1:A7)
    current_channel = (current_channel + 1) % 2;
    
    // Configurar próximo canal
    if (current_channel == 0) {
        // Configurar para A6 (110)
        ADMUX = (1 << REFS0) | (1 << MUX2) | (1 << MUX1);
    } else {
        // Configurar para A7 (111)
        ADMUX = (1 << REFS0) | (1 << MUX2) | (1 << MUX1) | (1 << MUX0);
    }
    
    // Actualizar posiciones de los servos
    pwm_manual_set_servo1(adc_values[0]);
    pwm_manual_set_servo2(adc_values[1]);
    
    // Iniciar nueva conversión
    ADCSRA |= (1 << ADSC);
}