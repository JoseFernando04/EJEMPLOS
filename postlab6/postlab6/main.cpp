/*  
 * PreLab06.c  
 *  
 * Created: 24/04/2025  
 * Author: JOSÉ GORDILLO
 */  

//  
// Encabezado (Libraries)  
#include <avr/io.h>  
#include <avr/interrupt.h>  
#include <stdlib.h>    // itoa

//  
// Function prototypes  
void setup(void);  
void initUart(void);  
void initADC(void);  
void escribirchar(char letra);  
void escribirstring(char* str);  
char recibirchar(void);  
void leerPotenciometro(void);  
void enviarAscii(void);  

//  
// Main Function  
int main(void)  
{  
    setup();  

    while (1)  
    {  
        // Mostrar menú  
        escribirstring("\r\n--- Menu ---\r\n");  
        escribirstring("1) Leer Potenciometro (A7)\r\n");  
        escribirstring("2) Enviar Ascii\r\n");  
        escribirstring("Seleccione opcion: ");  

        // Leo elección por polling y deshabilito momentáneamente el ISR  
        char opcion = recibirchar();    
        escribirchar(opcion);           // eco en UART  
        escribirstring("\r\n");  

        // Muestro en LEDs el valor leído (ahora en PORTD excepto PD0 y PD1)
        // Preservamos PD0 (RX) y PD1 (TX) para UART
        PORTD = (PORTD & 0x03) | ((uint8_t)opcion & 0xFC);      

        // Ejecuto acción  
        if (opcion == '1')  
            leerPotenciometro();  
        else if (opcion == '2')  
            enviarAscii();  
        // si no es 1 o 2, vuelve a mostrar menú  
    }  
}  

//  
// NON-Interrupt subroutines  
void setup(void)  
{  
    cli();               // Deshabilita interrupciones globales  
    initUart();          // Inicializa UART  
    initADC();           // Inicializa ADC en canal 7 (A7)  
    
    // Configuramos PORTD como salida excepto PD0 (RX) y PD1 (TX)
    DDRD = 0xFC;         // PD2-PD7 como salidas, PD0-PD1 se configuran en initUart()
    PORTD &= 0x03;       // Inicializa PD2-PD7 en 0, preserva PD0-PD1
    
    sei();               // Habilita interrupciones globales  
}  

void initUart(void)  
{  
    // Pines PD0=RX, PD1=TX  
    DDRD |=  (1 << DDD1);   // TX como salida  
    DDRD &= ~(1 << DDD0);   // RX como entrada  

    UCSR0A = 0;  
    UCSR0B = (1 << RXCIE0)  // interrupción RX complete  
           | (1 << RXEN0)   // habilita RX  
           | (1 << TXEN0);  // habilita TX  
    UCSR0C = (1 << UCSZ01)  // 8-bit data  
           | (1 << UCSZ00);  
    UBRR0H = 0;  
    UBRR0L = 103;            // 9600 baudios @16MHz  
}  

void initADC(void)  
{  
    // Referencia AVcc, canal ADC7 (A7) ? MUX[3:0]=0111  
    ADMUX  = (1 << REFS0)   // AVcc como referencia  
           | (1 << MUX2)    // MUX2:0 = 111  
           | (1 << MUX1)  
           | (1 << MUX0);   
    // ADCSRA: habilita ADC + prescaler 128 (?125 kHz)  
    ADCSRA = (1 << ADEN)    // ADC Enable  
           | (1 << ADPS2)  
           | (1 << ADPS1)  
           | (1 << ADPS0);  
}  

void escribirchar(char letra)  
{  
    while (!(UCSR0A & (1 << UDRE0)));  
    UDR0 = letra;  
}  

void escribirstring(char* str)  
{  
    for (int i = 0; str[i] != '\0'; i++)  
    {  
        while (!(UCSR0A & (1 << UDRE0)));  
        UDR0 = str[i];  
    }  
}  

char recibirchar(void)  
{  
    // Deshabilito la interrupción RX para lectura por polling  
    UCSR0B &= ~(1 << RXCIE0);  

    while (!(UCSR0A & (1 << RXC0)));  // espero byte  
    char c = UDR0;                    

    // Re-habilito la interrupción RX  
    UCSR0B |= (1 << RXCIE0);  

    return c;  
}  

void leerPotenciometro(void)  
{  
    // Inicia conversión ADC  
    ADCSRA |= (1 << ADSC);  
    // Espera fin de conversión  
    while (ADCSRA & (1 << ADSC));  
    uint16_t valor = ADC;        // 0–1023  

    // Envia resultado por UART  
    char buf[6];  
    itoa(valor, buf, 10);  

    escribirstring("Potenciometro (A7) = ");  
    escribirstring(buf);  
    escribirstring("\r\n");  
    
    // Muestra los 6 bits más significativos del valor en PORTD (PD2-PD7)
    PORTD = (PORTD & 0x03) | ((valor >> 4) & 0xFC);
}  

void enviarAscii(void)  
{  
    escribirstring("Ingrese caracter: ");  
    char c = recibirchar();       // tomo 1 carácter  
    escribirchar(c);              // eco  
    escribirstring(" -> ASCII = ");  

    char buf2[4];  
    itoa((uint8_t)c, buf2, 10);  

    escribirstring(buf2);  
    escribirstring("\r\n");  
}  

//  
// Interrupt routines  
ISR(USART_RX_vect)  
{  
    char valor = UDR0;  
    // Muestra en PORTD (excepto PD0-PD1) cualquier byte recibido fuera del menú
    PORTD = (PORTD & 0x03) | ((uint8_t)valor & 0xFC);
}