"""Genera íconos, íconos adaptativos, pantalla de inicio e ícono de notificación de las apps faxi.
Uso (desde la raíz):  python3 scripts/make_icons.py
Marca: palabra "faxi" en Plus Jakarta Sans ExtraBold con el punto verde (tokens de packages/ui/src/tokens.ts).
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / 'node_modules/@expo-google-fonts/plus-jakarta-sans/800ExtraBold/PlusJakartaSans_800ExtraBold.ttf'
GREEN, GREEN_DARK, MINT, INK, WHITE = '#1B7A57', '#0F5A3F', '#7FD3A8', '#181C1A', '#FFFFFF'
S = 4  # sobremuestreo para bordes suaves


def mark(size, letter_color, dot_color, scale=0.62, bg=None, word=False):
    """'f' + punto (ícono) o 'faxi' + punto (pantalla de inicio), centrado ópticamente."""
    W = size * S
    img = Image.new('RGBA', (W, W), bg or (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    text = 'faxi' if word else 'f'
    font = ImageFont.truetype(str(FONT), int(W * scale))
    l, t, r, b = d.textbbox((0, 0), text, font=font)
    tw, th = r - l, b - t
    dot = int(font.size * 0.20)
    gap = int(font.size * 0.05)
    total_w = tw + gap + dot
    x0 = (W - total_w) // 2 - l
    y0 = (W - th) // 2 - t
    d.text((x0, y0), text, font=font, fill=letter_color)
    bx = x0 + l + tw + gap
    by = y0 + b - dot  # el punto se apoya en la línea base
    d.ellipse([bx, by, bx + dot, by + dot], fill=dot_color)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print('·', path.relative_to(ROOT), img.size)


def app_assets(app, bg, letter, dot):
    a = ROOT / 'apps' / app / 'assets'
    # iOS/Android: 1024 sin transparencia, a sangre (las tiendas redondean las esquinas)
    save(mark(1024, letter, dot, bg=bg).convert('RGB'), a / 'icon.png')
    # Android adaptativo: solo el primer plano, contenido dentro del 66 % central
    save(mark(1024, letter, dot, scale=0.42), a / 'adaptive-icon.png')
    # Pantalla de inicio: palabra completa sobre el color de fondo (lo pone app.config)
    save(mark(1024, letter, dot, scale=0.30, word=True), a / 'splash-icon.png')
    # Notificación Android: silueta blanca sobre transparente
    save(mark(96, WHITE, WHITE, scale=0.70), a / 'notification-icon.png')


app_assets('passenger', GREEN, WHITE, MINT)
app_assets('driver', INK, WHITE, '#2FB37E')

# Admin (web): favicon y vista previa
admin = ROOT / 'apps/admin/src/app'
save(mark(512, WHITE, MINT, bg=GREEN).convert('RGB'), admin / 'icon.png')
save(mark(180, WHITE, MINT, bg=GREEN).convert('RGB'), admin / 'apple-icon.png')

# Ficha de tienda: gráfico destacado de Google Play 1024×500
fg = Image.new('RGB', (1024 * S // 2, 500 * S // 2), GREEN)
w = mark(500 * S // 2, WHITE, MINT, scale=0.42, word=True)
fg.paste(w, ((fg.width - w.width) // 2, 0), w)
fg = fg.resize((1024, 500), Image.LANCZOS)
save(fg, ROOT / 'docs/tiendas/play-grafico-destacado.png')
