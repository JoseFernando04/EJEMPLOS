/*
 * PreLab4.c
 *
 * Created: 30/03/2025
 * Author: José Gordillo
 */

// Encabezado (Libraries)

#define F_CPU 16000000
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>

//

// Definiciones para los segmentos (cátodo común)
#define SEG_A   (1 << 0)
#define SEG_B   (1 << 1)
#define SEG_C   (1 << 2)
#define SEG_D   (1 << 3)
#define SEG_E   (1 << 4)
#define SEG_F   (1 << 5)
#define SEG_G   (1 << 6)
#define SEG_DP  (1 << 7)

// Arreglo con los valores para mostrar dígitos 0-9 en display de 7 segmentos (cátodo común)
const uint8_t digitos[] = {
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F,         // 0
    SEG_B | SEG_C,                                          // 1
    SEG_A | SEG_B | SEG_G | SEG_E | SEG_D,                 // 2
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_G,                 // 3
    SEG_F | SEG_G | SEG_B | SEG_C,                         // 4
    SEG_A | SEG_F | SEG_G | SEG_C | SEG_D,                 // 5
    SEG_A | SEG_F | SEG_G | SEG_C | SEG_D | SEG_E,         // 6
    SEG_A | SEG_B | SEG_C,                                 // 7
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G, // 8
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_F | SEG_G          // 9
};

// Variables globales
// Para el contador binario
volatile uint8_t contador = 0;
volatile uint8_t debounceFlag = 0;

// Para el ADC y displays
volatile uint16_t adc_value = 0;
volatile uint8_t display_decenas = 0;
volatile uint8_t display_unidades = 0;
volatile uint8_t display_actual = 0;

// Function prototypes

void setup(void);
void initADC(void);
void actualizarLEDs(uint8_t valor);
void actualizarDisplays(uint16_t valor);
void mostrarDisplay(uint8_t display, uint8_t digito);

//

// Main Function

int main(void)
{
    setup();
    
    // Estado inicial de LEDs
    actualizarLEDs(contador);
    
    while (1)
    {
        // --- PARTE 1: CONTADOR BINARIO ---
        // Verificar botón de incremento (PC4)
        if (!(PINC & (1 << PC4)) && !(debounceFlag & (1 << 0)))
        {
            contador++;
            actualizarLEDs(contador);
            debounceFlag |= (1 << 0);  // Activar flag de antirebote
            _delay_ms(20);  // Pequeño retardo para estabilización
        }
        else if ((PINC & (1 << PC4)) && (debounceFlag & (1 << 0)))
        {
            debounceFlag &= ~(1 << 0);  // Desactivar flag de antirebote
            _delay_ms(20);  // Pequeño retardo para estabilización
        }
        
        // Verificar botón de decremento (PC5)
        if (!(PINC & (1 << PC5)) && !(debounceFlag & (1 << 1)))
        {
            contador--;
            actualizarLEDs(contador);
            debounceFlag |= (1 << 1);  // Activar flag de antirebote
            _delay_ms(20);  // Pequeño retardo para estabilización
        }
        else if ((PINC & (1 << PC5)) && (debounceFlag & (1 << 1)))
        {
            debounceFlag &= ~(1 << 1);  // Desactivar flag de antirebote
            _delay_ms(20);  // Pequeño retardo para estabilización
        }
        
        // --- PARTE 2: ADC Y DISPLAYS ---
        // Convertir valor ADC a voltaje (0-5V) y escalarlo a 0-50
        uint16_t valor_escalado = (adc_value * 50) / 1023;
        
        // Actualizar los valores a mostrar en los displays
        actualizarDisplays(valor_escalado);
        
        // Multiplexación de displays
        if (display_actual == 0)
        {
            // Mostrar unidades en el primer display
            mostrarDisplay(0, display_unidades);
            display_actual = 1;
        }
        else
        {
            // Mostrar decenas en el segundo display
            mostrarDisplay(1, display_decenas);
            display_actual = 0;
        }
        
        // Tiempo entre cambios de display (ajustar según necesidad)
        _delay_ms(5);
    }
}

//

// NON-Interrupt subroutines

