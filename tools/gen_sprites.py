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
OUT = (43, 32, 54, 255)  # общий цвет контура


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


def outline(img, color=OUT, diagonal=False):
    """Автоматический контур вокруг непрозрачных пикселей."""
    w, h = img.size
    src = img.copy()
    px = src.load()
    dst = img.load()
    nbs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        nbs += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in nbs:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 0 and px[nx, ny][:3] != color[:3]:
                    dst[x, y] = rgba(color)
                    break
    return img


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


# ---------------------------------------------------------------- персонаж
# Холст 20x26. Карты 16x24 смещаются на (2, 2).
CW, CH = 20, 26
G = {  # оттенки серого для перекрашиваемых слоёв
    "o": (72, 72, 72), "s": (205, 205, 205), "S": (255, 255, 255),
    "h": (165, 165, 165), "H": (220, 220, 220), "L": (255, 255, 255),
}

BODY = [
    "................",
    ".....oooooo.....",
    "...ooSSSSSSoo...",
    "..oSSSSSSSSSSo..",
    ".oSSSSSSSSSSSSo.",
    ".oSSSSSSSSSSSSo.",
    ".oSSSSSSSSSSSSo.",
    ".oSSSSSSSSSSSSo.",
    ".oSSSSSSSSSSSSo.",
    ".osSSSSSSSSSSso.",
    "..osSSSSSSSSso..",
    "...oosSSSSsoo...",
    ".....ooSSoo.....",
    "......oSSo......",
    "....ooSSSSoo....",
    "...oSoSSSSoSo...",
    "...oSoSSSSoSo...",
    "...oSoSSSSoSo...",
    "...ooosSSsooo...",
    "....oSSSSSSo....",
    "....oSSooSSo....",
    "....oSSooSSo....",
    "....oSSooSSo....",
    "....oooooooo....",
]

CLOTHES_BOY = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "....ooBBBBoo....",
    "...oBoBBBBoBo...",
    "...oBobBBboBo...",
    "......bBBb......",
    "......PPPP......",
    "....oPPPPPPo....",
    "....oPPooPPo....",
    "....oPpoopPo....",
    "....oKKooKKo....",
    "....oooooooo....",
]
CLOTHES_GIRL = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "....ooDWWDoo....",
    "...oDoDDDDoDo...",
    "...oDodDDdoDo...",
    "......DDDD......",
    "....ooDDDDoo....",
    "...oDDdDDdDDo...",
    "...oddddddddo...",
    "................",
    "....oKKooKKo....",
    "....oooooooo....",
]
CLOTHES_PAL = {
    "o": OUT, "B": (84, 170, 190), "b": (58, 128, 150), "P": (92, 88, 150), "p": (68, 62, 118),
    "K": (120, 76, 60), "D": (236, 120, 150), "d": (198, 86, 122), "W": (255, 250, 240),
}


def char_layer(rows16, pal, extra=None):
    img = new(CW, CH)
    from_map(rows16, pal, img=img, ox=2, oy=2)
    return img


def eyes_layers():
    base = new(CW, CH)   # ресницы + блик (не перекрашиваются)
    iris = new(CW, CH)   # радужка (перекрашивается)
    closed = new(CW, CH)
    face = new(CW, CH)   # рот и румянец
    ox, oy = 2, 2
    for ex in (4, 10):
        hline(base, ex + ox, ex + 1 + ox, 6 + oy, OUT)
        px(iris, ex + ox, 7 + oy, (235, 235, 235))
        px(base, ex + 1 + ox, 7 + oy, (255, 255, 255))
        hline(iris, ex + ox, ex + 1 + ox, 8 + oy, (200, 200, 200))
        hline(closed, ex + ox, ex + 1 + ox, 8 + oy, OUT)
    hline(face, 7 + ox, 8 + ox, 10 + oy, (170, 70, 90))
    for bx in (3, 11):
        hline(face, bx + ox, bx + 1 + ox, 9 + oy, (255, 130, 140, 150))
    return base, iris, closed, face


