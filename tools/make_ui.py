#!/usr/bin/env python3
"""Interface de Brumeval : cadres en bois et laiton, boutons en relief, barres, logo.

Produit art/ui.png, art/logo.png et scripts/ui_atlas.gd (positions des éléments).
À lancer après tools/make_font.py (le logo utilise la police).
"""
import json
import os
import re

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "art")


def rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(c, d, t):
    return tuple(int(round(c[i] + (d[i] - c[i]) * t)) for i in range(4))


class Img:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.im.load()

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def r(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.p(xx, yy, c)

    def frame(self, x, y, w, h, c):
        self.r(x, y, w, 1, c)
        self.r(x, y + h - 1, w, 1, c)
        self.r(x, y, 1, h, c)
        self.r(x + w - 1, y, 1, h, c)


INK = rgb("#140e10")
BRASS, BRASS_HI, BRASS_LO = rgb("#e0a848"), rgb("#ffe08a"), rgb("#8a5a20")


def panel():
    """Cadre en bois sombre, filet de laiton et rivets aux coins (9 tranches, marge 8)."""
    s = Img(32, 32)
    wood, wood_hi, wood_lo = rgb("#6a4224"), rgb("#8a5a30"), rgb("#4a2c16")
    s.r(0, 0, 32, 32, INK)
    s.r(1, 1, 30, 30, wood)
    for y in range(1, 31):
        for x in range(1, 31):
            if (x * 7 + y * 3) % 11 == 0:
                s.p(x, y, wood_lo)
            elif (x * 5 + y * 13) % 17 == 0:
                s.p(x, y, wood_hi)
    s.r(1, 1, 30, 1, wood_hi)
    s.r(1, 30, 30, 1, wood_lo)
    s.frame(5, 5, 22, 22, BRASS_LO)
    s.frame(6, 6, 20, 20, BRASS)
    s.r(7, 7, 18, 18, rgb("#24161a", 245))
    s.r(7, 7, 18, 1, rgb("#2e1e20", 245))
    for (x, y) in ((2, 2), (28, 2), (2, 28), (28, 28)):
        s.r(x, y, 2, 2, BRASS)
        s.p(x, y, BRASS_HI)
        s.p(x + 1, y + 1, BRASS_LO)
    return s


def hud_panel():
    s = Img(16, 16)
    s.r(0, 0, 16, 16, INK)
    s.r(1, 1, 14, 14, rgb("#24161a", 225))
    s.frame(1, 1, 14, 14, BRASS_LO)
    s.r(2, 1, 12, 1, BRASS)
    return s


def button(state):
    """Bouton bleu en relief, bord doré (marge 4)."""
    s = Img(16, 16)
    top, bot = {"normal": ("#4a86e0", "#2a52a8"), "hover": ("#62a0f4", "#3462c0"),
                "pressed": ("#2a52a8", "#3a6ccc"), "disabled": ("#56607a", "#3e4658")}[state]
    gold = BRASS if state != "disabled" else rgb("#8a8270")
    s.r(0, 0, 16, 16, INK)
    s.frame(1, 1, 14, 14, gold)
    for y in range(2, 14):
        s.r(2, y, 12, 1, mix(rgb(top), rgb(bot), (y - 2) / 11))
    if state == "pressed":
        s.r(2, 13, 12, 1, rgb("#6aa0f0"))
        s.r(2, 2, 12, 1, rgb("#1a3478"))
    else:
        s.r(2, 2, 12, 1, mix(rgb(top), rgb("#ffffff"), 0.45))
        s.r(2, 13, 12, 1, mix(rgb(bot), INK, 0.4))
    for (x, y) in ((1, 1), (14, 1), (1, 14), (14, 14)):
        s.p(x, y, INK)
    return s


def focus():
    s = Img(16, 16)
    s.frame(0, 0, 16, 16, rgb("#9ff0ff"))
    for (x, y) in ((0, 0), (15, 0), (0, 15), (15, 15)):
        s.p(x, y, (0, 0, 0, 0))
    return s


def bar(kind):
    s = Img(8, 8)
    if kind == "bg":
        s.r(0, 0, 8, 8, INK)
        s.r(1, 1, 6, 6, rgb("#2a1a16"))
        s.r(1, 1, 6, 1, rgb("#1a100e"))
        return s
    top, bot = {"hp": ("#ff6a50", "#b02a24"), "xp": ("#9ff0ff", "#3a9ac0"), "soul": ("#c8a0ff", "#6a40b0")}[kind]
    for y in range(8):
        s.r(0, y, 8, 1, mix(rgb(top), rgb(bot), y / 7))
    s.r(0, 1, 8, 1, mix(rgb(top), rgb("#ffffff"), 0.4))
    return s


def check(on):
    s = Img(10, 10)
    s.r(0, 0, 10, 10, INK)
    s.frame(1, 1, 8, 8, BRASS)
    s.r(2, 2, 6, 6, rgb("#24161a"))
    if on:
        for (x, y) in ((3, 5), (4, 6), (5, 5), (6, 4), (7, 3)):
            s.r(x - 1, y - 1, 2, 2, rgb("#9fe08a"))
    return s


def arrow():
    s = Img(7, 5)
    for i, w in enumerate((7, 5, 3, 1)):
        s.r((7 - w) // 2, i, w, 1, BRASS_HI if i == 0 else BRASS)
    return s


def grabber():
    s = Img(6, 10)
    s.r(0, 0, 6, 10, INK)
    s.r(1, 1, 4, 8, BRASS)
    s.r(1, 1, 4, 1, BRASS_HI)
    s.r(1, 8, 4, 1, BRASS_LO)
    return s


def slider():
    s = Img(8, 6)
    s.r(0, 0, 8, 6, INK)
    s.r(1, 1, 6, 4, rgb("#2a1a16"))
    return s


def load_font():
    fnt = open(os.path.join(ART, "font", "brume.fnt")).read()
    im = Image.open(os.path.join(ART, "font", "brume.png"))
    ch = {}
    for m in re.finditer(r"char id=(\d+) x=(\d+) y=(\d+) width=(\d+) height=(\d+) xoffset=0 yoffset=0 xadvance=(\d+)", fnt):
        i, x, y, w, h, a = map(int, m.groups())
        ch[chr(i)] = (im.crop((x, y, x + w, y + h)), a)
    return ch


def logo():
    """« BRUMEVAL » en grandes lettres pixel, dégradé brume et contour sombre."""
    ch = load_font()
    k = 4
    word = "BRUMEVAL"
    w = sum(ch[c][1] + 1 for c in word) * k + 8
    h = 12 * k + 10
    mask = Image.new("L", (w, h), 0)
    x = 4
    for c in word:
        g, a = ch[c]
        big = g.resize((g.width * k, g.height * k), Image.NEAREST).split()[3]
        mask.paste(big, (x, 2), big)
        x += (a + 1) * k
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mp = mask.load()
    op = out.load()
    rows = [y for y in range(h) if any(mp[x, y] for x in range(w))]
    y0, y1 = min(rows), max(rows)
    for y in range(h):
        for x in range(w):
            if mp[x, y]:
                t = (y - y0) / max(1, y1 - y0)
                c = mix(rgb("#e8fcff"), rgb("#7cd0f0"), min(1, t * 1.6)) if t < 0.6 else mix(rgb("#7cd0f0"), rgb("#3a6ad0"), (t - 0.6) / 0.4)
                if (x + y) % 7 == 0 and t > 0.3:
                    c = mix(c, rgb("#ffffff"), 0.3)
                op[x, y] = c
    # contour sombre puis halo bleu
    base = out.copy()
    bp = base.load()
    for y in range(h):
        for x in range(w):
            if bp[x, y][3]:
                continue
            near = [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
            if any(0 <= a < w and 0 <= b < h and bp[a, b][3] == 255 for a, b in near):
                op[x, y] = rgb("#102040")
    base = out.copy()
    bp = base.load()
    for y in range(h):
        for x in range(w):
            if bp[x, y][3]:
                continue
            near = [(x + dx, y + dy) for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2)]
            if any(0 <= a < w and 0 <= b < h and bp[a, b][3] == 255 for a, b in near):
                op[x, y] = rgb("#3a8ad0", 90)
    out.save(os.path.join(ART, "logo.png"))


def main():
    items = [("panel", panel()), ("hud", hud_panel())]
    for st in ("normal", "hover", "pressed", "disabled"):
        items.append(("btn_" + st, button(st)))
    items += [("focus", focus()), ("bar_bg", bar("bg")), ("bar_hp", bar("hp")), ("bar_xp", bar("xp")),
              ("check_on", check(True)), ("check_off", check(False)), ("arrow", arrow()),
              ("grabber", grabber()), ("slider", slider())]
    W = 128
    x = y = rh = 0
    regions = {}
    placed = []
    for name, s in items:
        if x + s.w > W:
            x, y, rh = 0, y + rh + 1, 0
        placed.append((name, s, x, y))
        regions[name] = [x, y, s.w, s.h]
        x += s.w + 1
        rh = max(rh, s.h)
    sheet = Image.new("RGBA", (W, y + rh), (0, 0, 0, 0))
    for name, s, px, py in placed:
        sheet.paste(s.im, (px, py))
    sheet.save(os.path.join(ART, "ui.png"))
    logo()
    with open(os.path.join(HERE, "..", "scripts", "ui_atlas.gd"), "w") as f:
        f.write("class_name UiAtlas\n## Généré par tools/make_ui.py — ne pas modifier à la main.\n\n")
        f.write("const R := " + json.dumps(regions, sort_keys=True) + "\n")
    print("ok :", len(items), "éléments d'interface + logo")


if __name__ == "__main__":
    main()
