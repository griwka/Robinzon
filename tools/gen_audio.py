#!/usr/bin/env python3
"""Генератор всех звуков и музыки игры (синтез, без сторонних записей — все права наши).

Запуск:  python3 tools/gen_audio.py
Нужно:   pip install numpy scipy ; ffmpeg (для .ogg)
Результат: assets/audio/music_*.ogg, amb_*.ogg, sfx_*.wav
"""
import os
import subprocess
import wave

import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


# ============================================================ утилиты
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def note_hz(name):
    names = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + names[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def lowpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def circ_lowpass(x, hz, order=2):
    """Низкочастотный фильтр для зацикленного звука: работает "по кругу", стык не появляется."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec *= 1 / np.sqrt(1 + (f / hz) ** (2 * order))
    return np.fft.irfft(spec, len(x))


def highpass(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def env_exp(n, decay, attack=0.004):
    t = np.arange(n) / SR
    e = np.exp(-t / decay)
    na = max(1, int(attack * SR))
    e[:na] *= np.linspace(0, 1, na)
    return e


def adsr(n, a, d, s, r):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na)
    e[na:na + nd] = np.linspace(1, s, nd)
    if nr > 0:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def reverb(x, seconds=1.4, mix=0.25, damp=3000):
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / (seconds / 5))
    ir = lowpass(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)[: len(x)]
    return x * (1 - mix) + wet * mix


def loop_reverb(x, seconds=1.4, mix=0.25, damp=3000):
    """Реверберация для зацикленного трека: хвост переносится в начало — шов не слышен."""
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR / (seconds / 5))
    ir = lowpass(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2))
    wet = signal.fftconvolve(x, ir)
    tail = wet[len(x):]
    wet = wet[: len(x)].copy()
    wet[: len(tail)] += tail
    return x * (1 - mix) + wet * mix


def place(buf, snd, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    end = min(len(buf), i + len(snd))
    buf[i:end] += snd[: end - i]


def place_wrap(buf, snd, at):
    """Положить звук в зацикленный буфер (что не влезло — в начало)."""
    i = int(at * SR) % len(buf)
    n = len(snd)
    first = min(n, len(buf) - i)
    buf[i:i + first] += snd[:first]
    if first < n:
        buf[: n - first] += snd[first:]


def write_wav(name, x, stereo=None):
    path = os.path.join(OUT, name + ".wav")
    data = np.clip(x, -1, 1)
    if stereo is not None:
        data = np.stack([np.clip(x, -1, 1), np.clip(stereo, -1, 1)], axis=1)
    pcm = (data * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2 if stereo is not None else 1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path


def write_ogg(name, left, right=None, quality=6):
    tmp = write_wav("_tmp_" + name, left, right if right is not None else left)
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), out], check=True)
    os.remove(tmp)


# ============================================================ инструменты
def pluck(freq, dur=1.6, bright=1.0, decay=0.55):
    """Укулеле: гармоники с затуханием, верхние гаснут быстрее + щелчок ногтя."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for k in range(1, 10):
        amp = (1.0 / k) * (bright if k > 2 else 1.0)
        x += amp * np.sin(2 * np.pi * freq * k * t * (1 + 0.0004 * k)) * np.exp(-t * (1 / decay) * (1 + 0.55 * k))
    click = rng.standard_normal(len(t)) * np.exp(-t / 0.003) * 0.06
    x = x + bandpass(click, 1200, 4500)
    return x * env_exp(len(t), 10, 0.002)


def marimba(freq, dur=1.2):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.45)
    x += 0.35 * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t / 0.09)
    x += 0.12 * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t / 0.03)
    return x * env_exp(len(t), 10, 0.002)


def musicbox(freq, dur=2.0):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.9)
    x += 0.3 * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t / 0.5)
    x += 0.15 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t / 0.12)
    return x * env_exp(len(t), 10, 0.003)


def bass(freq, dur=0.9):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    return lowpass(x * env_exp(len(t), 0.35, 0.01), 900)


