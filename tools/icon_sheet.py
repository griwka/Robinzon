#!/usr/bin/env python3
"""Контактный лист иконок предметов: все PNG из assets/icons (кроме портретов, страниц и т. п.) в сетке с подписями.
Запуск:  python tools/icon_sheet.py out.png [папка_с_иконками] [имя ...]
Без имён — все предметы. Нужен для проверки единого стиля после пересборки иконок."""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SKIP = ("portrait_", "page_", "letter_", "map_", "book_", "fresco_", "bubble", "exclaim", "sym_")


def names(folder):
    out = []
    for f in sorted(os.listdir(folder)):
        if f.endswith(".png") and not f.startswith(SKIP):
            out.append(f[:-4])
    return out


def sheet(folder, picks, cols=12, cell=132, bg=(243, 234, 214)):
    try:
        font = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    rows = (len(picks) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell, rows * (cell + 18)), bg)
    d = ImageDraw.Draw(img)
    for i, n in enumerate(picks):
        x, y = (i % cols) * cell, (i // cols) * (cell + 18)
        ic = Image.open(os.path.join(folder, n + ".png")).convert("RGBA")
        ic = ic.resize((cell - 6, cell - 6), Image.LANCZOS)
        img.paste(ic, (x + 3, y + 3), ic)
        w = d.textlength(n, font=font)
        d.text((x + (cell - w) / 2, y + cell - 2), n, fill=(70, 50, 30), font=font)
    return img


if __name__ == "__main__":
    out = sys.argv[1]
    folder = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "assets", "icons")
    picks = sys.argv[3:] or names(folder)
    sheet(folder, picks).save(out)
    print(len(picks), "icons ->", out)