# --- причёски (серые, перекрашиваются). Каждая: (front, back); карты 16x24 + (2,2)
HAIR = {}
HAIR["short"] = ([
    "....oooooooo....",
    "..ooHHHHHHLHoo..",
    ".oHHHHHHHLLHHHo.",
    "oHHHHHHHHHLHHHHo",
    "oHHHHHHHHHHHHHHo",
    "oHhHHhHHHHhHHhHo",
    "oHo...ohho...oHo",
    "oh............ho",
    "oo............oo",
], None)
HAIR["long"] = ([
    "....oooooooo....",
    "..ooHHHHHHHHoo..",
    ".oHHHHLLHHHHHHo.",
    "oHHHHLHHHHHHHHHo",
    "oHHHHHHHHHHHHHHo",
    "oHHHhHHHHHHhHHHo",
    "oHHo..ohHo...oHo",
    "oHo...........Ho",
    "oHo...........Ho",
    "oHo...........Ho",
    "oho..........oho",
], [
    "................",
    "....oooooooo....",
    "..ooHHHHHHHHoo..",
    ".oHHHHHHHHHHHHo.",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    "ohHHHHHHHHHHHHho",
    ".ohHhHHhhHHhHho.",
    "..oohoohhoohoo..",
])
HAIR["bob"] = ([
    "....oooooooo....",
    "..ooHHHHHHHHoo..",
    ".oHHHHLLLHHHHHo.",
    "oHHHHLHHHHHHHHHo",
    "oHHHHHHHHHHHHHHo",
    "oHhhhhhhhhhhhhHo",
    "oHo..........oHo",
    "oHo..........oHo",
    "oHHo........oHHo",
    "oHHo........oHHo",
    "ohho........ohho",
    "oooo........oooo",
], None)
HAIR["ponytail"] = (HAIR["short"][0], None)  # хвост добавляется ниже, в полных координатах

# Полные карты 20x26 (без смещения)
PONY_BACK = [
    "....................",
    "....................",
    "....................",
    "...............oo...",
    "..............oHHo..",
    "...............oHHo.",
    "................oHHo",
    "................oHHo",
    "................ohHo",
    "...............oHHo.",
    "...............oHho.",
    "...............oho..",
    "...............oo...",
]
SPIKY_FRONT = [
    "..........................",
]
SPIKY_FRONT = [
    ".....o....o...o.....",
    "....oHo..oHo.oHo....",
    "...oHHHooHHHoHHHo...",
    "..oHHHHHHHHHHHLHHo..",
    "..oHHHHHHHHHHLHHHo..",
    "..oHHHHHHHHHHHHHHo..",
    "..oHhHHhHHHhHHhHHo..",
    "..oHo..ohHho...oHo..",
    "..oh............ho..",
    "..oo............oo..",
]
BUNS_FRONT = [
    ".ooo............ooo.",
    "oHLHo..........oHLHo",
    "oHHHoo.oooooo.ooHHHo",
    "ohHHHooHHHHHHooHHHho",
    ".ohHHHHHHHLHHHHHHho.",
    "..oHHHHHHHHLHHHHHo..",
    "..oHHHHHHHHHHHHHHo..",
    "..oHHhHHHhhHHHhHHo..",
    "..oHo..........oHo..",
    "..oo............oo..",
]
HAIR_STYLES = ["short", "long", "ponytail", "bob", "buns", "spiky"]


def hair_layers(style):
    front, back = new(CW, CH), new(CW, CH)
    if style == "spiky":
        from_map(SPIKY_FRONT, G, img=front)
    elif style == "buns":
        from_map(BUNS_FRONT, G, img=front)
    else:
        f, b = HAIR[style]
        from_map(f, G, img=front, ox=2, oy=2)
        if b:
            from_map(b, G, img=back, ox=2, oy=2)
    if style == "ponytail":
        from_map(PONY_BACK, G, img=back)
    if style == "buns":
        # короткие пряди сзади, чтобы не было «лысины» по бокам шеи
        from_map(HAIR["bob"][0], G, img=back, ox=2, oy=2)
    return front, back


def gen_character():
    save(char_layer(BODY, G), "character/body.png")
    save(char_layer(CLOTHES_BOY, CLOTHES_PAL), "character/clothes_boy.png")
    save(char_layer(CLOTHES_GIRL, CLOTHES_PAL), "character/clothes_girl.png")
    base, iris, closed, face = eyes_layers()
    save(base, "character/eyes_base.png")
    save(iris, "character/eyes_iris.png")
    save(closed, "character/eyes_closed.png")
    save(face, "character/face.png")
    for st in HAIR_STYLES:
        f, b = hair_layers(st)
        save(f, f"character/hair_{st}_front.png")
        save(b, f"character/hair_{st}_back.png")


