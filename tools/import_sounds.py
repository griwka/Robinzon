#!/usr/bin/env python3
"""Импорт готовых звуков со свободной лицензией (не синтез): действия — из наборов Kenney (CC0),
голоса животных — записи с Wikimedia Commons (общественное достояние, CC0, CC BY, CC BY-SA).

Звуки ложатся вариантами: assets/audio/sfx_<имя>0.wav, sfx_<имя>1.wav, … — игра берёт случайный
(Audio.play сама выбирает вариант, если они есть). Источники и лицензии — в assets/audio/CREDITS.md.

Запуск:  python tools/import_sounds.py <папка с распакованными наборами Kenney> [<папка с записями животных>]
Наборы Kenney: kenney.nl/assets/rpg-audio, impact-sounds, interface-sounds (распаковать в папки с этими именами).
Животные: папка, которую заполняет загрузка с Commons (там же meta.json — название, лицензия, автор).
Нужно: pip install numpy scipy soundfile
"""
import glob
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")

# имя в игре -> (набор, шаблон файлов, громкость пика)
KENNEY = {
    "chop": ("impact-sounds", "impactWood_heavy_00*.ogg", 0.85),
    "rock": ("impact-sounds", "impactMining_00*.ogg", 0.8),
    "build": ("impact-sounds", "impactPlank_medium_00*.ogg", 0.8),
    "hammer": ("impact-sounds", "impactMetal_medium_00*.ogg", 0.7),
    "metal": ("impact-sounds", "impactMetal_light_00*.ogg", 0.6),
    "ice": ("impact-sounds", "impactGlass_medium_00*.ogg", 0.6),
    "plant": ("impact-sounds", "impactSoft_medium_00*.ogg", 0.7),
    "harvest": ("impact-sounds", "impactSoft_heavy_00*.ogg", 0.7),
    "step_grass": ("impact-sounds", "footstep_grass_00*.ogg", 0.32),
    "step_snow": ("impact-sounds", "footstep_snow_00*.ogg", 0.35),
    "craft": ("rpg-audio", ["handleSmallLeather*.ogg", "beltHandle*.ogg"], 0.7),
    "coins": ("rpg-audio", "handleCoins*.ogg", 0.7),
    "creak": ("rpg-audio", "creak*.ogg", 0.6),
    "click": ("interface-sounds", "click_00*.ogg", 0.5),
    "open": ("interface-sounds", "open_00*.ogg", 0.5),
    "pickup": ("interface-sounds", "pluck_00*.ogg", 0.55),
}


def load(path):
    x, sr = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr)
    return x


def tidy(x, peak):
    """Убрать тишину по краям, мягкие края, ровная громкость."""
    a = np.abs(x)
    thr = a.max() * 0.02
    idx = np.where(a > thr)[0]
    if len(idx):
        x = x[max(0, idx[0] - int(0.005 * SR)): idx[-1] + int(0.05 * SR)]
    f = min(len(x) // 4, int(0.004 * SR))
    if f > 1:
        x[:f] *= np.linspace(0, 1, f)
    t = min(len(x) // 3, int(0.03 * SR))
    if t > 1:
        x[-t:] *= np.linspace(1, 0, t)
    return x / (np.abs(x).max() + 1e-9) * peak


def write(name, k, x):
    sf.write(os.path.join(OUT, "sfx_%s%d.wav" % (name, k)), x.astype(np.float32), SR, subtype="PCM_16")


def main():
    src = sys.argv[1]
    done = {}
    for name, (pack, pat, peak) in KENNEY.items():
        files = []
        for p in (pat if isinstance(pat, list) else [pat]):
            files += sorted(glob.glob(os.path.join(src, pack, "**", p), recursive=True))
        files = [f for f in files if "Preview" not in f][:5]
        for k, f in enumerate(files):
            write(name, k, tidy(load(f), peak))
        # старый одиночный файл больше не нужен: варианты заменяют его
        old = os.path.join(OUT, "sfx_%s.wav" % name)
        for p in (old, old + ".import"):
            if os.path.exists(p):
                os.remove(p)
        done[name] = len(files)
    print("kenney:", done)


if __name__ == "__main__":
    main()
