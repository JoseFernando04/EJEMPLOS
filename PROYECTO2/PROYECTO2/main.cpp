/*  
 * PROYECTO2.c  
 *  
 * Author: JOSE GORDILLO
 */

#define F_CPU 16000000UL  
#define FILTER_SAMPLES 3

#include <avr/io.h>  
#include <stdlib.h>  
#include <avr/interrupt.h>  
#include <util/delay.h>  
#include <avr/eeprom.h>  

// Variables globales
volatile uint8_t operation_mode = 0;   // 0: Potenciómetro | 1: Memoria | 2: Serial  
volatile uint8_t btn_flag = 0;  
volatile uint16_t pot_readings[4] = {0,0,0,0};  

// Definición de pines
#define BUTTON_PIN        PD4  
#define MODE1_LED_PIN     PD3  
#define MODE2_LED_PIN     PD2  

// Direcciones EEPROM
#define MEM_SERVO1_ADDR   0  
#define MEM_SERVO2_ADDR   1  
#define MEM_SERVO3_ADDR   2  
#define MEM_SERVO4_ADDR   3  

// Prototipos de funciones
void initialize_hardware(void);  
uint16_t get_filtered_adc(uint8_t adc_channel);  
void init_serial(void);  
void send_byte(char byte_data);  
void send_text(const char* text);  
char receive_byte(void);  
uint8_t is_data_available(void);  
void clear_rx_buffer(void);  
void detect_button_press(void);  
void memory_control_menu(void);  
void control_servo(uint8_t servo_num, uint8_t position);  
void output_number(uint16_t value);  
void display_stored_position(uint8_t servo_num);  
uint8_t convert_adc_to_degrees(uint16_t adc_val);  
void store_position(uint8_t servo_num);  
void process_serial_command(void);  

// Buffer para comunicación serial
#define SERIAL_BUFFER_SIZE  16  
char serial_buffer[SERIAL_BUFFER_SIZE];  
uint8_t buffer_pos = 0;  

// Función principal
int main(void) {  
    initialize_hardware();  
    init_serial();  

    while (1) {  
        detect_button_press();  

        if (btn_flag) {  
            operation_mode = (operation_mode + 1) % 3;  
            btn_flag = 0;  
        }  

        // Actualizar indicadores LED según modo
        if (operation_mode == 0) {              // Modo Potenciómetro  
            PORTD |=  (1 << MODE1_LED_PIN);  
            PORTD &= ~(1 << MODE2_LED_PIN);  
        } else if (operation_mode == 1) {       // Modo Memoria  
            PORTD &= ~(1 << MODE1_LED_PIN);  
            PORTD |=  (1 << MODE2_LED_PIN);  
            memory_control_menu();  
        } else if (operation_mode == 2) {       // Modo Serial  
            PORTD |=  (1 << MODE1_LED_PIN);  
            PORTD |=  (1 << MODE2_LED_PIN);  
            process_serial_command();  
        }  
    }  
}  

// Procesa comandos seriales formato "X:NNN"
void process_serial_command(void) {  
    while (is_data_available()) {  
        char incoming = receive_byte();  
        if (incoming == '\n' || incoming == '\r') {  
            serial_buffer[buffer_pos] = '\0';  
            if (buffer_pos >= 3) {  
                char servo_id = serial_buffer[0];  
                if (serial_buffer[1] == ':' || serial_buffer[1] == ';') {  
                    uint8_t position = (uint8_t) atoi(&serial_buffer[2]);  
                    if (position > 180) position = 180;  
                    
                    switch (servo_id) {  
                        case 'A': case 'a': control_servo(0, position); break;  
                        case 'B': case 'b': control_servo(1, position); break;  
                        case 'C': case 'c': control_servo(2, position); break;  
                        case 'D': case 'd': control_servo(3, position); break;  
                        default: break;  
                    }  
                }  
            }  
            buffer_pos = 0;  
        } else if (buffer_pos < SERIAL_BUFFER_SIZE-1) {  
            serial_buffer[buffer_pos++] = incoming;  
        } else {  
            buffer_pos = 0;  
        }  
    }  
}  