def pad(freqs, dur):
    t = t_axis(dur)
    x = np.zeros_like(t)
    for f in freqs:
        for det in (-0.6, 0.0, 0.6):
            x += np.sin(2 * np.pi * (f + det) * t) + 0.2 * np.sin(2 * np.pi * 2 * (f + det) * t)
    return lowpass(x * adsr(len(t), dur * 0.3, 0.1, 1.0, dur * 0.4), 1500) / (len(freqs) * 3)


def shaker(dur=0.08, amp=1.0):
    n = int(dur * SR)
    x = bandpass(rng.standard_normal(n), 3500, 8000) * env_exp(n, dur / 4, 0.004)
    return x * amp * 0.6


CHORDS = {
    "C": ["C4", "E4", "G4", "C5"], "G": ["G3", "D4", "G4", "B4"], "Am": ["A3", "E4", "A4", "C5"],
    "F": ["F3", "C4", "F4", "A4"], "Em": ["E3", "B3", "E4", "G4"], "Dm": ["D4", "F4", "A4", "D5"],
}
ROOTS = {"C": "C2", "G": "G2", "Am": "A2", "F": "F2", "Em": "E2", "Dm": "D2"}
SCALE = ["C4", "D4", "E4", "G4", "A4", "C5", "D5", "E5", "G5", "A5"]
CHORD_TONES = {"C": {"C", "E", "G"}, "G": {"G", "B", "D"}, "Am": {"A", "C", "E"}, "F": {"F", "A", "C"},
               "Em": {"E", "G", "B"}, "Dm": {"D", "F", "A"}}


def strum(chord, at, buf, gain, down=True, bright=1.0):
    notes = CHORDS[chord] if down else CHORDS[chord][::-1]
    for i, n in enumerate(notes):
        place_wrap(buf, pluck(note_hz(n), 1.4, bright) * gain * (0.85 + 0.15 * i / 3), at + i * 0.012)


def melody_line(prog, beats_per_bar, rnd, density=0.6):
    """Простая мелодия: на сильных долях — звуки аккорда, между ними — шаги по пентатонике."""
    line = []
    idx = 5
    for bar, chord in enumerate(prog):
        for beat in range(beats_per_bar * 2):  # восьмые
            strong = beat % 4 == 0
            if not strong and rnd.random() > density:
                continue
            if strong:
                cands = [i for i, n in enumerate(SCALE) if n[:-1] in CHORD_TONES[chord]]
                idx = min(cands, key=lambda i: abs(i - idx) + rnd.random() * 1.5)
            else:
                idx = int(np.clip(idx + rnd.choice([-2, -1, -1, 1, 1, 2]), 1, len(SCALE) - 2))
            line.append((bar, beat, SCALE[idx], strong))
    return line


