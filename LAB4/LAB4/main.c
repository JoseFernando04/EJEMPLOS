/*  
 * ContadorBinario.c  
 *  
 * Created: 31/03/2025  
 * Author: JOSE GORDILLO
 */  
//  
// Encabezado (Libraries)  
#include <avr/io.h>  
#include <avr/interrupt.h>  

// Variables globales  
uint8_t counter_value = 0;        // Valor del contador de 8 bits  
uint8_t counter_10ms = 0;         // Contador para temporizador  
uint8_t antirrebote_counter_pc4 = 0; // Contador antirebote para PC4  
uint8_t antirrebote_counter_pc5 = 0; // Contador antirebote para PC5  
uint8_t button_state_pc4 = 0;     // Estado actual del bot�n PC4  
uint8_t button_state_pc5 = 0;     // Estado actual del bot�n PC5  
uint8_t button_pressed_pc4 = 0;   // Flag para bot�n PC4 presionado  
uint8_t button_pressed_pc5 = 0;   // Flag para bot�n PC5 presionado  

// Variables para ADC y display  
uint8_t adc_value = 0;           // Valor le�do del ADC (ADCH solamente)  
uint16_t adc_raw = 0;            // Valor completo del ADC (10 bits)
uint8_t scaled_adc = 0;          // Valor ADC escalado a 8 bits para comparaci�n
uint8_t display_digit[2];         // D�gitos para mostrar (0-F)  
uint8_t current_display = 0;      // Display actualmente activo (0 o 1)  
uint8_t display_counter = 0;      // Contador para tiempo de display

// Tabla de conversi�n para display de 7 segmentos (com�n c�todo)  
// Segmentos: DP G F E D C B A (0 = apagado, 1 = encendido)  
const uint8_t seven_seg[] = {  
    0x3F,  // 0  
    0x06,  // 1  
    0x5B,  // 2  
    0x4F,  // 3  
    0x66,  // 4  
    0x6D,  // 5  
    0x7D,  // 6  
    0x07,  // 7  
    0x7F,  // 8  
    0x6F,  // 9  
    0x77,  // A  
    0x7C,  // b  
    0x39,  // C  
    0x5E,  // d  
    0x79,  // E  
    0x71   // F  
};  

//  
// Function prototypes  
void setup();  
void update_counter();  
void update_leds();  
void start_adc_conversion();  
void update_display();  
void check_alarm();

//  
// Main Function  
int main(void)  
{  
    setup();
    
    while (1)  
    {  
        // Verificar si alg�n bot�n fue presionado  
        if (button_pressed_pc4)  
        {  
            counter_value++;    // Incrementar contador  
            update_leds();      // Actualizar LEDs  
            check_alarm();      // Verificar condici�n de alarma
            button_pressed_pc4 = 0; // Limpiar flag  
        }  
        
        if (button_pressed_pc5)  
        {  
            counter_value--;    // Decrementar contador  
            update_leds();      // Actualizar LEDs  
            check_alarm();      // Verificar condici�n de alarma
            button_pressed_pc5 = 0; // Limpiar flag  
        }  
        
        // Iniciar nueva conversi�n ADC cada ~500ms  
        if (counter_10ms % 50 == 0) {  
            start_adc_conversion();  
        }  
    }  
}  