void setup(void)
{
    cli(); // Deshabilitar interrupciones globales
    
    // Configuración del reloj
    CLKPR = (1 << CLKPCE);
    CLKPR = 0; // Sin división, frecuencia completa
    
    // Configurar puertos para PARTE 1 (Contador)
    DDRB |= (1 << PB2) | (1 << PB3) | (1 << PB4) | (1 << PB5);  // PB2-PB5 como salidas para LEDs
    DDRC |= (1 << PC0) | (1 << PC1) | (1 << PC2) | (1 << PC3);  // PC0-PC3 como salidas para LEDs
    DDRC &= ~((1 << PC4) | (1 << PC5));  // PC4-PC5 como entradas para botones
    PORTC |= (1 << PC4) | (1 << PC5);    // Habilitar pull-ups en PC4-PC5
    
    // Configurar puertos para PARTE 2 (Displays)
    DDRD = 0xFF;   // PORTD como salida para los segmentos
    DDRB |= (1 << PB0) | (1 << PB1);  // PB0 y PB1 como salidas para seleccionar display
    
    // Desactivar ambos displays inicialmente
    PORTB &= ~((1 << PB0) | (1 << PB1));
    
    // Deshabilitar USART para usar los pines del puerto D para otras funciones
    UCSR0B = 0x00;
    
    // Inicializar ADC
    initADC();
    
    sei(); // Habilitar interrupciones globales
}

void initADC(void)
{
    // Configurar ADMUX
    ADMUX = 0;
    ADMUX |= (1 << REFS0);              // Referencia: AVCC (5V)
    ADMUX |= (1 << MUX2) | (1 << MUX1); // Seleccionar canal ADC6 (110)
    
    // Configurar ADCSRA
    ADCSRA = 0;
    ADCSRA |= (1 << ADEN);                               // Habilitar ADC
    ADCSRA |= (1 << ADIE);                               // Habilitar interrupción de ADC
    ADCSRA |= (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); // Prescaler = 128
    
    // Iniciar primera conversión
    ADCSRA |= (1 << ADSC);
}

// Función para actualizar el estado de los LEDs según el valor del contador
void actualizarLEDs(uint8_t valor)
{
    // Guardar estado actual de PB0 y PB1 para no afectar los displays
    uint8_t pb_state = PORTB & ((1 << PB0) | (1 << PB1));
    
    // Actualizar LEDs en PORTB (bits 0-3 del contador)
    PORTB &= ~((1 << PB2) | (1 << PB3) | (1 << PB4) | (1 << PB5));  // Limpiar bits
    if (valor & 0x01) PORTB |= (1 << PB2);
    if (valor & 0x02) PORTB |= (1 << PB3);
    if (valor & 0x04) PORTB |= (1 << PB4);
    if (valor & 0x08) PORTB |= (1 << PB5);
    
    // Restaurar estado de PB0 y PB1
    PORTB = (PORTB & ~((1 << PB0) | (1 << PB1))) | pb_state;
    
    // Actualizar LEDs en PORTC (bits 4-7 del contador)
    PORTC &= ~((1 << PC0) | (1 << PC1) | (1 << PC2) | (1 << PC3));  // Limpiar bits
    if (valor & 0x10) PORTC |= (1 << PC0);
    if (valor & 0x20) PORTC |= (1 << PC1);
    if (valor & 0x40) PORTC |= (1 << PC2);
    if (valor & 0x80) PORTC |= (1 << PC3);
}

void actualizarDisplays(uint16_t valor)
{
    // Extraer dígitos individuales
    display_decenas = valor / 10;    // Parte entera (0-5)
    display_unidades = valor % 10;   // Parte decimal (0-9)
}

void mostrarDisplay(uint8_t display, uint8_t digito)
{
	// Desactivar ambos displays
	PORTB &= ~((1 << PB0) | (1 << PB1));
	
	// Pequeño retardo para evitar ghosting
	_delay_us(100);
	
	// Enviar el patrón del dígito a los segmentos y agregar el punto decimal (SEG_DP)
	PORTD = digitos[digito] | SEG_DP;
	
	// Activar el display correspondiente
	if (display == 0) {
		PORTB |= (1 << PB0); // Activar display de unidades
		} else {
		PORTB |= (1 << PB1); // Activar display de decenas
	}
}

//

// Interrupt routines
ISR(ADC_vect)
{
    // Leer el valor del ADC (10 bits)
    adc_value = ADC;
    
    // Iniciar siguiente conversión
    ADCSRA |= (1 << ADSC);
}

//