# ============================================================ музыка
def music_day():
    bpm = 96
    beat = 60 / bpm
    prog = ["C", "G", "Am", "F", "C", "G", "F", "G", "Am", "F", "C", "G", "F", "G", "C", "C"]
    dur = len(prog) * 4 * beat
    L = np.zeros(int(dur * SR))
    R = np.zeros_like(L)
    rnd = np.random.default_rng(11)
    for bar, chord in enumerate(prog):
        t0 = bar * 4 * beat
        # укулеле: "раз — и-два — (и) — три — и-четыре"
        pattern = [(0.0, True, 0.9), (1.0, True, 0.55), (1.5, False, 0.45), (2.5, False, 0.5), (3.0, True, 0.6), (3.5, False, 0.4)]
        for off, down, g in pattern:
            strum(chord, t0 + off * beat, L, 0.11 * g, down)
            strum(chord, t0 + off * beat + 0.006, R, 0.11 * g, down, 0.9)
        # бас
        place_wrap(L, bass(note_hz(ROOTS[chord])) * 0.42, t0)
        place_wrap(R, bass(note_hz(ROOTS[chord])) * 0.42, t0)
        place_wrap(L, bass(note_hz(ROOTS[chord]) * 1.5) * 0.28, t0 + 2 * beat)
        place_wrap(R, bass(note_hz(ROOTS[chord]) * 1.5) * 0.28, t0 + 2 * beat)
        # шейкер
        for e in range(8):
            g = 0.05 if e % 2 else 0.08
            place_wrap(L, shaker(0.06, g), t0 + e * beat / 2)
            place_wrap(R, shaker(0.06, g * 0.7), t0 + e * beat / 2 + 0.01)
    # мелодия маримбы: первые 8 тактов — тема, вторые — вариация
    theme = melody_line(prog[:8], 4, rnd, 0.45)
    var = melody_line(prog[8:], 4, rnd, 0.55)
    for part, shift in ((theme, 0), (var, 8)):
        for bar, b8, n, strong in part:
            at = (bar + shift) * 4 * beat + b8 * beat / 2
            g = 0.2 if strong else 0.14
            snd = marimba(note_hz(n))
            place_wrap(L, snd * g * 0.9, at)
            place_wrap(R, snd * g, at + 0.004)
    # повтор темы октавой выше колокольчиком в конце
    for bar, b8, n, strong in theme[:10]:
        at = (bar + 8) * 4 * beat + b8 * beat / 2
        place_wrap(R, musicbox(note_hz(n) * 2) * 0.05, at)
    L = circ_lowpass(loop_reverb(L, 1.6, 0.22), 7500)
    R = circ_lowpass(loop_reverb(R, 1.6, 0.22), 7500)
    m = max(np.max(np.abs(L)), np.max(np.abs(R)))
    write_ogg("music_day", L / m * 0.85, R / m * 0.85)


def music_night():
    bpm = 66
    beat = 60 / bpm
    prog = ["Am", "F", "C", "G", "Am", "F", "C", "Em", "Dm", "Am", "F", "G", "Am", "F", "G", "C"]
    dur = len(prog) * 4 * beat
    L = np.zeros(int(dur * SR))
    R = np.zeros_like(L)
    rnd = np.random.default_rng(23)
    for bar, chord in enumerate(prog):
        t0 = bar * 4 * beat
        p = pad([note_hz(n) for n in CHORDS[chord][:3]], 4 * beat + 1.0) * 0.5
        place_wrap(L, p, t0)
        place_wrap(R, p * 0.9, t0 + 0.02)
        # медленное арпеджио музыкальной шкатулки
        notes = CHORDS[chord]
        for i, k in enumerate([0, 2, 1, 3, 2, 1]):
            at = t0 + i * beat * 0.66
            n = note_hz(notes[k]) * 2
            g = 0.09 if i else 0.12
            place_wrap(L if i % 2 else R, musicbox(n, 2.5) * g, at)
        place_wrap(L, bass(note_hz(ROOTS[chord]), 2.0) * 0.25, t0)
        place_wrap(R, bass(note_hz(ROOTS[chord]), 2.0) * 0.25, t0)
    for bar, b8, n, strong in melody_line(prog, 4, rnd, 0.18):
        if rnd.random() < 0.55:
            at = bar * 4 * beat + b8 * beat / 2
            place_wrap(L, marimba(note_hz(n)) * 0.08, at)
            place_wrap(R, marimba(note_hz(n)) * 0.09, at + 0.01)
    L = loop_reverb(L, 2.6, 0.4, 2200)
    R = loop_reverb(R, 2.6, 0.4, 2200)
    m = max(np.max(np.abs(L)), np.max(np.abs(R)))
    write_ogg("music_night", L / m * 0.8, R / m * 0.8)


