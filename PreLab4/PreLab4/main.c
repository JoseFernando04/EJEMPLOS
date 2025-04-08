/*
 * PreLab4_Completo.c
 *
 * Created: 31/03/2025
 * Author: José Gordillo
 *
 * Descripción: Integración de contador binario de 8 bits con botones y
 * visualización de valor ADC en formato hexadecimal en displays de 7 segmentos
 * Sin usar la librería delay.h
 */

#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>

// Definiciones para los segmentos (cátodo común)
#define SEG_A   (1 << 0)
#define SEG_B   (1 << 1)
#define SEG_C   (1 << 2)
#define SEG_D   (1 << 3)
#define SEG_E   (1 << 4)
#define SEG_F   (1 << 5)
#define SEG_G   (1 << 6)
#define SEG_DP  (1 << 7)

// Arreglo con los valores para mostrar dígitos 0-F en display de 7 segmentos (cátodo común)
const uint8_t digitos_hex[] = {
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F,         // 0
    SEG_B | SEG_C,                                          // 1
    SEG_A | SEG_B | SEG_G | SEG_E | SEG_D,                 // 2
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_G,                 // 3
    SEG_F | SEG_G | SEG_B | SEG_C,                         // 4
    SEG_A | SEG_F | SEG_G | SEG_C | SEG_D,                 // 5
    SEG_A | SEG_F | SEG_G | SEG_C | SEG_D | SEG_E,         // 6
    SEG_A | SEG_B | SEG_C,                                 // 7
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_E | SEG_F | SEG_G, // 8
    SEG_A | SEG_B | SEG_C | SEG_D | SEG_F | SEG_G,         // 9
    SEG_A | SEG_B | SEG_C | SEG_E | SEG_F | SEG_G,         // A
    SEG_F | SEG_E | SEG_G | SEG_C | SEG_D,                 // b
    SEG_A | SEG_F | SEG_E | SEG_D,                         // C
    SEG_B | SEG_C | SEG_G | SEG_E | SEG_D,                 // d
    SEG_A | SEG_F | SEG_G | SEG_E | SEG_D,                 // E
    SEG_A | SEG_F | SEG_G | SEG_E                          // F
};

// Variables globales
// Para el contador binario
volatile uint8_t contador = 0;
volatile uint8_t btn_prev_state = 0;
volatile uint16_t antirebote_contador = 0;

// Para el ADC y displays
volatile uint16_t adc_value = 0;
volatile uint8_t display_msb = 0;  // Dígito hexadecimal más significativo
volatile uint8_t display_lsb = 0;  // Dígito hexadecimal menos significativo
volatile uint8_t display_actual = 0;
volatile uint8_t adc_actualizado = 0;  // Flag para indicar si el ADC ha sido actualizado

// Para temporizadores
volatile uint16_t timer_display = 0;
volatile uint16_t timer_botones = 0;
volatile uint8_t timer_overflow = 0;

// Prototipos de funciones
void setup(void);
void initADC(void);
void initTimer0(void);
void actualizarLEDs(uint8_t valor);
void actualizarDisplaysHex(uint16_t valor);
void mostrarDisplay(uint8_t display, uint8_t digito);
uint8_t leerBotones(void);

