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
    """Herbe : brins serrés qui se raccordent d'une case à l'autre ; variantes 4-7 plus sombres (taches de prairie)."""
    base, hi, lo, acc = [rgb(c) for c in BIO[bio]]
    if v >= 4:
        base, hi, acc = mix(base, lo, 0.35), mix(hi, base, 0.35), mix(acc, hi, 0.4)
    s = Spr(TS, TS)
    r = random.Random(sum(map(ord, bio)) * 31 + v * 7)
    s.r(0, 0, 16, 16, base)
    for _ in range(8):
        x, y = r.randrange(16), r.randrange(16)
        c = mix(base, lo if r.random() < 0.6 else hi, 0.45)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            s.p((x + dx) % 16, (y + dy) % 16, c)
    for _ in range(30):
        x, y = r.randrange(16), r.randrange(16)
        c = hi if r.random() < 0.55 else lo
        s.p(x, y, c)
        s.p(x, (y + 1) % 16, mix(c, base, 0.5))
    for _ in range([2, 3, 1, 2][v % 4]):
        x, y = r.randrange(16), r.randrange(16)
        for (dx, dy, c) in ((0, 0, acc), (-1, 1, hi), (1, 1, hi), (0, 1, lo), (0, 2, lo)):
            s.p((x + dx) % 16, (y + dy) % 16, c)
    if v % 4 == 3 and bio == "marsh":
        s.ellipse(8, 9, 5, 3, rgb("#2e443e"))
        s.r(5, 8, 3, 1, rgb("#45625a"))
        s.p(10, 10, rgb("#45625a"))
    elif v % 4 == 3 and bio == "crypt":
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