# ============================================================ атмосфера
def crossfade_loop(x, fade):
    n = int(fade * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    k = np.linspace(0, 1, n)
    joined = tail * (1 - k) + head * k
    return np.concatenate([joined, body])


def amb_ocean():
    dur = 36.0
    n = int((dur + 4) * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    brown = np.cumsum(noise)
    brown = highpass(brown, 25)
    brown /= np.max(np.abs(brown))
    out = []
    for ch in range(2):
        rumble = lowpass(brown, 420 + ch * 30)
        hiss = bandpass(rng.standard_normal(n), 900, 5000) * 0.12
        # волны: медленное "дыхание" с разным периодом
        swell = 0.55 + 0.45 * np.clip(np.sin(2 * np.pi * t / 7.3 + ch) * 0.7 + np.sin(2 * np.pi * t / 11.1) * 0.5, -1, 1)
        wash = np.clip(np.sin(2 * np.pi * t / 7.3 + ch + 0.6), 0, 1) ** 3
        x = rumble * swell * 0.8 + hiss * (0.25 + wash)
        out.append(crossfade_loop(x, 4.0))
    m = max(np.max(np.abs(out[0])), np.max(np.abs(out[1])))
    write_ogg("amb_ocean", out[0] / m * 0.7, out[1] / m * 0.7, 4)


def amb_night():
    dur = 24.0
    n = int(dur * SR)
    L = np.zeros(n)
    R = np.zeros(n)
    r = np.random.default_rng(5)
    for k in range(70):
        at = r.uniform(0, dur)
        f = r.uniform(4200, 5200)
        pulses = r.integers(3, 7)
        chirp = np.zeros(int(0.5 * SR))
        for p in range(pulses):
            tt = t_axis(0.03)
            seg = np.sin(2 * np.pi * f * tt) * np.sin(np.pi * tt / 0.03)
            i = int(p * 0.045 * SR)
            chirp[i:i + len(seg)] += seg
        g = r.uniform(0.05, 0.16)
        pan = r.uniform(0, 1)
        place_wrap(L, chirp * g * (1 - pan), at)
        place_wrap(R, chirp * g * pan, at)
    # низкий фон ночи
    hum = crossfade_loop(lowpass(rng.standard_normal(n + 2 * SR), 300), 2.0)[:n] * 0.05
    L += hum
    R += hum
    write_ogg("amb_night", L * 0.9, R * 0.9, 4)


def bird(seed):
    r = np.random.default_rng(seed)
    x = np.zeros(int(1.2 * SR))
    pos = 0.0
    base = r.uniform(2400, 3800)
    for k in range(r.integers(2, 6)):
        d = r.uniform(0.05, 0.14)
        tt = t_axis(d)
        f0 = base * r.uniform(0.9, 1.25)
        f1 = f0 * r.uniform(0.7, 1.5)
        f = np.linspace(f0, f1, len(tt))
        ph = 2 * np.pi * np.cumsum(f) / SR
        trill = 1 + 0.3 * np.sin(2 * np.pi * r.uniform(30, 60) * tt)
        s = np.sin(ph) * np.sin(np.pi * tt / d) * trill
        place(x, s, pos)
        pos += d + r.uniform(0.02, 0.08)
    return normalize(reverb(x, 0.6, 0.15), 0.6)


# ============================================================ звуковые эффекты
def sfx_chop():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    thud = np.sin(2 * np.pi * (180 * np.exp(-t * 18) + 90) * t) * np.exp(-t / 0.06)
    crack = bandpass(rng.standard_normal(n), 800, 4000) * np.exp(-t / 0.025)
    return normalize(thud * 0.8 + crack * 0.6)


def sfx_rock():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f in (1800, 2650, 3900):
        x += np.sin(2 * np.pi * f * t) * np.exp(-t / 0.03)
    x += bandpass(rng.standard_normal(n), 1500, 6000) * np.exp(-t / 0.015)
    return normalize(x)


def sfx_rustle():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    flutter = 0.5 + 0.5 * np.sin(2 * np.pi * 23 * t) * np.sin(2 * np.pi * 7 * t)
    x = bandpass(rng.standard_normal(n), 1500, 7000) * flutter * adsr(n, 0.03, 0.1, 0.6, 0.25)
    return normalize(x, 0.7)


def sfx_pickup():
    t = t_axis(0.16)
    f = np.linspace(600, 1400, len(t))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env_exp(len(t), 0.05, 0.003)
    return normalize(x, 0.6)


def sfx_harvest():
    x = np.zeros(int(0.6 * SR))
    for i, n in enumerate(["G5", "C6", "E6"]):
        place(x, marimba(note_hz(n), 0.5) * (0.7 + i * 0.1), i * 0.06)
    place(x, sfx_rustle()[: int(0.2 * SR)] * 0.4, 0)
    return normalize(reverb(x, 0.6, 0.15), 0.75)


def sfx_plant():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    x = lowpass(rng.standard_normal(n), 900) * np.exp(-t / 0.05)
    x2 = lowpass(rng.standard_normal(n), 900) * np.exp(-np.maximum(t - 0.12, 0) / 0.04) * (t > 0.12)
    return normalize(x + x2 * 0.8, 0.7)


def sfx_water():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(18):
        at = rng.uniform(0, 0.6)
        d = 0.05
        tt = t_axis(d)
        f = rng.uniform(700, 1600) * (1 + tt * 8)
        drop = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.015)
        place(x, drop * rng.uniform(0.2, 0.5), at)
    x += bandpass(rng.standard_normal(n), 1500, 6000) * adsr(n, 0.05, 0.2, 0.5, 0.4) * 0.25
    return normalize(reverb(x, 0.5, 0.15), 0.7)


def sfx_build():
    x = np.zeros(int(0.9 * SR))
    for i in range(3):
        n = int(0.2 * SR)
        t = np.arange(n) / SR
        knock = np.sin(2 * np.pi * (300 - i * 20) * t) * np.exp(-t / 0.04) + bandpass(rng.standard_normal(n), 1000, 3000) * np.exp(-t / 0.01) * 0.5
        place(x, knock, i * 0.22)
    place(x, marimba(note_hz("C6"), 0.6) * 0.4, 0.66)
    return normalize(reverb(x, 0.6, 0.12), 0.8)


def sfx_craft():
    x = np.zeros(int(0.7 * SR))
    for i in range(4):
        n = int(0.05 * SR)
        t = np.arange(n) / SR
        place(x, bandpass(rng.standard_normal(n), 2000, 6000) * np.exp(-t / 0.01) * 0.5, i * 0.07)
    place(x, marimba(note_hz("E6"), 0.5) * 0.6, 0.3)
    place(x, marimba(note_hz("A6"), 0.5) * 0.5, 0.38)
    return normalize(reverb(x, 0.6, 0.15), 0.7)


def sfx_quest():
    x = np.zeros(int(1.8 * SR))
    for i, n in enumerate(["C5", "E5", "G5", "C6"]):
        place(x, marimba(note_hz(n), 1.0) * 0.6, i * 0.11)
        place(x, musicbox(note_hz(n) * 2, 1.2) * 0.25, i * 0.11 + 0.01)
    for n in ("C5", "E5", "G5"):
        place(x, pluck(note_hz(n), 1.3) * 0.25, 0.5)
    return normalize(reverb(x, 1.2, 0.25), 0.8)


def sfx_rare():
    x = np.zeros(int(1.2 * SR))
    for i, n in enumerate(["E6", "G6", "B6", "E7"]):
        place(x, musicbox(note_hz(n), 0.8) * 0.5, i * 0.05)
    return normalize(reverb(x, 1.0, 0.3), 0.6)


def sfx_click():
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 1600 * t) * np.exp(-t / 0.008) + bandpass(rng.standard_normal(n), 2000, 7000) * np.exp(-t / 0.004) * 0.3
    return normalize(x, 0.5)


