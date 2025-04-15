/*
 * POSTLAB 5.c
 *
 * Created: 08/04/2025
 * Author : JOSÉ GORDILLO
 */ 

// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>
#include "pwm_manual/pwm_manual.h"

// Variables globales
volatile uint16_t adc_values[3] = {0, 0, 0}; // Almacena valores ADC para 3 canales
volatile uint8_t current_channel = 0;

void setup() {
    // 1. Inicializar control de servos y LED
    pwm_manual_init();
    
    // 2. Configurar ADC con autoscan de 3 canales (A5, A6, A7)
    ADMUX = (1 << REFS0); // AVcc como referencia
    ADCSRA = (1 << ADEN) | (1 << ADIE) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);
    ADCSRB = 0; // Modo libre
    
    // Iniciar primera conversión ADC en canal A5
    ADMUX = (1 << REFS0) | (1 << MUX2) | (1 << MUX0); // Canal A5 (101)
    ADCSRA |= (1 << ADSC);
    
    // Habilitar interrupciones globales
    sei();
}

int main(void) {
    setup();
    
    while (1) {
        // Actualizar efectos de LED y servos
        pwm_manual_update();
    }
}

// Interrupción ADC para lectura de potenciómetros
ISR(ADC_vect) {
    // Guardar valor del canal actual
    adc_values[current_channel] = ADC;
    
    // Cambiar al siguiente canal (0:A5, 1:A6, 2:A7)
    current_channel = (current_channel + 1) % 3;
    
    // Configurar próximo canal
    switch (current_channel) {
        case 0: // A5 (101)
            ADMUX = (1 << REFS0) | (1 << MUX2) | (1 << MUX0);
            break;
        case 1: // A6 (110)
            ADMUX = (1 << REFS0) | (1 << MUX2) | (1 << MUX1);
            break;
        case 2: // A7 (111)
            ADMUX = (1 << REFS0) | (1 << MUX2) | (1 << MUX1) | (1 << MUX0);
            break;
    }
    
    // Actualizar posiciones de los servos y LED
    // Cada valor ADC controla solo su dispositivo correspondiente
    pwm_manual_set_led(adc_values[0]);     // A5 controla LED
    pwm_manual_set_servo1(adc_values[1]);  // A6 controla Servo1
    pwm_manual_set_servo2(adc_values[2]);  // A7 controla Servo2
    
    // Iniciar nueva conversión
    ADCSRA |= (1 << ADSC);
}