// Inicialización del hardware
void initialize_hardware(void) {  
    // Configuración ADC
    ADCSRA = (1 << ADEN) | (1 << ADIE)  
           | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);  
    DIDR0  = 0xF0;  

    // Configuración pines PWM
    DDRB |= (1 << PB1) | (1 << PB2) | (1 << PB3);  
    DDRD |= (1 << PD5);  

    // Timer1 configuración
    TCCR1A = (1 << COM1A1) | (1 << COM1B1) | (1 << WGM11);  
    TCCR1B = (1 << WGM13)  | (1 << WGM12)  
           | (1 << CS11)   | (1 << CS10);  
    ICR1 = 4999;  
    OCR1A = 375;  
    OCR1B = 375;  

    // Timer0 configuración
    TCCR0A = (1 << COM0B1) | (1 << WGM01) | (1 << WGM00);  
    TCCR0B = (1 << CS02)   | (1 << CS00);  
    OCR0B  = 23;  

    // Timer2 configuración
    TCCR2A = (1 << COM2A1) | (1 << WGM21) | (1 << WGM20);  
    TCCR2B = (1 << CS22)   | (1 << CS21) | (1 << CS20);  
    OCR2A  = 23;  

    // Configuración ADC inicial
    ADMUX = (1 << REFS0) | 4;  
    PORTC |= 0xF0;  

    // Configuración botón y LEDs
    DDRD &= ~(1 << BUTTON_PIN);  
    PORTD |=  (1 << BUTTON_PIN);  
    DDRD |=  (1 << MODE1_LED_PIN) | (1 << MODE2_LED_PIN);  

    ADCSRA |= (1 << ADSC);  
    sei();  
}  

// Inicialización USART
void init_serial(void) {  
    uint16_t baud_value = 103;  // 9600 bps @16 MHz  
    UBRR0H = (baud_value >> 8);  
    UBRR0L = baud_value;  
    UCSR0B = (1 << RXEN0) | (1 << TXEN0);  
    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);  
}  

void send_byte(char byte_data) {  
    while (!(UCSR0A & (1 << UDRE0)));  
    UDR0 = byte_data;  
}  

void send_text(const char* text) {  
    while (*text) send_byte(*text++);  
}  

char receive_byte(void) {  
    while (!(UCSR0A & (1 << RXC0)));  
    return UDR0;  
}  

uint8_t is_data_available(void) {  
    return (UCSR0A & (1 << RXC0));  
}  

void clear_rx_buffer(void) {  
    while (UCSR0A & (1 << RXC0)) { (void)UDR0; }  
}  

void output_number(uint16_t value) {  
    char digits[6]; 
    uint8_t i = 0, j;  
    
    if (value == 0) { 
        send_byte('0'); 
        return; 
    }  
    
    while (value) { 
        digits[i++] = (value % 10) + '0'; 
        value /= 10; 
    }  
    
    for (j = 0; j < i; j++)  
        send_byte(digits[i-1-j]);  
}  

// Filtrado de lecturas ADC
uint16_t get_filtered_adc(uint8_t adc_channel) {  
    static uint16_t filter_buffer[4][ADC_FILTER_COUNT];  
    static uint8_t index[4] = {0};  
    
    filter_buffer[adc_channel][index[adc_channel]] = ADC;  
    index[adc_channel] = (index[adc_channel] + 1) % ADC_FILTER_COUNT;  
    
    uint32_t sum = 0;  
    for (uint8_t k = 0; k < ADC_FILTER_COUNT; k++)  
        sum += filter_buffer[adc_channel][k];  
        
    return sum / ADC_FILTER_COUNT;  
}  

// Detección de pulsación de botón
void detect_button_press(void) {  
    static uint8_t last_state = 1;  
    uint8_t current_state = (PIND & (1 << BUTTON_PIN)) >> BUTTON_PIN;  
    
    if (current_state == 0 && last_state == 1) {  
        _delay_ms(10);  // Debounce
        if ((PIND & (1 << BUTTON_PIN)) == 0) {  
            btn_flag = 1;  
        }  
    }  
    
    last_state = current_state;  
}  

