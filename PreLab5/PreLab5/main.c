/*
* PreLab5.c
*
* Author:  JOSÉ GORDILLO
* Created: 05/04/2025
*/

// Encabezado (Libraries)
#define F_CPU 16000000
#include <avr/io.h>
#include "ServoControl/ServoControl.h"

float adcValue = 0;
void ADC_init(void);
uint16_t adcRead(uint8_t);

int main(void)
{
	// Inicializar PWM para servo
	PWM_init();
	
	// Inicializar ADC
	ADC_init();
	
	while (1)
	{
		// Leer valor del potenciómetro en canal 6 (A6)
		adcValue = adcRead(6);
		
		// Controlar posición del servo
		servo_writeA(adcValue);
		
		// Pequeña pausa para estabilidad
		for(volatile uint16_t i=0; i<1000; i++);
	}
}

void ADC_init(void){
	ADMUX |= (1<<REFS0);    // VCC como referencia
	ADMUX &= ~(1<<REFS1);
	ADMUX &= ~(1<<ADLAR);   // Resultado de 10 bits (alineado a la derecha)
	
	// Prescaler 128 > 16MHz/128 = 125KHz
	ADCSRA |= (1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0);
	ADCSRA |= (1<<ADEN);    // Habilitar ADC
}

uint16_t adcRead(uint8_t canal){
	ADMUX = (ADMUX & 0xF0)|canal;    // Selección de canal
	ADCSRA |= (1<<ADSC);    // Iniciar conversión
	while((ADCSRA)&(1<<ADSC));    // Esperar hasta finalizar conversión
	return(ADC);
}