# ---------------------------------------------------------------- питомцы
# Лист 4 кадра по 16x16: 0 — покой A, 1 — покой B, 2 — глаза закрыты (сон/моргание), 3 — ест.
def pet_dog(frame):
    B, b, L, n = (196, 134, 82), (150, 96, 60), (242, 216, 172), OUT
    img = new(16, 16)
    dy = 1 if frame == 3 else 0
    # хвост
    if frame == 1:
        rect(img, 1, 6, 2, 7, B); rect(img, 2, 8, 3, 8, B)
    else:
        rect(img, 1, 4, 2, 6, B); rect(img, 2, 7, 3, 8, B)
    # туловище
    ellipse(img, 3, 7, 12, 13, B)
    rect(img, 5, 12, 10, 12, L)
    # лапы
    rect(img, 4, 12, 5, 14, B); rect(img, 10, 12, 11, 14, B)
    rect(img, 4, 14, 5, 14, L); rect(img, 10, 14, 11, 14, L)
    # голова
    rect(img, 9, 3 + dy, 13, 8 + dy, B)
    rect(img, 13, 6 + dy, 14, 8 + dy, L)
    img = outline(img)
    # ухо, глаз, нос
    rect(img, 9, 4 + dy, 10, 8 + dy, b)
    px(img, 14, 6 + dy, n)
    if frame == 2:
        hline(img, 11, 12, 5 + dy, n)
    else:
        px(img, 12, 5 + dy, n)
    if frame == 3:
        px(img, 14, 8 + dy, (200, 70, 80))  # язык
    return img


def pet_cat(frame):
    B, b, L, n = (238, 162, 84), (200, 116, 56), (252, 228, 192), OUT
    img = new(16, 16)
    dy = 1 if frame == 3 else 0
    # хвост вверх, покачивается
    if frame == 1:
        rect(img, 1, 4, 1, 9, B); rect(img, 2, 9, 3, 10, B); px(img, 2, 4, B)
    else:
        rect(img, 1, 5, 1, 9, B); rect(img, 2, 9, 3, 10, B); px(img, 0, 5, B)
    ellipse(img, 3, 8, 11, 13, B)
    rect(img, 4, 12, 5, 14, B); rect(img, 9, 12, 10, 14, B)
    # голова с ушами
    rect(img, 9, 4 + dy, 14, 9 + dy, B)
    px(img, 9, 3 + dy, B); px(img, 10, 2 + dy, B); px(img, 10, 3 + dy, B)
    px(img, 14, 3 + dy, B); px(img, 13, 2 + dy, B); px(img, 13, 3 + dy, B)
    img = outline(img)
    # полоски
    for x in (5, 7, 9):
        vline(img, x, 8, 9, b)
    rect(img, 11, 7 + dy, 13, 8 + dy, L)
    px(img, 12, 7 + dy, (240, 120, 140))  # нос
    if frame == 2:
        px(img, 10, 6 + dy, n); px(img, 11, 6 + dy, n); px(img, 13, 6 + dy, n); px(img, 14, 6 + dy, n)
    else:
        px(img, 11, 5 + dy, (120, 200, 90)); px(img, 11, 6 + dy, n)
        px(img, 13, 5 + dy, (120, 200, 90)); px(img, 13, 6 + dy, n)
    if frame == 3:
        px(img, 12, 9 + dy, (200, 70, 80))
    return img


def pet_parrot(frame):
    G_, g_, R, Y, Bl = (96, 196, 96), (58, 140, 76), (224, 76, 62), (250, 200, 70), (70, 120, 210)
    img = new(16, 16)
    dy = 1 if frame == 1 else 0
    # хвост
    rect(img, 5, 11 + dy, 6, 14, Bl)
    # тело
    ellipse(img, 4, 5 + dy, 11, 13, G_)
    # голова
    ellipse(img, 6, 1 + dy, 12, 7 + dy, R)
    # клюв
    rect(img, 12, 4 + dy, 13, 5 + dy, Y)
    px(img, 12, 6 + dy, Y)
    if frame == 3:
        px(img, 13, 6 + dy, Y)
    # лапки
    px(img, 7, 14, Y); px(img, 9, 14, Y)
    img = outline(img)
    # крыло
    if frame == 1:
        rect(img, 4, 6 + dy, 6, 9 + dy, g_); px(img, 3, 6 + dy, g_)
    else:
        rect(img, 5, 7 + dy, 7, 11, g_); rect(img, 5, 10, 6, 11, Bl)
    if frame == 2:
        hline(img, 9, 10, 4 + dy, OUT)
    else:
        px(img, 10, 3 + dy, (255, 255, 255)); px(img, 10, 4 + dy, OUT)
    return img