def prop(kind, v=0):
    """Petits décors posés sur l'herbe ou l'eau (sans collision)."""
    s = Spr(TS, TS)
    r = random.Random(700 + len(kind) * 13 + v)
    if kind == "tallgrass":
        cols = {0: ("#86b85a", "#5a8a3f", "#3e6a2c"), 1: ("#5a8a4e", "#3a6a40", "#244a30"), 2: ("#7e8e52", "#56663e", "#3a4831")}[v]
        hi, mid, dk = [rgb(c) for c in cols]
        for i in range(7):
            x = 3 + i * 1.6 + r.random()
            h = r.randrange(4, 9)
            for j in range(h):
                xx = int(x + (j / h) * (1 if i % 2 else -1) * 1.5)
                s.p(xx, 14 - j, hi if j > h - 3 else (mid if j > 1 else dk))
        s.shadow(8, 14.5, 6, 1.2, 60)
    elif kind == "bush":
        g = ramp("#4c8a3a")
        s.ellipse(8, 10, 6.5, 4.8, g[1])
        s.ellipse(6, 8.5, 3.2, 2.4, g[0])
        s.ellipse(10.5, 12, 3.5, 2, g[2])
        for _ in range(6):
            s.p(r.randrange(3, 13), r.randrange(6, 14), g[0] if r.random() < 0.5 else g[2])
        if v == 1:
            for (x, y) in ((5, 10), (9, 8), (11, 11), (7, 12)):
                s.p(x, y, rgb("#5aa0e8"))
                s.p(x, y - 1, rgb("#a8d4ff"))
        s.outline()
        s.shadow(8, 14.5, 7, 1.6)
    elif kind == "mushroom":
        for (x, y, c) in ((5, 11, "#d84a3a"), (10, 12, "#e0b040") if v else (10, 12, "#d84a3a")):
            s.r(x, y, 2, 3, rgb("#efe4cc"))
            s.r(x - 1, y - 2, 4, 2, rgb(c))
            s.p(x, y - 2, rgb("#ffffff"))
        s.outline(0.5)
        s.shadow(8, 14.5, 5, 1)
    elif kind == "pebbles":
        for _ in range(3):
            x, y = r.randrange(3, 12), r.randrange(6, 13)
            s.r(x, y, 2, 1, rgb("#9a9488"))
            s.p(x, y - 1, rgb("#b8b2a6"))
            s.p(x + 1, y + 1, rgb("#6a645a"))
    elif kind == "fern":
        g = ramp("#3f7a4a")
        for side in (-1, 1):
            for j in range(6):
                s.p(8 + side * j, 13 - j // 2, g[1])
                s.p(8 + side * j, 12 - j // 2, g[0] if j % 2 else g[2])
        s.r(8, 9, 1, 5, g[2])
        s.shadow(8, 14.5, 6, 1.2, 60)
    elif kind == "reeds":
        for i, x in enumerate((5, 8, 11, 7)):
            h = 8 + (i * 3) % 4
            s.r(x, 15 - h, 1, h, rgb("#7a8a4a"))
            if i < 3:
                s.r(x, 15 - h - 2, 1, 3, rgb("#6a4426"))
        s.p(4, 10, rgb("#8e9e5a"))
        s.p(12, 9, rgb("#8e9e5a"))
    elif kind == "lily":
        g = ramp("#4e8e4a")
        s.ellipse(8, 9, 5, 3.5, g[1])
        s.ellipse(7, 8, 2.5, 1.6, g[0])
        s.r(8, 9, 4, 1, rgb("#2f6a8e"))
        if v:
            s.r(6, 6, 3, 2, rgb("#f0a0c0"))
            s.p(7, 6, rgb("#ffe0f0"))
        s.outline(0.4)
    elif kind == "bones":
        c = rgb("#d8d0c0")
        s.r(4, 11, 7, 1, c)
        s.r(3, 10, 2, 3, c)
        s.r(10, 10, 2, 3, c)
        s.ellipse(11, 7, 2.5, 2, c)
        s.p(10, 7, rgb("#302838"))
        s.outline(0.6)
    elif kind == "crystal":
        c = ramp("#a080e0")
        s.r(7, 6, 2, 8, c[1])
        s.r(7, 6, 1, 8, c[0])
        s.r(5, 10, 2, 4, c[2])
        s.r(10, 9, 2, 5, c[1])
        s.p(7, 5, rgb("#e8d8ff"))
        s.outline(0.5)
        s.ellipse(8, 10, 6, 5, (180, 140, 255, 40))
    return s


def canopy(s, blobs, g, r, speck=18):
    """Feuillage fait de grappes rondes : bord sombre en bas à droite, reflet en haut à gauche."""
    hi, mid, lo, dk = g
    for (cx, cy, rr) in sorted(blobs, key=lambda b: b[1]):
        s.ellipse(cx, cy, rr, rr * 0.92, lo)
        s.ellipse(cx - rr * 0.18, cy - rr * 0.2, rr * 0.82, rr * 0.75, mid)
        s.ellipse(cx - rr * 0.38, cy - rr * 0.42, rr * 0.38, rr * 0.3, hi)
    for _ in range(speck):
        x, y = r.randrange(s.w), r.randrange(s.h)
        c = s.get(x, y)
        if c == mid:
            s.p(x, y, hi if r.random() < 0.4 else lo)
        elif c == lo and r.random() < 0.5:
            s.p(x, y, dk)


def tree(kind, v):
    """Arbres de 32×48 qui débordent sur les cases voisines (le tronc est sur la case)."""
    s = Spr(32, 48)
    r = random.Random(1000 + v * 17 + len(kind))
    bark, bark_lo, bark_hi = rgb("#6e4a28"), rgb("#4a3018"), rgb("#8a6036")
    if kind == "plain":
        g = [rgb(c) for c in (("#7ab84e", "#4f8f3a", "#356a2c", "#24501f") if v == 0 else ("#9ac050", "#6a9a36", "#4a7428", "#30561c"))]
        s.r(14, 30, 5, 14, bark)
        s.r(17, 30, 2, 14, bark_lo)
        s.r(15, 31, 1, 10, bark_hi)
        s.r(12, 42, 9, 2, bark)
        s.r(11, 43, 2, 1, bark_lo)
        s.r(20, 43, 2, 1, bark_lo)
        s.p(16, 36, bark_lo)
        blobs = [(16, 19, 11), (8, 22, 7), (24, 22, 7), (11, 12, 7.5), (21, 11, 7.5), (16, 27, 7)]
        canopy(s, blobs, g, r, 40)
        if v == 1:
            for (x, y) in ((8, 20), (20, 15), (14, 25), (24, 23), (11, 13)):
                s.r(x, y, 2, 2, rgb("#d84a3a"))
                s.p(x, y, rgb("#ff9a80"))
        s.outline()
        s.shadow(16, 44, 13, 3.5, 70)
    elif kind == "forest":
        g = [rgb(c) for c in ("#4a8a5e", "#2a6044", "#1c4632", "#123224")]
        s.r(15, 36, 3, 8, bark)
        s.r(17, 36, 1, 8, bark_lo)
        tiers = [(3, 6), (8, 10), (13, 14), (18, 18), (24, 22), (30, 26)] if v == 0 else [(4, 7), (10, 12), (16, 16), (22, 20), (28, 24)]
        for (y, w) in tiers:
            for i in range(7):
                ww = max(2, int(w * (0.35 + 0.65 * i / 6)))
                x0 = 16 - ww // 2
                s.r(x0, y + i, ww, 1, g[1])
                s.r(x0, y + i, max(1, ww // 4), 1, g[0])
                s.r(x0 + ww - max(1, ww // 3), y + i, max(1, ww // 3), 1, g[2])
            for k in range(0, w, 3):
                s.p(16 - w // 2 + k, y + 7, g[2])
            s.r(16 - w // 2 + 1, y + 6, w - 2, 1, g[3])
        for _ in range(14):
            x, y = r.randrange(6, 26), r.randrange(4, 36)
            if s.get(x, y) == g[1]:
                s.p(x, y, g[0])
        s.outline()
        s.shadow(16, 44, 10, 3, 70)
    elif kind == "marsh":
        wood, wlo = rgb("#5e4e3c"), rgb("#43382c")
        s.r(14, 18, 4, 26, wood)
        s.r(17, 18, 1, 26, wlo)
        s.r(12, 42, 8, 2, wood)
        s.r(10, 22, 4, 2, wood)
        s.r(18, 25, 5, 2, wood)
        g = [rgb(c) for c in ("#8a9a5a", "#5e6e42", "#46542f", "#303a22")]
        canopy(s, [(16, 14, 10), (8, 17, 6), (24, 17, 6), (16, 8, 6)], g, r, 20)
        for x in range(6, 27, 2):
            ln = 4 + (x * 7 + v * 3) % 9
            for j in range(ln):
                y = 19 + j
                if s.get(x, y)[3] == 0 or j < 3:
                    s.p(x, y, g[1] if j < ln - 2 else g[2])
        s.outline()
        s.shadow(16, 44, 11, 3, 70)
    elif kind == "crypt":
        wood, wlo = rgb("#3a3244"), rgb("#2a2432")
        s.r(15, 18, 3, 26, wood)
        s.r(17, 18, 1, 26, wlo)
        for (x, y, w, h) in ((10, 22, 5, 1), (9, 18, 1, 4), (18, 26, 5, 1), (22, 21, 1, 5), (14, 13, 1, 5), (18, 15, 3, 1), (20, 11, 1, 4)):
            s.r(x, y, w, h, wood)
        for (x, y) in ((9, 17), (22, 20), (20, 10)):
            s.p(x, y, rgb("#c0a0ff"))
        s.outline()
        s.shadow(16, 44, 8, 2.5, 70)
    return s


# ------------------------------------------------------------------ personnages

def human(dirn, f, P):
    """Personnage 20×30 : grosse tête expressive, 3 poses de marche avec léger rebond."""
    s = Spr(20, 30)
    T, H, S = P["tunic"], P["hair"], P["skin"]
    PA = P.get("pants", ramp("#4a4058"))
    BO, BO2 = rgb("#3a2618"), rgb("#5a3a22")
    belt = rgb("#f0c040") if P.get("gold") else rgb("#3a2a1a")
    step = [0, 1, -1][f]
    by = -1 if f else 0  # rebond du haut du corps pendant le pas
    eye = rgb("#20141c")
    # --- derrière le corps
    if P.get("cape"):
        cp = P["cape"]
        if dirn == "down":
            s.r(4, 15 + by, 12, 9, cp[2])
        elif dirn == "side":
            s.r(3, 15 + by, 5, 9, cp[1])
            s.r(3, 23 + by, 5, 1, cp[2])
    if P.get("staff") and dirn == "up":
        s.r(3, 5 + by, 1, 22, rgb("#6e4a28"))
        s.r(2, 3 + by, 3, 3, rgb("#7cc4cf"))
    if P.get("pack") and dirn == "side":
        s.r(2, 14 + by, 5, 8, rgb("#7a5230"))
        s.r(2, 14 + by, 5, 1, rgb("#9a6c40"))
        s.r(2, 18 + by, 5, 1, rgb("#553620"))
    # --- jambes
    if dirn == "side":
        for (x, dx, c) in {0: [(7, 0, PA[2]), (10, 0, PA[1])], 1: [(5, -1, PA[2]), (11, 1, PA[1])], 2: [(8, 0, PA[1])]}[f]:
            s.r(x, 22, 3, 4, c)
            s.r(x + dx, 25, 4 if dx else 3, 2, BO)
            s.r(x + dx, 25, 4 if dx else 3, 1, BO2)
    else:
        for (x, dl) in ((6, step), (11, -step)):
            s.r(x, 22, 3, 3 + dl, PA[1])
            s.r(x + 2, 22, 1, 3 + dl, PA[2])
            s.r(x, 25 + dl, 3, 2, BO)
            s.r(x, 25 + dl, 3, 1, BO2)
    # --- buste
    if dirn == "side":
        s.r(7, 14 + by, 7, 7, T[1])
        s.r(7, 14 + by, 1, 7, T[0])
        s.r(13, 14 + by, 1, 7, T[2])
        s.r(7, 19 + by, 7, 1, belt)
        s.r(6, 20 + by, 8, 2, T[2])
    else:
        s.r(5, 14 + by, 10, 7, T[1])
        s.r(5, 14 + by, 1, 7, T[0])
        s.r(6, 14 + by, 1, 5, mix(T[0], T[1], 0.5))
        s.r(14, 14 + by, 1, 7, T[2])
        s.r(5, 19 + by, 10, 1, belt)
        s.r(4, 20 + by, 12, 2, T[2])
        s.r(5, 20 + by, 10, 1, T[1])
        if dirn == "down":
            s.r(7, 14 + by, 6, 1, T[2])
            s.r(9, 15 + by, 2, 1, T[2])
            s.r(9, 19 + by, 2, 1, rgb("#e0b040"))
            if P.get("gold"):
                s.r(7, 14 + by, 6, 1, rgb("#f0c040"))
                s.r(9, 16 + by, 2, 2, rgb("#f0c040"))
        elif P.get("gold"):
            s.r(9, 14 + by, 2, 5, rgb("#c99a2a"))
    if P.get("cape") and dirn == "up":
        cp = P["cape"]
        s.r(4, 14 + by, 12, 10, cp[1])
        s.r(5, 14 + by, 1, 9, cp[0])
        s.r(4, 23 + by, 12, 1, cp[2])
    if P.get("pack"):
        if dirn == "up":
            s.r(5, 13 + by, 10, 8, rgb("#7a5230"))
            s.r(5, 13 + by, 10, 1, rgb("#9a6c40"))
            s.r(6, 16 + by, 8, 1, rgb("#553620"))
            s.r(8, 17 + by, 4, 2, rgb("#9a6c40"))
        elif dirn == "down":
            s.r(6, 14 + by, 1, 5, rgb("#553620"))
            s.r(13, 14 + by, 1, 5, rgb("#553620"))
    # --- bras
    if dirn == "side":
        ax = {0: 9, 1: 11, 2: 7}[f]
        s.r(ax, 14 + by, 2, 5, T[1])
        s.r(ax + 1, 14 + by, 1, 5, T[2])
        s.r(ax, 19 + by, 2, 2, S[1])
    else:
        for (x, a, c) in ((4, step, T[1]), (15, -step, T[2])):
            s.r(x, 14 + by, 1, 5 + a, c)
            s.r(x, 19 + by + a, 1, 2, S[1])
    # --- tête
    hy = 2 + by
    if dirn == "side":
        s.r(6, hy + 2, 9, 10, S[1])
        s.r(6, hy + 11, 8, 1, S[2])
        s.p(15, hy + 7, S[1])
        s.p(15, hy + 8, S[2])
        s.r(6, hy, 8, 3, H[1])
        s.r(5, hy + 1, 5, 8, H[1])
        s.r(10, hy + 1, 5, 2, H[1])
        s.r(6, hy, 4, 1, H[0])
        s.r(5, hy + 7, 1, 3, H[2])
        s.r(9, hy + 2, 2, 1, H[0])
        s.p(9, hy + 7, S[2])
        s.r(12, hy + 6, 1, 2, eye)
        s.p(13, hy + 9, rgb("#e8998a"))
        s.p(14, hy + 10, S[2])
    else:
        s.r(5, hy + 1, 10, 11, S[1])
        s.r(14, hy + 3, 1, 8, S[2])
        s.r(6, hy + 11, 8, 1, S[2])
        for (x, y) in ((5, hy + 1), (14, hy + 1), (5, hy + 11), (14, hy + 11)):
            s.p(x, y, CLEAR)
        s.r(6, hy, 8, 1, H[1])
        s.r(5, hy + 1, 10, 3, H[1])
        s.r(7, hy, 3, 1, H[0])
        s.r(6, hy + 1, 3, 1, H[0])
        if dirn == "up":
            s.r(5, hy + 4, 10, 7, H[1])
            s.r(5, hy + 10, 10, 1, H[2])
            s.r(14, hy + 4, 1, 6, H[2])
            s.r(7, hy + 3, 2, 3, H[0])
            s.r(10, hy + 5, 1, 4, H[2])
        else:
            s.r(5, hy + 4, 1, 4, H[2])
            s.r(14, hy + 4, 1, 4, H[2])
            for x in (6, 8, 9, 12, 13):
                s.p(x, hy + 4, H[1])
            s.p(11, hy + 4, H[2])
            s.r(7, hy + 6, 1, 2, eye)
            s.r(12, hy + 6, 1, 2, eye)
            s.p(7, hy + 6, rgb("#5a4a5a"))
            s.p(12, hy + 6, rgb("#5a4a5a"))
            s.p(6, hy + 8, rgb("#e8998a"))
            s.p(13, hy + 8, rgb("#e8998a"))
            s.r(9, hy + 9, 2, 1, S[2])
    if P.get("beard") and dirn != "up":
        bd, bl = rgb("#e4ded2"), rgb("#b8b0a2")
        if dirn == "down":
            s.r(6, hy + 8, 8, 4, bd)
            s.r(7, hy + 12, 6, 3, bd)
            s.r(8, hy + 15, 4, 1, bl)
            s.r(7, hy + 6, 1, 2, eye)
            s.r(12, hy + 6, 1, 2, eye)
            s.r(9, hy + 9, 2, 1, bl)
        else:
            s.r(10, hy + 8, 5, 4, bd)
            s.r(11, hy + 12, 3, 2, bl)
    if P.get("staff") and dirn != "up":
        x = 17 if dirn == "down" else 15
        s.r(x, 6 + by, 1, 21, rgb("#6e4a28"))
        s.r(x, 6 + by, 1, 21, rgb("#6e4a28"))
        s.r(x - 1, 3 + by, 3, 3, rgb("#7cc4cf"))
        s.p(x, 2 + by, rgb("#c8f0f4"))
        s.p(x - 1, 3 + by, rgb("#c8f0f4"))
    if P.get("hat"):
        hc = P["hat"]
        s.r(3, hy + 1, 14, 2, hc[2])
        s.r(6, hy - 2, 8, 3, hc[1])
        s.r(6, hy - 2, 8, 1, hc[0])
        s.r(6, hy, 8, 1, rgb("#c99a2a"))
    s.outline()
    s.shadow(10, 27, 6, 1.8)
    return s


def mask_overlay(m, dirn):
    s = Spr(20, 30)
    c = {"mask_gob": ramp("#6c9a3a"), "mask_wolf": ramp("#8a8c94"), "mask_wisp": ramp("#7cd0f0"), "mask_spectre": ramp("#b48ae6")}[m]
    eye = rgb("#111018")
    hy = 2
    if dirn == "down":
        s.r(5, hy + 4, 10, 5, c[1])
        s.r(5, hy + 4, 10, 1, c[0])
        s.r(5, hy + 8, 10, 1, c[2])
        s.r(7, hy + 6, 1, 2, eye)
        s.r(12, hy + 6, 1, 2, eye)
        if m == "mask_gob":
            s.r(1, hy + 5, 4, 2, c[1])
            s.r(15, hy + 5, 4, 2, c[1])
            s.p(1, hy + 4, c[1])
            s.p(18, hy + 4, c[1])
        elif m == "mask_wolf":
            s.r(5, hy + 1, 3, 3, c[1])
            s.r(12, hy + 1, 3, 3, c[1])
            s.r(8, hy + 9, 4, 1, c[2])
            s.p(9, hy + 8, eye)
        elif m == "mask_wisp":
            s.r(9, hy + 2, 2, 2, c[0])
            s.p(10, hy + 1, rgb("#e8faff"))
        else:
            s.r(6, hy + 9, 8, 1, c[1])
            s.r(9, hy + 9, 2, 1, eye)
    else:
        s.r(9, hy + 4, 7, 5, c[1])
        s.r(9, hy + 4, 7, 1, c[0])
        s.r(9, hy + 8, 7, 1, c[2])
        s.r(12, hy + 6, 1, 2, eye)
        if m == "mask_gob":
            s.r(5, hy + 5, 4, 2, c[1])
            s.p(4, hy + 4, c[1])
        elif m == "mask_wolf":
            s.r(9, hy + 1, 3, 3, c[1])
            s.r(16, hy + 7, 1, 2, c[1])
        elif m == "mask_wisp":
            s.p(12, hy + 3, rgb("#e8faff"))
    s.outline(0.6)
    return s


def goblin(dirn, f, k=1.0, chef=False):
    """Gobelin 20×26 : grosse tête, oreilles pointues, dague."""
    w, h = int(round(20 * k)), int(round(26 * k))
    s = Spr(w, h, k)
    G = ramp("#5a8a2e") if chef else ramp("#74a43e")
    cloth, cl2 = rgb("#6a4626"), rgb("#4a2e18")
    eye, eyeg = rgb("#ff4030"), rgb("#ffd040")
    step = [0, 1, -1][f]
    by = -1 if f else 0
    blade, hilt = rgb("#c4c4cc"), rgb("#6e4a28")
    if dirn == "side":
        for (x, dx) in {0: [(7, 0), (10, 0)], 1: [(5, -1), (11, 1)], 2: [(8, 0)]}[f]:
            s.r(x, 19, 3, 3, cl2)
            s.r(x + dx, 22, 3, 1, G[2])
        s.r(6, 14 + by, 8, 5, G[1])
        s.r(8, 15 + by, 5, 4, G[0])
        s.r(6, 18 + by, 8, 2, cloth)
        ax = {0: 10, 1: 12, 2: 8}[f]
        s.r(ax, 14 + by, 2, 4, G[2])
        s.r(ax + 2, 11 + by, 1, 7, blade)
        s.p(ax + 2, 10 + by, rgb("#ffffff"))
        s.r(ax + 1, 17 + by, 3, 1, hilt)
        hy = 3 + by
        s.r(6, hy, 9, 10, G[1])
        s.r(6, hy, 9, 1, G[0])
        s.r(6, hy + 9, 8, 1, G[2])
        s.r(2, hy + 3, 4, 1, G[1])
        s.r(1, hy + 2, 2, 1, G[1])
        s.r(3, hy + 4, 3, 1, G[2])
        s.r(15, hy + 5, 2, 2, G[2])
        s.p(12, hy + 4, eye)
        s.p(11, hy + 4, eyeg)
        s.r(11, hy + 3, 2, 1, G[2])
        s.r(11, hy + 7, 4, 1, rgb("#2a3a1a"))
        s.p(13, hy + 8, rgb("#f0f0d0"))
    else:
        for (x, dl) in ((6, step), (11, -step)):
            s.r(x, 19, 3, 3 + dl, cl2)
            s.r(x, 22 + dl, 3, 1, G[2])
        s.r(5, 14 + by, 10, 5, G[1])
        s.r(7, 15 + by, 6, 4, G[0] if dirn == "down" else G[1])
        s.r(5, 18 + by, 10, 2, cloth)
        s.r(5, 19 + by, 10, 1, cl2)
        for (x, a) in ((4, step), (15, -step)):
            s.r(x, 14 + by, 1, 4 + a, G[2])
            s.p(x, 18 + by + a, G[1])
        dx = 16 if dirn == "down" else 3
        s.r(dx, 11 + by - step, 1, 7, blade)
        s.p(dx, 10 + by - step, rgb("#ffffff"))
        s.r(dx - 1, 17 + by - step, 3, 1, hilt)
        hy = 3 + by
        s.r(5, hy, 10, 10, G[1])
        s.r(5, hy, 10, 1, G[0])
        s.r(6, hy + 1, 3, 1, G[0])
        s.r(5, hy + 9, 10, 1, G[2])
        s.r(14, hy + 1, 1, 8, G[2])
        s.p(5, hy, CLEAR)
        s.p(14, hy, CLEAR)
        for side in (-1, 1):
            bx = 4 if side < 0 else 15
            s.r(bx - (3 if side < 0 else 0), hy + 4, 4, 1, G[1])
            s.r(bx - (4 if side < 0 else -2), hy + 3, 3, 1, G[1])
            s.r(bx - (2 if side < 0 else 0), hy + 5, 3, 1, G[2])
        if dirn == "down":
            s.r(6, hy + 3, 3, 1, G[2])
            s.r(11, hy + 3, 3, 1, G[2])
            s.r(7, hy + 4, 1, 2, eye)
            s.r(12, hy + 4, 1, 2, eye)
            s.p(7, hy + 4, eyeg)
            s.p(12, hy + 4, eyeg)
            s.r(9, hy + 5, 2, 2, G[2])
            s.r(7, hy + 7, 6, 1, rgb("#2a3a1a"))
            s.p(8, hy + 8, rgb("#f0f0d0"))
            s.p(11, hy + 8, rgb("#f0f0d0"))
        else:
            s.r(6, hy + 2, 8, 1, G[2])
            s.r(7, hy + 6, 6, 1, G[2])
    if chef:
        gold, glo = rgb("#e8c040"), rgb("#a8801e")
        s.r(5, 1.4, 10, 2, gold)
        s.r(5, 2.7, 10, 0.7, glo)
        s.r(5, 0, 1.4, 1.4, gold)
        s.r(9.3, 0, 1.4, 1.4, gold)
        s.r(13.6, 0, 1.4, 1.4, gold)
        s.r(9.3, 1.4, 1.4, 1.3, rgb("#d84040"))
        s.r(5, 14, 10, 1, rgb("#8a2a2a"))
    s.outline()
    s.shadow(w / 2, 22.5 * k, 6 * k, 1.8 * k)
    return s


def wolf(f):
    """Loup 28×20 vu de côté, course en 4 images."""
    s = Spr(28, 20)
    W, lo, hi, belly, dk = rgb("#7d7f86"), rgb("#55575e"), rgb("#a6a8b0"), rgb("#c0c0c8"), rgb("#3e4046")
    bob = 1 if f in (1, 3) else 0
    legs = {0: (0, 0), 1: (1, -1), 2: (0, 0), 3: (-1, 1)}[f]
    for (x, o, c) in ((7, legs[0], lo), (9, legs[1], dk), (18, legs[1], lo), (20, legs[0], dk)):
        s.r(x + o, 14 - bob, 2, 4 + bob, c)
        s.r(x + o, 17, 2, 1, dark(c))
    s.r(5, 8 - bob, 15, 7, W)
    s.r(5, 8 - bob, 15, 1, hi)
    s.r(6, 9 - bob, 6, 2, hi)
    s.r(8, 13 - bob, 11, 2, belly)
    s.r(10, 10 - bob, 5, 1, lo)
    s.r(17, 6 - bob, 5, 7, W)
    s.r(19, 3 - bob, 6, 6, W)
    s.r(19, 3 - bob, 6, 1, hi)
    s.r(24, 6 - bob, 4, 3, W)
    s.r(24, 8 - bob, 4, 1, belly)
    s.p(27, 6 - bob, rgb("#1a1a20"))
    s.r(19, 0 - bob, 2, 3, W)
    s.r(22, 0 - bob, 2, 3, W)
    s.p(20, 1 - bob, rgb("#c08080"))
    s.p(22, 4 - bob, rgb("#ffd24a"))
    s.r(19, 9 - bob, 3, 2, belly)
    tail = 6 + (1 if f in (1, 2) else 0)
    s.r(1, tail - bob, 5, 2, W)
    s.r(1, tail - bob, 3, 1, hi)
    s.p(0, tail - 1 - bob, W)
    s.outline()
    s.shadow(14, 18, 11, 1.8)
    return s


def wisp(f):
    s = Spr(20, 28)
    s.ellipse(10, 14, 9.5, 9.5, (120, 208, 255, 36))
    s.ellipse(10, 14, 6.5, 6.5, (120, 208, 255, 64))
    s.ellipse(10, 15, 4.5, 5, rgb("#5cc0f0"))
    s.ellipse(10, 14.5, 3.2, 3.8, rgb("#9fe6ff"))
    s.r(9, 13, 2, 3, rgb("#e8faff"))
    tips = [((9, 9), (10, 8), (10, 7), (10, 6)), ((10, 9), (11, 8), (11, 7), (12, 6)),
            ((9, 9), (9, 8), (8, 7), (8, 6)), ((10, 9), (10, 8), (10, 7), (10, 5))][f]
    for i, (x, y) in enumerate(tips):
        s.p(x, y, rgb("#9fe6ff") if i < 2 else rgb("#e8faff"))
        if i < 2:
            s.p(x - 1, y, rgb("#5cc0f0"))
    s.r(8, 15, 1, 2, rgb("#14324a"))
    s.r(11, 15, 1, 2, rgb("#14324a"))
    for (x, y) in (((3, 10), (16, 18), (5, 20), (15, 8))[f],):
        s.p(x, y, rgb("#c8f4ff"))
    s.shadow(10, 26, 4, 1.2, 60)
    return s


def spectre(f):
    s = Spr(20, 28)
    c, lo, hi = (176, 131, 232, 215), (122, 88, 176, 215), (214, 186, 250, 225)
    s.ellipse(10, 9, 5.6, 6, c)
    s.r(5, 9, 10, 11, c)
    s.r(3, 13, 2, 5, c)
    s.r(15, 13, 2, 5, c)
    s.p(2, 17, c)
    s.p(17, 17, c)
    s.r(5, 4, 4, 2, hi)
    s.r(6, 6, 2, 1, hi)
    s.r(14, 9, 1, 11, lo)
    for i in range(5):
        s.r(5 + i * 2, 20, 2, 1 + ((i + f) % 2) + (1 if i % 2 == f % 2 else 0), c)
    s.r(7, 8, 2, 3, rgb("#1a0f2a"))
    s.r(11, 8, 2, 3, rgb("#1a0f2a"))
    s.p(7, 8, rgb("#e0c0ff"))
    s.p(11, 8, rgb("#e0c0ff"))
    s.r(9, 13, 2, 1 + f % 2, rgb("#1a0f2a"))
    s.outline(0.5, 150)
    s.shadow(10, 26, 5, 1.3, 60)
    return s


# ------------------------------------------------------------------ décor et bâtiments

def tent():
    """Tente de gobelins : toile rapiécée, mât à fanion, crâne."""
    s = Spr(24, 22)
    can, lo, hi = rgb("#a88a50"), rgb("#76583a"), rgb("#c8aa6e")
    for i in range(13):
        y = 6 + i
        s.r(12 - i, y, i * 2, 1, can)
        s.r(12 - i, y, max(1, i // 2), 1, hi)
        s.r(12 + i - max(1, i * 2 // 3), y, max(1, i * 2 // 3), 1, lo)
    s.r(4, 13, 4, 3, rgb("#8a5a3a"))
    s.r(16, 12, 3, 3, rgb("#6a7a4a"))
    s.r(9, 12, 6, 7, rgb("#2a1a10"))
    s.r(10, 13, 2, 6, rgb("#1a100a"))
    s.r(11, 1, 1, 6, rgb("#5a3b1f"))
    s.r(12, 1, 5, 3, rgb("#c4423b"))
    s.r(12, 1, 5, 1, rgb("#e86a5a"))
    s.r(19, 17, 3, 2, rgb("#e0d8c8"))
    s.p(20, 17, rgb("#302838"))
    s.outline()
    s.shadow(12, 19.5, 12, 2)
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


def shingles(s, x0, y0, w, h, cols, taper=0):
    """Toit en tuiles vu de face : rangées décalées, faîte clair, bas sombre."""
    hi, mid, lo, dk = cols
    for j in range(h):
        y = y0 + j
        inset = int(taper * (h - 1 - j) / max(1, h - 1))
        xa, xb = x0 + inset, x0 + w - inset
        row = j // 3
        t = j / max(1, h - 1)
        base = mid if t < 0.75 else lo
        s.r(xa, y, xb - xa, 1, base)
        if j % 3 == 0:
            s.r(xa, y, xb - xa, 1, hi if t < 0.4 else mid)
        if j % 3 == 2:
            s.r(xa, y, xb - xa, 1, lo if t < 0.75 else dk)
        for x in range(xa + (row % 2) * 2, xb, 4):
            if j % 3 != 0:
                s.p(x, y, dk if j % 3 == 2 else lo)
        s.p(xa, y, lo)
        s.p(xb - 1, y, dk)


def house(night):
    """Maison à colombages : toit de tuiles, cheminée, volets et jardinières."""
    s = Spr(32, 52)
    plaster, pl_lo, pl_hi = rgb("#e4d2aa"), rgb("#bca47a"), rgb("#f4e6c4")
    beam, beam_lo = rgb("#6e4426"), rgb("#4a2c16")
    stone, st_lo, st_hi = rgb("#8a8478"), rgb("#625c52"), rgb("#aaa496")
    roofc = [rgb(c) for c in ("#d4684a", "#b44a36", "#8a3426", "#5e2018")]
    # soubassement en pierre
    s.r(1, 45, 30, 7, stone)
    for (x, y, w) in ((1, 45, 6), (8, 45, 7), (16, 45, 5), (22, 45, 9), (1, 48, 4), (6, 48, 8), (15, 48, 7), (23, 48, 8)):
        s.r(x, y, w, 1, st_hi)
        s.r(x + w - 1, y, 1, 3, st_lo)
    s.r(1, 51, 30, 1, st_lo)
    # murs
    s.r(2, 29, 28, 16, plaster)
    s.r(2, 29, 28, 2, pl_lo)
    for x in (2, 15, 28):
        s.r(x, 29, 2, 16, beam)
        s.r(x + 1, 29, 1, 16, beam_lo)
    s.r(2, 37, 28, 1, beam)
    for i in range(7):
        s.p(4 + i, 37 - i, beam)
        s.p(27 - i, 37 - i, beam)
    for y in range(32, 45, 3):
        s.p(6 + (y * 5) % 7, y, pl_hi)
        s.p(20 + (y * 3) % 6, y, pl_hi)
    # fenêtres, volets, jardinières
    glass = rgb("#ffd76a") if night else rgb("#3a5a7e")
    for x in (5, 21):
        s.r(x - 1, 38, 1, 5, rgb("#3e6a8a"))
        s.r(x + 6, 38, 1, 5, rgb("#3e6a8a"))
        s.r(x, 38, 6, 5, beam_lo)
        s.r(x + 1, 39, 4, 3, glass)
        s.r(x + 3, 39, 1, 3, beam_lo)
        if night:
            s.r(x + 1, 39, 2, 1, rgb("#fff4c0"))
        else:
            s.p(x + 1, 39, rgb("#8ab0d4"))
        s.r(x, 43, 6, 2, rgb("#7a4a26"))
        for k in range(3):
            s.p(x + 1 + k * 2, 42, rgb("#e85a7a") if k != 1 else rgb("#f0d050"))
            s.p(x + 1 + k * 2, 43, rgb("#4a8a3a"))
    # porte
    s.r(13, 38, 6, 13, beam_lo)
    s.r(14, 39, 4, 12, rgb("#8a5a32"))
    s.r(14, 39, 4, 1, rgb("#a87444"))
    s.r(16, 39, 1, 12, rgb("#6a4224"))
    s.p(17, 45, rgb("#f0c050"))
    s.r(12, 51, 8, 1, st_hi)
    # toit
    shingles(s, 0, 6, 32, 24, roofc, taper=6)
    s.r(6, 5, 20, 1, rgb("#e88a66"))
    s.r(0, 29, 32, 1, roofc[3])
    s.r(2, 30, 28, 1, (30, 20, 20, 120))
    # cheminée
    s.r(22, 0, 6, 10, stone)
    s.r(22, 0, 6, 1, st_hi)
    s.r(27, 1, 1, 9, st_lo)
    s.r(22, 4, 6, 1, st_lo)
    s.r(23, 0, 4, 1, rgb("#2a2420"))
    s.outline()
    s.shadow(16, 51.5, 17, 2.2)
    return s


def workshop():
    """Atelier : forge sous auvent, enclume, établi et tonneau."""
    s = Spr(32, 48)
    stone, slo, shi = rgb("#8e8476"), rgb("#625a50"), rgb("#ada392")
    wood, wlo, whi = rgb("#7a5634"), rgb("#523620"), rgb("#9a7046")
    # mur du fond en pierre
    s.r(1, 26, 30, 22, stone)
    for y in range(26, 48, 4):
        s.r(1, y, 30, 1, slo)
        for x in range(1 + (y // 4 % 2) * 4, 31, 8):
            s.r(x, y + 1, 1, 3, slo)
            s.r(x + 1, y + 1, 3, 1, shi)
    # foyer de forge
    s.r(3, 33, 11, 15, slo)
    s.r(4, 34, 9, 12, rgb("#2a1c14"))
    s.r(5, 40, 7, 6, rgb("#e8742a"))
    s.r(6, 41, 5, 4, rgb("#f5b23a"))
    s.r(7, 42, 3, 2, rgb("#fff0a0"))
    s.r(3, 33, 11, 1, shi)
    # enclume
    s.r(17, 40, 10, 3, rgb("#5e5e6a"))
    s.r(16, 40, 2, 1, rgb("#5e5e6a"))
    s.r(18, 40, 8, 1, rgb("#a8a8b8"))
    s.r(20, 43, 4, 4, rgb("#46464e"))
    s.r(19, 47, 6, 1, rgb("#3a3a42"))
    # tonneau
    s.r(27, 38, 4, 10, wood)
    s.r(27, 40, 4, 1, rgb("#4a4a52"))
    s.r(27, 45, 4, 1, rgb("#4a4a52"))
    s.r(27, 38, 4, 1, whi)
    # auvent en bois
    for j in range(12):
        y = 13 + j
        s.r(0, y, 32, 1, wood if j % 4 else whi)
        for x in range(0, 32, 4):
            s.p(x, y, wlo)
    s.r(0, 25, 32, 2, wlo)
    s.r(0, 27, 32, 1, (20, 12, 10, 120))
    for x in (1, 29):
        s.r(x, 25, 2, 23, wlo)
        s.r(x, 25, 1, 23, wood)
    # enseigne marteau
    s.r(12, 17, 8, 6, rgb("#c49a58"))
    s.r(12, 17, 8, 1, rgb("#e0b878"))
    s.r(15, 18, 1, 4, rgb("#5a3b1f"))
    s.r(14, 18, 4, 2, rgb("#5e5e6a"))
    # cheminée
    s.r(4, 0, 6, 14, stone)
    s.r(4, 0, 6, 1, shi)
    s.r(9, 1, 1, 13, slo)
    s.r(4, 6, 6, 1, slo)
    s.r(5, 0, 4, 1, rgb("#2a2420"))
    s.outline()
    s.shadow(16, 47.5, 17, 2)
    return s


def farm():
    """Potager clôturé : rangs de baies, épouvantail."""
    s = Spr(32, 34)
    soil, slo, shi = rgb("#7a5232"), rgb("#5a3a22"), rgb("#946840")
    s.r(0, 4, 32, 30, soil)
    for y in range(5, 33, 2):
        s.r(1, y, 30, 1, slo if y % 4 == 1 else shi)
    leaf = [rgb(c) for c in ("#7ac05a", "#4f8f3a", "#356a2c")]
    for r in range(3):
        y = 7 + r * 9
        for c in range(4):
            x = 2 + c * 7
            s.ellipse(x + 3, y + 3, 3.4, 2.8, leaf[1])
            s.ellipse(x + 2.5, y + 2.2, 1.8, 1.4, leaf[0])
            s.r(x + 1, y + 5, 5, 1, leaf[2])
            for (dx, dy) in ((1, 2), (4, 1), (3, 4)):
                s.p(x + dx, y + dy, rgb("#d4384a"))
                s.p(x + dx, y + dy - 1, rgb("#ff8a9a"))
    # épouvantail
    s.r(27, 8, 1, 14, rgb("#6a4a2a"))
    s.r(24, 12, 7, 1, rgb("#6a4a2a"))
    s.r(25, 11, 5, 5, rgb("#a8483a"))
    s.r(26, 7, 3, 3, rgb("#e0c080"))
    s.r(25, 6, 5, 1, rgb("#5a4a2a"))
    s.r(26, 5, 3, 1, rgb("#5a4a2a"))
    # clôture
    fence, flo = rgb("#b08a54"), rgb("#7a5a32")
    s.r(0, 3, 32, 1, fence)
    s.r(0, 5, 32, 1, flo)
    s.r(0, 32, 32, 1, fence)
    for x in (0, 8, 16, 24, 31):
        s.r(x, 1, 1, 33, flo)
        s.p(x, 1, fence)
    s.outline()
    s.shadow(16, 33.5, 16, 1.5)
    return s


def mill():
    """Moulin en pierre, toit conique ; les ailes tournent par-dessus (moyeu en 16, 12)."""
    s = Spr(32, 48)
    body, blo, bhi = rgb("#c4b8a2"), rgb("#8e826e"), rgb("#ded2bc")
    for y in range(16, 48):
        hw = 8 + (y - 16) * 2 // 16
        s.r(16 - hw, y, hw * 2, 1, body)
        s.r(16 - hw, y, 2, 1, bhi)
        s.r(16 + hw - 3, y, 3, 1, blo)
    for y in range(19, 47, 4):
        hw = 8 + (y - 16) * 2 // 16
        for x in range(16 - hw + (y // 4 % 2) * 3, 16 + hw - 2, 6):
            s.r(x, y, 4, 1, blo)
    s.r(13, 37, 6, 11, rgb("#3a2414"))
    s.r(14, 38, 4, 10, rgb("#7a4e2c"))
    s.r(16, 38, 1, 10, rgb("#5a3a20"))
    s.r(14, 25, 4, 5, rgb("#3a2414"))
    s.r(15, 26, 2, 3, rgb("#33475e"))
    roofc = [rgb(c) for c in ("#c4604a", "#a4473a", "#7a3028", "#5a2018")]
    for i in range(14):
        y = 3 + i
        hw = 1 + i * 10 // 13
        s.r(16 - hw, y, hw * 2, 1, roofc[1])
        s.r(16 - hw, y, max(1, hw // 2), 1, roofc[0])
        s.r(16 + hw - max(1, hw // 2), y, max(1, hw // 2), 1, roofc[2])
        if i % 3 == 2:
            s.r(16 - hw, y, hw * 2, 1, roofc[2])
    s.r(5, 17, 22, 1, roofc[3])
    s.r(15, 1, 2, 2, rgb("#6a4a2a"))
    # sacs de farine
    for x in (3, 25):
        s.ellipse(x + 2.5, 45, 3, 3, rgb("#e8dcc0"))
        s.r(x + 1, 42, 3, 1, rgb("#b8a888"))
    s.outline()
    s.shadow(16, 47.5, 15, 2)
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
    """Tour de garde : pierre, créneaux, bannière."""
    s = Spr(16, 48)
    st, lo, hi = rgb("#9494a2"), rgb("#686876"), rgb("#b4b4c2")
    s.r(1, 18, 14, 30, st)
    s.r(1, 18, 2, 30, hi)
    s.r(12, 18, 3, 30, lo)
    for y in range(21, 48, 4):
        s.r(3, y, 9, 1, lo)
        for x in range(3 + (y // 4 % 2) * 3, 12, 6):
            s.r(x, y + 1, 1, 3, lo)
    s.r(0, 12, 16, 6, st)
    s.r(0, 12, 16, 1, hi)
    s.r(0, 17, 16, 1, rgb("#4e4e5a"))
    for x in (0, 6, 12):
        s.r(x, 8, 4, 4, st)
        s.r(x, 8, 4, 1, hi)
        s.r(x + 3, 9, 1, 3, lo)
    s.r(6, 24, 4, 6, rgb("#1e1e28"))
    s.r(7, 24, 2, 1, rgb("#3a3a48"))
    s.r(5, 38, 6, 10, rgb("#3a2414"))
    s.r(6, 39, 4, 9, rgb("#7a4e2c"))
    s.r(5, 38, 6, 1, hi)
    s.r(13, 0, 1, 9, rgb("#5a3b1f"))
    s.r(9, 1, 4, 3, rgb("#3a9ac0"))
    s.r(9, 1, 4, 1, rgb("#7cd4ef"))
    s.r(9, 4, 2, 1, rgb("#2a7aa0"))
    s.outline()
    s.shadow(8, 47.5, 9, 1.8)
    return s


def statue(night):
    """Statue dorée d'un gardien sur un socle sculpté."""
    s = Spr(16, 42)
    sto, slo, shi = rgb("#9494a2"), rgb("#686876"), rgb("#b4b4c2")
    s.r(1, 34, 14, 8, sto)
    s.r(1, 34, 14, 1, shi)
    s.r(2, 36, 12, 4, slo)
    s.r(3, 37, 10, 2, sto)
    s.r(1, 41, 14, 1, slo)
    g, glo, ghi = rgb("#d4ac50"), rgb("#9a7428"), rgb("#f8e08a")
    s.r(4, 30, 8, 4, g)
    s.r(5, 18, 6, 13, g)
    s.r(10, 18, 1, 13, glo)
    s.r(5, 18, 1, 13, ghi)
    s.r(3, 13, 10, 6, g)
    s.r(3, 13, 2, 6, ghi)
    s.r(11, 13, 2, 6, glo)
    s.r(6, 7, 4, 6, g)
    s.r(6, 7, 2, 2, ghi)
    s.r(9, 8, 1, 4, glo)
    s.r(12, 4, 1, 26, rgb("#b8b8c8"))
    s.r(11, 3, 3, 1, ghi)
    s.r(7, 3, 2, 4, glo)
    s.r(6, 14, 4, 3, rgb("#fff3b0") if night else rgb("#eac860"))
    s.outline()
    s.shadow(8, 41.5, 9, 1.6)
    if night:
        s.ellipse(8, 15, 7.5, 7.5, (255, 240, 160, 50))
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
    sheet = Image.new("RGBA", (16 * TS, 10 * TS), CLEAR)
    names = {}

    def put(name, spr, c, r):
        sheet.paste(spr.im, (c * TS, r * TS))
        names[name] = [c, r]

    for bi, bio in enumerate(("plain", "forest", "marsh", "crypt")):
        for v in range(8):
            put("grass_%s_%d" % (bio, v), grass(bio, v), (bi % 2) * 8 + v, bi // 2)
    for v in range(3):
        put("flower_%d" % v, flowers(v), v, 2)
    put("wall_0", wall(0), 3, 2)
    put("wall_1", wall(1), 4, 2)
    put("gate_0", gate(False), 5, 2)
    put("gate_1", gate(True), 6, 2)
    for v in range(3):
        put("crypt_%d" % v, crypt_floor(v), 7 + v, 2)
    put("bridge_v", bridge(False), 10, 2)
    put("bridge_h", bridge(True), 11, 2)
    put("rock_0", rock(0), 12, 2)
    put("rock_1", rock(1), 13, 2)
    put("stump", stump(), 14, 2)
    for m in range(16):
        put("path_%d" % m, path_tile(m), m, 3)
    for m in range(16):
        c, r = (m % 8) * 2, 4 + m // 8
        sheet.paste(water_tile(m, 0).im, (c * TS, r * TS))
        sheet.paste(water_tile(m, 1).im, ((c + 1) * TS, r * TS))
        names["water_%d" % m] = [c, r]
    props = [("tallgrass", 0), ("tallgrass", 1), ("tallgrass", 2), ("bush", 0), ("bush", 1), ("mushroom", 0), ("mushroom", 1),
             ("pebbles", 0), ("fern", 0), ("reeds", 0), ("lily", 0), ("lily", 1), ("bones", 0), ("crystal", 0)]
    for i, (k, v) in enumerate(props):
        put("prop_%s_%d" % (k, v), prop(k, v), i, 6)
    trees = [("plain", 0), ("plain", 1), ("forest", 0), ("forest", 1), ("marsh", 0), ("marsh", 1), ("crypt", 0)]
    for i, (k, v) in enumerate(trees):
        sheet.paste(tree(k, v).im, (i * 2 * TS, 7 * TS))
        names["tree_%s_%d" % (k, v)] = [i * 2, 7]
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
        items.append((name, [human(d, f, P) for d in DIRS for f in range(3)], 10, 27))
    items.append(("gobelin", [goblin(d, f) for d in DIRS for f in range(3)], 10, 22))
    items.append(("chef", [goblin(d, f, 1.5, True) for d in DIRS for f in range(3)], 15, 33))
    items.append(("loup", [wolf(f) for f in range(4)], 14, 18))
    items.append(("feufollet", [wisp(f) for f in range(4)], 10, 26))
    items.append(("spectre", [spectre(f) for f in range(4)], 10, 26))
    for m in ("mask_gob", "mask_wolf", "mask_wisp", "mask_spectre"):
        items.append((m, [mask_overlay(m, "down"), mask_overlay(m, "side")], 10, 27))
    items.append(("tent", [tent()], 12, 19))
    items.append(("chest", [chest(False), chest(True)], 8, 14))
    items.append(("campfire", [campfire(f) for f in range(3)], 0, 20))
    items.append(("house", [house(False), house(True)], 0, 52))
    items.append(("workshop", [workshop()], 0, 48))
    items.append(("farm", [farm()], 0, 34))
    items.append(("mill", [mill()], 0, 48))
    items.append(("mill_blades", [mill_blades()], 18, 18))
    items.append(("tower", [tower()], 0, 48))
    items.append(("statue", [statue(False), statue(True)], 0, 42))
    items.append(("glow", [soft_glow()], 16, 16))
    for name, size in (("attack", 32), ("interact", 24), ("soul", 24), ("potion", 20), ("bag", 18), ("build", 18), ("map", 18), ("pause", 18)):
        items.append(("btn_" + name, [button(name, size, False), button(name, size, True)], 0, 0))
    W = 512
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
