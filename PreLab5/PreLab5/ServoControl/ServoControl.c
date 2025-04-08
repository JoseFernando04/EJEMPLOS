#include "ServoControl.h"

void PWM_init(void){
	// Configurar PB1 como salida
	DDRB |= (1 << PB1);
	
	TCNT1 = 0;     // Reiniciar contador
	ICR1 = 39999;  // Valor TOP para periodo de 20ms (16MHz/8/50Hz)
	
	// Configurar modo Fast PWM con TOP=ICR1
	TCCR1A = (1 << COM1A1) | (0 << COM1A0);  // Modo no invertido en OC1A
	TCCR1A |= (1 << WGM11) | (0 << WGM10);   // Fast PWM con TOP=ICR1
	TCCR1B = (1 << WGM13) | (1 << WGM12);    // Fast PWM con TOP=ICR1
	TCCR1B |= (0 << CS12) | (1 << CS11) | (0 << CS10);  // Prescaler 8
}

void servo_writeA(float adc_Value){
	// Mapear valor ADC (0-1023) a ancho de pulso para servo (1000-4800)
	// 1000 = 0.5ms (0°), 4800 = 2.4ms (180°)
	OCR1A = map(adc_Value, 0, 1023, 1000, 4800);
}

float map(float x, float in_min, float in_max, float out_min, float out_max){
	return ((x - in_min)*(out_max - out_min)/(in_max - in_min)) + out_min;
}