#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <time.h>
#include "config.h"

constexpr int PIN_DISPARO = 5;
constexpr int PIN_ECO = 18;
constexpr int PIN_TDS = 34;      // ADC1: funciona con WiFi encendido
constexpr int PIN_TURBIDEZ = 35; // ADC1
constexpr int PIN_DS18B20 = 4;
constexpr int CAPACIDAD = 32;
constexpr uint32_t HORA_MINIMA = 1700000000UL;

struct Muestra {
  uint8_t canal;
  float valor;
  uint32_t instante;
  uint32_t ciclo;
};
RTC_DATA_ATTR Muestra pendientes[CAPACIDAD];
RTC_DATA_ATTR uint8_t cantidad = 0;
RTC_DATA_ATTR uint32_t cicloActual = 0;

const char* ids[] = {ID_NIVEL, ID_SALINIDAD, ID_TEMPERATURA, ID_TURBIDEZ};
const char* tokens[] = {TOKEN_NIVEL, TOKEN_SALINIDAD, TOKEN_TEMPERATURA, TOKEN_TURBIDEZ};
const char* tipos[] = {"nivel_agua", "salinidad", "temperatura", "turbidez"};
const char* unidades[] = {"m", "ppt", "°C", "NTU"};
OneWire cable(PIN_DS18B20);
DallasTemperature termometro(&cable);

void guardar(uint8_t canal, float valor) {
  if (!isfinite(valor)) return;
  if (cantidad == CAPACIDAD) {
    // La cola RTC es acotada: se conserva lo más reciente.
    memmove(pendientes, pendientes + 1, sizeof(Muestra) * (CAPACIDAD - 1));
    cantidad--;
  }
  const time_t ahora = time(nullptr);
  pendientes[cantidad++] = {canal, valor, ahora >= HORA_MINIMA ? uint32_t(ahora) : 0, cicloActual};
}

float nivelAgua() {
  float suma = 0;
  int validas = 0;
  for (int i = 0; i < 5; i++) {
    digitalWrite(PIN_DISPARO, LOW);
    delayMicroseconds(3);
    digitalWrite(PIN_DISPARO, HIGH);
    delayMicroseconds(10);
    digitalWrite(PIN_DISPARO, LOW);
    const unsigned long eco = pulseIn(PIN_ECO, HIGH, 35000UL);
    const float distancia = eco * 0.0001715f; // m, ida y vuelta a 343 m/s
    if (eco && distancia >= 0.20f && distancia <= 6.0f) {
      suma += distancia;
      validas++;
    }
    delay(80);
  }
  if (validas < 3) return NAN;
  const float nivel = ALTURA_REFERENCIA_M - suma / validas + AJUSTE_NIVEL_M;
  return nivel >= 0 && nivel <= 10 ? nivel : NAN;
}

float voltajePromedio(int pin) {
  float suma = 0;
  for (int i = 0; i < 10; i++) {
    suma += analogReadMilliVolts(pin) / 1000.0f;
    delay(10);
  }
  return suma / 10.0f;
}

String fechaIso(uint32_t segundos) {
  time_t t = segundos;
  struct tm utc;
  gmtime_r(&t, &utc);
  char texto[25];
  strftime(texto, sizeof(texto), "%Y-%m-%dT%H:%M:%SZ", &utc);
  return String(texto);
}

bool conectar() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_NOMBRE, WIFI_CLAVE);
  const unsigned long inicio = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - inicio < 12000UL) delay(200);
  if (WiFi.status() != WL_CONNECTED) return false;
  configTime(0, 0, "pool.ntp.org", "time.google.com");
  const unsigned long relojInicio = millis();
  while (time(nullptr) < HORA_MINIMA && millis() - relojInicio < 10000UL) delay(200);
  return time(nullptr) >= HORA_MINIMA;
}

void enviarCanal(uint8_t canal) {
  String cuerpo = "{\"sensor_id\":\"" + String(ids[canal]) + "\",\"lecturas\":[";
  uint8_t indices[CAPACIDAD];
  uint8_t n = 0;
  const uint32_t ahora = uint32_t(time(nullptr));
  for (uint8_t i = 0; i < cantidad; i++) {
    if (pendientes[i].canal != canal) continue;
    // Si se tomó antes de sincronizar NTP, estimar desde el ciclo de muestreo.
    const uint32_t instante = pendientes[i].instante ? pendientes[i].instante :
      ahora - (cicloActual - pendientes[i].ciclo) * INTERVALO_MINUTOS * 60UL;
    if (n) cuerpo += ',';
    cuerpo += "{\"tipo\":\"" + String(tipos[canal]) + "\",\"valor\":" +
      String(pendientes[i].valor, 3) + ",\"unidad\":\"" + String(unidades[canal]) +
      "\",\"medido_en\":\"" + fechaIso(instante) + "\"}";
    indices[n++] = i;
  }
  if (!n) return;
  cuerpo += "]}";
  WiFiClientSecure cliente;
  cliente.setCACert(CERTIFICADO_RAIZ); // Se verifica TLS; nunca usar setInsecure().
  HTTPClient http;
  if (!http.begin(cliente, URL_INGESTA)) return;
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", "Bearer " + String(tokens[canal]));
  http.setTimeout(10000);
  const int estado = http.POST(cuerpo);
  http.end();
  if (estado != 200) return; // Reintento en el próximo ciclo; la base evita duplicados.
  for (int i = n - 1; i >= 0; i--) {
    const uint8_t indice = indices[i];
    memmove(pendientes + indice, pendientes + indice + 1,
            sizeof(Muestra) * (cantidad - indice - 1));
    cantidad--;
  }
}

void setup() {
  Serial.begin(115200);
  cicloActual++;
  pinMode(PIN_DISPARO, OUTPUT);
  pinMode(PIN_ECO, INPUT);
  analogReadResolution(12);
  termometro.begin();
  termometro.requestTemperatures();
  const float temperatura = termometro.getTempCByIndex(0) + AJUSTE_TEMPERATURA_C;
  const float nivel = nivelAgua();
  guardar(0, nivel);
  if (temperatura >= -5 && temperatura <= 60) guardar(2, temperatura);
  const float voltiosTds = voltajePromedio(PIN_TDS);
  // Compensación térmica aproximada; la curva final depende de la calibración local.
  const float compensacion = isfinite(temperatura) ? 1.0f + 0.02f * (temperatura - 25.0f) : 1.0f;
  const float salinidad = SAL_PENDIENTE_PPT_V * voltiosTds / compensacion + SAL_ORIGEN_PPT;
  if (salinidad >= 0 && salinidad <= 60) guardar(1, salinidad);
  if (USAR_TURBIDEZ) {
    const float turbidez = TURB_PENDIENTE_NTU_V * voltajePromedio(PIN_TURBIDEZ) + TURB_ORIGEN_NTU;
    if (turbidez >= 0 && turbidez <= 4000) guardar(3, turbidez);
  }
  if (conectar()) {
    for (uint8_t canal = 0; canal < (USAR_TURBIDEZ ? 4 : 3); canal++) enviarCanal(canal);
  }
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  esp_sleep_enable_timer_wakeup(uint64_t(INTERVALO_MINUTOS) * 60ULL * 1000000ULL);
  esp_deep_sleep_start();
}

void loop() {}