def pet_fish(frame):
    """Рыбка 12x8; аквариум отдельно."""
    O, o_, F = (250, 140, 60), (220, 100, 40), (255, 196, 120)
    img = new(12, 8)
    ellipse(img, 3, 1, 10, 6, O)
    # хвост
    if frame == 1:
        poly(img, [(0, 1), (3, 3), (3, 4), (0, 5)], F)
    else:
        poly(img, [(0, 0), (3, 3), (3, 4), (0, 6)], F)
    img = outline(img)
    px(img, 6, 1, F); px(img, 6, 6, F)
    vline(img, 5, 2, 5, o_)
    if frame == 2:
        px(img, 8, 3, OUT); px(img, 9, 3, OUT)
    else:
        px(img, 8, 3, (255, 255, 255)); px(img, 8, 2, OUT)
    if frame == 3:
        px(img, 10, 4, OUT)
    return img


def fish_bowl():
    """Аквариум на подставке 28x30; стекло полупрозрачное."""
    img = new(28, 30)
    glass = (210, 236, 255, 90)
    water = (110, 180, 240, 120)
    ellipse(img, 2, 2, 25, 22, glass)
    ellipse(img, 3, 6, 24, 21, water)
    rect(img, 6, 1, 21, 3, (0, 0, 0, 0))
    # горлышко
    hline(img, 6, 21, 2, (230, 245, 255, 200))
    # гравий
    for x in range(6, 22):
        c = [(190, 160, 120), (160, 130, 100), (220, 190, 150)][x % 3]
        px(img, x, 20, c)
    for x in range(8, 20):
        px(img, x, 21, [(170, 140, 110), (210, 180, 140)][x % 2])
    # водоросль
    vline(img, 8, 15, 19, (70, 160, 90)); px(img, 9, 16, (70, 160, 90)); px(img, 7, 17, (70, 160, 90))
    # блик
    vline(img, 5, 8, 12, (255, 255, 255, 180))
    # подставка
    rect(img, 7, 23, 20, 24, (150, 100, 70))
    rect(img, 9, 25, 18, 29, (120, 78, 56))
    rect(img, 10, 25, 10, 29, (150, 100, 70))
    outline(img)
    return img


def gen_pets():
    for name, fn in [("dog", pet_dog), ("cat", pet_cat), ("parrot", pet_parrot), ("fish", pet_fish)]:
        save(sheet([fn(i) for i in range(4)]), f"pets/{name}.png")
    save(fish_bowl(), "pets/fish_bowl.png")


# ---------------------------------------------------------------- дома (экстерьер)
# Каждый дом рисуется на своём холсте, якорь — центр нижнего края.
HOUSE_WINDOWS = {}  # tier -> список (x, y) центров окон относительно якоря (для ночного света)