// Menú de control por memoria EEPROM
void memory_control_menu(void) {
    btn_flag = 0;
    
    while (operation_mode == 1) {
        detect_button_press();
        
        if (btn_flag) {
            send_text("\r\n[BOTÓN DETECTADO] Saliendo del modo Memoria...\r\n");
            operation_mode = 2;
            btn_flag = 0;
            return;
        }
        
        send_text("\r\n--- MENÚ DE CONTROL ---\r\n");
        send_text("1) Posición central (90°)\r\n");
        send_text("2) Guardar posición actual\r\n");
        send_text("3) Cargar posición guardada\r\n");
        send_text("4) Cambiar a modo Serial\r\n");
        send_text("Presione botón para salir\r\n");
        send_text("Seleccione opción: ");
        
        uint16_t timeout = 0;
        while (!is_data_available() && timeout < 600) {
            detect_button_press();
            if (btn_flag) break;
            _delay_ms(10);
            timeout++;
        }
        
        if (btn_flag) continue;
        
        if (!is_data_available()) {
            send_text("\r\nTiempo agotado, intente nuevamente.\r\n");
            continue;
        }
        
        char option = receive_byte();
        send_byte(option);
        send_text("\r\n");
        clear_rx_buffer();
        
        switch (option) {
            case '1': {
                for (uint8_t servo = 0; servo < 4; servo++)
                    control_servo(servo, 90);
                send_text("Servos centrados a 90°.\r\n");
                break;
            }
            
            case '2': {
                send_text("\r\nSeleccione servo para guardar (A-D): ");
                
                timeout = 0;
                while (!is_data_available() && timeout < 600) {
                    detect_button_press();
                    if (btn_flag) break;
                    _delay_ms(10);
                    timeout++;
                }
                
                if (btn_flag) continue;
                
                if (!is_data_available()) {
                    send_text("\r\nTiempo agotado, intente nuevamente.\r\n");
                    continue;
                }
                
                char servo_sel = receive_byte();
                send_byte(servo_sel);
                send_text("\r\n");
                clear_rx_buffer();
                
                uint16_t addr = 0;
                uint8_t servo_num = 0;
                
                switch (servo_sel) {
                    case 'A': case 'a': addr = MEM_SERVO1_ADDR; servo_num = 0; break;
                    case 'B': case 'b': addr = MEM_SERVO2_ADDR; servo_num = 1; break;
                    case 'C': case 'c': addr = MEM_SERVO3_ADDR; servo_num = 2; break;
                    case 'D': case 'd': addr = MEM_SERVO4_ADDR; servo_num = 3; break;
                    default: 
                        send_text("Opción inválida.\r\n"); 
                        continue;
                }
                
                uint16_t raw_value = pot_readings[servo_num];
                uint8_t angle = convert_adc_to_degrees(raw_value);
                
                eeprom_write_byte((uint8_t*)(uint16_t)addr, angle);
                
                send_text("Posición guardada: ");
                output_number(angle);
                send_text("°.\r\n");
                break;
            }
            
            case '3': {
                send_text("\r\nSeleccione servo para cargar (A-D): ");
                
                timeout = 0;
                while (!is_data_available() && timeout < 600) {
                    detect_button_press();
                    if (btn_flag) break;
                    _delay_ms(10);
                    timeout++;
                }
                
                if (btn_flag) continue;
                
                if (!is_data_available()) {
                    send_text("\r\nTiempo agotado, intente nuevamente.\r\n");
                    continue;
                }
                
                char servo_sel = receive_byte();
                send_byte(servo_sel);
                send_text("\r\n");
                clear_rx_buffer();
                
                uint8_t servo_num = 0;
                
                switch (servo_sel) {
                    case 'A': case 'a': servo_num = 0; break;
                    case 'B': case 'b': servo_num = 1; break;
                    case 'C': case 'c': servo_num = 2; break;
                    case 'D': case 'd': servo_num = 3; break;
                    default: 
                        send_text("Opción inválida.\r\n"); 
                        continue;
                }
                
                display_stored_position(servo_num);
                break;
            }
            
            case '4':
                send_text("Cambiando a modo Serial...\r\n");
                operation_mode = 2;
                return;
                
            default:
                send_text("Opción inválida.\r\n");
        }
        
        for (uint8_t i = 0; i < 20; i++) {
            detect_button_press();
            if (btn_flag) break;
            _delay_ms(10);
        }
    }
}

