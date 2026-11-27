# Estación ESP32 para Zanky

Una estación mide nivel de agua, una estimación de salinidad basada en TDS, temperatura y, si se instala, turbidez. Cada magnitud se registra como **un sensor distinto** en `public.sensores`, porque así está definido el esquema existente. El firmware agrupa hasta 32 muestras en memoria RTC, despierta cada `INTERVALO_MINUTOS` y envía un lote HTTPS por sensor. Un reintento con la misma fecha no duplica filas.

## Materiales y presupuesto orientativo

Precios de consulta en Colombia, noviembre de 2026; confirmar disponibilidad, envío y protección de campo antes de comprar.

| Componente | COP aproximados |
|---|---:|
| [ESP32 DevKit](https://gyoingenieria.com/producto/esp32-devkit-v1) | 28.000 |
| [JSN-SR04T](https://electronilab.co/etiqueta-producto/ultrasonido/) | 36.900 |
| [Sonda DS18B20](https://electronilab.co/tienda/sensor-de-temperatura-ds18b20-tipo-sonda/) | 9.900 |
| [Kit TDS analógico](https://electronilab.co/tienda/sensor-medidor-tds-solidos-disueltos-totales-calidad-agua-ppm/) | 62.900 |
| [Turbidez óptica, opcional](https://electronilab.co/tienda/sensor-optico-turbidez-liquida-agua-analogico-de-particulas/) | 62.900 |
| Caja IP65, prensaestopas, divisor de nivel, cables, soporte y alimentación | 80.000–180.000, cotizar localmente |
| **Total estimado sin turbidez** | **217.700–317.700** |
| **Total estimado con turbidez** | **280.600–380.600** |

La protección, energía solar y mantenimiento pueden costar más que la electrónica. Una sonda TDS económica suele cubrir agua dulce o salobre de baja conductividad; **no sirve para afirmar salinidad marina sin verificar rango, calibración y resistencia a corrosión**. Para agua más salina, sustituirla por una sonda EC de rango alto y ajustar la curva.

## Conexión

```text
ESP32                    Sensor / módulo
5 V  ------------------- JSN-SR04T VCC; módulo TDS VCC; turbidez VCC si aplica
GND  ------------------- tierra común de todos los módulos
GPIO 5 ----------------- JSN TRIG
JSN ECHO (5 V) --------- divisor resistivo 10 kΩ / 20 kΩ ---> GPIO 18 (máx. 3,3 V)
GPIO 34 (ADC1) <--------- TDS analógico, con divisor si su salida excede 3,3 V
GPIO 35 (ADC1) <--------- turbidez analógica opcional, con divisor a 3,3 V
GPIO 4 ----------------- DS18B20 DATA; resistencia 4,7 kΩ a 3,3 V
3,3 V ------------------ DS18B20 VCC
```

Si se usa divisor en una salida analógica, las constantes de calibración deben referirse al voltaje **que recibe el ESP32**. No alimentar el ESP32 directamente de una celda sin regulador ni exponer el módulo de la sonda al agua.

## Montaje y calibración en un caño

1. Fijar el transductor ultrasónico mirando verticalmente al espejo de agua, protegido de ramas y oleaje lateral. La distancia mínima útil depende de la versión del JSN; dejar al menos 25 cm de espacio ciego. Medir desde la cara del transductor al fondo de referencia y ponerlo en `ALTURA_REFERENCIA_M`. El nivel calculado es altura de agua sobre ese fondo; anotar la cota y no mover el soporte sin recalibrar.
2. Colocar las sondas de agua dentro de una protección perforada, bajo la lámina de agua incluso en bajamar, lejos del sedimento y sin tensar cables. La caja y conexiones eléctricas quedan por encima de la pleamar, con prensaestopas, desecante y fijación que permita retirarla para limpieza. Verificar permisos y seguridad de instalación local.
3. Para temperatura, comparar el DS18B20 en dos baños con termómetro de referencia y ajustar `AJUSTE_TEMPERATURA_C`. Para nivel, contrastar al menos dos alturas conocidas y ajustar `ALTURA_REFERENCIA_M` / `AJUSTE_NIVEL_M`.
4. Para TDS, medir dos soluciones patrón dentro del rango real de la sonda y registrar voltaje ADC y valor conocido en ppt. Calcular `SAL_PENDIENTE_PPT_V = (ppt₂-ppt₁)/(V₂-V₁)` y `SAL_ORIGEN_PPT = ppt₁ - pendiente×V₁`. Repetir con temperatura conocida; la compensación de 2 %/°C es aproximada. La salida de este sketch es un **indicador calibrado localmente**, no una determinación de laboratorio. Para turbidez, repetir dos puntos con patrones NTU y sus dos constantes.
5. Revisar bioincrustación y deriva al menos semanalmente al principio; comparar con medición manual y registrar cada limpieza y recalibración. Ajustar los umbrales con el equipo ambiental, nunca desde una sola lectura de prueba.

## Preparación

Instalar Arduino IDE, soporte de placas ESP32 y las bibliotecas `OneWire` y `DallasTemperature`. Copiar `config.example.h` a `config.h` y completar WiFi, URL, certificado raíz PEM, UUID y token de cada canal; `config.h` está ignorado por Git. Registrar esos cuatro sensores y sus hashes siguiendo [la guía de ingesta](../../docs/sensores.md). Seleccionar una placa ESP32 compatible y cargar `esp32-sensor.ino`.

El firmware usa TLS con validación del certificado raíz; no desactivar esa verificación. Necesita NTP para fechar las lecturas. Si nace sin WiFi, conserva los valores con número de ciclo y estima su fecha cuando sincroniza; esa estimación supone intervalos de despertar constantes. Con señal intermitente, las lecturas con reloj válido conservan su hora original. La cola RTC de 32 muestras sobrevive a `deep sleep`, pero **se pierde al cortar alimentación o reiniciar**; al llenarse, descarta las más antiguas. Para operación de campo sostenida, cambiarla por una cola circular en FRAM o flash con control de desgaste, y añadir reloj RTC si el primer arranque puede ser sin red.

## Variante LoRa

En sitios sin WiFi, un ESP32 con radio LoRa puede enviar el mismo lote por radio a una pasarela con internet. El nodo conserva el muestreo, la calibración y su cola; la pasarela autentica y reenvía por HTTPS a `lectura-sensor` usando el token de cada canal. **El token nunca debe viajar en claro por LoRa**: usar cifrado/autenticación del enlace y protección contra repetición, o guardar los tokens solo en la pasarela y asociar cada nodo a canales permitidos. Esta variante es una arquitectura de montaje, no un sketch LoRa probado. Respetar el plan de frecuencias y límites de potencia aplicables antes de transmitir.
