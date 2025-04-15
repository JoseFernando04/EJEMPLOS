#include "pwm_manual.h"

// Límites para los servos (en ticks)
#define SERVO_MIN 2000    // 1ms - 0 grados
#define SERVO_MAX 5250    // 2.6ms - 180 grados

void pwm_manual_init(void) {
	// Configurar pines de servos como salidas (PB1 y PB2)
	DDRB |= (1 << PB1) | (1 << PB2);
	
	// Configurar Timer1 para PWM modo 14 (ICR1 como TOP)
	TCCR1A = (1 << COM1A1) | (1 << COM1B1) | (1 << WGM11);
	TCCR1B = (1 << WGM13) | (1 << WGM12) | (1 << CS11); // Prescaler 8
	
	// Periodo PWM 20ms (50Hz) para servos
	ICR1 = 39999; // (16MHz/8)/50Hz - 1
	
	// Valores iniciales servos (posición central)
	OCR1A = 3000; // Servo1 en PB1
	OCR1B = 3000; // Servo2 en PB2
}

void pwm_manual_set_servo1(uint16_t position) {
	// Convertir posición (0-1023) a ancho de pulso (SERVO_MIN-SERVO_MAX)
	uint16_t pulse_width = SERVO_MIN + ((uint32_t)position * (SERVO_MAX - SERVO_MIN) / 1023);
	
	// Limitar valores para proteger el servo
	if (pulse_width < SERVO_MIN) pulse_width = SERVO_MIN;
	if (pulse_width > SERVO_MAX) pulse_width = SERVO_MAX;
	
	// Actualizar registro de comparación
	OCR1A = pulse_width;
}

void pwm_manual_set_servo2(uint16_t position) {
	// Convertir posición (0-1023) a ancho de pulso (SERVO_MIN-SERVO_MAX)
	uint16_t pulse_width = SERVO_MIN + ((uint32_t)position * (SERVO_MAX - SERVO_MIN) / 1023);
	
	// Limitar valores para proteger el servo
	if (pulse_width < SERVO_MIN) pulse_width = SERVO_MIN;
	if (pulse_width > SERVO_MAX) pulse_width = SERVO_MAX;
	
	// Actualizar registro de comparación
	OCR1B = pulse_width;
}

void pwm_manual_update(void) {
	// Esta función se deja vacía por ahora
	// Podría implementarse para suavizado de movimiento u otras funcionalidades
}