// Control de servomotor
void control_servo(uint8_t servo_num, uint8_t position) {  
    if (position > 180) position = 180;
    
    switch (servo_num) {  
        case 0: // Timer2A
            OCR2A = 8 + ((uint32_t)position * 30) / 180;  
            break;  
        case 1: // Timer1B
            OCR1B = 125 + ((uint32_t)position * 500) / 180;  
            break;  
        case 2: // Timer1A
            OCR1A = 125 + ((uint32_t)position * 500) / 180;  
            break;  
        case 3: // Timer0B
            OCR0B = 8 + ((uint32_t)position * 30) / 180;  
            break;  
    }  
}  

// Muestra y aplica posición guardada
void display_stored_position(uint8_t servo_num) {  
    uint16_t addr = 0;  
    switch (servo_num) {  
        case 0: addr = MEM_SERVO1_ADDR; break;  
        case 1: addr = MEM_SERVO2_ADDR; break;  
        case 2: addr = MEM_SERVO3_ADDR; break;  
        case 3: addr = MEM_SERVO4_ADDR; break;  
    }  
    
    uint8_t stored_angle = eeprom_read_byte((uint8_t*)(uint16_t)addr);  
    send_text("Posición guardada: ");  
    output_number(stored_angle);  
    send_text("°\r\n");  
    
    control_servo(servo_num, stored_angle);
    send_text("Servo movido a posición guardada.\r\n");
}  

// Conversión ADC a ángulo
uint8_t convert_adc_to_degrees(uint16_t adc_val) {  
    if (adc_val > 1023) adc_val = 1023;
    
    uint8_t angle = (uint8_t)((uint32_t)adc_val * 180UL / 1023UL);
    
    if (angle > 180) angle = 180;
    
    return angle;  
}  

// Guarda posición actual
void store_position(uint8_t servo_num) {  
    uint16_t addr;  
    switch (servo_num) {  
        case 0: addr = MEM_SERVO1_ADDR; break;  
        case 1: addr = MEM_SERVO2_ADDR; break;  
        case 2: addr = MEM_SERVO3_ADDR; break;  
        case 3: addr = MEM_SERVO4_ADDR; break;  
        default: return;  
    }  
    
    uint8_t angle = convert_adc_to_degrees(pot_readings[servo_num]);  
    eeprom_write_byte((uint8_t*)(uint16_t)addr, angle);  

    send_text("Servo ");  
    send_byte('A' + servo_num);  
    send_text(" guardado a ");  
    output_number(angle);  
    send_text("°\r\n");  
}  

// Interrupción ADC
ISR(ADC_vect) {  
    static uint8_t channel = 0;  

    pot_readings[channel] = get_filtered_adc(channel);  

    channel = (channel + 1) % 4;  
    ADMUX = (1 << REFS0) | (channel + 4);  

    if (operation_mode == 0) {  
        uint8_t angle0 = convert_adc_to_degrees(pot_readings[0]);
        uint8_t angle1 = convert_adc_to_degrees(pot_readings[1]);
        uint8_t angle2 = convert_adc_to_degrees(pot_readings[2]);
        uint8_t angle3 = convert_adc_to_degrees(pot_readings[3]);
        
        OCR2A = 8 + ((uint32_t)angle0 * 30) / 180;
        OCR1B = 125 + ((uint32_t)angle1 * 500) / 180;
        OCR1A = 125 + ((uint32_t)angle2 * 500) / 180;
        OCR0B = 8 + ((uint32_t)angle3 * 30) / 180;
    }  
    
    // Límites de seguridad
    if (OCR2A < 8)  OCR2A = 8;
    if (OCR2A > 38) OCR2A = 38;
    
    if (OCR0B < 8)  OCR0B = 8;
    if (OCR0B > 38) OCR0B = 38;

    ADCSRA |= (1 << ADSC);  
}