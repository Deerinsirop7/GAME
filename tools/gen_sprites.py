#!/usr/bin/env python3
"""Генератор всех пиксельных спрайтов игры Pixel Pet.

Запуск:  python tools/gen_sprites.py
Все PNG складываются в assets/sprites/. Скрипт детерминирован: повторный
запуск даёт те же картинки, поэтому арт можно спокойно править здесь.

Слои персонажа рисуются в оттенках серого: цвет кожи, волос и глаз
подставляется в игре через modulate, поэтому любые сочетания цветов
не требуют отдельных картинок.
"""
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")
OUT = (62, 39, 35, 255)  # общий тёплый тёмно-коричневый контур (как в Stardew)


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rgba(c, a=255):
    if len(c) == 4:
        return tuple(c)
    return (c[0], c[1], c[2], a)


def from_map(rows, pal, w=None, h=None, ox=0, oy=0, img=None):
    """Рисует ASCII-карту. '.' и ' ' — прозрачные пиксели."""
    width = len(rows[0])
    for r in rows:
        assert len(r) == width, (r, len(r), width)
    if img is None:
        img = new(w or width, h or len(rows))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in ". ":
                continue
            img.putpixel((x + ox, y + oy), rgba(pal[ch]))
    return img


def outline(img, color=None, diagonal=False):
    """Автоматический контур вокруг непрозрачных пикселей.
    color=None — «цветной» контур: тёмная тёплая версия соседнего цвета (мягче чёрного)."""
    w, h = img.size
    src = img.copy()
    p = src.load()
    dst = img.load()
    nbs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        nbs += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for y in range(h):
        for x in range(w):
            if p[x, y][3] != 0:
                continue
            for dx, dy in nbs:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and p[nx, ny][3] > 200:
                    if color is None:
                        dst[x, y] = selout(p[nx, ny])
                    else:
                        dst[x, y] = rgba(color)
                    break
    return img


def selout(c):
    r, g, b = c[0], c[1], c[2]
    k = 0.42
    return (int(r * k + 30), int(g * k + 16), int(b * k + 14), 255)