def sfx_open():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    x = bandpass(rng.standard_normal(n), 600, 3000) * np.sin(np.pi * t / 0.25) ** 2
    x += marimba(note_hz("G5"), 0.25)[:n] * 0.4
    return normalize(x, 0.45)


def sfx_blip():
    return normalize(marimba(note_hz("A5"), 0.12) * env_exp(int(0.12 * SR), 0.04), 0.35)


def sfx_step(kind):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    if kind == "sand":
        x = bandpass(rng.standard_normal(n), 400, 2500) * adsr(n, 0.01, 0.03, 0.4, 0.06)
    else:
        x = bandpass(rng.standard_normal(n), 1200, 6000) * adsr(n, 0.005, 0.02, 0.3, 0.07) * (0.6 + 0.4 * np.sin(2 * np.pi * 40 * t))
    return normalize(x, 0.35)


def sfx_cluck():
    x = np.zeros(int(0.6 * SR))
    for i, (f, d) in enumerate(((520, 0.07), (560, 0.06), (700, 0.14))):
        tt = t_axis(d)
        freq = f * (1 + 0.15 * np.sin(np.pi * tt / d))
        pulse = signal.square(2 * np.pi * np.cumsum(freq) / SR, 0.3)
        s = bandpass(pulse, 600, 2500) * np.sin(np.pi * tt / d)
        place(x, s, i * 0.11)
    return normalize(x, 0.6)


