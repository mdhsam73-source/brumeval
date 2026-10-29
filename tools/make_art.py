#!/usr/bin/env python3
"""Génère les sprites de Brumeval (art/tiles.png, art/sprites.png, scripts/atlas_data.gd).

Tout est dessiné ici, pixel par pixel, pour rester 100 % original.
Relancer après une modification :  python3 tools/make_art.py
Les PNG peuvent ensuite être retouchés dans Aseprite / LibreSprite, tant que la
disposition décrite dans scripts/atlas_data.gd est respectée.
"""
import json
import math
import os
import random

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art")
TS = 16


# ------------------------------------------------------------------ couleurs

def rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c, d, t):
    return tuple(int(round(c[i] + (d[i] - c[i]) * t)) for i in range(3)) + (c[3],)


def dark(c, t=0.3):
    return mix(c, (20, 16, 28, 255), t)


def light(c, t=0.25):
    return mix(c, (255, 250, 235, 255), t)


def ramp(h):
    c = rgb(h)
    return (light(c, 0.28), c, dark(c, 0.3))


CLEAR = (0, 0, 0, 0)


class Spr:
    def __init__(self, w, h, k=1.0):
        self.w, self.h, self.k = w, h, k
        self.im = Image.new("RGBA", (w, h), CLEAR)
        self.px = self.im.load()

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if len(c) == 4 and c[3] < 255 and self.px[x, y][3] > 0:
                a = c[3] / 255
                o = self.px[x, y]
                self.px[x, y] = tuple(int(o[i] * (1 - a) + c[i] * a) for i in range(3)) + (max(o[3], c[3]),)
            else:
                self.px[x, y] = c

    def r(self, x, y, w, h, c):
        k = self.k
        x0, y0 = int(round(x * k)), int(round(y * k))
        x1, y1 = int(round((x + w) * k)), int(round((y + h) * k))
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                self.p(xx, yy, c)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(self.h):
            for x in range(self.w):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    self.p(x, y, c)

    def outline(self, strength=0.55, skip_alpha=200):
        """Contour d'un pixel autour des formes, teinté par la couleur voisine."""
        src = self.im.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] != 0:
                    continue
                best = None
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and src[xx, yy][3] >= skip_alpha:
                        best = src[xx, yy]
                        break
                if best:
                    self.px[x, y] = mix(best, (18, 12, 24, 255), strength)[:3] + (255,)

    def shadow(self, cx, cy, rx, ry, a=80):
        for y in range(self.h):
            for x in range(self.w):
                if self.px[x, y][3] == 0 and ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                    self.px[x, y] = (10, 8, 20, a)

    def flip(self):
        self.im = self.im.transpose(Image.FLIP_LEFT_RIGHT)
        self.px = self.im.load()
        return self


# ------------------------------------------------------------------ tuiles

BIO = {
    "plain": ("#5a8a3f", "#6f9e4a", "#4a7534", "#86b85a"),
    "forest": ("#34573a", "#406a44", "#284630", "#557f4e"),
    "marsh": ("#4a5a3c", "#5a6b46", "#3a4831", "#6e7e4c"),
    "crypt": ("#302a3a", "#3b3448", "#241f2e", "#4c4262"),
}


def grass(bio, v):
    base, hi, lo, acc = [rgb(c) for c in BIO[bio]]
    s = Spr(TS, TS)
    r = random.Random(sum(map(ord, bio)) * 31 + v)
    s.r(0, 0, 16, 16, base)
    for _ in range(14):
        x, y = r.randrange(16), r.randrange(16)
        s.p(x, y, lo if r.random() < 0.5 else hi)
    for _ in range(5):
        x, y = r.randrange(16), r.randrange(16)
        s.r(x, y, 2, 1, lo)
    tufts = [2, 4, 3, 1][v]
    for _ in range(tufts):
        x, y = r.randrange(2, 14), r.randrange(2, 14)
        s.p(x, y, acc)
        s.p(x - 1, y + 1, hi)
        s.p(x + 1, y + 1, hi)
        s.p(x, y + 1, lo)
    if v == 2:
        for _ in range(2):
            x, y = r.randrange(2, 13), r.randrange(2, 13)
            s.p(x, y, rgb("#9a9488") if bio != "crypt" else rgb("#5a5068"))
            s.p(x + 1, y, rgb("#7a746a") if bio != "crypt" else rgb("#463e54"))
    if v == 3 and bio == "marsh":
        s.ellipse(8, 9, 5, 3, rgb("#2e443e"))
        s.r(5, 8, 3, 1, rgb("#45625a"))
        s.p(10, 10, rgb("#45625a"))
    elif v == 3 and bio == "plain":
        for _ in range(2):
            x, y = r.randrange(2, 14), r.randrange(2, 14)
            s.p(x, y, rgb("#f2efe6"))
    elif v == 3 and bio == "crypt":
        s.r(4, 7, 1, 3, rgb("#4c4262"))
        s.r(10, 3, 1, 2, rgb("#4c4262"))
    return s


def flowers(v):
    s = Spr(TS, TS)
    r = random.Random(900 + v)
    cols = [("#f0d45a", "#c9a43a"), ("#e8799a", "#b8566f"), ("#f4f1e8", "#c4c0b8"), ("#b28ae6", "#8a64bc")]
    for i in range(3 + v % 2):
        x, y = r.randrange(3, 13), r.randrange(3, 13)
        c, d = [rgb(q) for q in cols[(v + i) % 4]]
        s.p(x, y + 2, rgb("#3f6a2e"))
        s.p(x, y + 3, rgb("#3f6a2e"))
        s.p(x, y - 1, c)
        s.p(x - 1, y, c)
        s.p(x + 1, y, d)
        s.p(x, y + 1, d)
        s.p(x, y, rgb("#f7c23a"))
    return s


def edge_mask(mask, depth, rnd, x, y):
    """Distance au bord non relié le plus proche, avec bord irrégulier."""
    d = 99.0
    sides = []
    if not mask & 1:
        sides.append(("N", y, x))
    if not mask & 2:
        sides.append(("E", 15 - x, y))
    if not mask & 4:
        sides.append(("S", 15 - y, x))
    if not mask & 8:
        sides.append(("W", x, y))
    for name, dist, along in sides:
        jitter = rnd[name][along]
        d = min(d, dist - jitter)
    for a, b, cx, cy in (("N", "W", 0, 0), ("N", "E", 15, 0), ("S", "W", 0, 15), ("S", "E", 15, 15)):
        if any(s[0] == a for s in sides) and any(s[0] == b for s in sides):
            if abs(x - cx) + abs(y - cy) <= 2:
                d = min(d, -1)
            elif abs(x - cx) + abs(y - cy) <= 3:
                d = min(d, 0.5)
    return d


def jitters(seed, amp):
    r = random.Random(seed)
    return {k: [r.random() * amp for _ in range(16)] for k in "NESW"}


