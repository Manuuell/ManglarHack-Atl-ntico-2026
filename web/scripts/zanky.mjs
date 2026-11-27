// Prepara el arte oficial de Zanky (../marca/zanky, de Manuel) para la web.
//
//   npm run marca:zanky
//
// - Los 4 ánimos (PNG transparentes de 1024 px) → WebP de 256 y 512 px.
// - El ícono de la app → favicons PNG (32, 192, 512) y apple-touch-icon (180).
// - La portada 16:9 → imagen para compartir (og) de 1200×630.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const web = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const marca = path.resolve(web, '../marca/zanky');
const salida = path.resolve(web, 'public/marca/zanky');
if (!fs.existsSync(marca)) { console.log(`No está ${marca}. Nada que preparar.`); process.exit(0); }
fs.mkdirSync(salida, { recursive: true });

for (const animo of ['feliz', 'curioso', 'preocupado', 'celebrando']) {
  const origen = path.join(marca, 'animos', `zanky-${animo}.png`);
  for (const lado of [256, 512]) {
    await sharp(origen).resize(lado, lado).webp({ quality: 82, alphaQuality: 90 }).toFile(path.join(salida, `zanky-${animo}-${lado}.webp`));
  }
}
const icono = path.join(marca, 'materiales', '11-icono-app.jpg');
await sharp(icono).resize(32, 32).png().toFile(path.join(web, 'public/favicon-32.png'));
await sharp(icono).resize(192, 192).png().toFile(path.join(web, 'public/icon-192.png'));
await sharp(icono).resize(512, 512).png().toFile(path.join(web, 'public/icon-512.png'));
await sharp(icono).resize(180, 180).png().toFile(path.join(web, 'public/apple-touch-icon.png'));
await sharp(path.join(marca, 'materiales', '13-portada-16x9.jpg')).resize(1200, 630, { fit: 'cover' }).jpeg({ quality: 82 }).toFile(path.join(web, 'public/og-zanky.jpg'));

const peso = fs.readdirSync(salida).reduce((s, f) => s + fs.statSync(path.join(salida, f)).size, 0);
console.log(`Arte de Zanky listo en public/ (ánimos: ${(peso / 1024).toFixed(0)} KB en total).`);
