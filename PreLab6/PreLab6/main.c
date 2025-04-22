/*
 * PreLab6.c
 *
 * Created: 20/04/2025
 * Author : JOSÉ GORDILLO
 */ 

// Encabezado (Libraries)
#include <avr/io.h>
#include <avr/interrupt.h>
//
// Function prototypes
void setup();
void initUart();
void escribirchar(char letra);
void escribirString(char* str);

//
// Main Function
int main(void)
{
	setup();
	escribirString("23460");
	while (1)
	{
		
	}
}
//
// NON-Interrupt subroutines
void setup()
{
	cli();
	initUart();
	DDRB=0xFF;
	PORTB=0x00;
	sei();
	
}

void initUart()
{
	//PInes de comunicación, PD0 y PD1  rx y tx
	DDRD |= (1<<DDD1);
	DDRD &= ~(1<<DDD0);
	
	
	// Configuramos el UCSR0A,Todos en 0 para este caso.
	UCSR0A=0;
	//Configuramos el UCSR0B, Habilitamos interrupciónes al recibir , Habilitamos recepcion y transmisión.
	UCSR0B |= (1<<RXCIE0)| (1<<RXEN0)| (1<<TXEN0);
	// Modo asincrono.
	UCSR0C =0;
	UCSR0C |= (1<< UCSZ01) | (1<< UCSZ00); //Tamaño del caracter
	//Nos da 9600 de baudrate con una frecuencia de reloj de 16Mhz
	UBRR0= 103;
}

void escribirchar(char letra)
{
	while((UCSR0A & (1<<UDRE0))==0);//Vemos si el buffer No esta listo para recibir datos y lo hacemos esperar
	UDR0=letra; //Mandamos el caracter
}

// Nueva función para enviar una cadena completa
void escribirString(char* str)
{
	for(int i = 0; str[i] != '\0'; i++) {
		escribirchar(str[i]);
	}
}

// Interrupt routines
ISR(USART_RX_vect)
{
	char valor=UDR0;
	PORTB= (uint8_t)valor;
}