def path_tile(mask):
    s = Spr(TS, TS)
    r = random.Random(40 + mask)
    base, hi, lo = rgb("#a2865a"), rgb("#b89c6c"), rgb("#86693f")
    edge = rgb("#6e5434")
    rnd = jitters(70 + mask, 1.2)
    for y in range(16):
        for x in range(16):
            d = edge_mask(mask, 1, rnd, x, y)
            if d < 0.6:
                continue
            c = base
            if d < 1.6:
                c = edge
            elif d < 2.6:
                c = lo
            s.p(x, y, c)
    for _ in range(9):
        x, y = r.randrange(1, 15), r.randrange(1, 15)
        if s.get(x, y) == base:
            s.p(x, y, hi if r.random() < 0.6 else lo)
    for _ in range(3):
        x, y = r.randrange(2, 13), r.randrange(2, 13)
        if s.get(x, y) == base and s.get(x + 1, y) == base:
            s.p(x, y, rgb("#cdb48a"))
            s.p(x + 1, y, rgb("#8c7350"))
    return s


WATER = (rgb("#2f6a8e"), rgb("#25577a"), rgb("#5294bc"), rgb("#d6ecf2"))


def water_tile(mask, f, full=False):
    base, deep, hi, foam = WATER
    s = Spr(TS, TS)
    r = random.Random(500 + mask * 7)
    rnd = jitters(300 + mask, 1.0)
    for y in range(16):
        for x in range(16):
            d = 99 if full else edge_mask(mask, 2, rnd, x, y)
            if d < 0.5:
                continue
            c = base if (x + y * 3) % 11 else deep
            if d < 1.5:
                c = foam if (x + y + f) % 3 else hi
            elif d < 2.5:
                c = hi if (x * 3 + y + f * 2) % 4 == 0 else base
            s.p(x, y, c)
    for i in range(3):
        x = (r.randrange(0, 12) + f * 2) % 13
        y = (i * 5 + r.randrange(0, 3) + f) % 15
        for xx in range(x, x + 3):
            if s.get(xx, y) == base or s.get(xx, y) == deep:
                s.p(xx, y, hi)
    return s


def bridge(horizontal):
    s = water_tile(15, 0, full=True)
    wood, wlo, whi = rgb("#9a6a3a"), rgb("#6a4422"), rgb("#b8844c")
    for y in range(0, 16, 4):
        s.r(1, y, 14, 3, wood)
        s.r(1, y, 14, 1, whi)
        s.r(1, y + 3, 14, 1, wlo)
        s.p(4 + y % 8, y + 1, wlo)
    s.r(0, 0, 1, 16, wlo)
    s.r(15, 0, 1, 16, wlo)
    for y in (1, 9):
        s.r(0, y, 2, 3, rgb("#4e3218"))
        s.r(14, y, 2, 3, rgb("#4e3218"))
    if horizontal:
        s.im = s.im.transpose(Image.ROTATE_90)
        s.px = s.im.load()
    return s


def wall(v):
    s = Spr(TS, TS)
    base, hi, lo, mort = rgb("#57516a"), rgb("#6e6884"), rgb("#423d52"), rgb("#2c2838")
    s.r(0, 0, 16, 16, mort)
    for row in range(4):
        y = row * 4
        off = 0 if row % 2 else 4
        for bx in range(-1, 3):
            x = bx * 8 + off
            s.r(x + 1, y + 1, 7, 3, base)
            s.r(x + 1, y + 1, 7, 1, hi)
            s.r(x + 7, y + 2, 1, 2, lo)
    if v == 1:
        s.r(3, 9, 3, 1, rgb("#4e6a3e"))
        s.r(4, 10, 1, 2, rgb("#4e6a3e"))
        s.p(11, 5, mort)
        s.p(12, 6, mort)
    return s


def gate(opened):
    s = Spr(TS, TS)
    stone, lo = rgb("#6e6884"), rgb("#423d52")
    s.r(0, 0, 16, 16, rgb("#120e18"))
    s.r(0, 0, 3, 16, stone)
    s.r(13, 0, 3, 16, stone)
    s.r(0, 0, 16, 3, stone)
    s.r(2, 3, 1, 13, lo)
    s.r(13, 3, 1, 13, lo)
    s.r(3, 3, 10, 1, lo)
    if opened:
        s.r(3, 4, 10, 12, rgb("#1c1626"))
        s.r(4, 14, 8, 2, rgb("#2a2236"))
    else:
        for x in range(4, 13, 3):
            s.r(x, 3, 1, 13, rgb("#9a94a8"))
            s.p(x, 4, rgb("#c4bed0"))
        s.r(3, 8, 10, 1, rgb("#9a94a8"))
        s.r(7, 7, 2, 3, rgb("#b48ae6"))
        s.p(7, 7, rgb("#e0c8ff"))
    return s


def crypt_floor(v):
    s = Spr(TS, TS)
    base, hi, lo, gap = rgb("#3a3346"), rgb("#463e54"), rgb("#2e2838"), rgb("#1e1928")
    s.r(0, 0, 16, 16, gap)
    for (x, y) in ((0, 0), (8, 0), (0, 8), (8, 8)):
        s.r(x + 1, y + 1, 7, 7, base)
        s.r(x + 1, y + 1, 7, 1, hi)
        s.r(x + 1, y + 7, 7, 1, lo)
    if v == 1:
        s.p(3, 4, gap)
        s.p(4, 5, gap)
        s.p(5, 5, gap)
        s.p(12, 11, gap)
    if v == 2:
        s.r(10, 2, 4, 4, rgb("#4a3a66"))
        s.p(11, 3, rgb("#a080e0"))
        s.p(12, 4, rgb("#a080e0"))
    return s


def rock(v):
    s = Spr(TS, TS)
    base, hi, lo = rgb("#8a8792"), rgb("#aeabb6"), rgb("#64616e")
    s.ellipse(8, 9.5, 6.5, 5, base)
    s.ellipse(6.5, 7.5, 3.5, 2.2, hi)
    s.r(3, 12, 10, 2, lo)
    s.r(10, 8, 2, 4, lo)
    s.p(7, 10, lo)
    if v == 1:
        s.r(4, 5, 5, 2, rgb("#5c7a44"))
        s.r(5, 4, 3, 1, rgb("#6e8e50"))
    s.outline()
    s.shadow(8, 14.5, 7, 2)
    return s


def stump():
    s = Spr(TS, TS)
    s.r(4, 8, 8, 6, rgb("#6b4a2a"))
    s.r(4, 8, 8, 2, rgb("#b08850"))
    s.r(6, 8, 4, 1, rgb("#d0a868"))
    s.r(10, 10, 2, 4, rgb("#523620"))
    s.p(3, 13, rgb("#6b4a2a"))
    s.p(12, 13, rgb("#523620"))
    s.outline()
    s.shadow(8, 14.5, 6, 1.8)
    return s


