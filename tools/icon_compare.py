#!/usr/bin/env python3
"""Лист «было / стало»: пары иконок (слева старая, справа новая) для выбранных предметов.
Запуск:  python tools/icon_compare.py out.png папка_было [папка_стало] имя имя ..."""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))


def compare(old, new, names, cols=7, cell=118):
    try:
        font = ImageFont.truetype("arial.ttf", 13)
        big = ImageFont.truetype("arial.ttf", 22)
    except OSError:
        font = big = ImageFont.load_default()
    head = 44
    rows = (len(names) + cols - 1) // cols
    pw = 2 * cell + 20
    img = Image.new("RGB", (cols * pw, head + rows * (cell + 24)), (243, 234, 214))
    d = ImageDraw.Draw(img)
    d.text((16, 10), "Иконки предметов: слева — было, справа — стало", fill=(70, 50, 30), font=big)
    for i, n in enumerate(names):
        x, y = (i % cols) * pw + 8, head + (i // cols) * (cell + 24)
        for k, folder in enumerate((old, new)):
            ic = Image.open(os.path.join(folder, n + ".png")).convert("RGBA").resize((cell, cell), Image.LANCZOS)
            img.paste(ic, (x + k * (cell + 4), y), ic)
        d.text((x + 6 + cell, y + cell // 2 - 8), "›", fill=(150, 110, 70), font=big) if False else None
        w = d.textlength(n, font=font)
        d.text((x + cell + 2 - w / 2, y + cell), n, fill=(70, 50, 30), font=font)
    return img


if __name__ == "__main__":
    out, old = sys.argv[1], sys.argv[2]
    new = sys.argv[3] if os.path.isdir(sys.argv[3]) else os.path.join(HERE, "..", "assets", "icons")
    names = [a for a in sys.argv[3:] if not os.path.isdir(a)]
    compare(old, new, names).save(out)
    print(len(names), "pairs ->", out)
