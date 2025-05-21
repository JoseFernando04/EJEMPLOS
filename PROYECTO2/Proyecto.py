import sys
import time
import serial
from Adafruit_IO import MQTTClient

# Configuración de usuario y clave de Adafruit IO
// AIO_USER = "JosFer"
// ADAFRUIT_IO_KEY = "aio_ODME42cWXbA32WPyXCykQdCYOErN"

# Diccionario de feeds para cada servo
SERVO_FEEDS = {
    "A": {"TX": "MotorA_TX", "RX": "MotorA_RX"},
    "B": {"TX": "MotorB_TX", "RX": "MotorB_RX"},
    "C": {"TX": "MotorC_TX", "RX": "MotorC_RX"},
    "D": {"TX": "MotorD_TX", "RX": "MotorD_RX"}
}

# Inicialización del puerto serie
try:
    arduino = serial.Serial(
        port='COM6',  # Cambia según corresponda
        baudrate=9600,
        timeout=1
    )
    print(f"Puerto serie abierto: {arduino.name}")
except serial.SerialException as err:
    print(f"No se pudo abrir el puerto serie: {err}")
    sys.exit(1)

def on_connect(client):
    print('\nConexión exitosa a Adafruit IO')
    for key, feed in SERVO_FEEDS.items():
        print(f"Suscribiendo a {feed['SEND']}")
        client.subscribe(feed["SEND"])
    print('Listo para recibir instrucciones...')

def on_disconnect(client):
    print("Desconectado de Adafruit IO")
    sys.exit(1)

def on_message(client, feed_id, payload):
    print(f'Feed {feed_id} envió: {payload}')
    servo_id = None

    # Determinar a qué servo corresponde el feed
    for s, feed in SERVO_FEEDS.items():
        if feed_id == feed["SEND"]:
            servo_id = s
            break

    if servo_id is None:
        print(f"Feed no reconocido: {feed_id}")
        return

    try:
        pos = int(payload)
        pos = max(0, min(180, pos))
        command = f"{servo_id}:{pos}\r\n"
        arduino.write(command.encode('utf-8'))
        print(f"Enviado a Arduino: {command.strip()}")

        # Esperar confirmación del Arduino
        start = time.time()
        confirmed = False

        while time.time() - start < 1:
            if arduino.in_waiting:
                try:
                    reply = arduino.readline().decode('utf-8', errors='ignore').strip()
                    if reply.startswith("OK"):
                        print(f"Arduino confirmó: {reply}")
                        client.publish(SERVO_FEEDS[servo_id]["RECV"], str(pos))
                        confirmed = True
                        break
                except Exception as err:
                    print(f"Error leyendo confirmación: {err}")
                    break

        if not confirmed:
            print("No se recibió confirmación del Arduino")

    except ValueError:
        print(f"Valor recibido no válido: {payload}")
    except Exception as err:
        print(f"Error al enviar comando: {err}")

# Configuración del cliente MQTT
try:
    mqtt = MQTTClient(AIO_USER, AIO_KEY)
    mqtt.on_connect = on_connect
    mqtt.on_disconnect = on_disconnect
    mqtt.on_message = on_message

    mqtt.connect()
    mqtt.loop_background()

    print("Sistema iniciado. Esperando instrucciones...")

    # Bucle principal
    while True:
        try:
            # Leer mensajes del Arduino si existen
            if arduino.in_waiting:
                try:
                    data = arduino.readline().decode('utf-8', errors='ignore').strip()
                    if data and not data.startswith("OK"):
                        print(f"Arduino dice: {data}")

                        # Si es reporte de posición, actualizar feed
                        if data.startswith("POS:"):
                            items = data[4:].split(',')
                            for item in items:
                                if ':' in item:
                                    s_id, val = item.split(':')
                                    s_id = s_id[0]
                                    if s_id in SERVO_FEEDS:
                                        try:
                                            ang = int(val)
                                            mqtt.publish(SERVO_FEEDS[s_id]["RECV"], str(ang))
                                            print(f"Feed {SERVO_FEEDS[s_id]['RECV']} actualizado con {ang}")
                                        except ValueError:
                                            print(f"Valor no válido en respuesta: {val}")
                except Exception as err:
                    print(f"Error leyendo del puerto serie: {err}")

            time.sleep(0.1)

        except KeyboardInterrupt:
            print("\nCerrando recursos...")
            arduino.close()
            mqtt.disconnect()
            sys.exit(0)

        except Exception as err:
            print(f"Error en el ciclo principal: {err}")
            time.sleep(1)

except Exception as err:
    print(f"Error al iniciar: {err}")
    if 'arduino' in locals() and arduino.is_open:
        arduino.close()
    sys.exit(1)