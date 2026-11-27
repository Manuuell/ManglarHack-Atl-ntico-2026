#pragma once
// Copiar como config.h y completar localmente. Nunca publicar config.h.
#define WIFI_NOMBRE "NOMBRE_DE_LA_RED"
#define WIFI_CLAVE "CLAVE_DE_LA_RED"
#define URL_INGESTA "https://TU_PROYECTO.supabase.co/functions/v1/lectura-sensor"
// Certificado raíz PEM que firma el dominio HTTPS. Actualizarlo cuando venza.
#define CERTIFICADO_RAIZ R"PEM(-----BEGIN CERTIFICATE-----
PEGAR_AQUI_CERTIFICADO_RAIZ_PEM
-----END CERTIFICATE-----)PEM"

// Una estación física registra un sensor Supabase por magnitud; cada uno tiene su token.
#define ID_NIVEL "UUID_DEL_SENSOR_NIVEL"
#define TOKEN_NIVEL "TOKEN_ALEATORIO_DEL_SENSOR_NIVEL"
#define ID_SALINIDAD "UUID_DEL_SENSOR_SALINIDAD"
#define TOKEN_SALINIDAD "TOKEN_ALEATORIO_DEL_SENSOR_SALINIDAD"
#define ID_TEMPERATURA "UUID_DEL_SENSOR_TEMPERATURA"
#define TOKEN_TEMPERATURA "TOKEN_ALEATORIO_DEL_SENSOR_TEMPERATURA"
#define USAR_TURBIDEZ false
#define ID_TURBIDEZ "UUID_DEL_SENSOR_TURBIDEZ"
#define TOKEN_TURBIDEZ "TOKEN_ALEATORIO_DEL_SENSOR_TURBIDEZ"

#define INTERVALO_MINUTOS 10
#define ALTURA_REFERENCIA_M 2.00f  // distancia vertical del transductor al fondo
#define AJUSTE_NIVEL_M 0.00f
#define AJUSTE_TEMPERATURA_C 0.00f
// Calibración de dos puntos con soluciones patrón: ppt = pendiente * voltios + origen.
// Los valores de ejemplo NO convierten la sonda TDS en instrumento marino.
#define SAL_PENDIENTE_PPT_V 1.00f
#define SAL_ORIGEN_PPT 0.00f
#define TURB_PENDIENTE_NTU_V 1.00f
#define TURB_ORIGEN_NTU 0.00f

