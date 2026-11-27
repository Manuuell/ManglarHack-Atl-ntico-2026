"""Genera los íconos de la web de Zanky: cara de Zanky con su corona de hojas sobre un pin de ubicación, fondo agua.

Uso (desde app/):  python tool/generar_iconos.py
Necesita Pillow (pip install --user pillow). Escribe en web/: favicon.png, icons/*.png, og-zanky.png.
Todo se dibuja en código a 4x y se reduce, así los bordes salen limpios.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
WEB = RAIZ / "web"
FUENTES = RAIZ / "google_fonts"

AGUA = (0x1F, 0xA2, 0xA6)
AGUA_OSCURA = (0x12, 0x78, 0x7C)
CORTEZA = (0x8B, 0x3A, 0x2B)
CORTEZA_CLARA = (0xA2, 0x4B, 0x39)
HOJA = (0x2E, 0x7D, 0x32)
HOJA_CLARA = (0x43, 0xA0, 0x47)
OJO = (0x1B, 0x12, 0x10)
BLANCO = (255, 255, 255)
SOL = (0xF9, 0xC8, 0x0E)
ROJO = (0xE6, 0x39, 0x46)

S = 4  # sobremuestreo


def degradado(tam, arriba, abajo):
    """Degradado vertical con un brillo suave arriba a la izquierda."""
    w, h = tam
    img = Image.new("RGB", tam)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(round(arriba[i] + (abajo[i] - arriba[i]) * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    brillo = Image.new("L", tam, 0)
    d = ImageDraw.Draw(brillo)
    d.ellipse((-w * 0.2, -h * 0.35, w * 0.75, h * 0.5), fill=70)
    brillo = brillo.filter(ImageFilter.GaussianBlur(w * 0.12))
    return Image.composite(Image.new("RGB", tam, (255, 255, 255)), img, brillo)


def hoja(capa, centro, largo, ancho, grados, color, nervio):
    """Una hoja ovalada brillante, girada, pegada en `capa`."""
    lienzo = Image.new("RGBA", (int(largo * 1.3), int(largo * 1.3)), (0, 0, 0, 0))
    d = ImageDraw.Draw(lienzo)
    cx, cy = lienzo.size[0] / 2, lienzo.size[1] / 2
    d.ellipse((cx - ancho / 2, cy - largo / 2, cx + ancho / 2, cy + largo / 2), fill=color)
    d.line((cx, cy - largo * 0.42, cx, cy + largo * 0.42), fill=nervio, width=max(2, int(ancho * 0.07)))
    lienzo = lienzo.rotate(grados, resample=Image.BICUBIC)
    capa.alpha_composite(lienzo, (int(centro[0] - lienzo.size[0] / 2), int(centro[1] - lienzo.size[1] / 2)))


def dibujar_zanky(lado, margen_seguro=1.0):
    """Capa RGBA (lado x lado, fondo transparente) con el pin + cara + corona de hojas.

    Todo cabe en el círculo seguro de un ícono maskable (80 % del lado) cuando margen_seguro = 1.
    """
    n = lado * S
    k = n / 1000 * margen_seguro
    off = n * (1 - margen_seguro) / 2

    def p(x, y):
        return (off + x * k, off + y * k)

    def caja(cx, cy, rx, ry=None):
        ry = rx if ry is None else ry
        a, b = p(cx - rx, cy - ry), p(cx + rx, cy + ry)
        return (*a, *b)

    capa = Image.new("RGBA", (n, n), (0, 0, 0, 0))

    # Sombra del pin sobre el agua.
    sombra = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(sombra).ellipse(caja(500, 868, 150, 26), fill=(0, 40, 44, 120))
    capa.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(14 * k)))

    # Pin: círculo + punta.
    d = ImageDraw.Draw(capa)
    d.polygon([p(500 - 214, 520), p(500 + 214, 520), p(500, 858)], fill=BLANCO)
    d.ellipse(caja(500, 440, 236), fill=BLANCO)

    # Cara: tronco de mangle (corteza).
    d.ellipse(caja(500, 450, 188), fill=CORTEZA)
    d.ellipse(caja(500, 420, 150, 118), fill=CORTEZA_CLARA)  # brillo de la corteza

    # Mejillas.
    mej = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    dm = ImageDraw.Draw(mej)
    dm.ellipse(caja(392, 510, 34, 24), fill=(255, 140, 120, 150))
    dm.ellipse(caja(608, 510, 34, 24), fill=(255, 140, 120, 150))
    capa.alpha_composite(mej.filter(ImageFilter.GaussianBlur(5 * k)))
    d = ImageDraw.Draw(capa)

    # Ojos grandes con brillo.
    for ex in (436, 564):
        d.ellipse(caja(ex, 452, 40, 46), fill=OJO)
        d.ellipse(caja(ex + 12, 436, 14), fill=BLANCO)
        d.ellipse(caja(ex - 10, 468, 6), fill=BLANCO)

    # Sonrisa ancha.
    a, b = p(412, 458), p(588, 590)
    d.arc((*a, *b), start=20, end=160, fill=OJO, width=int(15 * k))
    # Cejitas de hoja.
    for ex, g in ((436, 18), (564, -18)):
        hoja(capa, p(ex, 392), 62 * k, 24 * k, 90 + g, HOJA_CLARA, HOJA)
    d = ImageDraw.Draw(capa)

    # Corona de hojas (se asoma por arriba del pin).
    base = (500, 300)
    hojas = [
        (-62, 148, 70, HOJA), (62, 148, 70, HOJA),
        (-38, 176, 78, HOJA_CLARA), (38, 176, 78, HOJA_CLARA),
        (-14, 196, 82, HOJA), (14, 196, 82, HOJA_CLARA),
    ]
    for grados, largo, ancho, color in hojas:
        import math
        r = math.radians(grados)
        cx = base[0] + math.sin(r) * largo * 0.5
        cy = base[1] - math.cos(r) * largo * 0.5
        hoja(capa, p(cx, cy), largo * k, ancho * k, -grados, color, HOJA if color == HOJA_CLARA else (0x1B, 0x5E, 0x20))

    # Propágulo: la semilla larga que cuelga como antena.
    d = ImageDraw.Draw(capa)
    d.line([p(536, 176), p(588, 118)], fill=(0x55, 0x8B, 0x2F), width=int(14 * k))
    d.ellipse(caja(592, 112, 16), fill=(0x7C, 0xB3, 0x42))

    # Cintas del Carnaval en la base del pin (rojo, amarillo, verde).
    for i, c in enumerate((ROJO, SOL, (0x2A, 0x9D, 0x8F))):
        x0 = 500 - 54 + i * 36
        d.rounded_rectangle((*p(x0, 770), *p(x0 + 28, 826)), radius=int(10 * k), fill=c)
    return capa.resize((lado, lado), Image.LANCZOS)


def icono(lado, redondeado):
    fondo = degradado((lado, lado), AGUA, AGUA_OSCURA).convert("RGBA")
    fondo.alpha_composite(dibujar_zanky(lado))
    if redondeado:
        m = Image.new("L", (lado * 2, lado * 2), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, lado * 2 - 1, lado * 2 - 1), radius=int(lado * 2 * 0.22), fill=255)
        fondo.putalpha(m.resize((lado, lado), Image.LANCZOS))
    return fondo


def tarjeta_og():
    w, h = 1200, 630
    fondo = degradado((w, h), (0x0F, 0x6B, 0x6F), (0x0A, 0x3F, 0x42)).convert("RGBA")
    # Olas suaves abajo.
    olas = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(olas)
    for i, (y, a) in enumerate(((470, 40), (520, 55), (570, 70))):
        pts = [(x * S, (y + 14 * __import__("math").sin(x / 90 + i * 1.7)) * S) for x in range(0, w + 20, 20)]
        d.polygon(pts + [(w * S, h * S), (0, h * S)], fill=(0x1F, 0xA2, 0xA6, a))
    fondo.alpha_composite(olas.resize((w, h), Image.LANCZOS))
    # Zanky a la izquierda, sobre un disco de agua.
    disco = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(disco).ellipse((60, 60, 570, 570), fill=(0x1F, 0xA2, 0xA6, 255))
    fondo.alpha_composite(disco)
    z = dibujar_zanky(520)
    fondo.alpha_composite(z, (55, 55))
    d = ImageDraw.Draw(fondo)
    f_grande = ImageFont.truetype(str(FUENTES / "Inter-Bold.ttf"), 118)
    f_med = ImageFont.truetype(str(FUENTES / "Inter-SemiBold.ttf"), 46)
    f_peq = ImageFont.truetype(str(FUENTES / "Inter-Medium.ttf"), 28)
    d.text((620, 150), "Zanky", font=f_grande, fill=BLANCO)
    d.text((624, 290), "Guardianes del manglar", font=f_med, fill=(0xDD, 0xF2, 0xF2))
    d.text((624, 360), "Mira qué le pasa al manglar y repórtalo\ndesde tu teléfono. Sin instalar nada.", font=f_peq,
           fill=(0xBF, 0xE6, 0xE6), spacing=8)
    pill = (624, 500, 1060, 562)
    d.rounded_rectangle(pill, radius=31, fill=SOL)
    d.text((624 + 28, 512), "Manglar Hack Atlántico 2026", font=ImageFont.truetype(str(FUENTES / "Inter-SemiBold.ttf"), 28),
           fill=(0x3A, 0x26, 0x00))
    return fondo.convert("RGB")


def main():
    (WEB / "icons").mkdir(parents=True, exist_ok=True)
    # "any": esquinas redondeadas con transparencia. "maskable": a sangre, el sistema recorta (zona segura 80 %).
    for lado in (192, 512):
        icono(lado, True).save(WEB / "icons" / f"Icon-{lado}.png", optimize=True)
        icono(lado, False).convert("RGB").save(WEB / "icons" / f"Icon-maskable-{lado}.png", optimize=True)
    icono(180, False).convert("RGB").save(WEB / "icons" / "apple-touch-icon.png", optimize=True)  # iOS redondea solo
    icono(64, True).save(WEB / "favicon.png", optimize=True)
    tarjeta_og().save(WEB / "og-zanky.png", optimize=True)
    print("Íconos escritos en", WEB)


if __name__ == "__main__":
    main()