def shade_blob(img, box, base, light, dark):
    """Эллипс в три тона: тень снизу-справа, свет сверху-слева."""
    x0, y0, x1, y1 = box
    ellipse(img, x0, y0, x1, y1, dark)
    ellipse(img, x0, y0, x1 - 1, y1 - 2, base)
    w, h = x1 - x0, y1 - y0
    if w > 4 and h > 4:
        ellipse(img, x0 + 2, y0 + 1, x0 + max(3, w // 2), y0 + max(2, h // 3), light)


def darker(c, k=0.75):
    return (int(c[0] * k), int(c[1] * k), int(c[2] * k))


def lighter(c, k=0.35):
    return tuple(int(v + (255 - v) * k) for v in c[:3])


def rect(img, x0, y0, x1, y1, c):
    """Заливка прямоугольника включительно по обоим концам."""
    ImageDraw.Draw(img).rectangle([x0, y0, x1, y1], fill=rgba(c))


def ellipse(img, x0, y0, x1, y1, c):
    ImageDraw.Draw(img).ellipse([x0, y0, x1, y1], fill=rgba(c))


def poly(img, pts, c):
    ImageDraw.Draw(img).polygon(pts, fill=rgba(c))


def px(img, x, y, c):
    if 0 <= x < img.size[0] and 0 <= y < img.size[1]:
        img.putpixel((x, y), rgba(c))


def hline(img, x0, x1, y, c):
    for x in range(x0, x1 + 1):
        px(img, x, y, c)


def vline(img, x, y0, y1, c):
    for y in range(y0, y1 + 1):
        px(img, x, y, c)


def sheet(frames):
    w, h = frames[0].size
    out = new(w * len(frames), h)
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


# ---------------------------------------------------------------- питомцы v2
# Лист из 12 кадров 24x24 (для рыбки — 4 кадра 14x10):
#  0,1 покой (дыхание/хвост) · 2 моргание · 3-6 ходьба · 7,8 ест · 9 радость · 10,11 сон
PET_FRAMES = 12
EYE_DARK = (40, 28, 30)
WHITE = (255, 255, 255)
PINK = (236, 120, 130)

DOG_COATS = [
    {"name": "Рыжий", "base": (196, 132, 78), "light": (228, 172, 112), "dark": (150, 96, 58), "acc": (246, 226, 190), "ear": (124, 78, 50)},
    {"name": "Золотистый", "base": (234, 182, 100), "light": (250, 214, 146), "dark": (198, 140, 72), "acc": (252, 240, 214), "ear": (204, 144, 76)},
    {"name": "Пятнистый", "base": (240, 234, 224), "light": (255, 252, 246), "dark": (200, 192, 182), "acc": (255, 255, 255), "ear": (70, 58, 56), "spots": (70, 58, 56)},
    {"name": "Чёрный", "base": (74, 64, 66), "light": (106, 96, 98), "dark": (50, 44, 46), "acc": (196, 150, 108), "ear": (44, 38, 40)},
]
CAT_COATS = [
    {"name": "Рыжий", "base": (240, 152, 72), "light": (252, 188, 114), "dark": (204, 114, 52), "acc": (252, 234, 206), "stripe": (198, 104, 46), "eye": (110, 190, 80)},
    {"name": "Серый", "base": (152, 152, 166), "light": (186, 186, 200), "dark": (118, 118, 132), "acc": (234, 234, 238), "stripe": (112, 112, 126), "eye": (230, 196, 70)},
    {"name": "Чёрный", "base": (66, 60, 72), "light": (96, 88, 104), "dark": (46, 42, 52), "acc": (66, 60, 72), "stripe": None, "eye": (236, 210, 80)},
    {"name": "Сиамский", "base": (242, 226, 198), "light": (252, 242, 222), "dark": (214, 194, 162), "acc": (252, 246, 236), "stripe": None, "points": (112, 86, 72), "eye": (100, 160, 230)},
]
PARROT_COATS = [
    {"name": "Зелёный", "body": (112, 192, 92), "light": (154, 222, 124), "dark": (72, 142, 72), "head": (228, 86, 66), "wing": (66, 124, 196), "tail": (66, 124, 196), "beak": (250, 206, 92)},
    {"name": "Голубой", "body": (88, 160, 228), "light": (140, 196, 244), "dark": (60, 114, 186), "head": (252, 214, 80), "wing": (50, 90, 160), "tail": (50, 90, 160), "beak": (60, 56, 60)},
    {"name": "Жако", "body": (156, 156, 164), "light": (190, 190, 198), "dark": (118, 118, 128), "head": (176, 176, 184), "wing": (126, 126, 136), "tail": (222, 62, 62), "beak": (52, 50, 56)},
    {"name": "Розовый", "body": (246, 196, 208), "light": (252, 222, 230), "dark": (222, 158, 178), "head": (250, 214, 222), "wing": (232, 168, 188), "tail": (232, 168, 188), "beak": (214, 200, 186), "crest": (250, 120, 140)},
]
FISH_COATS = [
    {"name": "Золотая", "base": (250, 142, 60), "light": (255, 196, 120), "dark": (214, 98, 42), "fin": (255, 206, 140)},
    {"name": "Лимонная", "base": (250, 214, 80), "light": (255, 238, 150), "dark": (214, 170, 50), "fin": (255, 240, 180)},
    {"name": "Кои", "base": (250, 246, 240), "light": (255, 255, 255), "dark": (214, 206, 200), "fin": (255, 220, 214), "spots": (230, 80, 60)},
    {"name": "Петушок", "base": (80, 120, 220), "light": (130, 170, 245), "dark": (54, 84, 176), "fin": (190, 90, 210)},
]

# параметры кадров: (поза, фаза ног, глаза, рот, хвост, дыхание)
FRAME_SPEC = [
    ("stand", None, "open", False, 0, 0),
    ("stand", None, "open", False, 1, 1),
    ("stand", None, "closed", False, 0, 0),
    ("stand", 0, "open", False, 0, 0),
    ("stand", 1, "open", False, 1, 0),
    ("stand", 2, "open", False, 0, 0),
    ("stand", 3, "open", False, 1, 0),
    ("eat", None, "open", False, 0, 0),
    ("eat", None, "closed", True, 1, 0),
    ("stand", None, "happy", True, 2, 0),
    ("lie", None, "closed", False, 0, 0),
    ("lie", None, "closed", False, 0, 1),
]
LEG_OFFS = {None: (0, 0, 0, 0), 0: (1, -1, -1, 1), 1: (0, 0, 0, 0), 2: (-1, 1, 1, -1), 3: (0, 0, 0, 0)}
LEG_LIFT = {None: (0, 0, 0, 0), 0: (0, 0, 0, 0), 1: (1, 0, 0, 1), 2: (0, 0, 0, 0), 3: (0, 1, 1, 0)}


def _legs(img, xs, offs, lifts, top, col, paw, near):
    for i in (0, 2) if not near else (1, 3):
        pass
    for i, x in enumerate(xs):
        if (i % 2 == 1) != near:
            continue
        x += offs[i]
        bottom = 23 - lifts[i]
        c = col if near else darker(col, 0.8)
        rect(img, x, top, x + 1, bottom, c)
        hline(img, x, x + 1, bottom, paw if near else darker(paw, 0.85))


def _eye(img, x, y, kind, iris=EYE_DARK):
    if kind == "open":
        px(img, x, y, WHITE); px(img, x + 1, y, iris)
        px(img, x, y + 1, iris); px(img, x + 1, y + 1, EYE_DARK)
    elif kind == "closed":
        hline(img, x, x + 1, y + 1, EYE_DARK)
    else:  # happy ^
        px(img, x, y + 1, EYE_DARK); px(img, x + 1, y, EYE_DARK); px(img, x + 2, y + 1, EYE_DARK)


def dog_frame(c, spec):
    pose, legs, eyes, mouth, tail, br = spec
    img = new(24, 24)
    B, L, D, A, E = c["base"], c["light"], c["dark"], c["acc"], c["ear"]
    if pose == "lie":
        poly(img, [(1, 21), (5, 18), (6, 20), (2, 22)], D)  # хвост
        shade_blob(img, (3, 14 - br, 18, 22), B, L, D)
        rect(img, 15, 20, 21, 22, A)
        shade_blob(img, (12, 9, 20, 18), B, L, D)
        rect(img, 18, 14, 22, 17, A)
        outline(img)
        poly(img, [(13, 10), (15, 10), (15, 17), (13, 17)], E)
        px(img, 22, 14, EYE_DARK)
        _eye(img, 17, 12, "closed")
        if c.get("spots"):
            for p in [(6, 16), (9, 18), (11, 15)]:
                rect(img, p[0], p[1], p[0] + 1, p[1], c["spots"])
        return img
    hy = 4 if pose == "eat" else 0
    # хвост
    if tail == 0:
        poly(img, [(2, 7), (4, 7), (6, 12), (4, 13)], B)
    elif tail == 1:
        poly(img, [(1, 10), (3, 9), (6, 12), (4, 13)], B)
    else:
        poly(img, [(3, 4), (5, 4), (6, 12), (4, 12)], B)
    _legs(img, [5, 7, 13, 15], LEG_OFFS[legs], LEG_LIFT[legs], 16, B, A, near=False)
    shade_blob(img, (4, 10 - br, 17, 19), B, L, D)
    rect(img, 7, 17, 13, 18, A)
    _legs(img, [5, 7, 13, 15], LEG_OFFS[legs], LEG_LIFT[legs], 16, B, A, near=True)
    shade_blob(img, (12, 3 + hy, 20, 12 + hy), B, L, D)
    rect(img, 18, 8 + hy, 22, 11 + hy, A)
    outline(img)
    poly(img, [(13, 5 + hy), (15, 4 + hy), (16, 11 + hy), (14, 12 + hy)], E)
    px(img, 22, 8 + hy, EYE_DARK); px(img, 23, 8 + hy, EYE_DARK)
    _eye(img, 17, 6 + hy, eyes)
    if mouth:
        hline(img, 20, 22, 11 + hy, EYE_DARK)
        px(img, 21, 12 + hy, PINK); px(img, 22, 12 + hy, PINK)
    if c.get("spots"):
        for p in [(7, 12), (10, 15), (13, 13), (5, 15)]:
            rect(img, p[0], p[1], p[0] + 1, p[1] + 1, c["spots"])
    return img


def cat_frame(c, spec):
    pose, legs, eyes, mouth, tail, br = spec
    img = new(24, 24)
    B, L, D, A, S = c["base"], c["light"], c["dark"], c["acc"], c.get("stripe")
    pts = c.get("points")
    T = pts or B
    if pose == "lie":
        shade_blob(img, (3, 15 - br, 18, 22), B, L, D)
        rect(img, 5, 21, 16, 22, T)  # хвост обвивает лапки
        shade_blob(img, (12, 10, 20, 18), B, L, D)
        poly(img, [(12, 12), (13, 7), (15, 11)], pts or B)
        poly(img, [(17, 11), (19, 7), (20, 12)], pts or B)
        outline(img)
        rect(img, 16, 14, 20, 17, A if not pts else pts)
        px(img, 20, 14, PINK)
        _eye(img, 14, 12, "closed"); _eye(img, 17, 12, "closed")
        if S:
            for x in (6, 9, 12):
                vline(img, x, 16, 18, S)
        return img
    hy = 4 if pose == "eat" else 0
    # хвост вверх
    if tail == 0:
        poly(img, [(4, 13), (2, 8), (2, 4), (4, 4), (4, 8), (6, 12)], T)
    elif tail == 1:
        poly(img, [(4, 13), (1, 9), (0, 6), (2, 5), (3, 8), (6, 12)], T)
    else:
        poly(img, [(4, 13), (4, 6), (5, 2), (7, 3), (6, 8), (6, 12)], T)
    _legs(img, [6, 8, 13, 15], LEG_OFFS[legs], LEG_LIFT[legs], 17, B, A, near=False)
    shade_blob(img, (5, 11 - br, 17, 19), B, L, D)
    _legs(img, [6, 8, 13, 15], LEG_OFFS[legs], LEG_LIFT[legs], 17, B, A, near=True)
    shade_blob(img, (12, 4 + hy, 21, 12 + hy), B, L, D)
    poly(img, [(12, 6 + hy), (13, 1 + hy), (16, 5 + hy)], pts or B)
    poly(img, [(17, 5 + hy), (20, 1 + hy), (21, 7 + hy)], pts or B)
    outline(img)
    px(img, 13, 4 + hy, PINK); px(img, 20, 4 + hy, PINK)
    rect(img, 17, 9 + hy, 21, 11 + hy, A if not pts else pts)
    px(img, 21, 9 + hy, PINK)
    iris = c.get("eye", (110, 190, 80))
    if eyes == "open":
        px(img, 14, 7 + hy, iris); px(img, 14, 8 + hy, EYE_DARK)
        px(img, 18, 7 + hy, iris); px(img, 18, 8 + hy, EYE_DARK)
        px(img, 15, 7 + hy, iris); px(img, 19, 7 + hy, iris)
    else:
        _eye(img, 14, 6 + hy, eyes); _eye(img, 18, 6 + hy, eyes)
    if mouth:
        px(img, 19, 12 + hy, EYE_DARK); px(img, 20, 12 + hy, PINK)
    # усы
    px(img, 22, 10 + hy, lighter(B, 0.6)); px(img, 23, 9 + hy, lighter(B, 0.6))
    if S:
        for x in (8, 10, 12):
            vline(img, x, 12 - br, 14 - br, S)
        hline(img, 15, 17, 5 + hy, S)
    return img


def parrot_frame(c, spec):
    pose, legs, eyes, mouth, tail, br = spec
    img = new(24, 24)
    Bd, L, D, H, W, T, K = c["body"], c["light"], c["dark"], c["head"], c["wing"], c["tail"], c["beak"]
    hop = {None: 0, 0: 0, 1: 2, 2: 3, 3: 1}[legs] if pose == "stand" else 0
    dy = -hop
    if pose == "lie":  # сон: нахохлился, голова вжата
        rect(img, 9, 19, 12, 23, T)
        shade_blob(img, (6, 9, 17, 21), Bd, L, D)
        shade_blob(img, (9, 6, 17, 13), H, lighter(H), darker(H, 0.85))
        outline(img)
        rect(img, 7, 12, 11, 19, W)
        rect(img, 16, 9, 17, 10, K)
        _eye(img, 13, 8 - br, "closed")
        px(img, 10, 22, (120, 110, 110)); px(img, 13, 22, (120, 110, 110))
        return img
    hy = 3 if pose == "eat" else 0
    rect(img, 9, 18 + dy, 12, 23 + dy if hop else 23, T)
    shade_blob(img, (7, 8 + dy - br, 16, 21 + dy), Bd, L, D)
    shade_blob(img, (9, 2 + dy + hy, 17, 10 + dy + hy), H, lighter(H), darker(H, 0.85))
    if c.get("crest"):
        poly(img, [(10, 3 + dy), (9, -1 + dy), (13, 2 + dy)], c["crest"])
    # клюв
    rect(img, 16, 5 + dy + hy, 18, 7 + dy + hy, K)
    px(img, 18, 8 + dy + hy, K)
    if mouth:
        px(img, 17, 8 + dy + hy, darker(K, 0.6))
    outline(img)
    # крыло
    if pose == "stand" and (legs in (1, 2) or eyes == "happy"):
        poly(img, [(8, 10 + dy), (2, 7 + dy), (3, 13 + dy), (8, 16 + dy)], W)
    else:
        rect(img, 8, 11 + dy, 11, 19 + dy, W)
        vline(img, 8, 12 + dy, 18 + dy, darker(W, 0.8))
    _eye(img, 13, 4 + dy + hy, eyes)
    feet = (120, 110, 110)
    px(img, 10, 23, feet); px(img, 13, 23, feet)
    if hop:
        px(img, 10, 22 + dy + 1, feet); px(img, 13, 22 + dy + 1, feet)
    return img


def fish_frame(c, i):
    B, L, D, F = c["base"], c["light"], c["dark"], c["fin"]
    img = new(14, 10)
    if i == 1:
        poly(img, [(0, 2), (4, 4), (4, 5), (0, 7)], F)
    else:
        poly(img, [(0, 1), (4, 4), (4, 5), (0, 8)], F)
    poly(img, [(7, 1), (9, 0), (10, 2)], F)
    shade_blob(img, (3, 2, 12, 8), B, L, D)
    outline(img)
    vline(img, 6, 3, 6, D)
    if c.get("spots"):
        rect(img, 7, 3, 8, 4, c["spots"]); px(img, 10, 6, c["spots"])
    if i == 2:
        hline(img, 9, 10, 4, EYE_DARK)
    else:
        px(img, 9, 3, WHITE); px(img, 10, 3, EYE_DARK); px(img, 10, 4, EYE_DARK)
    if i == 3:
        px(img, 12, 6, EYE_DARK)
    return img


def fish_bowl():
    """Круглый аквариум на тумбе 36x42; низ — якорь."""
    img = new(36, 42)
    rect(img, 6, 30, 29, 41, (150, 96, 60))
    rect(img, 6, 30, 29, 31, (186, 128, 82))
    rect(img, 8, 33, 27, 39, (126, 80, 50))
    px(img, 17, 36, (230, 190, 110)); px(img, 18, 36, (230, 190, 110))
    outline(img)
    glass = (214, 238, 255, 70)
    water = (112, 184, 236, 110)
    ellipse(img, 3, 2, 32, 30, glass)
    ellipse(img, 4, 7, 31, 29, water)
    rect(img, 9, 1, 26, 4, (0, 0, 0, 0))
    hline(img, 8, 27, 3, (236, 248, 255, 220))
    hline(img, 8, 27, 4, (180, 214, 236, 200))
    rnd = random.Random(4)
    for x in range(8, 28):
        for y in range(26, 29):
            if (x - 17.5) ** 2 / 110 + (y - 22) ** 2 / 50 < 1.0:
                px(img, x, y, rnd.choice([(212, 182, 132), (182, 150, 108), (232, 206, 160)]))
    for x, h in [(10, 7), (11, 5), (24, 6)]:
        vline(img, x, 26 - h, 25, (82, 168, 96))
        px(img, x + 1, 26 - h + 2, (110, 196, 112))
    vline(img, 7, 10, 17, (255, 255, 255, 170))
    vline(img, 8, 9, 11, (255, 255, 255, 140))
    return img


def gen_pets():
    for kind, coats, fn in [("dog", DOG_COATS, dog_frame), ("cat", CAT_COATS, cat_frame), ("parrot", PARROT_COATS, parrot_frame)]:
        for ci, c in enumerate(coats):
            save(sheet([fn(c, spec) for spec in FRAME_SPEC]), f"pets/{kind}_{ci}.png")
    for ci, c in enumerate(FISH_COATS):
        save(sheet([fish_frame(c, i) for i in range(4)]), f"pets/fish_{ci}.png")
    save(fish_bowl(), "pets/fish_bowl.png")


# ---------------------------------------------------------------- мир v2 (тёплая палитра)
GRASS = (124, 186, 82)
GRASS_D = (98, 160, 66)
GRASS_DD = (78, 134, 58)
GRASS_L = (156, 210, 98)
DIRT = (214, 168, 108)
DIRT_D = (182, 136, 84)
WOOD = (176, 116, 70)
WOOD_D = (134, 84, 52)
WOOD_L = (210, 152, 96)
HOUSE_WINDOWS = {}


def hills():
    import math
    img = new(320, 72)
    for x in range(320):
        h1 = 26 + 9 * math.sin(x / 38.0) + 5 * math.sin(x / 15.0 + 1)
        for y in range(int(h1), 72):
            px(img, x, y, (148, 186, 170) if y > h1 + 2 else (172, 206, 186))
        h2 = 42 + 6 * math.sin(x / 27.0 + 2) + 3 * math.sin(x / 9.0)
        for y in range(int(h2), 72):
            c = (104, 168, 92) if y > h2 + 2 else (130, 190, 100)
            if (x + y) % 7 == 0 and y > h2 + 4:
                c = (92, 150, 82)
            px(img, x, y, c)
        # кромка леса на ближнем холме
        if x % 6 < 4:
            top = int(h2) - 3 - (x % 6 == 1) - (x % 6 == 2)
            vline(img, x, top, int(h2), (84, 144, 80))
    return img


def ground():
    img = new(320, 48)
    rect(img, 0, 0, 319, 47, GRASS)
    rnd = random.Random(7)
    # дизеринг-пятна
    for _ in range(900):
        x, y = rnd.randrange(320), rnd.randrange(1, 48)
        px(img, x, y, rnd.choice([GRASS_D, GRASS_L, GRASS_D, (114, 178, 76)]))
    # пучки травы «v»
    for _ in range(140):
        x, y = rnd.randrange(2, 318), rnd.randrange(3, 47)
        c = rnd.choice([GRASS_D, GRASS_DD])
        px(img, x - 1, y - 1, c); px(img, x, y, c); px(img, x + 1, y - 1, c); px(img, x + 1, y - 2, lighter(c, 0.2))
    # цветочки
    for _ in range(36):
        x, y = rnd.randrange(2, 318), rnd.randrange(4, 46)
        c = rnd.choice([(255, 250, 240), (252, 214, 90), (240, 130, 160), (176, 150, 240)])
        px(img, x, y, c); px(img, x, y + 1, GRASS_DD)
    for x in range(320):
        px(img, x, 0, GRASS_L if x % 3 else GRASS)
    return img


def path_patch():
    img = new(44, 34)
    poly(img, [(15, 0), (28, 0), (42, 33), (1, 33)], DIRT)
    rnd = random.Random(5)
    for _ in range(70):
        x, y = rnd.randrange(6, 38), rnd.randrange(1, 33)
        if img.getpixel((x, y))[3]:
            px(img, x, y, rnd.choice([DIRT_D, (228, 188, 128), DIRT_D]))
    for _ in range(10):
        x, y = rnd.randrange(8, 36), rnd.randrange(3, 31)
        if img.getpixel((x, y))[3]:
            px(img, x, y, (170, 160, 150)); px(img, x + 1, y, (200, 190, 178))
    return img


def tree_round():
    img = new(44, 56)
    rect(img, 18, 34, 25, 55, (138, 92, 58))
    rect(img, 22, 34, 25, 55, (112, 74, 48))
    rect(img, 16, 52, 27, 55, (138, 92, 58))
    rnd = random.Random(12)
    blobs = [(4, 12, 24, 34), (18, 10, 40, 34), (8, 2, 34, 24), (12, 18, 32, 38)]
    for b in blobs:
        ellipse(img, *b, (64, 128, 70))
    for b in blobs:
        ellipse(img, b[0], b[1], b[2] - 2, b[3] - 3, (86, 156, 80))
    for b in [(8, 4, 24, 18), (20, 12, 32, 24), (6, 14, 16, 24)]:
        ellipse(img, *b, (112, 182, 92))
    for _ in range(30):
        x, y = rnd.randrange(6, 36), rnd.randrange(4, 30)
        if img.getpixel((x, y))[3] and img.getpixel((x, y))[:3] == (112, 182, 92):
            px(img, x, y, (146, 206, 112))
    for _ in range(40):
        x, y = rnd.randrange(4, 40), rnd.randrange(10, 38)
        if img.getpixel((x, y))[:3] == (86, 156, 80):
            px(img, x, y, (70, 136, 70))
    outline(img)
    return img


def tree_pine():
    img = new(30, 52)
    rect(img, 13, 40, 17, 51, (124, 84, 54))
    rect(img, 15, 40, 17, 51, (100, 66, 44))
    for i, (y, w) in enumerate([(2, 5), (10, 9), (18, 12), (27, 14)]):
        poly(img, [(15, y), (15 - w, y + 14), (15 + w, y + 14)], (52, 112, 84))
        poly(img, [(15, y), (15 - w + 2, y + 12), (15 + w - 3, y + 12)], (70, 140, 96))
        poly(img, [(14, y + 2), (15 - w + 4, y + 10), (13, y + 10)], (96, 166, 112))
    outline(img)
    return img


def bush():
    img = new(26, 16)
    ellipse(img, 1, 3, 14, 15, (74, 140, 72))
    ellipse(img, 9, 1, 24, 15, (86, 156, 80))
    ellipse(img, 4, 4, 12, 10, (112, 182, 92))
    ellipse(img, 12, 2, 20, 8, (112, 182, 92))
    for p in [(6, 7), (15, 5), (19, 9)]:
        px(img, *p, (240, 120, 140))
    outline(img)
    return img


def fence():
    img = new(48, 18)
    for x in (2, 16, 30, 44):
        rect(img, x, 2, x + 2, 17, WOOD_L)
        vline(img, x + 2, 3, 17, WOOD)
        px(img, x + 1, 1, WOOD_L)
    rect(img, 0, 6, 47, 7, WOOD)
    rect(img, 0, 12, 47, 13, WOOD)
    outline(img)
    return img


def cloud(w, h, seed):
    img = new(w, h)
    rnd = random.Random(seed)
    for _ in range(7):
        cx = rnd.randint(h // 2, w - h // 2)
        r = rnd.randint(h // 3, h // 2)
        ellipse(img, cx - r, h - 1 - 2 * r, cx + r, h - 1, (255, 255, 255))
    rect(img, h // 2, h - h // 3, w - h // 2, h - 1, (255, 255, 255))
    for x in range(w):
        col = [img.getpixel((x, y))[3] for y in range(h)]
        bottom = max([y for y in range(h) if col[y]] or [-1])
        if bottom >= 0:
            px(img, x, bottom, (214, 214, 236))
            if bottom - 1 >= 0 and col[bottom - 1]:
                px(img, x, bottom - 1, (232, 232, 246))
    return img


def sun():
    img = new(20, 20)
    ellipse(img, 1, 1, 18, 18, (255, 226, 130))
    ellipse(img, 3, 3, 16, 16, (255, 238, 170))
    ellipse(img, 5, 4, 10, 9, (255, 250, 220))
    return img


def moon():
    img = new(16, 16)
    ellipse(img, 1, 1, 14, 14, (246, 240, 214))
    ImageDraw.Draw(img).ellipse([6, -1, 17, 11], fill=(0, 0, 0, 0))
    px(img, 4, 8, (214, 206, 180)); px(img, 6, 11, (214, 206, 180)); px(img, 3, 5, (214, 206, 180))
    return img


# --- дома
def _shingles(img, x0, x1, y0, y1, c1, c2, mask=None):
    for y in range(y0, y1 + 1):
        row = (y - y0) // 3
        for x in range(x0, x1 + 1):
            if mask and not mask(x, y):
                continue
            k = (x + (row % 2) * 3) % 6
            c = c2 if (y - y0) % 3 == 2 or k == 0 else c1
            px(img, x, y, c)


def _boards(img, x0, y0, x1, y1, c1, c2, step=4, vertical=False):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            line = (x - x0) % step == 0 if vertical else (y - y0) % step == 0
            px(img, x, y, c2 if line else c1)


def _window2(img, x0, y0, w, h, wins, anchor, frame=(242, 236, 222), glass=(126, 180, 222)):
    rect(img, x0 - 2, y0 - 2, x0 + w + 1, y0 + h + 1, frame)
    rect(img, x0, y0, x0 + w - 1, y0 + h - 1, glass)
    rect(img, x0, y0, x0 + w - 1, y0 + h // 3, lighter(glass, 0.25))
    vline(img, x0 + w // 2, y0, y0 + h - 1, frame)
    hline(img, x0, x0 + w - 1, y0 + h // 2, frame)
    px(img, x0 + 1, y0 + 1, (255, 255, 255))
    rect(img, x0 - 3, y0 + h + 1, x0 + w + 2, y0 + h + 2, darker(frame, 0.8))
    ax, ay = anchor
    wins.append((x0 + w / 2 - ax, y0 + h / 2 - ay))


def _door(img, x0, y0, x1, y1, c=(150, 96, 62)):
    rect(img, x0, y0, x1, y1, darker(c, 0.75))
    rect(img, x0 + 1, y0 + 1, x1 - 1, y1, c)
    for x in range(x0 + 3, x1, 3):
        vline(img, x, y0 + 2, y1, darker(c, 0.85))
    px(img, x1 - 2, (y0 + y1) // 2 + 1, (250, 214, 110))


def house_tent():
    W, H = 66, 48
    img = new(W, H)
    wins = []
    c1, c2 = (232, 112, 88), (250, 238, 214)
    for x in range(4, 62):
        top = int(44 - 36 * (1 - abs(x - 33) / 29))
        vline(img, x, top, 44, c1 if (x // 6) % 2 == 0 else c2)
        if x > 33:
            vline(img, x, top + 1, 44, darker(c1 if (x // 6) % 2 == 0 else c2, 0.88))
    poly(img, [(33, 18), (24, 44), (42, 44)], (86, 56, 60))
    poly(img, [(33, 18), (27, 44), (33, 44)], (126, 82, 74))
    vline(img, 33, 2, 10, (150, 104, 66))
    poly(img, [(34, 2), (42, 4), (34, 6)], (252, 206, 90))
    outline(img)
    for x in (3, 62):
        vline(img, x, 44, 46, (150, 104, 66))
    wins.append((0, -12))
    return img, wins


def house_hut():
    W, H = 78, 60
    img = new(W, H)
    wins = []
    an = (W / 2, H - 1)
    for y in range(28, 58):
        for x in range(12, 66):
            log = (y - 28) // 4
            c = (178, 120, 74) if log % 2 == 0 else (160, 104, 64)
            if (y - 28) % 4 == 3:
                c = (128, 82, 52)
            px(img, x, y, c)
    for x in (12, 13, 64, 65):
        vline(img, x, 28, 57, (128, 82, 52))
    poly(img, [(39, 3), (3, 31), (75, 31)], (226, 186, 100))
    for y in range(6, 31, 3):
        hw = int((y - 3) * 36 / 28)
        hline(img, 39 - hw + 1, 39 + hw - 1, y, (198, 154, 76))
    for x in range(6, 74, 4):
        vline(img, x, 30, 32, (198, 154, 76))
    _door(img, 33, 40, 45, 57)
    ellipse(img, 16, 35, 27, 46, (242, 236, 222))
    ellipse(img, 18, 37, 25, 44, (126, 180, 222))
    px(img, 20, 39, (255, 255, 255))
    wins.append((21.5 - an[0], 40.5 - an[1]))
    _window2(img, 52, 38, 8, 8, wins, an)
    outline(img)
    return img, wins


def house_small():
    W, H = 96, 76
    img = new(W, H)
    wins = []
    an = (W / 2, H - 1)
    rect(img, 66, 6, 74, 24, (176, 98, 80))
    for y in range(6, 25, 3):
        hline(img, 66, 74, y, (150, 82, 70))
    rect(img, 64, 4, 76, 6, (120, 70, 60))
    _boards(img, 10, 34, 85, 70, (246, 226, 196), (226, 202, 168), step=5)
    rect(img, 8, 70, 87, 74, (168, 158, 150))
    for x in range(8, 88, 6):
        vline(img, x, 70, 74, (140, 132, 126))
    poly(img, [(48, 4), (0, 36), (95, 36)], (198, 82, 72))
    _shingles(img, 0, 95, 6, 35, (206, 92, 78), (166, 64, 60),
              mask=lambda x, y: img.getpixel((x, y))[3] > 0)
    hline(img, 0, 95, 36, (140, 56, 56))
    hline(img, 1, 94, 37, (120, 48, 50))
    _door(img, 42, 50, 54, 69)
    _window2(img, 18, 46, 14, 12, wins, an)
    _window2(img, 64, 46, 14, 12, wins, an)
    outline(img)
    return img, wins


def house_cozy():
    W, H = 120, 92
    img = new(W, H)
    wins = []
    an = (W / 2, H - 1)
    rect(img, 88, 4, 96, 24, (160, 120, 108))
    for y in range(4, 25, 3):
        hline(img, 88, 96, y, (136, 100, 90))
    rect(img, 86, 2, 98, 4, (110, 80, 72))
    _boards(img, 10, 32, 109, 85, (240, 214, 164), (218, 188, 138), step=5)
    rect(img, 8, 85, 111, 89, (168, 158, 150))
    for x in range(8, 112, 6):
        vline(img, x, 85, 89, (140, 132, 126))
    poly(img, [(60, 2), (0, 34), (119, 34)], (84, 118, 186))
    _shingles(img, 0, 119, 4, 33, (92, 128, 196), (64, 92, 158),
              mask=lambda x, y: img.getpixel((x, y))[3] > 0)
    hline(img, 0, 119, 34, (56, 80, 140))
    hline(img, 1, 118, 35, (46, 68, 120))
    _window2(img, 53, 15, 14, 11, wins, an)
    _window2(img, 18, 41, 16, 12, wins, an)
    _window2(img, 86, 41, 16, 12, wins, an)
    # крыльцо
    poly(img, [(32, 60), (60, 50), (88, 60)], (84, 118, 186))
    hline(img, 32, 88, 60, (56, 80, 140))
    for x in (36, 84):
        rect(img, x - 1, 61, x, 85, (230, 216, 196))
    _door(img, 52, 64, 67, 84, (126, 84, 62))
    ellipse(img, 56, 67, 62, 72, (252, 226, 140))
    for x0 in (16, 88):
        _window2(img, x0, 65, 16, 11, wins, an)
        rect(img, x0 - 2, 79, x0 + 17, 81, (150, 100, 66))
        for i in range(0, 18, 2):
            px(img, x0 - 1 + i, 78, [(240, 96, 120), (252, 206, 90), (210, 130, 230), (96, 176, 90)][(i // 2) % 4])
    outline(img)
    return img, wins


# --- интерьеры 320x180: окно-дыра на месте (24..88, 26..76); у Уютного дома второе окно справа
INT_WINDOWS = [(24, 26)]


def interior(tier):
    img = new(320, 180)
    rnd = random.Random(tier)
    if tier == 0:  # палатка изнутри
        for x in range(320):
            c = (236, 214, 178) if (x // 16) % 2 == 0 else (226, 200, 160)
            vline(img, x, 0, 135, c)
        for y in range(0, 136, 12):
            hline(img, 0, 319, y, (214, 188, 150))
        floor_c, floor_d = (160, 186, 104), (138, 166, 88)   # травяной коврик
    elif tier == 1:  # шалаш из брёвен
        for y in range(0, 136):
            log = y // 9
            c = (170, 116, 72) if log % 2 == 0 else (154, 102, 62)
            if y % 9 == 8:
                c = (120, 78, 50)
            hline(img, 0, 319, y, c)
        floor_c, floor_d = (186, 134, 86), (160, 112, 70)
    elif tier == 2:
        rect(img, 0, 0, 319, 135, (232, 220, 190))
        for x in range(0, 320, 10):
            vline(img, x, 0, 95, (222, 208, 176))
        _boards(img, 0, 96, 319, 133, (176, 120, 78), (146, 98, 62), step=8, vertical=True)
        hline(img, 0, 319, 96, (120, 80, 54))
        floor_c, floor_d = (200, 146, 92), (172, 122, 76)
    else:
        rect(img, 0, 0, 319, 135, (244, 222, 206))
        for y in range(4, 96, 12):
            for x in range((y // 12) % 2 * 8, 320, 16):
                px(img, x, y, (230, 150, 160)); px(img, x - 1, y + 1, (120, 170, 120)); px(img, x + 1, y + 1, (120, 170, 120))
        _boards(img, 0, 96, 319, 133, (160, 112, 140), (136, 92, 118), step=8, vertical=True)
        hline(img, 0, 319, 96, (110, 74, 96))
        floor_c, floor_d = (196, 140, 88), (168, 116, 72)
    # плинтус
    rect(img, 0, 134, 319, 137, darker(floor_d, 0.75))
    # пол
    rect(img, 0, 138, 319, 179, floor_c)
    for y in range(138, 180, 7):
        hline(img, 0, 319, y, floor_d)
        off = (y // 7) % 2 * 24
        if tier > 0:
            for x in range(off, 320, 48):
                vline(img, x, y, y + 6, floor_d)
    if tier == 0:
        for _ in range(300):
            px(img, rnd.randrange(320), rnd.randrange(139, 180), rnd.choice([floor_d, lighter(floor_c, 0.15)]))
    windows = INT_WINDOWS + ([(232, 26)] if tier >= 3 else [])
    for wx, wy in windows:
        w, h = 64, 50
        if tier == 0:  # откинутый полог палатки
            rect(img, wx, wy, wx + w - 1, wy + h - 1, (0, 0, 0, 0))
            poly(img, [(wx - 4, wy - 4), (wx + 10, wy - 4), (wx - 4, wy + h + 2)], (222, 110, 90))
            poly(img, [(wx + w + 4, wy - 4), (wx + w - 10, wy - 4), (wx + w + 4, wy + h + 2)], (222, 110, 90))
            hline(img, wx - 4, wx + w + 4, wy - 5, (160, 110, 70))
            continue
        frame = (150, 100, 66) if tier < 3 else (242, 236, 226)
        rect(img, wx - 4, wy - 4, wx + w + 3, wy + h + 3, frame)
        rect(img, wx - 6, wy + h + 2, wx + w + 5, wy + h + 5, darker(frame, 0.85))
        rect(img, wx, wy, wx + w - 1, wy + h - 1, (0, 0, 0, 0))
        vline(img, wx + w // 2 - 1, wy, wy + h - 1, frame)
        vline(img, wx + w // 2, wy, wy + h - 1, frame)
        hline(img, wx, wx + w - 1, wy + h // 2, frame)
        curtain = [(150, 190, 120), (120, 170, 210), (226, 120, 130)][min(tier, 3) - 1]
        for i in range(12):
            rect(img, wx - 11 + i // 3, wy - 6 + i * 5, wx - 3, wy - 2 + i * 5, curtain)
            rect(img, wx + w + 2, wy - 6 + i * 5, wx + w + 10 - i // 3, wy - 2 + i * 5, curtain)
            vline(img, wx - 7, wy - 6 + i * 5, wy - 2 + i * 5, darker(curtain, 0.85))
        rect(img, wx - 13, wy - 9, wx + w + 12, wy - 7, (120, 84, 60))
    return img


def gen_world():
    for tier, fn in enumerate([house_tent, house_hut, house_small, house_cozy]):
        img, wins = fn()
        save(img, f"house/house_{tier}.png")
        HOUSE_WINDOWS[tier] = wins
        save(interior(tier), f"house/interior_{tier}.png")
    save(hills(), "world/hills.png")
    save(ground(), "world/ground.png")
    save(path_patch(), "world/path.png")
    save(tree_round(), "world/tree_round.png")
    save(tree_pine(), "world/tree_pine.png")
    save(bush(), "world/bush.png")
    save(fence(), "world/fence.png")
    save(cloud(42, 16, 1), "world/cloud_a.png")
    save(cloud(30, 12, 2), "world/cloud_b.png")
    save(cloud(56, 18, 3), "world/cloud_c.png")
    save(sun(), "world/sun.png")
    save(moon(), "world/moon.png")


# ---------------------------------------------------------------- инструменты, миска, курсоры
def bowl(level):
    img = new(18, 9)
    rect(img, 1, 3, 16, 8, (208, 92, 84))
    rect(img, 2, 3, 15, 4, (232, 120, 104))
    hline(img, 3, 14, 8, (170, 70, 70))
    rect(img, 3, 2, 14, 3, (100, 56, 52))
    rnd = random.Random(level)
    for i in range(level * 9):
        x = rnd.randrange(3, 15)
        y = 3 - (i // 9) - rnd.randrange(0, 2) + 1
        px(img, x, max(0, y), rnd.choice([(196, 136, 76), (168, 108, 60), (220, 168, 100)]))
    outline(img)
    return img


def cursors():
    d = {}
    S = (250, 222, 190); Sd = (226, 186, 150)
    d["cur_hand"] = from_map([
        "....oo........",
        "...oSSo.oo....",
        "...oSSooSSo...",
        "...oSSoSSSo.o.",
        ".oooSSoSSoooSo",
        "oSSoSSSSSSoSSo",
        "oSSSSSSSSSSSo.",
        ".oSSSSSSSSSdo.",
        "..oSSSSSSSSo..",
        "..oSSSSSSSdo..",
        "...oSSSSSdo...",
        "....oooooo....",
    ], {"o": OUT, "S": S, "d": Sd})
    d["cur_hand_pet"] = from_map([
        "..............",
        "..............",
        "...oooooooo...",
        "..oSSoSSoSSo..",
        ".oSSSSSSSSSSo.",
        "oSSSSSSSSSSSSo",
        "oSSSSSSSSSSSdo",
        ".oSSSSSSSSSdo.",
        "..oSSSSSSSSo..",
        "...oSSSSSdo...",
        "....oooooo....",
        "..............",
    ], {"o": OUT, "S": S, "d": Sd})
    img = new(16, 14)  # совок с кормом
    poly(img, [(1, 6), (10, 3), (12, 9), (3, 12)], (196, 206, 216))
    poly(img, [(2, 7), (10, 4), (11, 8), (3, 10)], (226, 234, 240))
    for p in [(4, 6), (6, 5), (8, 5), (5, 8), (7, 7), (9, 6)]:
        px(img, *p, (196, 136, 76))
    rect(img, 11, 6, 15, 8, (150, 96, 62))
    d["cur_scoop"] = outline(img)
    img = new(14, 11)
    rect(img, 1, 2, 12, 9, (252, 214, 90))
    rect(img, 1, 2, 12, 4, (126, 196, 110))
    for p in [(3, 6), (6, 7), (9, 6), (4, 8), (10, 8)]:
        px(img, *p, (226, 180, 60))
    d["cur_sponge"] = outline(img)
    img = new(20, 20)  # палочка с пёрышком (кончик пера — левый верх)
    for i in range(12):
        px(img, 7 + i, 7 + i, (150, 100, 66))
    poly(img, [(0, 0), (6, 2), (9, 8), (2, 6)], (236, 96, 120))
    poly(img, [(1, 1), (6, 3), (8, 7)], (252, 170, 186))
    px(img, 9, 9, (252, 214, 90))
    d["cur_feather"] = outline(img)
    d["cur_finger"] = from_map([
        "..oo........",
        ".oSSo.......",
        ".oSSo.......",
        ".oSSooooo...",
        ".oSSoSSoSoo.",
        "ooSSSSSSSSSo",
        "oSSSSSSSSSSo",
        "oSSSSSSSSSdo",
        ".oSSSSSSSdo.",
        "..oSSSSSdo..",
        "...oooooo...",
    ], {"o": OUT, "S": S, "d": Sd})
    img = new(12, 16)  # погремушка-колокольчик для попугая
    vline(img, 6, 0, 4, (150, 100, 66))
    ellipse(img, 1, 4, 11, 13, (252, 206, 80))
    ellipse(img, 3, 5, 7, 9, (255, 236, 160))
    rect(img, 1, 12, 11, 13, (214, 160, 56))
    px(img, 6, 15, (120, 84, 60))
    d["cur_rattle"] = outline(img)
    img = new(10, 10)
    shade_blob(img, (1, 1, 8, 8), (236, 90, 90), (255, 160, 150), (196, 60, 70))
    hline(img, 1, 8, 5, (255, 250, 240))
    d["ball"] = outline(img)
    return d


def misc_fx():
    d = {}
    for i in range(4):
        d[f"bowl_{i}"] = bowl(i)
    img = new(7, 6)
    ellipse(img, 0, 1, 4, 5, (255, 255, 255, 235))
    ellipse(img, 3, 0, 6, 4, (240, 246, 255, 235))
    px(img, 1, 2, (255, 255, 255)); px(img, 4, 3, (210, 226, 246))
    d["foam"] = img
    d["kibble"] = from_map(["cC", "Cc"], {"c": (168, 108, 60), "C": (210, 156, 92)})
    d["flake"] = from_map(["ab", "b."], {"a": (240, 140, 70), "b": (252, 206, 100)})
    img = new(12, 12)
    ellipse(img, 0, 0, 11, 11, (255, 255, 255, 60))
    ellipse(img, 2, 2, 9, 9, (255, 255, 255, 120))
    d["poof"] = img
    return d


# ---------------------------------------------------------------- мебель и декор


def item_flowers():
    img = new(26, 12)
    rect(img, 1, 7, 24, 11, (150, 100, 70))
    rect(img, 2, 7, 23, 8, (110, 80, 60))
    cols = [(240, 90, 110), (250, 200, 80), (200, 120, 220), (255, 250, 250), (250, 140, 60)]
    for i, x in enumerate(range(3, 23, 4)):
        vline(img, x, 3, 6, (70, 150, 80))
        px(img, x + 1, 5, (70, 150, 80))
        c = cols[i % len(cols)]
        px(img, x, 1, c); px(img, x - 1, 2, c); px(img, x + 1, 2, c); px(img, x, 3, c); px(img, x, 2, (250, 230, 120))
    outline(img)
    return img


def item_lantern():
    img = new(12, 28)
    rect(img, 5, 8, 6, 26, (70, 70, 80))
    rect(img, 3, 26, 8, 27, (70, 70, 80))
    rect(img, 2, 1, 9, 2, (70, 70, 80))
    rect(img, 3, 3, 8, 8, (255, 220, 130))
    vline(img, 5, 3, 8, (70, 70, 80))
    rect(img, 3, 9, 8, 9, (70, 70, 80))
    outline(img)
    return img


def item_bench():
    img = new(32, 16)
    for y in (2, 5):
        rect(img, 2, y, 29, y + 1, WOOD)
    rect(img, 1, 9, 30, 10, WOOD_L)
    for x in (4, 26):
        rect(img, x, 11, x + 1, 15, WOOD_D)
        rect(img, x, 1, x + 1, 9, WOOD_D)
    outline(img)
    return img


def item_mailbox():
    img = new(12, 22)
    rect(img, 5, 9, 6, 21, WOOD_D)
    rect(img, 1, 2, 10, 9, (80, 130, 200))
    rect(img, 2, 1, 9, 1, (80, 130, 200))
    rect(img, 9, 3, 10, 6, (230, 70, 70))
    px(img, 10, 2, (230, 70, 70))
    outline(img)
    return img


def item_gnome():
    img = new(10, 16)
    poly(img, [(5, 0), (1, 7), (8, 7)], (220, 60, 60))
    rect(img, 2, 7, 7, 9, (250, 214, 180))
    poly(img, [(2, 9), (7, 9), (5, 13)], (250, 250, 250))
    rect(img, 1, 10, 8, 15, (70, 120, 200))
    rect(img, 1, 10, 2, 13, (70, 120, 200))
    px(img, 4, 8, OUT)
    outline(img)
    return img


def item_bed():
    img = new(44, 28)
    rect(img, 1, 4, 5, 27, WOOD_D)
    rect(img, 38, 12, 42, 27, WOOD_D)
    rect(img, 4, 14, 40, 22, WOOD)
    rect(img, 6, 10, 15, 15, (250, 250, 250))
    rect(img, 12, 12, 39, 18, (110, 150, 220))
    for x in range(14, 39, 6):
        vline(img, x, 12, 18, (90, 126, 200))
    rect(img, 12, 18, 39, 19, (80, 110, 180))
    outline(img)
    return img


def item_rug():
    img = new(60, 14)
    ellipse(img, 0, 0, 59, 13, (200, 90, 90))
    ellipse(img, 5, 2, 54, 11, (240, 190, 120))
    ellipse(img, 12, 4, 47, 9, (200, 90, 90))
    return img


def item_lamp():
    img = new(14, 32)
    poly(img, [(3, 1), (10, 1), (13, 9), (0, 9)], (250, 220, 150))
    hline(img, 0, 13, 9, (220, 180, 110))
    vline(img, 6, 10, 29, (90, 80, 90)); vline(img, 7, 10, 29, (90, 80, 90))
    rect(img, 3, 29, 10, 31, (90, 80, 90))
    outline(img)
    return img


def item_plant():
    img = new(16, 24)
    rect(img, 4, 16, 11, 23, (200, 110, 80))
    rect(img, 3, 15, 12, 17, (220, 130, 96))
    for (x, y, w) in [(7, 2, 3), (3, 6, 4), (10, 5, 4), (5, 10, 5), (1, 11, 3), (11, 10, 3)]:
        ellipse(img, x - w // 2, y, x + w // 2 + 1, y + w + 1, (80, 160, 90))
    vline(img, 7, 6, 15, (60, 130, 70))
    outline(img)
    return img


def item_shelf():
    img = new(28, 36)
    rect(img, 1, 1, 26, 35, WOOD_D)
    rect(img, 3, 3, 24, 33, (110, 72, 50))
    rnd = random.Random(11)
    for sy in (3, 13, 23):
        hline(img, 3, 24, sy + 9, WOOD)
        x = 4
        while x < 23:
            w = rnd.choice([2, 2, 3])
            h = rnd.randint(5, 8)
            c = rnd.choice([(220, 80, 80), (80, 140, 210), (240, 200, 90), (120, 190, 120), (200, 130, 210)])
            rect(img, x, sy + 9 - h, min(x + w - 1, 23), sy + 8, c)
            x += w + (1 if rnd.random() < 0.3 else 0)
    outline(img)
    return img


def item_pet_bed():
    img = new(28, 12)
    ellipse(img, 0, 1, 27, 11, (150, 110, 190))
    ellipse(img, 4, 3, 23, 9, (230, 210, 240))
    return img


def item_toy_box():
    img = new(22, 18)
    rect(img, 1, 6, 20, 17, (100, 170, 210))
    rect(img, 1, 6, 20, 8, (80, 140, 190))
    ellipse(img, 3, 1, 8, 6, (240, 90, 90))
    ellipse(img, 10, 0, 16, 6, (250, 210, 80))
    rect(img, 16, 2, 19, 6, (120, 200, 120))
    px(img, 5, 3, (255, 255, 255))
    outline(img)
    return img


def item_painting():
    img = new(24, 18)
    rect(img, 0, 0, 23, 17, (200, 150, 70))
    rect(img, 2, 2, 21, 15, (150, 210, 240))
    poly(img, [(2, 15), (9, 7), (15, 15)], (100, 170, 110))
    poly(img, [(10, 15), (16, 9), (21, 15)], (80, 150, 100))
    ellipse(img, 15, 3, 19, 7, (255, 230, 120))
    outline(img)
    return img


def item_fireplace():
    img = new(40, 36)
    rect(img, 0, 2, 39, 5, (160, 150, 150))
    rect(img, 2, 6, 37, 35, (190, 110, 90))
    for y in range(8, 36, 4):
        off = (y // 4) % 2 * 3
        for x in range(2 + off, 38, 6):
            vline(img, x, y, y + 3, (170, 96, 80))
        hline(img, 2, 37, y, (170, 96, 80))
    rect(img, 10, 16, 29, 35, (50, 36, 40))
    rect(img, 12, 32, 27, 33, (120, 80, 56))
    poly(img, [(14, 32), (17, 22), (20, 32)], (250, 140, 60))
    poly(img, [(18, 32), (22, 19), (26, 32)], (250, 180, 70))
    poly(img, [(16, 32), (20, 26), (23, 32)], (255, 230, 140))
    outline(img)
    return img


# ---------------------------------------------------------------- мелочи для эффектов
def fx_sprites():
    d = {}
    img = new(12, 7)  # миска с кормом
    rect(img, 1, 3, 10, 6, (220, 80, 80)); rect(img, 2, 2, 9, 3, (180, 120, 70))
    px(img, 3, 1, (200, 140, 80)); px(img, 6, 1, (200, 140, 80)); px(img, 8, 1, (160, 100, 60))
    d["food_bowl"] = outline(img)
    img = new(8, 8)
    ellipse(img, 1, 1, 6, 6, (240, 90, 90)); hline(img, 1, 6, 4, (255, 255, 255)); px(img, 3, 2, (255, 200, 200))
    d["ball"] = outline(img)
    img = new(6, 6)
    ellipse(img, 0, 0, 5, 5, (200, 230, 255, 200)); ellipse(img, 1, 1, 4, 4, (0, 0, 0, 0)); px(img, 1, 1, (255, 255, 255))
    d["bubble"] = img
    img = from_map([
        ".oo.oo.",
        "oRRoRRo",
        "oRLRRRo",
        "oRRRRRo",
        ".oRRRo.",
        "..oRo..",
        "...o...",
    ], {"o": OUT, "R": (240, 80, 110), "L": (255, 190, 200)})
    d["heart"] = img
    d["zzz"] = from_map([
        "ooooo",
        "oWWWo",
        "ooWoo",
        "oWooo",
        "oWWWo",
        "ooooo",
    ], {"o": OUT, "W": (220, 230, 255)})
    d["note"] = from_map([
        "...ooo",
        "...oYo",
        "...oYo",
        ".oooYo",
        "oYYYYo",
        "oYYYo.",
        ".ooo..",
    ], {"o": OUT, "Y": (250, 210, 90)})
    d["coin"] = from_map([
        "..oooo..",
        ".oYYYYo.",
        "oYLYYYYo",
        "oYLYyYYo",
        "oYYYyYYo",
        "oYYYYYYo",
        ".oyyyyo.",
        "..oooo..",
    ], {"o": OUT, "Y": (250, 200, 60), "y": (210, 150, 40), "L": (255, 244, 180)})
    d["sparkle"] = from_map([
        "..W..",
        "..W..",
        "WWYWW",
        "..W..",
        "..W..",
    ], {"W": (255, 255, 230), "Y": (255, 240, 150)})
    d["drop"] = from_map([
        ".o..",
        "oBo.",
        "oBBo",
        "oLBo",
        ".oo.",
    ], {"o": (60, 90, 160), "B": (120, 180, 250), "L": (220, 240, 255)})
    d["crumb"] = from_map(["cc", "cc"], {"c": (190, 130, 70)})
    d["star"] = from_map([".w.", "wWw", ".w."], {"w": (200, 210, 255, 160), "W": (255, 255, 255)})
    d["firefly"] = from_map(["Y"], {"Y": (240, 255, 150)})
    return d


# ---------------------------------------------------------------- иконки интерфейса 14x14
def icons():
    d = {}
    P = {"o": OUT, "R": (230, 90, 80), "r": (180, 60, 60), "W": (255, 250, 240), "B": (200, 140, 90), "b": (160, 100, 60),
         "Y": (250, 210, 70), "y": (220, 160, 40), "C": (100, 170, 240), "c": (60, 120, 200), "L": (220, 240, 255),
         "P": (240, 120, 150), "p": (200, 80, 120), "G": (120, 200, 120), "g": (80, 150, 90), "N": (90, 90, 140),
         "M": (240, 230, 170), "m": (200, 190, 130), "S": (160, 160, 170), "s": (120, 120, 130), "K": (250, 220, 190)}
    d["need_hunger"] = from_map([
        "..............",
        "........ooo...",
        ".......oBBBo..",
        "......oBBBBBo.",
        ".....oBBBbBBo.",
        ".....oBBBBBbo.",
        "....oBBBBBbo..",
        "...oobBBbbo...",
        "..oWooooo.....",
        ".oWWo.........",
        "oWWo..........",
        ".oWo..........",
        "..o...........",
        "..............",
    ], P)
    d["need_joy"] = from_map([
        "..............",
        "..ooo...ooo...",
        ".oPPPo.oPPPo..",
        "oPWPPPoPPPPPo.",
        "oPWPPPPPPPPPo.",
        "oPPPPPPPPPPPo.",
        "oPPPPPPPPPPpo.",
        ".oPPPPPPPPpo..",
        "..oPPPPPPpo...",
        "...oPPPPpo....",
        "....oPPpo.....",
        ".....opo......",
        "......o.......",
        "..............",
    ], P)
    d["need_energy"] = from_map([
        "..............",
        "......oooo....",
        ".....oYYYo....",
        "....oYYYo.....",
        "...oYYYo......",
        "..oYYYYoooo...",
        ".oYYYYYYYYo...",
        ".ooooYYYYo....",
        "....oYYYo.....",
        "...oYYyo......",
        "..oYyo........",
        "..oyo.........",
        "..oo..........",
        "..............",
    ], P)
    d["need_clean"] = from_map([
        "..............",
        "......oo......",
        ".....oCCo.....",
        ".....oCCo.....",
        "....oCCCCo....",
        "...oCCCCCCo...",
        "...oCLCCCCo...",
        "..oCLCCCCCCo..",
        "..oCLCCCCCco..",
        "..oCCCCCCCco..",
        "...oCCCCCco...",
        "....occcco....",
        ".....oooo.....",
        "..............",
    ], P)
    d["act_feed"] = from_map([
        "..............",
        "....B..B..B...",
        "...BbB.bB.Bb..",
        "..oooooooooo..",
        ".oBBbBBBbBBBo.",
        "oRRRRRRRRRRRRo",
        "oRWRRRRRRRRRRo",
        "oRRRRRRRRRRRRo",
        ".oRRRRRRRRRro.",
        "..orrrrrrrro..",
        "...oooooooo...",
        "..............",
        "..............",
        "..............",
    ], P)
    d["act_play"] = from_map([
        "..............",
        "....oooooo....",
        "...oRRRRRRo...",
        "..oRWRRRRRRo..",
        ".oRWRRRRRRRRo.",
        ".oRRRRRRRRRRo.",
        ".oWWWWWWWWWWo.",
        ".oWWWWWWWWWWo.",
        ".oRRRRRRRRRro.",
        ".oRRRRRRRRRro.",
        "..oRRRRRRRro..",
        "...orrrrrro...",
        "....oooooo....",
        "..............",
    ], P)
    d["act_wash"] = from_map([
        "..........oo..",
        ".........oLLo.",
        "..oo.....oLLo.",
        ".oLLo.....oo..",
        ".oLLo.........",
        "..oooooooooo..",
        ".oPPPPPPPPPPo.",
        "oPWWPPPPPPPPPo",
        "oPPPPPPPPPPPpo",
        "oPPPPPPPPPPPpo",
        ".opppppppppppo",
        "..oooooooooo..",
        "..............",
        "..............",
    ], P)
    d["act_sleep"] = from_map([
        "..............",
        ".....oooo.....",
        "...ooMMMo.....",
        "..oMMMMo......",
        ".oMMMMo.......",
        ".oMMMMo.......",
        "oMMMMMo.......",
        "oMMMMMo.....oo",
        "oMMMMMMo..ooMo",
        ".oMMMMMMooMMo.",
        ".omMMMMMMMMmo.",
        "..ommMMMMmmo..",
        "...oooooooo...",
        "..............",
    ], P)
    d["act_pet"] = from_map([
        "..............",
        "......oo......",
        ".....oKKo.oo..",
        "..oo.oKKooKKo.",
        ".oKKooKKoKKo..",
        ".oKKoKKKKKKo..",
        "..oKKKKKKKKo..",
        "..oKKKKKKKKo..",
        "..oKKKKKKKo...",
        "...oKKKKKKo...",
        "...oKKKKKo....",
        "....ooooo.....",
        "..............",
        "..............",
    ], P)
    d["act_shop"] = from_map([
        "..............",
        "..oooooooooo..",
        ".oRWRWRWRWRWo.",
        "oRWRWRWRWRWRWo",
        "oooooooooooooo",
        ".oBBBBBBBBBBo.",
        ".oBooooBBBBBo.",
        ".oBoCCoBoooBo.",
        ".oBoCCoBoYoBo.",
        ".oBoCCoBoooBo.",
        ".oBoCCoBBBBBo.",
        ".oooooooooooo.",
        "..............",
        "..............",
    ], P)
    d["act_home"] = from_map([
        "......oo......",
        ".....oRRo.....",
        "....oRRRRo....",
        "...oRRRRRRo...",
        "..oRRRRRRRRo..",
        ".oRRRRRRRRRRo.",
        "oooWWWWWWWWooo",
        "..oWWWWWBBWo..",
        "..oWCCWWBBWo..",
        "..oWCCWWBBWo..",
        "..oWWWWWBYWo..",
        "..oWWWWWBBWo..",
        "..oooooooooo..",
        "..............",
    ], P)
    d["act_tree"] = from_map([
        "..............",
        ".....oooo.....",
        "...ooGGGGoo...",
        "..oGGGGGGGGo..",
        ".oGGGgGGGGGGo.",
        ".oGGGGGGGgGGo.",
        ".oGgGGGGGGGGo.",
        "..oGGGGGGGgo..",
        "...oogBBgoo...",
        ".....oBBo.....",
        ".....oBBo.....",
        "....obBBbo....",
        "....oooooo....",
        "..............",
    ], P)
    d["act_gear"] = from_map([
        "..............",
        ".....oooo.....",
        "..oo.oSSo.oo..",
        ".oSSooSSooSSo.",
        ".oSSSSSSSSSSo.",
        "..oSSsooSSSo..",
        "ooSSSo..oSSSoo",
        "oSSSSo..oSSSSo",
        "ooSSSSooSSSsoo",
        "..oSSSSSSSso..",
        ".oSSSSSSSSsso.",
        ".oSSooSsooSso.",
        "..oo.oSso.oo..",
        ".....oooo.....",
    ], P)
    d["act_music"] = from_map([
        "..............",
        "......ooooooo.",
        "......oYYYYYo.",
        "......oYooooo.",
        "......oYo..oo.",
        "......oYo..oYo",
        "......oYo..oYo",
        "......oYo..oYo",
        "...ooooYo.ooYo",
        "..oYYYYYooYYYo",
        "..oYYYYYooYYo.",
        "...oYYYo..oo..",
        "....ooo.......",
        "..............",
    ], P)
    d["coin"] = fx_sprites()["coin"]
    return d


def emotes():
    """Пузыри-эмоции над питомцем 15x14."""
    bubble = from_map([
        "..ooooooooooo..",
        ".oWWWWWWWWWWWo.",
        "oWWWWWWWWWWWWWo",
        "oWWWWWWWWWWWWWo",
        "oWWWWWWWWWWWWWo",
        "oWWWWWWWWWWWWWo",
        "oWWWWWWWWWWWWWo",
        "oWWWWWWWWWWWWWo",
        "oWWWWWWWWWWWWWo",
        ".oWWWWWWWWWWWo.",
        "..oooooWooooo..",
        "......oWo......",
        ".......o.......",
        "...............",
    ], {"o": OUT, "W": (255, 255, 255)})
    ic = icons()
    out = {}
    for key, src in [("hunger", "need_hunger"), ("joy", "need_joy"), ("energy", "act_sleep"), ("clean", "need_clean")]:
        b = bubble.copy()
        small = ic[src].resize((9, 9), Image.NEAREST)
        b.alpha_composite(small, (3, 1))
        out[key] = b
    return out


def gen_items():
    items = {
        "flowers": item_flowers(), "lantern": item_lantern(), "bench": item_bench(), "mailbox": item_mailbox(),
        "gnome": item_gnome(), "bed": item_bed(), "rug": item_rug(), "lamp": item_lamp(), "plant": item_plant(),
        "shelf": item_shelf(), "pet_bed": item_pet_bed(), "toy_box": item_toy_box(), "painting": item_painting(),
        "fireplace": item_fireplace(),
    }
    for k, v in items.items():
        save(v, f"items/{k}.png")
    for k, v in fx_sprites().items():
        save(v, f"fx/{k}.png")
    for k, v in misc_fx().items():
        save(v, f"fx/{k}.png")
    for k, v in cursors().items():
        save(v, f"fx/{k}.png")
    for k, v in icons().items():
        save(v, f"ui/{k}.png")
    for k, v in emotes().items():
        save(v, f"fx/emote_{k}.png")


def gen_icon():
    """Иконка приложения 64x64: рыжий кот на круге."""
    img = new(32, 32)
    ellipse(img, 1, 1, 30, 30, (252, 226, 160))
    ellipse(img, 3, 3, 28, 28, (255, 238, 190))
    cat = cat_frame(CAT_COATS[0], FRAME_SPEC[9])
    img.alpha_composite(cat, (4, 4))
    outline(img)
    save(img.resize((64, 64), Image.NEAREST), "../../icon.png")


if __name__ == "__main__":
    gen_pets()
    gen_world()
    gen_items()
    gen_icon()
    print("windows:", HOUSE_WINDOWS)
    print("done ->", os.path.normpath(ROOT))