def tree(kind, v):
    s = Spr(TS, 32)
    r = random.Random(1000 + v * 17 + len(kind))
    if kind == "plain":
        leaf = [rgb(c) for c in (("#4c8a3a", "#6aa84a", "#356a2c", "#8cc45a") if v == 0 else ("#5a8f36", "#78ae48", "#3e6c28", "#a2c85a"))]
        s.r(6, 19, 4, 10, rgb("#6e4a28"))
        s.r(9, 19, 1, 10, rgb("#4e3218"))
        s.r(7, 20, 1, 7, rgb("#8a6036"))
        s.r(5, 27, 6, 2, rgb("#5e3e20"))
        s.ellipse(8, 11, 7.5, 8.5, leaf[0])
        s.ellipse(5, 9, 3.5, 3.5, leaf[1])
        s.ellipse(11, 7, 2.8, 2.6, leaf[1])
        s.ellipse(9, 16, 5.5, 3, leaf[2])
        for _ in range(16):
            x, y = r.randrange(2, 14), r.randrange(4, 18)
            if s.get(x, y)[3]:
                s.p(x, y, leaf[3] if y < 10 else leaf[2])
        if v == 1:
            for (x, y) in ((5, 11), (10, 13), (8, 6)):
                s.p(x, y, rgb("#d84a4a"))
        s.outline()
        s.shadow(8, 29.5, 7, 2.4)
    elif kind == "forest":
        lv = [rgb(c) for c in ("#24503a", "#336a48", "#173a2a", "#4a845a")]
        s.r(7, 24, 2, 5, rgb("#4a301a"))
        tiers = [(2, 3), (5, 6), (8, 8), (12, 10), (16, 12), (20, 14)] if v == 0 else [(3, 4), (7, 7), (11, 10), (15, 12), (19, 14)]
        for (y, w) in tiers:
            for i in range(5):
                ww = w - (4 - i) * 2 if w > 6 else w - (4 - i)
                ww = max(2, ww)
                s.r(8 - ww / 2, y + i, ww, 1, lv[0])
            s.r(8 - w / 2 + 1, y + 4, w - 2, 1, lv[2])
            s.r(8 - w / 4, y + 1, 2, 1, lv[1])
            s.p(int(8 - w / 4) - 1, y + 2, lv[3])
        s.outline()
        s.shadow(8, 29.5, 6, 2.2)
    elif kind == "marsh":
        wood, wlo = rgb("#5e4e3c"), rgb("#43382c")
        s.r(7, 8, 3, 21, wood)
        s.r(9, 8, 1, 21, wlo)
        s.r(4, 12, 3, 1, wood)
        s.r(3, 9, 1, 3, wood)
        s.r(10, 15, 4, 1, wood)
        s.r(13, 12, 1, 3, wood)
        s.r(6, 6, 2, 2, wood)
        s.r(9, 5, 1, 3, wood)
        moss = rgb("#6e7e4c")
        for (x, y, h) in ((3, 12, 4), (13, 15, 5), (8, 9, 3), (5, 13, 2)):
            s.r(x, y, 1, h, moss)
        s.ellipse(8, 6, 4.5 if v == 0 else 3.5, 3, rgb("#4c5a3a"))
        s.p(6, 5, rgb("#607048"))
        s.r(5, 28, 7, 1, wlo)
        s.outline()
        s.shadow(8, 29.5, 6, 2)
    elif kind == "crypt":
        wood, wlo = rgb("#3a3244"), rgb("#2a2432")
        s.r(7, 10, 2, 19, wood)
        s.r(4, 14, 3, 1, wood)
        s.r(4, 11, 1, 3, wood)
        s.r(9, 17, 3, 1, wood)
        s.r(11, 13, 1, 4, wood)
        s.r(8, 7, 1, 3, wood)
        s.p(4, 10, rgb("#a080e0"))
        s.p(11, 12, rgb("#a080e0"))
        s.outline()
        s.shadow(8, 29.5, 5, 2)
    return s


# ------------------------------------------------------------------ personnages

