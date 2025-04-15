#ifndef PWM_MANUAL_H
#define PWM_MANUAL_H

#include <avr/io.h>
#include <avr/interrupt.h>

// Inicializa el control de servos y LED
void pwm_manual_init(void);

// Establece la intensidad del LED (0-1023)
void pwm_manual_set_led(uint16_t brightness);

// Establece la posici�n del servo 1 (0-1023)
void pwm_manual_set_servo1(uint16_t position);

// Establece la posici�n del servo 2 (0-1023)
void pwm_manual_set_servo2(uint16_t position);

// Funci�n para actualizaci�n peri�dica
void pwm_manual_update(void);

#endif