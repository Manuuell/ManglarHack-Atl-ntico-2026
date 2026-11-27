#!/usr/bin/env bash
# Publica la versión web de la app Flutter en /app/ de mimanglar.sentralabs.co.
#
#   cd app && flutter build web --release --base-href /app/
#   DESTINO=usuario@servidor:/var/www/mimanglar/app/ web/scripts/publicar-app.sh app/build/web
#
# Por qué no basta con copiar: el servidor guarda en caché 30 días los .js, y Flutter no les cambia el
# nombre entre compilaciones (main.dart.js, flutter_bootstrap.js). Un teléfono que ya abrió la app
# seguiría con la versión vieja. Aquí se renombran con su huella (main.dart.<hash>.js) y se actualizan
# las referencias; index.html no se guarda en caché, así que cada publicación llega de inmediato.
#
# DESTINO es obligatorio (este repositorio es público: aquí no van servidores ni claves). Para la
# clave SSH usa tu ~/.ssh/config o RSYNC_RSH="ssh -i <clave>".
# El despliegue de la web excluye /app/ (rsync --exclude=/app/), así que no se pisan.
set -euo pipefail

ORIGEN="${1:?Uso: DESTINO=usuario@servidor:/ruta/app/ publicar-app.sh <app/build/web>}"
: "${DESTINO:?Falta DESTINO, por ejemplo usuario@servidor:/var/www/mimanglar/app/}"
[ -f "$ORIGEN/index.html" ] || { echo "✗ $ORIGEN no parece un build web de Flutter (falta index.html)." >&2; exit 1; }
grep -q '<base href="/app/">' "$ORIGEN/index.html" || {
  echo "✗ index.html no tiene <base href=\"/app/\">. Compila con: flutter build web --release --base-href /app/" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp -R "$ORIGEN"/. "$TMP"/
cd "$TMP"

huella() { shasum -a 256 "$1" | cut -c1-10; }
# Reemplaza un nombre de archivo exacto (entre comillas o como atributo) en los archivos que existan.
cambiar() { local viejo="$1" nuevo="$2"; shift 2
  for f in "$@"; do [ -f "$f" ] && VIEJO="$viejo" NUEVO="$nuevo" perl -pi -e 's/(?<![\w.\/-])\Q$ENV{VIEJO}\E(?![\w.-])/$ENV{NUEVO}/g' "$f"; done; return 0; }

if [ -f main.dart.js ]; then
  m="main.dart.$(huella main.dart.js).js"
  mv main.dart.js "$m"
  [ -f main.dart.js.map ] && mv main.dart.js.map "$m.map" && cambiar main.dart.js.map "$m.map" "$m"
  cambiar main.dart.js "$m" flutter_bootstrap.js flutter.js index.html flutter_service_worker.js
  grep -q "$m" flutter_bootstrap.js index.html 2>/dev/null || { echo "✗ No encontré dónde se carga main.dart.js; no publico a medias." >&2; exit 1; }
  echo "· main.dart.js → $m"
fi
if [ -f flutter_bootstrap.js ]; then
  b="flutter_bootstrap.$(huella flutter_bootstrap.js).js"
  mv flutter_bootstrap.js "$b"
  cambiar flutter_bootstrap.js "$b" index.html flutter_service_worker.js
  grep -q "$b" index.html || { echo "✗ index.html no carga flutter_bootstrap.js; no publico a medias." >&2; exit 1; }
  echo "· flutter_bootstrap.js → $b"
fi

rsync -az --delete --exclude=.DS_Store ./ "$DESTINO"
echo "✓ Publicada en $DESTINO"