def human(dirn, f, P):
    s = Spr(16, 24)
    T, H, S = P["tunic"], P["hair"], P["skin"]
    PA, BO = P.get("pants", ramp("#4a4058")), rgb("#3a2618")
    belt = P.get("belt", rgb("#3a2a1a"))
    step = [0, 1, -1][f]
    if P.get("cape") and dirn != "up":
        cp = P["cape"]
        if dirn == "down":
            s.r(3, 11, 10, 8, cp[2])
        else:
            s.r(3, 11, 4, 8, cp[1])
            s.r(3, 18, 4, 1, cp[2])
    if P.get("staff") and dirn == "up":
        s.r(2, 4, 1, 18, rgb("#6e4a28"))
    if P.get("pack") and dirn == "side":
        s.r(2, 10, 4, 7, rgb("#7a5230"))
        s.r(2, 10, 4, 1, rgb("#9a6c40"))
    # jambes
    if dirn == "side":
        legs = {0: [(6, 0), (8, 0)], 1: [(9, 1), (5, -1)], 2: [(7, 0)]}[f]
        for (x, dx) in legs:
            s.r(x, 18, 2, 3, PA[1])
            s.r(x + dx, 21, 2, 1, BO)
            s.r(x + 1, 18, 1, 3, PA[2])
    else:
        for (x, dl) in ((5, step), (9, -step)):
            s.r(x, 18, 2, 3 + dl, PA[1])
            s.r(x + 1, 18, 1, 3 + dl, PA[2])
            s.r(x, 21 + dl, 2, 1, BO)
    # buste
    if dirn == "side":
        s.r(5, 11, 6, 6, T[1])
        s.r(5, 11, 1, 6, T[0])
        s.r(10, 11, 1, 6, T[2])
        s.r(5, 16, 6, 1, belt)
        s.r(5, 17, 6, 1, T[2])
    else:
        s.r(4, 11, 8, 6, T[1])
        s.r(4, 11, 1, 6, T[0])
        s.r(11, 11, 1, 6, T[2])
        s.r(4, 16, 8, 1, belt)
        s.r(4, 17, 8, 1, T[2])
        if dirn == "down":
            s.r(6, 11, 4, 1, T[2])
        if P.get("gold"):
            g = rgb("#f0c040")
            s.r(4, 16, 8, 1, g)
            if dirn == "down":
                s.r(6, 11, 4, 1, g)
                s.r(7, 13, 2, 2, g)
            else:
                s.r(7, 11, 2, 5, rgb("#c99a2a"))
    if P.get("cape") and dirn == "up":
        cp = P["cape"]
        s.r(3, 11, 10, 8, cp[1])
        s.r(4, 11, 1, 7, cp[0])
        s.r(3, 18, 10, 1, cp[2])
    if P.get("pack") and dirn == "up":
        s.r(4, 10, 8, 7, rgb("#7a5230"))
        s.r(4, 10, 8, 1, rgb("#9a6c40"))
        s.r(5, 13, 6, 1, rgb("#553620"))
    if P.get("pack") and dirn == "down":
        s.r(5, 11, 1, 5, rgb("#553620"))
        s.r(10, 11, 1, 5, rgb("#553620"))
    # bras
    if dirn == "side":
        ax = {0: 7, 1: 9, 2: 5}[f]
        s.r(ax, 11, 2, 4, T[1])
        s.r(ax + 1, 11, 1, 4, T[2])
        s.r(ax, 15, 2, 1, S[1])
    else:
        for (x, a, c) in ((3, step, T[1]), (12, -step, T[2])):
            s.r(x, 11, 1, 4 + a, c)
            s.p(x, 15 + a, S[1])
    # tête
    if dirn == "side":
        s.r(5, 3, 7, 8, S[1])
        s.r(5, 10, 6, 1, S[2])
        s.p(12, 7, S[1])
        s.p(11, 3, CLEAR)
        s.r(5, 2, 6, 2, H[1])
        s.r(4, 3, 4, 6, H[1])
        s.r(8, 3, 4, 1, H[1])
        s.r(5, 2, 3, 1, H[0])
        s.r(4, 7, 1, 2, H[2])
        s.p(7, 7, S[2])
        s.p(9, 7, rgb("#1a1010"))
        s.p(10, 8, rgb("#e8998a"))
    else:
        s.r(4, 3, 8, 8, S[1])
        s.r(11, 5, 1, 5, S[2])
        s.r(5, 10, 6, 1, S[2])
        for (x, y) in ((4, 3), (11, 3), (4, 10), (11, 10)):
            s.p(x, y, CLEAR)
        s.r(5, 2, 6, 1, H[1])
        s.r(4, 3, 8, 2, H[1])
        s.r(6, 2, 3, 1, H[0])
        s.r(5, 3, 2, 1, H[0])
        if dirn == "up":
            s.r(4, 5, 8, 5, H[1])
            s.r(4, 9, 8, 1, H[2])
            s.r(11, 5, 1, 4, H[2])
            s.r(6, 4, 2, 2, H[0])
        else:
            s.r(4, 5, 1, 3, H[2])
            s.r(11, 5, 1, 3, H[2])
            s.p(5, 5, H[1])
            s.p(8, 5, H[1])
            s.p(10, 5, H[1])
            s.p(6, 7, rgb("#1a1010"))
            s.p(9, 7, rgb("#1a1010"))
            s.p(5, 8, rgb("#e8998a"))
            s.p(10, 8, rgb("#e8998a"))
            s.r(7, 9, 2, 1, S[2])
    if P.get("beard") and dirn != "up":
        bd, bl = rgb("#e4ded2"), rgb("#b8b0a2")
        if dirn == "down":
            s.r(5, 8, 6, 3, bd)
            s.r(6, 11, 4, 2, bd)
            s.r(6, 12, 4, 1, bl)
            s.p(6, 7, rgb("#1a1010"))
            s.p(9, 7, rgb("#1a1010"))
        else:
            s.r(8, 8, 4, 3, bd)
            s.r(9, 11, 2, 1, bl)
    if P.get("staff") and dirn != "up":
        x = 13 if dirn == "down" else 12
        s.r(x, 5, 1, 17, rgb("#6e4a28"))
        s.r(x - 1, 3, 3, 2, rgb("#7cc4cf"))
        s.p(x, 2, rgb("#c8f0f4"))
    if P.get("hat"):
        hc = P["hat"]
        if dirn == "side":
            s.r(3, 2, 10, 1, hc[2])
            s.r(5, 0, 6, 2, hc[1])
        else:
            s.r(3, 2, 10, 1, hc[2])
            s.r(5, 0, 6, 2, hc[1])
            s.r(5, 1, 6, 1, hc[0])
    s.outline()
    s.shadow(8, 22, 5, 1.6)
    return s


def mask_overlay(m, dirn):
    s = Spr(16, 24)
    c = {"mask_gob": ramp("#6c9a3a"), "mask_wolf": ramp("#8a8c94"), "mask_wisp": ramp("#7cd0f0"), "mask_spectre": ramp("#b48ae6")}[m]
    eye = rgb("#111018")
    if dirn == "down":
        s.r(4, 5, 8, 4, c[1])
        s.r(4, 5, 8, 1, c[0])
        s.r(4, 8, 8, 1, c[2])
        s.p(6, 7, eye)
        s.p(9, 7, eye)
        if m == "mask_gob":
            s.r(1, 6, 3, 1, c[1])
            s.r(12, 6, 3, 1, c[1])
            s.p(2, 5, c[1])
            s.p(13, 5, c[1])
        elif m == "mask_wolf":
            s.r(4, 3, 2, 2, c[1])
            s.r(10, 3, 2, 2, c[1])
            s.r(7, 9, 2, 1, c[2])
        elif m == "mask_wisp":
            s.p(7, 4, c[0])
            s.p(8, 3, rgb("#e8faff"))
        else:
            s.r(5, 9, 6, 1, c[1])
            s.p(7, 9, eye)
    else:
        s.r(8, 5, 5, 4, c[1])
        s.r(8, 5, 5, 1, c[0])
        s.r(8, 8, 5, 1, c[2])
        s.p(10, 7, eye)
        if m == "mask_gob":
            s.r(5, 6, 3, 1, c[1])
            s.p(4, 5, c[1])
        elif m == "mask_wolf":
            s.r(8, 3, 2, 2, c[1])
            s.r(13, 7, 1, 2, c[1])
        elif m == "mask_wisp":
            s.p(10, 4, rgb("#e8faff"))
    s.outline(0.6)
    return s