int main(void)
{
    setup();
    
    // Estado inicial de LEDs
    actualizarLEDs(contador);
    
    // Inicializar valores de displays
    actualizarDisplaysHex(adc_value);
    
    while (1)
    {
        // --- PARTE 1: CONTADOR BINARIO ---
        // Procesar botones cada ~20ms (usando timer_botones)
        if (timer_botones >= 20)
        {
            timer_botones = 0;
            
            // Leer estado de botones
            uint8_t btn_estado = leerBotones();
            
            // Verificar si el botón PC4 (incremento) fue presionado
            if ((btn_estado & (1 << PC4)) && !(btn_prev_state & (1 << PC4)))
            {
                contador++;
                actualizarLEDs(contador);
                antirebote_contador = 50; // ~50ms de antirebote
            }
            
            // Verificar si el botón PC5 (decremento) fue presionado
            if ((btn_estado & (1 << PC5)) && !(btn_prev_state & (1 << PC5)))
            {
                contador--;
                actualizarLEDs(contador);
                antirebote_contador = 50; // ~50ms de antirebote
            }
            
            // Actualizar el estado previo de los botones
            btn_prev_state = btn_estado;
        }
        
        // Decrementar contador de antirebote si está activo
        if (antirebote_contador > 0 && timer_overflow)
        {
            antirebote_contador--;
            timer_overflow = 0;
        }
        
        // --- PARTE 2: ADC Y DISPLAYS HEXADECIMALES ---
        // Actualizar los valores a mostrar en los displays si el ADC ha cambiado
        if (adc_actualizado)
        {
            actualizarDisplaysHex(adc_value);
            adc_actualizado = 0;
        }
        
        // Multiplexación de displays cada ~5ms
        if (timer_display >= 5)
        {
            timer_display = 0;
            
            // Alternar entre displays
            if (display_actual == 0)
            {
                // Mostrar dígito menos significativo en el primer display
                mostrarDisplay(0, display_lsb);
                display_actual = 1;
            }
            else
            {
                // Mostrar dígito más significativo en el segundo display
                mostrarDisplay(1, display_msb);
                display_actual = 0;
            }
        }
    }
}

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
    
    // Inicializar Timer0 para temporización
    initTimer0();
    
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

void initTimer0(void)
{
    // Configurar Timer0 en modo CTC (Clear Timer on Compare Match)
    TCCR0A = (1 << WGM01);
    
    // Prescaler = 64
    TCCR0B = (1 << CS01) | (1 << CS00);
    
    // Configurar para interrumpir cada ~1ms con F_CPU = 16MHz
    // 16MHz/64/250 = 1000Hz = 1ms
    OCR0A = 249;
    
    // Habilitar interrupción de comparación
    TIMSK0 = (1 << OCIE0A);
}

// Función para leer el estado de los botones
uint8_t leerBotones(void)
{
    // Leer el estado del puerto C (botones en PC4 y PC5)
    // Los botones son activos en bajo (pull-up), pero devolvemos activo en alto
    // para facilitar la lógica
    uint8_t estado = ~PINC & 0b00110000;
    return estado;
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

// Función para actualizar los valores hexadecimales a mostrar en los displays
void actualizarDisplaysHex(uint16_t valor)
{
    // Escalar el valor ADC (0-1023) a un rango de 0-255 (0x00-0xFF)
    uint8_t valor_escalado = (uint8_t)((valor * 255UL) / 1023);
    
    // Extraer dígitos hexadecimales
    display_msb = (valor_escalado >> 4) & 0x0F;  // Dígito más significativo (0-F)
    display_lsb = valor_escalado & 0x0F;         // Dígito menos significativo (0-F)
}

void mostrarDisplay(uint8_t display, uint8_t digito)
{
    // Desactivar ambos displays
    PORTB &= ~((1 << PB0) | (1 << PB1));
    
    // Pequeño retardo para evitar ghosting (implementado con un bucle simple)
    for (volatile uint8_t i = 0; i < 10; i++);
    
    // Enviar el patrón del dígito a los segmentos
    PORTD = digitos_hex[digito];
    
    // Activar el display correspondiente
    if (display == 0) {
        PORTB |= (1 << PB0); // Activar display de dígito menos significativo
    } else {
        PORTB |= (1 << PB1); // Activar display de dígito más significativo
    }
}

// Rutina de interrupción del ADC
ISR(ADC_vect)
{
    // Leer el valor del ADC (10 bits)
    adc_value = ADC;
    
    // Marcar que el ADC ha sido actualizado
    adc_actualizado = 1;
    
    // Iniciar siguiente conversión
    ADCSRA |= (1 << ADSC);
}

// Rutina de interrupción del Timer0 (cada ~1ms)
ISR(TIMER0_COMPA_vect)
{
    // Incrementar contadores de tiempo
    timer_display++;
    timer_botones++;
    timer_overflow = 1;
}