def _planks(img, x0, y0, x1, y1, c1, c2, step=3):
    for y in range(y0, y1 + 1):
        rect(img, x0, y, x1, y, c1 if ((y - y0) // step) % 2 == 0 else c2)


def _window(img, x0, y0, w, h, frame=(120, 80, 60), glass=(150, 200, 235), wins=None, anchor=None):
    rect(img, x0 - 1, y0 - 1, x0 + w, y0 + h, frame)
    rect(img, x0, y0, x0 + w - 1, y0 + h - 1, glass)
    vline(img, x0 + w // 2, y0, y0 + h - 1, frame)
    hline(img, x0, x0 + w - 1, y0 + h // 2, frame)
    px(img, x0 + 1, y0 + 1, (230, 245, 255))
    if wins is not None:
        ax, ay = anchor
        wins.append((x0 + w / 2 - ax, y0 + h / 2 - ay))


def house_tent():
    W, H = 64, 46
    img = new(W, H)
    wins = []
    c1, c2 = (232, 110, 90), (250, 236, 210)
    # полосатый тент
    for x in range(4, 60):
        top = int(40 - (40 - 8) * (1 - abs(x - 32) / 28))
        col = c1 if (x // 5) % 2 == 0 else c2
        vline(img, x, top, 42, col)
    # вход
    poly(img, [(32, 18), (24, 42), (40, 42)], (70, 50, 70))
    poly(img, [(32, 18), (27, 42), (32, 42)], (110, 70, 80))
    # шест и флажок
    vline(img, 32, 2, 10, (140, 100, 70))
    poly(img, [(33, 2), (40, 4), (33, 6)], (250, 200, 80))
    outline(img)
    # колышки
    px(img, 3, 43, (140, 100, 70)); px(img, 60, 43, (140, 100, 70))
    wins.append((0, -12))  # тёплый свет изнутри палатки
    return img, wins


def house_hut():
    W, H = 76, 58
    img = new(W, H)
    wins = []
    anchor = (W / 2, H - 1)
    # стены из брёвен
    _planks(img, 12, 26, 63, 55, (170, 116, 72), (146, 96, 60), step=3)
    # соломенная крыша
    poly(img, [(38, 4), (4, 30), (72, 30)], (226, 190, 100))
    for i in range(6, 30, 4):
        hline(img, 38 - i + 2, 38 + i - 2, 4 + i, (196, 156, 76))
    # дверь
    rect(img, 32, 38, 43, 55, (110, 72, 52))
    rect(img, 33, 39, 42, 55, (130, 86, 60))
    px(img, 41, 47, (250, 210, 90))
    # круглое окно
    ellipse(img, 16, 34, 26, 44, (120, 80, 60))
    ellipse(img, 17, 35, 25, 43, (150, 200, 235))
    wins.append((21 - anchor[0], 39 - anchor[1]))
    _window(img, 51, 36, 8, 8, wins=wins, anchor=anchor)
    outline(img)
    return img, wins


def house_small():
    W, H = 92, 72
    img = new(W, H)
    wins = []
    anchor = (W / 2, H - 1)
    # труба
    rect(img, 64, 6, 71, 22, (170, 90, 80))
    rect(img, 63, 5, 72, 7, (140, 70, 64))
    # стены
    rect(img, 10, 32, 81, 69, (246, 232, 206))
    for y in range(34, 70, 6):
        hline(img, 10, 81, y, (232, 214, 186))
    # крыша
    poly(img, [(46, 6), (2, 34), (90, 34)], (206, 82, 76))
    for i in range(8, 30, 5):
        hline(img, 46 - int(i * 1.55), 46 + int(i * 1.55), 6 + i, (176, 62, 62))
    hline(img, 2, 90, 34, (150, 50, 56))
    # дверь
    rect(img, 40, 48, 52, 69, (126, 84, 62))
    rect(img, 42, 50, 50, 69, (150, 100, 72))
    px(img, 49, 59, (250, 210, 90))
    _window(img, 18, 44, 12, 10, wins=wins, anchor=anchor)
    _window(img, 62, 44, 12, 10, wins=wins, anchor=anchor)
    # ступенька
    rect(img, 38, 70, 54, 71, (170, 160, 150))
    outline(img)
    return img, wins


def house_cozy():
    W, H = 116, 88
    img = new(W, H)
    wins = []
    anchor = (W / 2, H - 1)
    rect(img, 84, 4, 92, 24, (150, 110, 100))
    rect(img, 83, 3, 93, 5, (120, 86, 80))
    # стены (2 этажа)
    rect(img, 10, 30, 105, 83, (238, 214, 170))
    for y in range(32, 84, 5):
        hline(img, 10, 105, y, (222, 194, 150))
    # крыша
    poly(img, [(58, 2), (0, 32), (115, 32)], (86, 120, 196))
    for i in range(6, 30, 4):
        hline(img, 58 - int(i * 1.9), 58 + int(i * 1.9), 2 + i, (66, 96, 170))
    hline(img, 0, 115, 32, (56, 80, 150))
    # мансардное окно
    _window(img, 52, 14, 12, 10, wins=wins, anchor=anchor)
    # окна 2 этажа
    _window(img, 18, 38, 14, 11, wins=wins, anchor=anchor)
    _window(img, 84, 38, 14, 11, wins=wins, anchor=anchor)
    # крыльцо с навесом
    rect(img, 34, 56, 81, 58, (180, 120, 80))
    poly(img, [(32, 56), (58, 48), (84, 56)], (86, 120, 196))
    vline(img, 36, 58, 83, (200, 150, 110)); vline(img, 79, 58, 83, (200, 150, 110))
    # дверь
    rect(img, 51, 62, 64, 83, (110, 74, 58))
    rect(img, 53, 64, 62, 83, (140, 94, 70))
    ellipse(img, 55, 66, 60, 70, (250, 220, 130))
    px(img, 61, 74, (250, 210, 90))
    # нижние окна с ящиками для цветов
    for x0 in (16, 86):
        _window(img, x0, 63, 14, 10, wins=wins, anchor=anchor)
        rect(img, x0 - 1, 74, x0 + 14, 76, (150, 100, 70))
        for i in range(0, 15, 3):
            px(img, x0 + i, 73, [(240, 90, 110), (250, 200, 80), (200, 120, 220)][(i // 3) % 3])
    rect(img, 30, 84, 86, 86, (170, 160, 150))
    outline(img)
    return img, wins


# ---------------------------------------------------------------- интерьеры 320x180
def interior(tier):
    img = new(320, 180)
    if tier >= 3:
        wall1, wall2 = (242, 214, 196), (230, 196, 180)
    else:
        wall1, wall2 = (220, 226, 204), (206, 214, 188)
    rect(img, 0, 0, 319, 131, wall1)
    for x in range(0, 320, 8):
        vline(img, x, 0, 131, wall2)
        vline(img, x + 1, 0, 131, wall2)
    # бордюр
    rect(img, 0, 118, 319, 131, (180, 130, 96))
    hline(img, 0, 319, 118, (140, 96, 70))
    # пол
    rect(img, 0, 132, 319, 179, (196, 146, 98))
    for y in range(132, 180, 6):
        hline(img, 0, 319, y, (170, 122, 80))
        off = (y // 6) % 2 * 20
        for x in range(off, 320, 40):
            vline(img, x, y, y + 5, (170, 122, 80))
    windows = [(24, 28)] + ([(232, 28)] if tier >= 3 else [])
    for wx, wy in windows:
        w, h = 64, 50
        rect(img, wx - 4, wy - 4, wx + w + 3, wy + h + 3, (150, 100, 70))
        rect(img, wx - 6, wy + h + 2, wx + w + 5, wy + h + 5, (170, 118, 82))
        rect(img, wx, wy, wx + w - 1, wy + h - 1, (0, 0, 0, 0))  # дыра под небо
        vline(img, wx + w // 2 - 1, wy, wy + h - 1, (150, 100, 70))
        vline(img, wx + w // 2, wy, wy + h - 1, (150, 100, 70))
        hline(img, wx, wx + w - 1, wy + h // 2, (150, 100, 70))
        # шторы
        curtain = (120, 170, 200) if tier < 3 else (214, 110, 120)
        for i in range(0, 12):
            rect(img, wx - 10 + i // 3, wy - 6 + i * 5, wx - 2, wy - 2 + i * 5, curtain)
            rect(img, wx + w + 1, wy - 6 + i * 5, wx + w + 9 - i // 3, wy - 2 + i * 5, curtain)
        rect(img, wx - 12, wy - 8, wx + w + 11, wy - 6, (120, 84, 60))
    return img


# ---------------------------------------------------------------- окружение
def hills():
    img = new(320, 70)
    rnd = random.Random(3)
    import math
    for x in range(320):
        h1 = 30 + 10 * math.sin(x / 40.0) + 6 * math.sin(x / 17.0 + 1)
        vline(img, x, int(h1), 69, (150, 170, 210))
        h2 = 44 + 7 * math.sin(x / 30.0 + 2) + 4 * math.sin(x / 11.0)
        vline(img, x, int(h2), 69, (110, 180, 120))
    return img


def ground():
    img = new(320, 48)
    rect(img, 0, 0, 319, 47, (116, 186, 96))
    rnd = random.Random(7)
    for _ in range(420):
        x, y = rnd.randrange(320), rnd.randrange(2, 48)
        px(img, x, y, rnd.choice([(96, 164, 84), (136, 200, 110), (104, 172, 90)]))
    for _ in range(40):
        x, y = rnd.randrange(320), rnd.randrange(4, 46)
        c = rnd.choice([(250, 240, 250), (250, 210, 80), (240, 120, 150), (170, 150, 240)])
        px(img, x, y, c)
    for x in range(0, 320):
        if rnd.random() < 0.5:
            px(img, x, 0, (136, 200, 110))
    return img


def path_patch():
    img = new(40, 30)
    poly(img, [(14, 0), (26, 0), (38, 29), (2, 29)], (214, 190, 140))
    rnd = random.Random(5)
    for _ in range(40):
        px(img, rnd.randrange(8, 32), rnd.randrange(2, 29), (196, 170, 124))
    return img


def tree_round():
    img = new(34, 46)
    rect(img, 15, 28, 19, 45, (130, 90, 64))
    ellipse(img, 2, 2, 31, 32, (76, 150, 86))
    ellipse(img, 6, 4, 26, 22, (96, 176, 100))
    ellipse(img, 10, 6, 18, 12, (130, 200, 120))
    outline(img)
    return img


def tree_pine():
    img = new(26, 46)
    rect(img, 11, 36, 14, 45, (120, 84, 60))
    for i, (y, w) in enumerate([(2, 4), (10, 8), (18, 11), (26, 12)]):
        poly(img, [(12, y), (12 - w, y + 12), (13 + w, y + 12)], (58, 132, 96) if i % 2 else (70, 150, 104))
    outline(img)
    return img


def bush():
    img = new(22, 12)
    ellipse(img, 1, 2, 12, 11, (86, 160, 90))
    ellipse(img, 8, 0, 20, 11, (96, 176, 100))
    outline(img)
    return img


def cloud(w, h, seed):
    img = new(w, h)
    rnd = random.Random(seed)
    for _ in range(6):
        cx = rnd.randint(h // 2, w - h // 2)
        r = rnd.randint(h // 3, h // 2)
        ellipse(img, cx - r, h - 1 - 2 * r, cx + r, h - 1, (255, 255, 255))
    rect(img, h // 2, h - h // 3, w - h // 2, h - 1, (255, 255, 255))
    # тень снизу
    for x in range(w):
        for y in range(h - 1, -1, -1):
            if img.getpixel((x, y))[3]:
                px(img, x, y, (220, 226, 240))
                break
    return img


def sun():
    img = new(18, 18)
    ellipse(img, 2, 2, 15, 15, (255, 222, 110))
    ellipse(img, 4, 4, 11, 11, (255, 240, 170))
    return img


def moon():
    img = new(14, 14)
    ellipse(img, 1, 1, 12, 12, (240, 240, 220))
    ellipse(img, 5, -1, 15, 10, (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse([5, -1, 15, 10], fill=(0, 0, 0, 0))
    px(img, 3, 7, (210, 210, 190)); px(img, 5, 10, (210, 210, 190))
    return img


def gen_world():
    global HOUSE_WINDOWS
    for tier, fn in enumerate([house_tent, house_hut, house_small, house_cozy]):
        img, wins = fn()
        save(img, f"house/house_{tier}.png")
        HOUSE_WINDOWS[tier] = wins
    save(interior(2), "house/interior_2.png")
    save(interior(3), "house/interior_3.png")
    save(hills(), "world/hills.png")
    save(ground(), "world/ground.png")
    save(path_patch(), "world/path.png")
    save(tree_round(), "world/tree_round.png")
    save(tree_pine(), "world/tree_pine.png")
    save(bush(), "world/bush.png")
    save(cloud(40, 16, 1), "world/cloud_a.png")
    save(cloud(28, 12, 2), "world/cloud_b.png")
    save(cloud(52, 18, 3), "world/cloud_c.png")
    save(sun(), "world/sun.png")
    save(moon(), "world/moon.png")


# ---------------------------------------------------------------- мебель и декор
WOOD, WOOD_D, WOOD_L = (170, 116, 76), (130, 86, 58), (200, 150, 104)


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
    for k, v in icons().items():
        save(v, f"ui/{k}.png")
    for k, v in emotes().items():
        save(v, f"fx/emote_{k}.png")


def gen_icon():
    """Иконка приложения 64x64: мордочка кота на круге."""
    img = new(32, 32)
    ellipse(img, 1, 1, 30, 30, (250, 220, 150))
    cat = pet_cat(0).crop((8, 1, 16, 11)).resize((16, 20), Image.NEAREST)
    img.alpha_composite(cat, (8, 6))
    outline(img)
    save(img.resize((64, 64), Image.NEAREST), "../../icon.png")


if __name__ == "__main__":
    gen_character()
    gen_pets()
    gen_world()
    gen_items()
    gen_icon()
    print("windows:", HOUSE_WINDOWS)
    print("done ->", os.path.normpath(ROOT))