def goblin(dirn, f, k=1.0, chef=False):
    w, h = int(16 * k), int(24 * k)
    s = Spr(w, h, k)
    G = ramp("#5a8a2e") if chef else ramp("#6c9a3a")
    cloth, cl2 = rgb("#6a4626"), rgb("#4a2e18")
    step = [0, 1, -1][f]
    if dirn == "side":
        for (x, dx) in ({0: [(6, 0), (8, 0)], 1: [(9, 1), (5, -1)], 2: [(7, 0)]}[f]):
            s.r(x, 18, 2, 2, cl2)
            s.r(x + dx, 20, 2, 1, G[2])
        s.r(5, 13, 6, 4, G[1])
        s.r(6, 14, 4, 3, G[0])
        s.r(5, 16, 6, 2, cloth)
        ax = {0: 7, 1: 9, 2: 5}[f]
        s.r(ax, 13, 2, 3, G[2])
        s.r(ax + 2, 11, 1, 6, rgb("#c4c4cc"))
        s.r(ax + 1, 15, 3, 1, rgb("#6e4a28"))
        s.r(5, 5, 7, 8, G[1])
        s.r(5, 5, 7, 1, G[0])
        s.r(5, 12, 6, 1, G[2])
        s.r(2, 6, 3, 1, G[1])
        s.r(1, 5, 2, 1, G[1])
        s.r(3, 7, 2, 1, G[2])
        s.r(12, 8, 2, 2, G[2])
        s.p(9, 8, rgb("#ff4030"))
        s.p(9, 7, G[2])
        s.r(9, 10, 3, 1, rgb("#2a3a1a"))
        s.p(10, 11, rgb("#f0f0d0"))
    else:
        for (x, dl) in ((5, step), (9, -step)):
            s.r(x, 18, 2, 2 + dl, cl2)
            s.r(x, 20 + dl, 2, 1, G[2])
        s.r(5, 13, 6, 4, G[1])
        s.r(6, 14, 4, 3, G[0] if dirn == "down" else G[1])
        s.r(5, 16, 6, 2, cloth)
        s.r(5, 17, 6, 1, cl2)
        for (x, a) in ((4, step), (11, -step)):
            s.r(x, 13, 1, 3 + a, G[2])
            s.p(x, 16 + a, G[1])
        dx = 12 if dirn == "down" else 3
        s.r(dx, 10 - step, 1, 6, rgb("#c4c4cc"))
        s.p(dx, 9 - step, rgb("#e8e8f0"))
        s.r(dx - 1, 15 - step, 3, 1, rgb("#6e4a28"))
        s.r(4, 5, 8, 8, G[1])
        s.r(4, 5, 8, 1, G[0])
        s.r(4, 12, 8, 1, G[2])
        s.r(11, 6, 1, 6, G[2])
        s.p(4, 5, CLEAR)
        s.p(11, 5, CLEAR)
        for side in (-1, 1):
            bx = 3 if side < 0 else 12
            s.r(bx - (2 if side < 0 else 0), 7, 3, 1, G[1])
            s.r(bx - (3 if side < 0 else -1), 6, 2, 1, G[1])
            s.r(bx - (1 if side < 0 else 0), 8, 2, 1, G[2])
        if dirn == "down":
            s.r(5, 7, 2, 1, G[2])
            s.r(9, 7, 2, 1, G[2])
            s.p(6, 8, rgb("#ff4030"))
            s.p(9, 8, rgb("#ff4030"))
            s.r(7, 9, 2, 1, G[2])
            s.r(6, 10, 4, 1, rgb("#2a3a1a"))
            s.p(6, 11, rgb("#f0f0d0"))
            s.p(9, 11, rgb("#f0f0d0"))
        else:
            s.r(5, 6, 6, 1, G[2])
            s.r(6, 9, 4, 1, G[2])
    if chef:
        gold, glo = rgb("#e8c040"), rgb("#a8801e")
        s.r(4, 3, 8, 2, gold)
        s.r(4, 4, 8, 1, glo)
        s.r(4, 2, 1, 1, gold)
        s.r(7, 1, 2, 2, gold)
        s.r(11, 2, 1, 1, gold)
        s.p(7, 3, rgb("#d84040"))
        s.r(4, 13, 8, 1, rgb("#8a2a2a"))
    s.outline()
    s.shadow(w / 2, 20.5 * k, 5 * k, 1.6 * k)
    return s


def wolf(f):
    s = Spr(24, 16)
    W, lo, hi, belly = rgb("#7d7f86"), rgb("#55575e"), rgb("#a2a4ac"), rgb("#b8b8c0")
    bob = 1 if f in (1, 3) else 0
    legs = {0: (0, 0), 1: (1, -1), 2: (0, 0), 3: (-1, 1)}[f]
    for (x, o) in ((6, legs[0]), (8, legs[1]), (15, legs[1]), (17, legs[0])):
        s.r(x + o, 11 - bob, 1, 3 + bob, lo)
        s.p(x + o, 13, dark(lo))
    s.r(5, 6 - bob, 12, 5, W)
    s.r(5, 6 - bob, 12, 1, hi)
    s.r(7, 10 - bob, 9, 1, belly)
    s.r(15, 5 - bob, 3, 5, W)
    s.r(16, 2 - bob, 5, 5, W)
    s.r(16, 2 - bob, 5, 1, hi)
    s.r(20, 5 - bob, 3, 2, W)
    s.r(20, 6 - bob, 3, 1, belly)
    s.p(22, 5 - bob, rgb("#1a1a20"))
    s.r(16, 0 - bob, 1, 2, W)
    s.r(19, 0 - bob, 1, 2, W)
    s.p(19, 3 - bob, rgb("#ffd24a"))
    s.r(9, 7 - bob, 4, 1, lo)
    tail = 4 + (1 if f in (1, 2) else 0)
    s.r(1, tail - bob, 4, 2, W)
    s.r(1, tail - bob, 2, 1, hi)
    s.p(0, tail - 1 - bob, W)
    s.outline()
    s.shadow(12, 14, 9, 1.6)
    return s


def wisp(f):
    s = Spr(16, 24)
    s.ellipse(8, 12, 7.5, 7.5, (120, 208, 255, 40))
    s.ellipse(8, 12, 5, 5, (120, 208, 255, 70))
    s.ellipse(8, 12.5, 3.5, 4, rgb("#5cc0f0"))
    s.ellipse(8, 12.5, 2.4, 3, rgb("#9fe6ff"))
    s.r(7, 11, 2, 2, rgb("#e8faff"))
    tips = [((7, 7), (8, 6), (8, 5)), ((8, 7), (9, 6), (9, 5)), ((7, 7), (7, 6), (6, 5)), ((8, 7), (8, 6), (8, 4))][f]
    for i, (x, y) in enumerate(tips):
        s.p(x, y, rgb("#9fe6ff") if i < 2 else rgb("#e8faff"))
    s.p(6, 13, rgb("#14324a"))
    s.p(9, 13, rgb("#14324a"))
    s.shadow(8, 22, 3, 1, 60)
    return s


def spectre(f):
    s = Spr(16, 24)
    c, lo, hi = (176, 131, 232, 215), (122, 88, 176, 215), (210, 180, 250, 225)
    s.ellipse(8, 8, 4.6, 5, c)
    s.r(4, 8, 8, 9, c)
    s.r(3, 11, 1, 4, c)
    s.r(12, 11, 1, 4, c)
    s.r(4, 4, 3, 2, hi)
    s.r(11, 8, 1, 9, lo)
    for i in range(4):
        y = 17 + ((i + f) % 2)
        s.r(4 + i * 2, 17, 2, 1 + ((i + f) % 2) + (1 if i % 2 == f % 2 else 0), c)
    s.r(6, 7, 1, 2, rgb("#1a0f2a"))
    s.r(9, 7, 1, 2, rgb("#1a0f2a"))
    s.r(7, 11, 2, 1 + f % 2, rgb("#1a0f2a"))
    s.outline(0.5, 150)
    s.shadow(8, 22.5, 4, 1.2, 60)
    return s