//  
// NON-Interrupt subroutines  
void setup()  
{  
    cli(); // Deshabilitar interrupciones globales  
    
    // Desactivar USART (TX/RX)  
    UCSR0B = 0x00;  
    
    // Configurar puertos  
    DDRB = 0x3F;   // PB0-PB5 como salidas (PB0-PB1 para displays, PB2-PB5 para LEDs)
    PORTB = 0x00;  // Inicialmente todos apagados  
    
    DDRC = 0x0F;   // PC0-PC3 como salidas para LEDs, PC4-PC5 como entradas para botones
    PORTC = 0x30;  // Pull-ups en PC4-PC5, PC0-PC3 inicialmente apagados  
    
    DDRD = 0xFF;   // PD0-PD7 como salidas para los segmentos de los displays y LED de alarma (PD7)
    PORTD = 0x00;  // Inicialmente todos apagados  
    
    // Configurar Timer0 
    TCCR0A = 0x00;  // Modo normal  
    TCCR0B = (1 << CS02) | (1 << CS00); // Prescaler 1024  
    TCNT0 = 100;    // Valor inicial para ~10ms 
    TIMSK0 = (1 << TOIE0); // Habilitar interrupci�n por overflow  
    
    // Configurar interrupciones para botones (PCINT)  
    PCICR = (1 << PCIE1);       // Habilitar PCINT para PORTC  
    PCMSK1 = (1 << PCINT12) | (1 << PCINT13); // Habilitar para PC4 y PC5  
    
    // Configurar ADC para leer el potenci�metro en ADC7
    // Cambiamos a alineaci�n derecha para leer el valor completo
    ADMUX = (1 << REFS0) | (1 << MUX2) | (1 << MUX1) | (1 << MUX0); // Referencia AVcc, alineaci�n derecha, seleccionar ADC7 (111)
    ADCSRA = (1 << ADEN) | (1 << ADIE) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0); // Habilitar ADC, habilitar interrupci�n ADC, prescaler 128  
    
    // Inicializar display  
    display_digit[0] = 0;  
    display_digit[1] = 0;  
    current_display = 0;  
    
    counter_10ms = 0;  
    update_leds(); // Inicializar LEDs con el valor actual  
    
    // Verificar que PB0 y PB1 est�n correctamente configurados como salidas
    DDRB |= (1 << PB0) | (1 << PB1);
    
    // Asegurar que PD7 est� configurado como salida para el LED de alarma
    DDRD |= (1 << PD7);
    
    sei(); // Habilitar interrupciones globales  
    
    // Iniciar primera conversi�n ADC
    start_adc_conversion();  
}  

// Actualiza el estado de los LEDs basado en el valor del contador   
// Mapeo para tus pines espec�ficos:
// PB2 = bit 0, PB3 = bit 1, PB4 = bit 2, PB5 = bit 3
// PC0 = bit 4, PC1 = bit 5, PC2 = bit 6, PC3 = bit 7
void update_leds()  
{  
    uint8_t portb_value = 0;  
    uint8_t portc_value = 0;  
    
    // Mapeo para puerto B (bits 0-3 del contador)
    if (counter_value & (1 << 0)) portb_value |= (1 << 2);  // Bit 0 -> PB2
    if (counter_value & (1 << 1)) portb_value |= (1 << 3);  // Bit 1 -> PB3
    if (counter_value & (1 << 2)) portb_value |= (1 << 4);  // Bit 2 -> PB4
    if (counter_value & (1 << 3)) portb_value |= (1 << 5);  // Bit 3 -> PB5
    
    // Guardar estado de PB0 y PB1 (para los displays)  
    portb_value |= (PORTB & 0x03);  
    
    // Mapeo para puerto C (bits 4-7 del contador)
    if (counter_value & (1 << 4)) portc_value |= (1 << 0);  // Bit 4 -> PC0
    if (counter_value & (1 << 5)) portc_value |= (1 << 1);  // Bit 5 -> PC1
    if (counter_value & (1 << 6)) portc_value |= (1 << 2);  // Bit 6 -> PC2
    if (counter_value & (1 << 7)) portc_value |= (1 << 3);  // Bit 7 -> PC3
    
    PORTB = portb_value;  
    
    // Asegurar que los pull-ups de PC4 y PC5 se mantienen activos  
    PORTC = portc_value | 0x30;  
}  

// Inicia una conversi�n ADC  
void start_adc_conversion() {  
    ADCSRA |= (1 << ADSC);  // Iniciar conversi�n ADC  
}  

// Verifica si el valor del ADC es mayor que el contador y activa la alarma
void check_alarm() {
    // Comparar el valor escalado del ADC con el contador
    if (scaled_adc > counter_value) {
        // Activar LED de alarma en PD7
        PORTD |= (1 << PD7);
    } else {
        // Desactivar LED de alarma
        PORTD &= ~(1 << PD7);
    }
}

