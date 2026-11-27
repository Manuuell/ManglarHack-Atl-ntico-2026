// Copia ligera para la web de la cobertura de manglar de la C.R.A. (1:5.000).
//
//   npm run capas:manglar
//
// Entrada: ../datos/cra/manglar_cra_escala_1-5000.geojson (WGS84). Se obtuvo de
//          la geodatabase entregada por la C.R.A. (manglar_escala_1-5000.gdb.zip,
//          capa Cobertura_manglar_Atlantico, EPSG:9377) con GDAL/geopandas.
// Salida:  public/datos/manglar-cra.geojson (simplificada con mapshaper).
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const web = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ENTRADA = path.resolve(web, '../datos/cra/manglar_cra_escala_1-5000.geojson');
const SALIDA = path.resolve(web, 'public/datos/manglar-cra.geojson');
if (!fs.existsSync(ENTRADA)) { console.log(`No está ${ENTRADA}. Nada que convertir.`); process.exit(0); }
fs.mkdirSync(path.dirname(SALIDA), { recursive: true });
const mapshaper = path.resolve(web, 'node_modules/mapshaper/bin/mapshaper');
execFileSync(process.execPath, [mapshaper, ENTRADA, '-simplify', '30%', 'keep-shapes', '-o', 'format=geojson', 'precision=0.000005', SALIDA, 'force'], { stdio: 'inherit' });
const capa = JSON.parse(fs.readFileSync(SALIDA, 'utf8'));
capa.features = capa.features.filter((f) => f.geometry && f.geometry.coordinates?.length);
capa.name = 'cobertura_manglar_cra_1_5000';
capa.fuente = 'Cobertura de manglar del Atlántico, C.R.A., escala 1:5.000 (imágenes Maxar 2021–2022, verificación en campo).';
fs.writeFileSync(SALIDA, JSON.stringify(capa));
const ha = capa.features.reduce((s, f) => s + (f.properties.area_ha || 0), 0);
console.log(`Escrito ${path.relative(web, SALIDA)}: ${capa.features.length} polígonos, ${ha.toFixed(1)} ha, ${(fs.statSync(SALIDA).size / 1048576).toFixed(2)} MB.`);