# ------------------------------------------------------------------ décor et bâtiments

def tent():
    s = Spr(24, 20)
    can, lo, hi = rgb("#9a7a44"), rgb("#6e5230"), rgb("#b89a5e")
    for i in range(11):
        s.r(12 - i, 7 + i, i * 2, 1, can if i % 3 else lo)
    s.r(12 - 1, 7, 1, 11, hi)
    s.r(10, 13, 4, 5, rgb("#2a1a10"))
    s.r(11, 2, 1, 6, rgb("#5a3b1f"))
    s.r(12, 2, 4, 2, rgb("#b5423b"))
    s.outline()
    s.shadow(12, 18, 10, 1.6)
    return s


def chest(opened):
    s = Spr(16, 16)
    wood, lo, hi, gold = rgb("#7a5230"), rgb("#553620"), rgb("#9a6c40"), rgb("#e0b040")
    s.r(2, 7, 12, 7, wood)
    s.r(2, 13, 12, 1, lo)
    s.r(2, 9, 12, 1, lo)
    if opened:
        s.r(2, 4, 12, 3, lo)
        s.r(3, 7, 10, 2, rgb("#2a1a10"))
    else:
        s.r(2, 5, 12, 3, hi)
        s.r(2, 5, 12, 1, light(hi))
    s.r(7, 8, 2, 3, gold)
    s.r(2, 7, 1, 7, gold)
    s.r(13, 7, 1, 7, gold)
    s.outline()
    s.shadow(8, 14.5, 7, 1.5)
    return s


def campfire(f):
    s = Spr(16, 20)
    s.r(3, 15, 10, 2, rgb("#5a3b1f"))
    s.r(4, 14, 8, 1, rgb("#7a5230"))
    s.r(2, 16, 3, 1, rgb("#8a8792"))
    s.r(11, 16, 3, 1, rgb("#8a8792"))
    flames = [
        [(5, 9, 6, 6, "#e8742a"), (6, 7, 4, 6, "#f5b23a"), (7, 6, 2, 4, "#fff0a0")],
        [(5, 10, 6, 5, "#e8742a"), (6, 6, 4, 7, "#f5b23a"), (7, 4, 2, 5, "#fff0a0")],
        [(4, 9, 7, 6, "#e8742a"), (6, 8, 5, 5, "#f5b23a"), (8, 6, 2, 4, "#fff0a0")],
    ][f]
    for (x, y, w, h, c) in flames:
        s.r(x, y, w, h, rgb(c))
    s.p(4 + f * 3, 4 - f % 2, rgb("#f5b23a"))
    s.outline(0.4)
    s.shadow(8, 17.5, 7, 1.5)
    return s


def house(night):
    s = Spr(32, 44)
    wall_c, wlo, whi = rgb("#c49a68"), rgb("#9a7448"), rgb("#dcb47e")
    roof, rlo, rhi = rgb("#a4473a"), rgb("#7a3028"), rgb("#c4604a")
    s.r(2, 24, 28, 20, wall_c)
    s.r(2, 24, 28, 1, wlo)
    s.r(29, 24, 1, 20, wlo)
    for x in (2, 15, 29):
        s.r(x, 24, 1, 20, rgb("#6e4a28"))
    s.r(2, 33, 28, 1, rgb("#6e4a28"))
    for i in range(12):
        y = 2 + i * 2
        inset = max(0, 11 - i)
        s.r(inset, y, 32 - inset * 2, 2, roof if i % 2 else rlo)
        s.r(inset, y, 32 - inset * 2, 1, rhi if i % 2 else roof)
    s.r(0, 25, 32, 1, rlo)
    s.r(22, 3, 4, 8, rgb("#7a7480"))
    s.r(22, 3, 4, 1, rgb("#a29ca8"))
    s.r(13, 34, 6, 10, rgb("#5a3b1f"))
    s.r(13, 34, 6, 1, rgb("#3a2414"))
    s.p(17, 39, rgb("#e0b040"))
    win = rgb("#ffd76a") if night else rgb("#33475e")
    for x in (5, 22):
        s.r(x, 28, 5, 4, win)
        s.r(x + 2, 28, 1, 4, rgb("#6e4a28"))
        s.r(x, 32, 5, 1, rgb("#6e4a28"))
        if not night:
            s.p(x, 28, rgb("#5a7a9a"))
    s.outline()
    return s


def workshop():
    s = Spr(32, 44)
    stone, slo, shi = rgb("#857a6e"), rgb("#62584e"), rgb("#a2968a")
    s.r(1, 26, 30, 18, stone)
    for y in range(28, 44, 4):
        s.r(1, y, 30, 1, slo)
        for x in range(1 + (y % 8), 31, 8):
            s.r(x, y, 1, 4, slo)
    s.r(1, 26, 30, 1, shi)
    s.r(0, 14, 32, 10, rgb("#5a4432"))
    for x in range(0, 32, 4):
        s.r(x, 14, 2, 10, rgb("#6e5440"))
    s.r(0, 23, 32, 2, rgb("#3a2a20"))
    s.r(2, 12, 28, 2, rgb("#3a2a20"))
    s.r(4, 32, 10, 12, rgb("#2e2218"))
    s.r(5, 33, 8, 1, rgb("#e8742a"))
    s.r(18, 34, 9, 3, rgb("#9a9aa6"))
    s.r(19, 34, 7, 1, rgb("#c4c4d0"))
    s.r(20, 37, 5, 4, rgb("#5e5e6a"))
    s.r(24, 2, 4, 12, rgb("#5a5462"))
    s.r(24, 2, 4, 1, rgb("#7a7480"))
    s.r(16, 26, 8, 4, rgb("#8a6a3a"))
    s.r(19, 27, 2, 2, rgb("#cfcfd6"))
    s.outline()
    return s


def farm():
    s = Spr(32, 32)
    soil, slo = rgb("#6b4a2b"), rgb("#54381f")
    s.r(0, 3, 32, 29, soil)
    for r in range(3):
        y = 6 + r * 9
        s.r(1, y + 6, 30, 1, slo)
        for c in range(4):
            x = 2 + c * 8
            s.r(x, y, 6, 5, rgb("#3f7a34"))
            s.r(x + 1, y, 4, 1, rgb("#5a9a44"))
            s.r(x, y + 4, 6, 1, rgb("#2e5a26"))
            s.p(x + 1, y + 2, rgb("#d4384a"))
            s.p(x + 4, y + 1, rgb("#d4384a"))
            s.p(x + 3, y + 3, rgb("#e8607a"))
    fence = rgb("#9a7a4a")
    s.r(0, 2, 32, 1, fence)
    s.r(0, 31, 32, 1, fence)
    for x in (0, 10, 21, 31):
        s.r(x, 1, 1, 31, rgb("#7a5a32"))
    s.outline()
    return s


