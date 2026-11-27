"""Prepara el ARTE OFICIAL de Zanky (render 3D de ../marca/zanky/) para la app: assets, íconos y arranque.

Uso (desde app/):  python tool/preparar_arte_zanky.py [animos] [etapas] [iconos] [arranque]
Sin argumentos hace todo. Necesita Pillow >= 10 con WebP, numpy y scipy. Las fuentes son solo lectura:
  ../marca/zanky/animos/zanky-{feliz,curioso,preocupado,celebrando}.png   (1024 px, transparentes)
  ../marca/zanky/materiales/09-etapas-de-crecimiento.jpg                  (5 etapas sobre fondo liso)
  ../marca/zanky/materiales/11-icono-app.jpg                              (ícono: pin blanco con la cara de Zanky)

Qué escribe (todo con rutas relativas a app/):
  assets/zanky/zanky-<animo>.webp            4 ánimos, 512 px, WebP con alfa
  assets/zanky/etapas/etapa-<n>.webp         5 etapas de crecimiento, fondo quitado, mismo lienzo y misma escala
  android/.../mipmap-*/ic_launcher.png       ícono clásico (48 a 192 px, esquinas redondeadas)
  android/.../drawable-nodpi/ic_launcher_foreground.png   primer plano del ícono adaptativo (zona segura 66 %)
  android/.../drawable-nodpi/zanky_arranque.png           Zanky feliz para la pantalla de arranque
  web/favicon.png, web/icons/*.png           íconos de la web y de la PWA (los «maskable» con margen seguro)
  web/zanky-arranque.webp                    Zanky feliz pequeño para la pantalla de carga de la web

Nota: tool/generar_iconos.py dibujaba los íconos viejos en código; para los íconos, ESTE script manda.
"""
import sys
from collections import deque
from pathlib import Path

import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw, ImageFilter

RAIZ = Path(__file__).resolve().parent.parent
MARCA = RAIZ.parent / "marca" / "zanky"
ASSETS = RAIZ / "assets" / "zanky"
RES = RAIZ / "android" / "app" / "src" / "main" / "res"
WEB = RAIZ / "web"

ANIMOS = ["feliz", "curioso", "preocupado", "celebrando"]
LADO_ANIMO = 512
CALIDAD = 82
AGUA = (0x1F, 0xA2, 0xA6)        # color de marca (Zc.cienaga)
FONDO_ICONO = (0x3B, 0xAC, 0xAD)  # el teal real del ícono de Manuel (para que el adaptativo no tenga costura)


def webp(img, ruta, calidad=CALIDAD):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    img.save(ruta, "WEBP", quality=calidad, method=6, alpha_quality=90)
    print(f"  {ruta.relative_to(RAIZ)}  {ruta.stat().st_size / 1024:.1f} KB  {img.size}")


def png(img, ruta):
    ruta.parent.mkdir(parents=True, exist_ok=True)
    if ruta.parent.name == "icons":
        # Paleta de 256 colores con difuminado: ~6x más liviano, PSNR > 36 dB (no se nota).
        img = img.convert("RGBA").quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
    img.save(ruta, "PNG", optimize=True)
    print(f"  {ruta.relative_to(RAIZ)}  {ruta.stat().st_size / 1024:.1f} KB  {img.size}")


# ───────────────────────────── ánimos ─────────────────────────────
def animos():
    print("Ánimos:")
    total = 0
    for a in ANIMOS:
        im = Image.open(MARCA / "animos" / f"zanky-{a}.png").convert("RGBA")
        # Se premultiplica con LANCZOS para que los bordes transparentes no sangren un halo oscuro.
        im = im.resize((LADO_ANIMO, LADO_ANIMO), Image.LANCZOS)
        ruta = ASSETS / f"zanky-{a}.webp"
        webp(im, ruta)
        total += ruta.stat().st_size
    print(f"  TOTAL {total / 1024:.1f} KB")


# ───────────────────────────── etapas ─────────────────────────────
def _fondo_por_inundacion(rgb, umbral):
    """Máscara del fondo liso: píxeles casi blancos conectados con el borde de la imagen."""
    h, w, _ = rgb.shape
    cerca = (255 - rgb.astype(np.int16)).max(axis=2) <= umbral
    fondo = np.zeros((h, w), bool)
    cola = deque()
    for x in range(w):
        for y in (0, h - 1):
            if cerca[y, x] and not fondo[y, x]:
                fondo[y, x] = True
                cola.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if cerca[y, x] and not fondo[y, x]:
                fondo[y, x] = True
                cola.append((y, x))
    while cola:
        y, x = cola.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and cerca[ny, nx] and not fondo[ny, nx]:
                fondo[ny, nx] = True
                cola.append((ny, nx))
    return fondo


