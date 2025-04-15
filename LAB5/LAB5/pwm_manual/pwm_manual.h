#ifndef PWM_MANUAL_H
#define PWM_MANUAL_H

#include <avr/io.h>
#include <avr/interrupt.h>

// Inicializa el control de servos
void pwm_manual_init(void);

// Establece la posición del servo 1 (0-1023)
void pwm_manual_set_servo1(uint16_t position);

// Establece la posición del servo 2 (0-1023)
void pwm_manual_set_servo2(uint16_t position);

// Función para actualización periódica (si es necesario)
void pwm_manual_update(void);

#endif