// Actualiza los displays de 7 segmentos  
void update_display() {  
    // Guardar estado del LED de alarma (PD7)
    uint8_t alarm_state = PORTD & (1 << PD7);
    
    // Apagar ambos displays  
    PORTB &= ~0x03;  // Limpiar PB0 y PB1  
    
    // Peque�o retardo para evitar ghosting
    for (volatile uint8_t i = 0; i < 5; i++);
    
    // Alternar entre los displays  
    current_display = !current_display;  
    
    // Mostrar el d�gito actual sin punto decimal  
    PORTD = seven_seg[display_digit[current_display]];  
    
    // Restaurar estado del LED de alarma
    PORTD |= alarm_state;
    
    // Activar el display actual con mayor intensidad
    // INTERCAMBIADO: Ahora display 0 usa PB1 y display 1 usa PB0
    if (current_display == 0) {
        PORTB |= (1 << PB1);  // Activar display 0 (ahora en PB1)
    } else {
        PORTB |= (1 << PB0);  // Activar display 1 (ahora en PB0)
    }
    
    // Incrementar contador de display para dar m�s tiempo al display problem�tico
    display_counter++;
    
    // Si estamos en el display PB0 (ahora display 1), darle m�s tiempo de activaci�n
    if (current_display == 1 && display_counter < 3) {
        // No cambiar de display en el pr�ximo ciclo
        current_display = 1;
    } else {
        display_counter = 0;
    }
}  

// Convierte el valor del ADC a d�gitos hexadecimales para el display  
void convert_adc_to_hex_digits() {  
    // Escalar el valor ADC de 10 bits (0-1023) a 8 bits (0-255)
    scaled_adc = (uint8_t)((adc_raw * 255UL) / 1023);
    
    // Extraer d�gitos hexadecimales
    display_digit[0] = (scaled_adc >> 4) & 0x0F;  // D�gito hexadecimal alto (bits 7-4)  
    display_digit[1] = scaled_adc & 0x0F;         // D�gito hexadecimal bajo (bits 3-0)  
    
    // Verificar condici�n de alarma despu�s de actualizar el valor escalado
    check_alarm();
}  

//  
// Interrupt routines  
ISR(TIMER0_OVF_vect)  
{  
    TCNT0 = 100; // Reiniciar el timer  
    
    // Manejar antirebote para PC4  
    if (antirrebote_counter_pc4 > 0)  
    {  
        antirrebote_counter_pc4--;  
        if (antirrebote_counter_pc4 == 0 && button_state_pc4 == 0)  
        {  
            // Bot�n estable y presionado  
            button_pressed_pc4 = 1;  
        }  
    }  
    
    // Manejar antirebote para PC5  
    if (antirrebote_counter_pc5 > 0)  
    {  
        antirrebote_counter_pc5--;  
        if (antirrebote_counter_pc5 == 0 && button_state_pc5 == 0)  
        {  
            // Bot�n estable y presionado  
            button_pressed_pc5 = 1;  
        }  
    }  
    
    counter_10ms++;  
    
    // Actualizar display (multiplexar)  
    update_display();  
}  

// Interrupci�n para cambios en PORTC (botones)  
ISR(PCINT1_vect)  
{  
    // Leer estado actual de los botones (invertido debido a pull-up)  
    uint8_t pc4_current = !(PINC & (1 << PINC4));  
    uint8_t pc5_current = !(PINC & (1 << PINC5));  
    
    // Si hay cambio en PC4 y no est� en periodo de antirebote  
    if (pc4_current != button_state_pc4 && antirrebote_counter_pc4 == 0)  
    {  
        button_state_pc4 = pc4_current;  
        antirrebote_counter_pc4 = 5; // 50ms antirebote (5 * 10ms)  
    }  
    
    // Si hay cambio en PC5 y no est� en periodo de antirebote  
    if (pc5_current != button_state_pc5 && antirrebote_counter_pc5 == 0)  
    {  
        button_state_pc5 = pc5_current;  
        antirrebote_counter_pc5 = 5; // 50ms antirebote (5 * 10ms)  
    }  
}  

// Interrupci�n para conversi�n ADC completada  
ISR(ADC_vect) {  
    // Leer el valor completo del ADC (10 bits)
    adc_raw = ADC;
    
    // Convertir valor ADC a d�gitos hexadecimales para el display  
    convert_adc_to_hex_digits();  
}