def sfx_bleat():
    d = 0.7
    tt = t_axis(d)
    freq = 380 * (1 + 0.06 * np.sin(2 * np.pi * 9 * tt)) * (1 - 0.1 * tt)
    saw = signal.sawtooth(2 * np.pi * np.cumsum(freq) / SR)
    x = bandpass(saw, 500, 1400) + 0.5 * bandpass(saw, 1800, 2800)
    x *= adsr(len(tt), 0.05, 0.1, 0.8, 0.25)
    return normalize(x, 0.6)


def sfx_oink():
    x = np.zeros(int(0.5 * SR))
    for i, (f, d) in enumerate(((150, 0.12), (180, 0.16))):
        tt = t_axis(d)
        freq = f * (1 + 0.3 * np.sin(np.pi * tt / d))
        pulse = signal.square(2 * np.pi * np.cumsum(freq) / SR, 0.25)
        s = bandpass(pulse, 200, 1400) * np.sin(np.pi * tt / d) + 0.3 * bandpass(rng.standard_normal(len(tt)), 300, 900) * np.sin(np.pi * tt / d)
        place(x, s, i * 0.17)
    return normalize(x, 0.6)


def sfx_squawk():
    d = 0.32
    tt = t_axis(d)
    freq = np.interp(tt, [0, 0.08, 0.32], [900, 1500, 1100])
    mod = np.sin(2 * np.pi * freq * 1.5 * tt) * 3
    s = np.sin(2 * np.pi * np.cumsum(freq) / SR + mod)
    s = bandpass(s + 0.3 * rng.standard_normal(len(tt)), 700, 4000) * adsr(len(tt), 0.01, 0.05, 0.7, 0.12)
    return normalize(s, 0.6)


def sfx_sleep():
    x = np.zeros(int(2.5 * SR))
    for i, n in enumerate(["E5", "C5", "A4", "E4"]):
        place(x, musicbox(note_hz(n), 1.6) * 0.5, i * 0.28)
    return normalize(reverb(x, 1.8, 0.4), 0.6)


def sfx_shake():
    x = sfx_rustle()
    x = np.concatenate([x, x * 0.6])
    thump = np.zeros_like(x)
    t = t_axis(0.2)
    place(thump, np.sin(2 * np.pi * 120 * t) * np.exp(-t / 0.05), 0.35)
    return normalize(x + thump * 0.8, 0.75)


def main():
    os.makedirs(OUT, exist_ok=True)
    sfx = {
        "chop": sfx_chop(), "rock": sfx_rock(), "rustle": sfx_rustle(), "pickup": sfx_pickup(),
        "harvest": sfx_harvest(), "plant": sfx_plant(), "water": sfx_water(), "build": sfx_build(),
        "craft": sfx_craft(), "quest": sfx_quest(), "rare": sfx_rare(), "click": sfx_click(),
        "open": sfx_open(), "blip": sfx_blip(), "step_sand": sfx_step("sand"), "step_grass": sfx_step("grass"),
        "cluck": sfx_cluck(), "bleat": sfx_bleat(), "squawk": sfx_squawk(), "oink": sfx_oink(), "sleep": sfx_sleep(),
        "shake": sfx_shake(),
    }
    for i in range(4):
        sfx["bird%d" % i] = bird(100 + i)
    for name, x in sfx.items():
        write_wav("sfx_" + name, x)
    amb_ocean()
    amb_night()
    music_day()
    music_night()
    print("audio:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