def mill():
    s = Spr(32, 48)
    body, blo, bhi = rgb("#a89c8a"), rgb("#7a6e5e"), rgb("#c4b8a6")
    s.r(8, 18, 16, 30, body)
    s.r(8, 18, 1, 30, bhi)
    s.r(23, 18, 1, 30, blo)
    for y in range(22, 48, 5):
        s.r(9, y, 14, 1, blo)
    s.r(13, 38, 6, 10, rgb("#5a3b1f"))
    s.r(14, 27, 4, 4, rgb("#33475e"))
    for i in range(8):
        s.r(6 + i, 16 - i, 20 - i * 2, 1, rgb("#8e3b2e") if i % 2 else rgb("#a4473a"))
    s.r(5, 17, 22, 2, rgb("#7a3028"))
    s.outline()
    return s


def mill_blades():
    s = Spr(36, 36)
    c = 18
    for ang in range(4):
        for t in range(2, 17):
            a = ang * math.pi / 2
            x = c + math.cos(a) * t
            y = c + math.sin(a) * t
            s.p(int(round(x)), int(round(y)), rgb("#8a6a3a"))
            if t > 4:
                for w in range(1, 5):
                    xx = x + math.cos(a + math.pi / 2) * w
                    yy = y + math.sin(a + math.pi / 2) * w
                    s.p(int(round(xx)), int(round(yy)), rgb("#f0e4c4") if w < 4 else rgb("#c8b890"))
    s.r(c - 2, c - 2, 4, 4, rgb("#3a2a20"))
    s.outline(0.5)
    return s


def tower():
    s = Spr(16, 44)
    st, lo, hi = rgb("#8a8a96"), rgb("#62626e"), rgb("#a8a8b4")
    s.r(2, 16, 12, 28, st)
    s.r(2, 16, 1, 28, hi)
    s.r(13, 16, 1, 28, lo)
    for y in range(20, 44, 4):
        s.r(3, y, 10, 1, lo)
    s.r(1, 11, 14, 6, rgb("#9a9aa6"))
    s.r(1, 16, 14, 1, lo)
    for x in (1, 6, 11):
        s.r(x, 8, 4, 3, rgb("#9a9aa6"))
        s.r(x, 8, 4, 1, hi)
    s.r(6, 24, 4, 6, rgb("#22222c"))
    s.r(6, 36, 4, 8, rgb("#5a3b1f"))
    s.r(13, 0, 1, 9, rgb("#5a3b1f"))
    s.r(14, 0, 2, 3, rgb("#7cc4cf"))
    s.outline()
    return s


def statue(night):
    s = Spr(16, 40)
    s.r(2, 33, 12, 7, rgb("#8a8a96"))
    s.r(2, 33, 12, 1, rgb("#a8a8b4"))
    s.r(3, 39, 10, 1, rgb("#62626e"))
    g, glo, ghi = rgb("#c9a24a"), rgb("#9a7428"), rgb("#f0d070")
    s.r(5, 18, 6, 15, g)
    s.r(10, 18, 1, 15, glo)
    s.r(4, 12, 8, 7, g)
    s.r(4, 12, 1, 7, ghi)
    s.r(6, 6, 4, 6, g)
    s.r(6, 6, 2, 2, ghi)
    s.r(7, 2, 2, 4, glo)
    s.r(6, 13, 4, 3, rgb("#fff3b0") if night else rgb("#e8c860"))
    s.outline()
    if night:
        s.ellipse(8, 14.5, 7, 7, (255, 240, 160, 50))
    return s


def soft_glow():
    s = Spr(32, 32)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - 16, y + 0.5 - 16) / 16
            if d < 1:
                s.px[x, y] = (255, 255, 255, int(255 * (1 - d) ** 2))
    return s


# ------------------------------------------------------------------ boutons tactiles

def icon(name, k):
    s = Spr(int(12 * k), int(12 * k), k)
    W, G, B = rgb("#e8e4dc"), rgb("#9a9aa6"), rgb("#7a5230")
    if name == "attack":
        for i in range(7):
            s.r(3 + i, 8 - i, 2, 1, W if i < 6 else rgb("#ffffff"))
        s.r(1, 8, 4, 1, rgb("#e0b040"))
        s.r(2, 7, 1, 3, rgb("#e0b040"))
        s.r(1, 10, 2, 1, B)
    elif name == "interact":
        s.r(1, 2, 10, 6, W)
        s.r(2, 1, 8, 8, W)
        s.r(3, 9, 2, 2, W)
        s.r(5, 2, 2, 4, rgb("#1d4b52"))
        s.r(5, 7, 2, 1, rgb("#1d4b52"))
    elif name == "soul":
        s.r(4, 4, 4, 6, rgb("#5cc0f0"))
        s.r(3, 6, 6, 3, rgb("#5cc0f0"))
        s.r(5, 5, 2, 4, rgb("#dff8ff"))
        s.r(5, 2, 1, 2, rgb("#9fe6ff"))
        s.r(6, 1, 1, 2, rgb("#dff8ff"))
    elif name == "potion":
        s.r(5, 1, 2, 3, G)
        s.r(4, 1, 4, 1, B)
        s.r(3, 4, 6, 6, rgb("#d4483b"))
        s.r(2, 5, 8, 4, rgb("#d4483b"))
        s.r(4, 5, 2, 2, rgb("#ff9a8a"))
    elif name == "bag":
        s.r(3, 4, 6, 7, B)
        s.r(2, 6, 8, 4, B)
        s.r(4, 2, 4, 2, rgb("#9a6c40"))
        s.r(4, 4, 4, 1, rgb("#e0b040"))
    elif name == "build":
        s.r(2, 2, 7, 3, G)
        s.r(2, 2, 7, 1, W)
        s.r(5, 5, 2, 6, B)
    elif name == "map":
        s.r(1, 2, 10, 8, rgb("#e8d8a8"))
        s.r(4, 2, 1, 8, rgb("#c8b888"))
        s.r(7, 2, 1, 8, rgb("#c8b888"))
        s.r(8, 4, 2, 2, rgb("#d4483b"))
    elif name == "pause":
        s.r(3, 2, 2, 8, W)
        s.r(7, 2, 2, 8, W)
    return s


def button(name, size, pressed):
    s = Spr(size, size)
    c = size / 2
    ring, fill = rgb("#d29a45"), rgb("#2d6a72") if pressed else rgb("#1d4b52")
    s.ellipse(c, c, c, c, (*ring[:3], 230))
    s.ellipse(c, c, c - 1.5, c - 1.5, (*fill[:3], 210))
    s.ellipse(c - size * 0.12, c - size * 0.16, c * 0.55, c * 0.35, (255, 255, 255, 40 if not pressed else 70))
    k = 1.5 if size >= 28 else 1.0
    ic = icon(name, k)
    off = int(round((size - ic.w) / 2)) + (1 if pressed else 0)
    s.im.alpha_composite(ic.im, (off, off))
    return s


