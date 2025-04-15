#include "pwm_manual.h"

// Límites para los servos (en ticks)
#define SERVO_MIN 2000    // 1ms - 0 grados
#define SERVO_MAX 5250    // 2.6ms - 180 grados

// Variables para control del LED
#define LED_PIN PD6       // LED en pin 6 (PD6)
static volatile uint8_t led_brightness = 0;
static volatile uint8_t led_effect_mode = 0;
static volatile uint16_t effect_counter = 0;

void pwm_manual_init(void) {
	// 1. Configurar pines de servos como salidas (PB1 y PB2)
	DDRB |= (1 << PB1) | (1 << PB2);
	
	// 2. Configurar pin del LED como salida (PD6)
	DDRD |= (1 << LED_PIN);
	
	// 3. Configurar Timer1 para PWM de servos (modo 14, ICR1 como TOP)
	TCCR1A = (1 << COM1A1) | (1 << COM1B1) | (1 << WGM11);
	TCCR1B = (1 << WGM13) | (1 << WGM12) | (1 << CS11); // Prescaler 8
	
	// Periodo PWM 20ms (50Hz) para servos
	ICR1 = 39999; // (16MHz/8)/50Hz - 1
	
	// Valores iniciales servos (posición central)
	OCR1A = 3000; // Servo1 en PB1
	OCR1B = 3000; // Servo2 en PB2
	
	// 4. Configurar Timer0 para PWM del LED
	TCCR0A = 0;  // Modo normal
	TCCR0B = (1 << CS01) | (1 << CS00);  // Prescaler 64
	TIMSK0 = (1 << TOIE0);  // Habilitar interrupción de overflow
}

void pwm_manual_set_led(uint16_t brightness) {
	// Dividir el valor ADC (0-1023) en dos partes:
	// - Modo de efecto (2 bits más significativos)
	// - Brillo (8 bits menos significativos)
	led_effect_mode = brightness >> 8;  // Obtener bits 8-9 (0-3)
	led_brightness = (brightness & 0xFF);  // Obtener bits 0-7 (0-255)
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

// Implementación de PWM por software para el LED
void pwm_manual_update(void) {
	static uint8_t pwm_counter = 0;
	static uint8_t current_led_value = 0;
	
	// Incrementar contador PWM
	pwm_counter++;
	
	// Calcular valor actual del LED según el modo de efecto
	switch (led_effect_mode) {
		case 0:  // Brillo estático
		current_led_value = led_brightness;
		break;
		
		case 1:  // Efecto de respiración
		// Usar contador de efectos para crear un patrón de respiración
		if (effect_counter < 128) {
			current_led_value = (effect_counter * led_brightness) >> 7;
			} else {
			current_led_value = ((255 - effect_counter) * led_brightness) >> 7;
		}
		effect_counter = (effect_counter + 1) & 0xFF;
		break;
		
		case 2:  // Parpadeo rápido
		if ((effect_counter & 0x20) == 0) {  // Alternar cada 32 ciclos
			current_led_value = led_brightness;
			} else {
			current_led_value = 0;
		}
		effect_counter++;
		break;
		
		case 3:  // Parpadeo con intensidad variable
		if ((effect_counter & 0x40) == 0) {  // Ciclo de 64
			current_led_value = ((effect_counter & 0x3F) * led_brightness) >> 6;
			} else {
			current_led_value = (((0x3F - effect_counter) & 0x3F) * led_brightness) >> 6;
		}
		effect_counter++;
		break;
	}
	
	// Implementar PWM por software
	if (pwm_counter < current_led_value) {
		PORTD |= (1 << LED_PIN);  // Encender LED
		} else {
		PORTD &= ~(1 << LED_PIN);  // Apagar LED
	}
}

// Interrupción del Timer0 para temporización
ISR(TIMER0_OVF_vect) {
	// Esta interrupción se usa solo para temporización
	// La lógica principal está en pwm_manual_update()
}