def etapas():
    print("Etapas:")
    rgb = np.array(Image.open(MARCA / "materiales" / "09-etapas-de-crecimiento.jpg").convert("RGB"))
    fondo = _fondo_por_inundacion(rgb, 28)
    # Borde suave: se reduce la máscara de fondo 1 px y se difumina, y los píxeles de la orilla que
    # todavía son muy claros se vuelven más transparentes (quita el halo blanco del JPG).
    objeto = Image.fromarray(((~fondo) * 255).astype(np.uint8))
    objeto = objeto.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.9))
    alfa = np.array(objeto).astype(np.float32)
    claridad = rgb.astype(np.float32).min(axis=2)
    orilla = (alfa < 250) & (alfa > 0)
    alfa[orilla] *= np.clip((255 - claridad[orilla]) / 70.0, 0.25, 1.0)
    rgba = np.dstack([rgb, alfa.astype(np.uint8)])
    hoja = Image.fromarray(rgba, "RGBA")

    # Cada etapa es una isla de píxeles (de izquierda a derecha). La 4 y la 5 se tocan con las hojas y el
    # propágulo: la isla grande se parte con un corte vertical donde hay menos píxeles de objeto.
    sol = np.array(objeto) > 40
    islas, n = ndimage.label(sol)
    areas = ndimage.sum(sol, islas, range(1, n + 1))
    islas_x = sorted((k + 1 for k in range(n) if areas[k] > 5000), key=lambda k: np.where(islas == k)[1].min())
    mascaras = [islas == k for k in islas_x]
    assert len(mascaras) == 4, len(mascaras)
    grande = mascaras.pop()
    cuenta = grande.sum(axis=0)
    xs = np.where(cuenta > 0)[0]
    centro = (xs.min() + xs.max()) // 2
    corte = int(np.argmin(cuenta[centro - 120:centro + 120])) + centro - 120
    print(f"  corte entre las etapas 4 y 5 en x={corte}")
    izq, der = grande.copy(), grande.copy()
    izq[:, corte:] = False
    der[:, :corte] = False
    mascaras += [izq, der]
    cajas = []
    for m in mascaras:
        ys, xs = np.where(m)
        cajas.append((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    # Todas se escalan igual y se pegan a la misma línea del suelo: así se ve cuánto crece.
    alto = max(c[3] - c[1] for c in cajas)
    ancho = max(c[2] - c[0] for c in cajas)
    escala = 440 / alto
    lw, lh = round(ancho * escala) + 16, round(alto * escala) + 16
    print(f"  lienzo {lw}x{lh}, escala {escala:.3f}")
    for i, (c, m) in enumerate(zip(cajas, mascaras), 1):
        propia = Image.fromarray(np.where(m, np.array(hoja)[..., 3], 0).astype(np.uint8))
        pieza = hoja.copy()
        pieza.putalpha(propia)
        rec = pieza.crop(c)
        rec = rec.resize((round(rec.width * escala), round(rec.height * escala)), Image.LANCZOS)
        lienzo = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
        lienzo.paste(rec, ((lw - rec.width) // 2, lh - 8 - rec.height), rec)
        webp(lienzo, ASSETS / "etapas" / f"etapa-{i}.webp", 80)
        # Sola: recortada a su dibujo en un lienzo cuadrado. A escala, el propágulo ocupa el 31 % x 27 % del lienzo y
        # mostrado solo en 64 px se ve como una mancha; para eso está esta versión (la de escala sirve para comparar).
        lado = max(rec.width, rec.height) + 16
        sola = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
        sola.paste(rec, ((lado - rec.width) // 2, lado - 8 - rec.height), rec)
        webp(sola.resize((256, 256), Image.LANCZOS), ASSETS / "etapas" / f"etapa-{i}-sola.webp", 80)
    print("  proporciones (alto/ancho de lienzo):", round(lh / lw, 4))


# ───────────────────────────── ícono ─────────────────────────────
def _esquinas_blancas_a_teal(im):
    """El JPG del ícono es un cuadrado redondeado sobre blanco: las esquinas se rellenan con el teal."""
    a = np.array(im.convert("RGB"))
    h, w, _ = a.shape
    blanco = (255 - a.astype(np.int16)).max(axis=2) <= 40
    fondo = np.zeros((h, w), bool)
    cola = deque()
    for (y, x) in ((0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)):
        fondo[y, x] = True
        cola.append((y, x))
    while cola:
        y, x = cola.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and blanco[ny, nx] and not fondo[ny, nx]:
                fondo[ny, nx] = True
                cola.append((ny, nx))
    m = Image.fromarray((fondo * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))
    relleno = Image.new("RGB", (w, h), FONDO_ICONO)
    return Image.composite(relleno, im.convert("RGB"), m)


def _icono_base():
    """Cuadrado de 1600 px a sangre: sin esquinas blancas."""
    im = Image.open(MARCA / "materiales" / "11-icono-app.jpg").convert("RGB")
    return _esquinas_blancas_a_teal(im)


def _esquinas_redondas(im, radio_rel=0.2):
    im = im.convert("RGBA")
    s = 4
    m = Image.new("L", (im.width * s, im.height * s), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, m.width - 1, m.height - 1], radius=int(m.width * radio_rel), fill=255)
    im.putalpha(m.resize(im.size, Image.LANCZOS))
    return im


def _primer_plano(base):
    """Pin + cara de Zanky sin el fondo teal (silueta = todo lo que no es agua conectada con el borde)."""
    a = np.array(base.convert("RGB")).astype(np.float32) / 255
    mx, mn = a.max(axis=2), a.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    agua = (g > r + 0.05) & (b > r + 0.05) & (sat > 0.18) & (abs(g - b) < 0.12)
    h, w = agua.shape
    conectada = np.zeros((h, w), bool)
    cola = deque()
    for x in range(w):
        for y in (0, h - 1):
            if agua[y, x] and not conectada[y, x]:
                conectada[y, x] = True
                cola.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if agua[y, x] and not conectada[y, x]:
                conectada[y, x] = True
                cola.append((y, x))
    while cola:
        y, x = cola.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and agua[ny, nx] and not conectada[ny, nx]:
                conectada[ny, nx] = True
                cola.append((ny, nx))
    obj = Image.fromarray(((~conectada) * 255).astype(np.uint8))
    # Quita motas sueltas (reflejos): se queda con lo grande y lo cierra.
    obj = obj.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(5))
    alfa = obj.filter(ImageFilter.GaussianBlur(1.6))
    pf = base.convert("RGBA")
    pf.putalpha(alfa)
    return pf.crop(pf.getbbox())


def _sobre_lienzo(pf, lado, alto_rel):
    """Centra el primer plano en un lienzo cuadrado; su lado mayor ocupa alto_rel del lienzo."""
    k = alto_rel * lado / max(pf.size)
    p = pf.resize((max(1, round(pf.width * k)), max(1, round(pf.height * k))), Image.LANCZOS)
    lienzo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    lienzo.paste(p, ((lado - p.width) // 2, (lado - p.height) // 2), p)
    return lienzo


def iconos():
    print("Íconos:")
    base = _icono_base()
    pf = _primer_plano(base)
    # Para el centrado óptico, el pin pesa arriba: se centra por la caja y se sube un pelo en el adaptativo.
    # Android clásico (esquinas redondeadas, por si el sistema no usa el adaptativo)
    for carpeta, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        png(_esquinas_redondas(base.resize((px, px), Image.LANCZOS)), RES / f"mipmap-{carpeta}" / "ic_launcher.png")
    # Adaptativo: 432 px (108 dp a 4x). La zona segura es el círculo central de 66 dp (61 %); el pin
    # entra con su lado mayor en ~60 % del lienzo.
    png(_sobre_lienzo(pf, 432, 0.60), RES / "drawable-nodpi" / "ic_launcher_foreground.png")
    # Web: «any» con esquinas redondeadas, «maskable» a sangre con el pin dentro del 80 % central.
    png(_esquinas_redondas(base.resize((192, 192), Image.LANCZOS)), WEB / "icons" / "Icon-192.png")
    png(_esquinas_redondas(base.resize((512, 512), Image.LANCZOS)), WEB / "icons" / "Icon-512.png")
    for px in (192, 512):
        fondo = Image.new("RGBA", (px, px), FONDO_ICONO + (255,))
        fondo.alpha_composite(_sobre_lienzo(pf, px, 0.66))
        png(fondo.convert("RGB"), WEB / "icons" / f"Icon-maskable-{px}.png")
    png(base.resize((180, 180), Image.LANCZOS), WEB / "icons" / "apple-touch-icon.png")
    png(_esquinas_redondas(base.resize((64, 64), Image.LANCZOS), 0.22), WEB / "favicon.png")


# ───────────────────────────── arranque ─────────────────────────────
def arranque():
    print("Arranque:")
    feliz = Image.open(MARCA / "animos" / "zanky-feliz.png").convert("RGBA")
    png(feliz.resize((288, 288), Image.LANCZOS), RES / "drawable-nodpi" / "zanky_arranque.png")
    webp(feliz.resize((256, 256), Image.LANCZOS), WEB / "zanky-arranque.webp", 80)


PASOS = {"animos": animos, "etapas": etapas, "iconos": iconos, "arranque": arranque}

if __name__ == "__main__":
    pedidos = sys.argv[1:] or list(PASOS)
    for p in pedidos:
        PASOS[p]()