# ------------------------------------------------------------------ assemblage

def build_tiles():
    sheet = Image.new("RGBA", (16 * TS, 8 * TS), CLEAR)
    names = {}

    def put(name, spr, c, r):
        sheet.paste(spr.im, (c * TS, r * TS))
        names[name] = [c, r]

    for bi, bio in enumerate(("plain", "forest", "marsh", "crypt")):
        for v in range(4):
            put("grass_%s_%d" % (bio, v), grass(bio, v), bi * 4 + v, 0)
    for v in range(3):
        put("flower_%d" % v, flowers(v), v, 1)
    put("wall_0", wall(0), 3, 1)
    put("wall_1", wall(1), 4, 1)
    put("gate_0", gate(False), 5, 1)
    put("gate_1", gate(True), 6, 1)
    for v in range(3):
        put("crypt_%d" % v, crypt_floor(v), 7 + v, 1)
    put("bridge_v", bridge(False), 10, 1)
    put("bridge_h", bridge(True), 11, 1)
    put("rock_0", rock(0), 12, 1)
    put("rock_1", rock(1), 13, 1)
    put("stump", stump(), 14, 1)
    for m in range(16):
        put("path_%d" % m, path_tile(m), m, 2)
    for m in range(16):
        c, r = (m % 8) * 2, 3 + m // 8
        sheet.paste(water_tile(m, 0).im, (c * TS, r * TS))
        sheet.paste(water_tile(m, 1).im, ((c + 1) * TS, r * TS))
        names["water_%d" % m] = [c, r]
    trees = [("plain", 0), ("plain", 1), ("forest", 0), ("forest", 1), ("marsh", 0), ("marsh", 1), ("crypt", 0)]
    for i, (k, v) in enumerate(trees):
        sheet.paste(tree(k, v).im, (i * TS, 5 * TS))
        names["tree_%s_%d" % (k, v)] = [i, 5]
    sheet.save(os.path.join(ROOT, "tiles.png"))
    return names


def strip(frames):
    w, h = frames[0].w, frames[0].h
    im = Image.new("RGBA", (w * len(frames), h), CLEAR)
    for i, f in enumerate(frames):
        im.paste(f.im, (i * w, 0))
    return im, w, h


def build_sprites():
    anims = {}
    DIRS = ("down", "up", "side")
    skin = ramp("#ecbc92")
    hero = {"tunic": ramp("#3d5c8a"), "hair": ramp("#3a2418"), "skin": skin}
    people = {
        "hero": hero,
        "hero_cape": dict(hero, cape=ramp("#8a5a34")),
        "hero_gold": dict(hero, gold=True),
        "hero_gold_cape": dict(hero, gold=True, cape=ramp("#8a5a34")),
        "elder": {"tunic": ramp("#6a4a8a"), "hair": ramp("#d8d0c0"), "skin": ramp("#d9b090"), "beard": True, "staff": True},
        "trader": {"tunic": ramp("#8a6a2a"), "hair": ramp("#4a2a1a"), "skin": ramp("#c99a72"), "pack": True, "hat": ramp("#5a7a4a")},
    }
    vcol = [("#b5523b", "#3b2a1e"), ("#3b74b5", "#c9a24a"), ("#6a9a4a", "#1e1a17"), ("#9a4aa0", "#d8d0c0"), ("#c08a3a", "#5a2e1a"), ("#3a9a94", "#2a2a3a")]
    for i, (t, h) in enumerate(vcol):
        people["villager_%d" % i] = {"tunic": ramp(t), "hair": ramp(h), "skin": ramp("#d9a882")}
    items = []
    for name, P in people.items():
        items.append((name, [human(d, f, P) for d in DIRS for f in range(3)], 8, 22))
    items.append(("gobelin", [goblin(d, f) for d in DIRS for f in range(3)], 8, 21))
    items.append(("chef", [goblin(d, f, 1.5, True) for d in DIRS for f in range(3)], 12, 31))
    items.append(("loup", [wolf(f) for f in range(4)], 12, 14))
    items.append(("feufollet", [wisp(f) for f in range(4)], 8, 22))
    items.append(("spectre", [spectre(f) for f in range(4)], 8, 22))
    for m in ("mask_gob", "mask_wolf", "mask_wisp", "mask_spectre"):
        items.append((m, [mask_overlay(m, "down"), mask_overlay(m, "side")], 8, 22))
    items.append(("tent", [tent()], 12, 18))
    items.append(("chest", [chest(False), chest(True)], 8, 14))
    items.append(("campfire", [campfire(f) for f in range(3)], 0, 20))
    items.append(("house", [house(False), house(True)], 0, 44))
    items.append(("workshop", [workshop()], 0, 44))
    items.append(("farm", [farm()], 0, 32))
    items.append(("mill", [mill()], 0, 48))
    items.append(("mill_blades", [mill_blades()], 18, 18))
    items.append(("tower", [tower()], 0, 44))
    items.append(("statue", [statue(False), statue(True)], 0, 40))
    items.append(("glow", [soft_glow()], 16, 16))
    for name, size in (("attack", 32), ("interact", 24), ("soul", 24), ("potion", 20), ("bag", 18), ("build", 18), ("map", 18), ("pause", 18)):
        items.append(("btn_" + name, [button(name, size, False), button(name, size, True)], 0, 0))
    W = 256
    x = y = row_h = 0
    placed = []
    for name, frames, ox, oy in items:
        im, w, h = strip(frames)
        if x + im.width > W:
            x, y, row_h = 0, y + row_h, 0
        placed.append((name, im, x, y, w, h, len(frames), ox, oy))
        x += im.width
        row_h = max(row_h, h)
    H = y + row_h
    sheet = Image.new("RGBA", (W, H), CLEAR)
    for name, im, px, py, w, h, n, ox, oy in placed:
        sheet.paste(im, (px, py))
        anims[name] = {"x": px, "y": py, "w": w, "h": h, "n": n, "ox": ox, "oy": oy}
    sheet.save(os.path.join(ROOT, "sprites.png"))
    return anims


def main():
    os.makedirs(ROOT, exist_ok=True)
    tiles = build_tiles()
    sprites = build_sprites()
    # Données de l'atlas en GDScript : pas de fichier .json à ajouter aux exports.
    out = os.path.join(ROOT, "..", "scripts", "atlas_data.gd")
    with open(out, "w") as f:
        f.write("class_name AtlasData\n## Généré par tools/make_art.py — ne pas modifier à la main.\n\n")
        f.write("const TILES := " + json.dumps(tiles, sort_keys=True) + "\n")
        f.write("const SPRITES := " + json.dumps(sprites, sort_keys=True) + "\n")
    print("ok :", len(tiles), "tuiles,", len(sprites), "sprites")


if __name__ == "__main__":
    main()
