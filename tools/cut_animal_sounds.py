"""Нарезать скачанные записи животных на короткие звуки для игры: громкие события (крик, хрюк, блеяние),
по 2–4 варианта на зверя, моно 44.1 кГц, ровная громкость, мягкие края. Пишет assets/audio/sfx_<имя><N>.wav.
Запуск: py -I cut_sounds.py <папка загрузок> <папка assets/audio>"""
import json
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SRC, OUT = sys.argv[1], sys.argv[2]
SR = 44100
meta = json.load(open(os.path.join(SRC, "meta.json"), encoding="utf-8"))

# зверь -> (файлы-источники по названию на Викискладе, сколько вариантов, мин/макс длина, полоса частот)
PLAN = {
    "cluck": (["File:Chickens demanding food.ogg", "File:Hen announcing shes lain an egg.ogg", "File:Hens leaving coop.ogg"], 4, 0.25, 1.2, (250, 9000)),
    "honk": (["File:Geese Honking (loud).ogg"], 3, 0.25, 1.2, (200, 8000)),
    "baa": (["File:Sheep bleat.ogg", "File:Sheep bleating.ogg"], 3, 0.4, 1.6, (150, 8000)),
    "bleat": (["File:Herd of goats bleating.ogg"], 3, 0.35, 1.4, (200, 8000)),
    "oink": (["File:Pig grunt - Erdie.ogg", "File:Mudchute pig 1.ogg", "File:Mudchute pig 2.ogg", "File:Mudchute pig 3.ogg"], 4, 0.2, 1.2, (80, 6000)),
    "penguin": (["File:20091121 Little Penguin calls at St Kilda Breakwater.ogg"], 3, 0.4, 1.8, (200, 8000)),
    "snore": (["File:Walrus sound effect.wav"], 2, 0.8, 2.5, (60, 5000)),
}


def load(path):
    x, sr = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr)
    return x


def events(x, lo, hi, min_len, max_len):
    b, a = signal.butter(2, [lo / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], btype="band")
    y = signal.filtfilt(b, a, x)
    hop = int(0.01 * SR)
    env = np.sqrt(np.convolve(y ** 2, np.ones(hop * 3) / (hop * 3), mode="same"))[::hop]
    floor = np.percentile(env, 30)
    peak = np.percentile(env, 99.5)
    thr = floor + (peak - floor) * 0.22
    on = env > thr
    segs = []
    i = 0
    while i < len(on):
        if on[i]:
            j = i
            gap = 0
            while j < len(on) and (on[j] or gap < 12):
                gap = 0 if on[j] else gap + 1
                j += 1
            s0, s1 = i * hop, (j - gap) * hop
            d = (s1 - s0) / SR
            if min_len <= d <= max_len:
                segs.append((float(env[i:j].max()), s0, s1))
            i = j
        else:
            i += 1
    segs.sort(reverse=True)
    return y, segs


written = {}
for name, (titles, n, mn, mx, band) in PLAN.items():
    cands = []
    for t in titles:
        if t not in meta:
            continue
        x = load(os.path.join(SRC, meta[t]["file"]))
        y, segs = events(x, band[0], band[1], mn, mx)
        if len(x) / SR < 1.6:
            # короткая запись — это и есть один звук: берём целиком
            segs = [(float(np.abs(y).max()) * 10, 0, len(y))] + segs
        for sc, s0, s1 in segs[:6]:
            cands.append((sc, y, s0, s1, t))
    cands.sort(key=lambda c: -c[0])
    # разные источники по очереди, чтобы варианты отличались
    picked, used = [], {}
    for c in cands:
        if used.get(c[4], 0) >= max(1, n // max(1, len({k[4] for k in cands})) + 1):
            continue
        picked.append(c)
        used[c[4]] = used.get(c[4], 0) + 1
        if len(picked) >= n:
            break
    for k, (sc, y, s0, s1, t) in enumerate(picked):
        pad = int(0.04 * SR)
        clip = y[max(0, s0 - pad): s1 + pad * 3].copy()
        f = min(len(clip) // 4, int(0.02 * SR))
        clip[:f] *= np.linspace(0, 1, f)
        tail = min(len(clip) // 3, int(0.08 * SR))
        clip[-tail:] *= np.linspace(1, 0, tail)
        clip = clip / (np.max(np.abs(clip)) + 1e-9) * 0.8
        fn = os.path.join(OUT, "sfx_%s%d.wav" % (name, k))
        sf.write(fn, clip.astype(np.float32), SR, subtype="PCM_16")
        written.setdefault(name, []).append((os.path.basename(fn), round(len(clip) / SR, 2), t))
for k, v in written.items():
    print(k, v)
json.dump({k: [x[2] for x in v] for k, v in written.items()}, open(os.path.join(SRC, "used.json"), "w", encoding="utf-8"), ensure_ascii=False)
