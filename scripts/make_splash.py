"""Pantalla de inicio de la app de pasajeros a partir del diseño del dueño (docs/marca/faxi-inicio.png).
Uso (desde la raíz):  python3 scripts/make_splash.py
Saca la palabra "faxi" y el punto del diseño (fondo degradado verde) y genera:
  · splash-icon.png  logo sobre transparente para la pantalla nativa (fondo liso SPLASH_BG en app.config.ts)
  · intro-logo.png   el mismo logo, recortado, para la pantalla de entrada animada (src/Intro.tsx)
  · intro-bg.png     el degradado diagonal del diseño, para el fondo de la pantalla de entrada
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'docs/marca/faxi-inicio.png'
OUT = ROOT / 'apps/passenger/assets'
TOP, BOTTOM = (0x05, 0xE0, 0x72), (0x00, 0x54, 0x4F)   # degradado: arriba-izquierda → abajo-derecha
LETTER, DOT = (0xF7, 0xFD, 0xF6), (0x00, 0xBE, 0x63)
S = 4

im = np.asarray(Image.open(SRC).convert('RGB')).astype(float)
h, w, _ = im.shape
yy, xx = np.mgrid[0:h, 0:w]
t = (xx / (w - 1) + yy / (h - 1)) / 2
bg_r = TOP[0] + (BOTTOM[0] - TOP[0]) * t

# Letras: el canal rojo del fondo es casi 0 y el de las letras ~247 → transparencia limpia.
alpha = np.clip((im[..., 0] - bg_r) / (LETTER[0] - bg_r), 0, 1)
ys, xs = np.nonzero(alpha > 0.5)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()

# Punto: se busca a la derecha de la "i", por color, y se redibuja como círculo perfecto.
g_dev = np.abs(im[..., 1] - DOT[1]) < 25
region = np.zeros_like(g_dev)
region[y0:y1 + 40, x1 + 1:] = True
dy, dx = np.nonzero(g_dev & region & (im[..., 0] < 20) & (np.abs(im[..., 2] - DOT[2]) < 20))
cx, cy, rad = (dx.min() + dx.max()) / 2, (dy.min() + dy.max()) / 2, (dx.max() - dx.min() + 1) / 2

L, R, T_, B = int(x0) - 2, int(cx + rad) + 3, int(min(y0, cy - rad)) - 2, int(max(y1, cy + rad)) + 3
mark = Image.new('RGBA', ((R - L) * S, (B - T_) * S), (0, 0, 0, 0))
letters = Image.new('RGBA', (R - L, B - T_), LETTER + (0,))
a = Image.fromarray((alpha[T_:B, L:R] * 255).astype('uint8'))
letters.putalpha(a)
mark.alpha_composite(letters.resize(mark.size, Image.LANCZOS))
d = ImageDraw.Draw(mark)
d.ellipse([(cx - rad - L) * S, (cy - rad - T_) * S, (cx + rad - L) * S, (cy + rad - T_) * S], fill=DOT + (255,))
mark = mark.resize((R - L, B - T_), Image.LANCZOS)


def save(img, name):
    img.save(OUT / name, optimize=True)
    print('·', (OUT / name).relative_to(ROOT), img.size)


save(mark, 'intro-logo.png')

# Pantalla nativa: lienzo 1024 con el logo del mismo ancho que antes (637 px), centrado.
icon = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
k = 637 / mark.width
m = mark.resize((637, round(mark.height * k)), Image.LANCZOS)
icon.alpha_composite(m, ((1024 - m.width) // 2, (1024 - m.height) // 2))
save(icon, 'splash-icon.png')

# Degradado para la pantalla de entrada (se estira a la pantalla).
GW, GH = 540, 1170
gy, gx = np.mgrid[0:GH, 0:GW]
gt = ((gx / (GW - 1) + gy / (GH - 1)) / 2)[..., None]
grad = np.array(TOP) + (np.array(BOTTOM) - np.array(TOP)) * gt
save(Image.fromarray(np.round(grad).astype('uint8'), 'RGB'), 'intro-bg.png')
mid = tuple(round((a + b) / 2) for a, b in zip(TOP, BOTTOM))
print('SPLASH_BG = #%02X%02X%02X' % mid)
