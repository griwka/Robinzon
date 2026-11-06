#!/usr/bin/env python3
"""Генератор всех звуков и музыки игры (синтез, без сторонних записей — все права наши).

Запуск:  python3 tools/gen_audio.py
Нужно:   pip install numpy scipy soundfile  (.ogg пишет soundfile; если есть ffmpeg — им)
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
    out = os.path.join(OUT, name + ".ogg")
    import shutil
    if shutil.which("ffmpeg") is None:
        # без ffmpeg: Vorbis через libsndfile (pip install soundfile)
        import soundfile as sf
        data = np.stack([np.clip(left, -1, 1), np.clip(right if right is not None else left, -1, 1)], axis=1)
        with sf.SoundFile(out, "w", SR, 2, format="OGG", subtype="VORBIS") as f:
            for i in range(0, len(data), 4096):   # кусками: большой блок libvorbis на Windows не переваривает
                f.write(data[i:i + 4096].astype(np.float32))
        return
    tmp = write_wav("_tmp_" + name, left, right if right is not None else left)
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


# ------------------------------------------------------------ глава 8: темы Ока шторма
def _fade_tail(L, R, secs=4.0):
    n = int(secs * SR)
    k = np.linspace(1.0, 0.0, n) ** 1.5
    L[-n:] *= k
    R[-n:] *= k
    return L, R


def _write_theme(name, L, R, peak=0.8):
    m = max(np.max(np.abs(L)), np.max(np.abs(R))) + 1e-9
    write_ogg(name, L / m * peak, R / m * peak)


def music_eye():
    """Око шторма (подъём): тихие тянущиеся аккорды, редкие звуки шкатулки, низкий гул и ветер вдали. Петля."""
    bpm = 58
    beat = 60 / bpm
    prog = ["Am", "F", "C", "G", "Am", "F", "Em", "Em", "Dm", "Am", "F", "G", "Am", "F", "G", "Am"]
    dur = len(prog) * 4 * beat
    L = np.zeros(int(dur * SR))
    R = np.zeros_like(L)
    r = np.random.default_rng(81)
    for bar, chord in enumerate(prog):
        t0 = bar * 4 * beat
        p = pad([note_hz(n) for n in CHORDS[chord][:3]], 4 * beat + 1.5) * 0.55
        place_wrap(L, p, t0)
        place_wrap(R, p * 0.92, t0 + 0.03)
        place_wrap(L, bass(note_hz(ROOTS[chord]), 3.0) * 0.22, t0)
        place_wrap(R, bass(note_hz(ROOTS[chord]), 3.0) * 0.22, t0)
        # «маяк»: короткий мотив из трёх нот через такт — как мигающий огонь
        if bar % 2 == 0:
            notes = CHORDS[chord]
            for i, k in enumerate((0, 2, 3)):
                at = t0 + beat * (1.0 + i * 0.75)
                place_wrap(L if i % 2 else R, musicbox(note_hz(notes[k]) * 2, 3.0) * 0.08, at)
    # ветер вдали: шум, который медленно дышит
    t = np.arange(len(L)) / SR
    wind = bandpass(r.standard_normal(len(L)), 300, 1200) * (0.5 + 0.5 * np.sin(2 * np.pi * t / dur * 4)) * 0.05
    L += wind
    R += np.roll(wind, int(0.4 * SR))
    L = loop_reverb(L, 3.0, 0.45, 2000)
    R = loop_reverb(R, 3.0, 0.45, 2000)
    _write_theme("music_eye", L, R, 0.75)


def music_meeting():
    """Встреча с братом: тёплая укулеле в медленном темпе и мелодия маримбы; в конце — тихий аккорд. Один раз."""
    bpm = 74
    beat = 60 / bpm
    prog = ["C", "G", "Am", "F", "C", "F", "G", "C", "Am", "F", "C", "G"]
    dur = len(prog) * 4 * beat + 4.0
    L = np.zeros(int(dur * SR))
    R = np.zeros_like(L)
    r = np.random.default_rng(91)
    for bar, chord in enumerate(prog):
        t0 = bar * 4 * beat
        for off, g in ((0.0, 0.9), (2.0, 0.6)):
            for i, n in enumerate(CHORDS[chord]):
                place(L, pluck(note_hz(n), 2.0, 0.7) * 0.09 * g, t0 + off * beat + i * 0.03)
                place(R, pluck(note_hz(n), 2.0, 0.7) * 0.09 * g, t0 + off * beat + i * 0.03 + 0.008)
        place(L, bass(note_hz(ROOTS[chord]), 2.2) * 0.3, t0)
        place(R, bass(note_hz(ROOTS[chord]), 2.2) * 0.3, t0)
    for bar, b8, n, strong in melody_line(prog, 4, r, 0.35):
        at = bar * 4 * beat + b8 * beat / 2
        place(L, marimba(note_hz(n)) * (0.16 if strong else 0.11), at)
        place(R, marimba(note_hz(n)) * (0.17 if strong else 0.12), at + 0.005)
    end = len(prog) * 4 * beat
    p = pad([note_hz(n) for n in CHORDS["C"][:3]], 4.0) * 0.6
    place(L, p, end - 0.5)
    place(R, p, end - 0.48)
    L, R = reverb(L, 2.2, 0.35), reverb(R, 2.2, 0.35)
    L, R = _fade_tail(L, R, 3.0)
    _write_theme("music_meeting", L, R)


def music_sea():
    """Финал «Открытое море»: светлая, широкая тема — укулеле, шкатулка октавой выше, морской шум. Один раз."""
    bpm = 92
    beat = 60 / bpm
    prog = ["F", "C", "G", "Am", "F", "C", "G", "C", "F", "C", "Dm", "G", "F", "G", "C", "C"]
    dur = len(prog) * 4 * beat + 5.0
    L = np.zeros(int(dur * SR))
    R = np.zeros_like(L)
    r = np.random.default_rng(101)
    for bar, chord in enumerate(prog):
        t0 = bar * 4 * beat
        for off, down, g in ((0.0, True, 0.9), (1.5, False, 0.5), (2.0, True, 0.7), (3.0, True, 0.55), (3.5, False, 0.45)):
            for i, n in enumerate(CHORDS[chord] if down else CHORDS[chord][::-1]):
                place(L, pluck(note_hz(n), 1.4) * 0.1 * g, t0 + off * beat + i * 0.012)
                place(R, pluck(note_hz(n), 1.4, 0.9) * 0.1 * g, t0 + off * beat + i * 0.012 + 0.006)
        place(L, bass(note_hz(ROOTS[chord])) * 0.4, t0)
        place(R, bass(note_hz(ROOTS[chord])) * 0.4, t0)
    for bar, b8, n, strong in melody_line(prog, 4, r, 0.5):
        at = bar * 4 * beat + b8 * beat / 2
        place(L, musicbox(note_hz(n) * 2) * (0.07 if strong else 0.05), at)
        place(R, marimba(note_hz(n)) * (0.15 if strong else 0.1), at + 0.004)
    t = np.arange(len(L)) / SR
    surf = lowpass(r.standard_normal(len(L)), 700) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 7.0)) * 0.04
    L += surf
    R += np.roll(surf, int(1.3 * SR))
    L, R = reverb(L, 1.8, 0.25), reverb(R, 1.8, 0.25)
    L, R = _fade_tail(L, R, 5.0)
    _write_theme("music_sea", L, R)


def music_keeper():
    """Финал «Хранитель огня»: медленные аккорды, шкатулка ведёт мелодию, тёплый гул огня. Один раз."""
    bpm = 60
    beat = 60 / bpm
    prog = ["Am", "F", "C", "G", "F", "C", "Dm", "G", "Am", "F", "G", "C"]
    dur = len(prog) * 4 * beat + 6.0
    L = np.zeros(int(dur * SR))
    R = np.zeros_like(L)
    r = np.random.default_rng(111)
    for bar, chord in enumerate(prog):
        t0 = bar * 4 * beat
        p = pad([note_hz(n) for n in CHORDS[chord][:3]], 4 * beat + 1.2) * 0.6
        place(L, p, t0)
        place(R, p * 0.9, t0 + 0.02)
        place(L, bass(note_hz(ROOTS[chord]), 3.5) * 0.25, t0)
        place(R, bass(note_hz(ROOTS[chord]), 3.5) * 0.25, t0)
    for bar, b8, n, strong in melody_line(prog, 4, r, 0.3):
        at = bar * 4 * beat + b8 * beat / 2
        place(L if b8 % 2 else R, musicbox(note_hz(n) * 2, 2.8) * (0.1 if strong else 0.07), at)
    t = np.arange(len(L)) / SR
    fire = lowpass(r.standard_normal(len(L)), 300) * (0.8 + 0.2 * np.sin(2 * np.pi * t * 0.3)) * 0.05
    L += fire
    R += fire
    L, R = reverb(L, 2.8, 0.4, 2400), reverb(R, 2.8, 0.4, 2400)
    L, R = _fade_tail(L, R, 6.0)
    _write_theme("music_keeper", L, R)


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


def amb_rain():
    """Тёплый тропический дождь: ровный шелест + капли по листьям, бесшовная петля."""
    r = np.random.default_rng(11)
    dur = 20.0
    n = int((dur + 3) * SR)
    out = []
    for ch in range(2):
        hiss = bandpass(r.standard_normal(n), 500, 7000) * 0.35
        body = lowpass(r.standard_normal(n), 900) * 0.5
        drops = np.zeros(n)
        for k in range(int(dur * 55)):
            at = r.uniform(0, dur + 2.5)
            m = int(0.03 * SR)
            tt = np.arange(m) / SR
            f = r.uniform(1800, 5200)
            d = np.sin(2 * np.pi * f * tt * (1.0 - tt * 8.0)) * np.exp(-tt / 0.006)
            i = int(at * SR)
            if i + m < n:
                drops[i:i + m] += d * r.uniform(0.05, 0.22)
        swell = 0.85 + 0.15 * np.sin(2 * np.pi * np.arange(n) / SR / 6.3 + ch)
        x = (hiss + body) * swell + drops
        out.append(crossfade_loop(x, 3.0))
    m = max(np.max(np.abs(out[0])), np.max(np.abs(out[1])))
    write_ogg("amb_rain", out[0] / m * 0.7, out[1] / m * 0.7, 4)


def sfx_thud():
    """Глухой удар о землю: упало дерево, разбился валун."""
    r = np.random.default_rng(12)
    t = t_axis(0.6)
    low = np.sin(2 * np.pi * (70 - 30 * t) * t) * np.exp(-t / 0.12)
    crunch = lowpass(r.standard_normal(len(t)), 1400) * np.exp(-t / 0.08) * 0.5
    return normalize(low + crunch, 0.85)


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
def sfx_chop(seed=0):
    """Удар топора по дереву: щелчок лезвия, глухой «тук» ствола, звон древесины (несколько собственных
    частот, как у полена) и треск щепок. seed — вариант: другой ствол, другая сила удара."""
    r = np.random.default_rng(500 + seed)
    d = 0.42
    n = int(d * SR)
    t = np.arange(n) / SR
    k = r.uniform(0.9, 1.12)                                  # «размер» ствола — сдвигает все частоты
    blade = bandpass(r.standard_normal(n), 1800, 7000) * np.exp(-t / 0.004) * 0.9
    f0 = 105 * k
    thump = np.sin(2 * np.pi * np.cumsum(f0 + 120 * np.exp(-t * 40)) / SR) * np.exp(-t / 0.045) * 1.1
    body = np.zeros(n)
    for f, dec, a in ((230, 0.11, 0.55), (410, 0.07, 0.4), (690, 0.045, 0.28), (1180, 0.025, 0.18), (1720, 0.015, 0.1)):
        ff = f * k * r.uniform(0.96, 1.04)
        body += a * np.sin(2 * np.pi * ff * t + r.uniform(0, 6.28)) * np.exp(-t / (dec * r.uniform(0.85, 1.15)))
    body *= np.clip(t / 0.0015, 0, 1)
    x = blade + thump + body
    for _ in range(int(r.integers(4, 9))):                    # щепки
        at = r.uniform(0.008, 0.07)
        m = int(r.integers(60, 200))
        c = bandpass(r.standard_normal(m), 2500, 8000) * np.exp(-np.arange(m) / (m / 5))
        place(x, c * r.uniform(0.15, 0.35), at)
    x = lowpass(x, 9000)
    x *= np.clip((d - t) / 0.05, 0, 1)
    return normalize(x, 0.85)


def sfx_whoosh():
    """Свист замаха: воздух рассекается — шум, который нарастает и уходит вверх по высоте."""
    r = np.random.default_rng(171)
    d = 0.3
    n = int(d * SR)
    t = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(t / d, 0, 1)) ** 3
    lo = bandpass(r.standard_normal(n), 300, 1100)
    hi = bandpass(r.standard_normal(n), 1100, 3200)
    mixk = np.clip(t / d, 0, 1)
    x = (lo * (1 - mixk) + hi * mixk) * env
    return normalize(x, 0.5)


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


def sfx_step(kind, seed=0):
    """Шаг. Песок: мягкий глухой удар пятки и тихий хруст отдельных песчинок (сначала пятка, через миг — носок).
    Трава: тот же мягкий удар и шелест стеблей. Несколько вариантов (seed), чтобы шаги не звучали одинаково."""
    r = np.random.default_rng(300 + seed + (50 if kind != "sand" else 0))
    d = 0.24
    n = int(d * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for at, g in ((0.0, 1.0), (r.uniform(0.05, 0.08), 0.6)):   # пятка, затем носок
        m = int(0.09 * SR)
        tt = np.arange(m) / SR
        thud = lowpass(r.standard_normal(m), 220) * np.exp(-tt / 0.018) * np.clip(tt / 0.004, 0, 1) * 2.2
        place(x, thud * g, at)
        if kind == "sand":
            # песчинки: короткие щелчки, густо в начале и реже к концу, приглушённые
            k = int(r.integers(55, 80))
            for _ in range(k):
                at2 = at + r.exponential(0.025)
                c = int(r.integers(30, 90))
                click = r.standard_normal(c) * np.exp(-np.arange(c) / (c / 4))
                place(x, click * r.uniform(0.05, 0.16) * g, at2)
        else:
            m2 = int(0.14 * SR)
            tt2 = np.arange(m2) / SR
            swish = bandpass(r.standard_normal(m2), 1500, 5000) * np.exp(-tt2 / 0.04) * np.clip(tt2 / 0.01, 0, 1) * 0.35
            place(x, swish * g, at + 0.005)
    if kind == "sand":
        x = bandpass(x, 90, 4200)
    x *= np.clip((d - t) / 0.03, 0, 1)   # без щелчка в конце
    return normalize(x, 0.3)


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


# ============================================================ глава 4 — Грозовой остров
def sfx_thunder(seed):
    """Гром: резкий треск разряда, затем низкий раскатистый гул с «перекатами» (3–4 с)."""
    r = np.random.default_rng(300 + seed)
    d = 3.6 + seed * 0.3
    n = int(d * SR)
    t = np.arange(n) / SR
    crack = highpass(r.standard_normal(n), 1500) * np.exp(-t / 0.05) * 0.8
    rumble = lowpass(r.standard_normal(n), 140 + seed * 30, 3) * 3.0
    rolls = np.ones(n)
    for k in range(4 + seed):
        at = r.uniform(0.15, d * 0.6)
        rolls += 1.4 * np.exp(-((t - at) / r.uniform(0.15, 0.35)) ** 2)
    env = (1 - np.exp(-t / 0.08)) * np.exp(-t / (1.1 + seed * 0.2))
    body = lowpass(r.standard_normal(n), 600) * np.exp(-t / 0.4) * 0.4
    return normalize(crack + (rumble * rolls + body) * env, 0.9)


def sfx_radio():
    """Рация: щелчок тангенты, шипение эфира с «уплывающим» тоном."""
    r = np.random.default_rng(41)
    d = 0.7
    t = t_axis(d)
    hiss = bandpass(r.standard_normal(len(t)), 900, 5000) * 0.35
    tone = np.sin(2 * np.pi * (1200 + 300 * np.sin(2 * np.pi * 3 * t)) * t) * 0.12
    click = np.zeros(len(t))
    click[:200] = r.standard_normal(200) * np.linspace(1, 0, 200)
    env = np.minimum(1, t / 0.03) * np.minimum(1, (d - t) / 0.12)
    gate = (np.sin(2 * np.pi * 11 * t) > -0.6).astype(float) * 0.5 + 0.5
    return normalize(click + (hiss * gate + tone) * env, 0.6)


def sfx_honk():
    """Гусь: два гнусавых «га-га» с хрипотцой."""
    x = np.zeros(int(0.7 * SR))
    for i, (f, d) in enumerate(((330, 0.16), (300, 0.22))):
        tt = t_axis(d)
        freq = f * (1 + 0.08 * np.sin(np.pi * tt / d)) * (1 - 0.15 * tt / d)
        saw = signal.sawtooth(2 * np.pi * np.cumsum(freq) / SR)
        s = bandpass(saw, 400, 2600) * np.sin(np.pi * tt / d) ** 0.6
        s += bandpass(rng.standard_normal(len(tt)), 1500, 4000) * 0.08 * np.sin(np.pi * tt / d)
        place(x, s, i * 0.24)
    return normalize(x, 0.6)


def sfx_metal():
    """Удар по ржавому железу: звонкий лязг с быстро гаснущими обертонами."""
    r = np.random.default_rng(55)
    d = 0.6
    t = t_axis(d)
    x = np.zeros(len(t))
    for f, a, dec in ((420, 0.5, 0.18), (1130, 0.35, 0.12), (2470, 0.25, 0.07), (3900, 0.15, 0.05)):
        x += np.sin(2 * np.pi * f * t + r.uniform(0, 6)) * a * np.exp(-t / dec)
    x += highpass(r.standard_normal(len(t)), 2000) * np.exp(-t / 0.02) * 0.6
    return normalize(x, 0.7)


# ============================================================ глава 5 — Ледяной остров
def sfx_wind():
    """Порыв холодного ветра: шум, который то набирает силу, то стихает, с лёгким «посвистом»."""
    r = np.random.default_rng(71)
    d = 3.2
    t = t_axis(d)
    n = len(t)
    env = np.sin(np.pi * t / d) ** 1.5 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.9 * t + 1.0))
    base = bandpass(r.standard_normal(n), 250, 1400) * env
    whistle_f = 900 + 250 * np.sin(2 * np.pi * 0.4 * t) + 120 * np.sin(2 * np.pi * 1.7 * t)
    whistle = np.sin(2 * np.pi * np.cumsum(whistle_f) / SR) * 0.06 * env ** 2
    gusty = bandpass(r.standard_normal(n), 1500, 4000) * 0.25 * env ** 3
    return normalize(base + whistle + gusty, 0.55)


def sfx_ice():
    """Удар ледорубом по льду: звонкий хруст, осыпаются мелкие осколки."""
    r = np.random.default_rng(83)
    d = 0.6
    t = t_axis(d)
    n = len(t)
    crack = highpass(r.standard_normal(n), 2500) * np.exp(-t / 0.015)
    ring = np.zeros(n)
    for f, a, dec in ((1850, 0.3, 0.09), (3100, 0.25, 0.06), (4700, 0.18, 0.04)):
        ring += np.sin(2 * np.pi * f * t + r.uniform(0, 6)) * a * np.exp(-t / dec)
    tinkle = np.zeros(n)
    for k in range(9):
        at = r.uniform(0.05, 0.45)
        tt = t_axis(0.04)
        place(tinkle, np.sin(2 * np.pi * r.uniform(3000, 6500) * tt) * np.exp(-tt / 0.01) * r.uniform(0.1, 0.25), at)
    body = lowpass(r.standard_normal(n), 400) * np.exp(-t / 0.05) * 0.5
    return normalize(crack * 0.8 + ring + tinkle + body, 0.7)


def sfx_penguin():
    """Пингвин: хрипловатое «а-а-а» с икающими переходами, как маленькая труба."""
    x = np.zeros(int(0.9 * SR))
    for i, (f, d) in enumerate(((480, 0.12), (520, 0.12), (430, 0.3))):
        tt = t_axis(d)
        freq = f * (1 + 0.1 * np.sin(np.pi * tt / d)) * (1 + 0.03 * np.sin(2 * np.pi * 30 * tt))
        saw = signal.sawtooth(2 * np.pi * np.cumsum(freq) / SR, 0.3)
        s = bandpass(saw, 500, 3000) * np.sin(np.pi * tt / d) ** 0.7
        place(x, s, i * 0.15 + (0.05 if i == 2 else 0.0))
    return normalize(x, 0.5)


def sfx_snore():
    """Храп моржа: долгий низкий рокот на вдохе и пыхтение на выдохе."""
    r = np.random.default_rng(97)
    d = 2.2
    t = t_axis(d)
    n = len(t)
    inhale = (t < 1.1).astype(float) * np.sin(np.pi * np.clip(t / 1.1, 0, 1))
    exhale = (t >= 1.2).astype(float) * np.sin(np.pi * np.clip((t - 1.2) / 0.9, 0, 1))
    buzz = signal.sawtooth(2 * np.pi * (55 + 8 * np.sin(2 * np.pi * 3 * t)) * t)
    rumble = lowpass(buzz, 400) * (0.6 + 0.4 * np.sin(2 * np.pi * 26 * t)) * inhale
    puff = bandpass(r.standard_normal(n), 300, 1500) * exhale * 0.5
    return normalize(rumble + puff, 0.6)


def sfx_drip():
    """Капля: оттепель, с сосулек капает — короткий «плюк» с подъёмом тона."""
    d = 0.35
    t = t_axis(d)
    f = 900 + 1400 * (1 - np.exp(-t / 0.03))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.06)
    x += np.sin(2 * np.pi * 2600 * t) * np.exp(-t / 0.02) * 0.2
    return normalize(x, 0.5)


def sfx_step_snow():
    """Шаг по снегу: сухой скрип-хруст."""
    r = np.random.default_rng(13)
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    crunch = bandpass(r.standard_normal(n), 1800, 7000) * adsr(n, 0.01, 0.05, 0.4, 0.08)
    grain = (r.random(n) > 0.985).astype(float) * r.standard_normal(n) * 1.5
    squeak = np.sin(2 * np.pi * (1100 + 400 * t / 0.16) * t) * 0.08 * adsr(n, 0.02, 0.05, 0.3, 0.06)
    return normalize(crunch + bandpass(grain, 2000, 8000) * 0.5 + squeak, 0.35)


# ============================================================ глава 6 — Остров Вулкана
def sfx_lava():
    """Бульканье лавы: густые медленные пузыри с глухим «плюх»."""
    r = np.random.default_rng(111)
    d = 1.6
    x = np.zeros(int(d * SR))
    for k in range(5):
        at = r.uniform(0.0, 1.3)
        dd = r.uniform(0.12, 0.25)
        tt = t_axis(dd)
        f = r.uniform(70, 130) * (1 + 1.5 * tt / dd)
        s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / dd) ** 2
        place(x, s * r.uniform(0.5, 1.0), at)
    x += lowpass(r.standard_normal(len(x)), 300) * 0.3
    return normalize(x, 0.6)


def sfx_steam():
    """Шипение пара: резкий белый шум, быстро нарастает и медленно гаснет."""
    r = np.random.default_rng(113)
    d = 1.1
    t = t_axis(d)
    env = np.minimum(1, t / 0.04) * np.exp(-t / 0.35)
    return normalize(bandpass(r.standard_normal(len(t)), 2500, 9000) * env, 0.55)


def sfx_hammer():
    """Удар молота по наковальне: звонкий металлический «дзынь» и короткий стук."""
    r = np.random.default_rng(117)
    d = 0.9
    t = t_axis(d)
    x = np.zeros(len(t))
    for f, a, dec in ((870, 0.5, 0.25), (2130, 0.35, 0.15), (3420, 0.22, 0.09), (5100, 0.12, 0.05)):
        x += np.sin(2 * np.pi * f * t + r.uniform(0, 6)) * a * np.exp(-t / dec)
    x += highpass(r.standard_normal(len(t)), 1500) * np.exp(-t / 0.01) * 0.8
    return normalize(x, 0.7)


def sfx_tortoise():
    """Черепаха: смешной глубокий вздох-пыхтение, как у старого дивана."""
    r = np.random.default_rng(119)
    d = 1.4
    t = t_axis(d)
    env = np.sin(np.pi * np.clip(t / 1.2, 0, 1)) ** 1.5
    breath = bandpass(r.standard_normal(len(t)), 200, 900) * env
    hum = np.sin(2 * np.pi * (95 - 20 * t) * t) * 0.25 * env
    return normalize(breath + hum, 0.5)


def sfx_rumble():
    """Гул вулкана: очень низкий рокот издалека."""
    r = np.random.default_rng(121)
    d = 3.0
    t = t_axis(d)
    env = np.sin(np.pi * t / d) ** 1.2
    x = lowpass(r.standard_normal(len(t)), 90, 3) * 4.0 * env
    x += np.sin(2 * np.pi * 38 * t) * 0.3 * env
    return normalize(x, 0.7)


# ============================================================ глава 7 — Туманный остров
def sfx_frog():
    """Лягушка в болоте: два-три низких булькающих «ква»."""
    r = np.random.default_rng(131)
    x = np.zeros(int(0.9 * SR))
    for k in range(r.integers(2, 4)):
        d = 0.14
        tt = t_axis(d)
        f = 180 * (1 + 0.4 * np.sin(np.pi * tt / d))
        s = signal.square(2 * np.pi * np.cumsum(f) / SR, 0.4) * np.sin(np.pi * tt / d) ** 1.5
        place(x, bandpass(s, 150, 1200), k * 0.22)
    return normalize(x, 0.45)


def sfx_creak():
    """Скрип корабля: медленное деревянное «ии-и» с дрожью."""
    r = np.random.default_rng(137)
    d = 1.2
    t = t_axis(d)
    f = 240 + 80 * np.sin(2 * np.pi * 0.7 * t) + 30 * r.standard_normal(len(t)).cumsum() / len(t)
    s = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR, 0.2) * (0.5 + 0.5 * (np.sin(2 * np.pi * 23 * t) > 0))
    env = np.sin(np.pi * t / d) ** 1.2
    return normalize(bandpass(s, 300, 2400) * env, 0.5)


def sfx_sail():
    """Хлопок паруса: ветер ударяет в ткань — глухой хлопок и шелест."""
    r = np.random.default_rng(139)
    d = 0.8
    t = t_axis(d)
    pop = lowpass(r.standard_normal(len(t)), 500) * np.exp(-t / 0.05) * 2.0
    rustle = bandpass(r.standard_normal(len(t)), 800, 4000) * np.exp(-t / 0.3) * 0.4
    return normalize(pop + rustle, 0.6)


def sfx_cheer():
    """Праздник: несколько голосов «ура!» и хлопки."""
    r = np.random.default_rng(141)
    d = 1.6
    x = np.zeros(int(d * SR))
    for k in range(5):
        dd = 0.5
        tt = t_axis(dd)
        f = r.uniform(180, 320) * (1 + 0.25 * np.sin(np.pi * tt / dd))
        v = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / dd)
        place(x, bandpass(v, 300, 2500) * 0.4, r.uniform(0.0, 0.5))
    for k in range(10):
        c = highpass(r.standard_normal(int(0.02 * SR)), 1500) * np.exp(-t_axis(0.02) / 0.004)
        place(x, c, r.uniform(0.3, 1.5))
    return normalize(x, 0.6)


def sfx_gust():
    """Порыв ветра на высоте: шум нарастает, свистит в перилах и обрывается."""
    r = np.random.default_rng(151)
    d = 2.4
    t = t_axis(d)
    n = len(t)
    env = np.clip(t / 1.2, 0, 1) ** 2 * np.exp(-np.clip(t - 1.6, 0, None) / 0.3)
    base = bandpass(r.standard_normal(n), 300, 2200) * env
    whistle_f = 1200 + 400 * t + 90 * np.sin(2 * np.pi * 3.0 * t)
    whistle = np.sin(2 * np.pi * np.cumsum(whistle_f) / SR) * 0.08 * env ** 2
    return normalize(base + whistle, 0.6)


def sfx_fire_out():
    """Великий огонь гаснет: тёплый низкий выдох, затихающий треск, лёгкое шипение."""
    r = np.random.default_rng(161)
    d = 3.0
    t = t_axis(d)
    n = len(t)
    whoosh = lowpass(r.standard_normal(n), 400) * np.exp(-t / 0.9) * np.clip(t / 0.15, 0, 1)
    hiss = bandpass(r.standard_normal(n), 2500, 7000) * np.exp(-t / 1.2) * 0.15
    x = whoosh + hiss
    for k in range(14):
        at = r.uniform(0.0, 2.2)
        c = bandpass(r.standard_normal(int(0.015 * SR)), 1500, 5000) * np.exp(-t_axis(0.015) / 0.003) * np.exp(-at / 1.0) * 0.6
        place(x, c, at)
    return normalize(x, 0.6)


def sfx_pull(seed=0):
    """Выдернуть траву с корнем: шорох стеблей, треск рвущихся корешков и мягкий «чпок» земли."""
    r = np.random.default_rng(700 + seed)
    d = 0.5
    n = int(d * SR)
    t = np.arange(n) / SR
    swish_env = np.clip(t / 0.04, 0, 1) * np.exp(-t / 0.16)
    swish = bandpass(r.standard_normal(n), 1200, 6500) * swish_env * 0.35
    x = swish.copy()
    for _ in range(int(r.integers(26, 40))):          # корешки рвутся: густые сухие щелчки
        at = 0.03 + r.exponential(0.05)
        m = int(r.integers(25, 90))
        c = bandpass(r.standard_normal(m), 900, 5000) * np.exp(-np.arange(m) / (m / 4))
        place(x, c * r.uniform(0.15, 0.45), at)
    m = int(0.09 * SR)
    tt = np.arange(m) / SR
    pop = lowpass(r.standard_normal(m), 350) * np.exp(-tt / 0.02) * 1.4
    place(x, pop, r.uniform(0.09, 0.13))
    x *= np.clip((d - t) / 0.05, 0, 1)
    return normalize(x, 0.6)


def main():
    import sys
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:]   # имена эффектов (без sfx_) — сгенерировать только их, без музыки и фона
    if only:
        table = {"thunder0": lambda: sfx_thunder(0), "thunder1": lambda: sfx_thunder(1), "thunder2": lambda: sfx_thunder(2),
                 "radio": sfx_radio, "honk": sfx_honk, "metal": sfx_metal,
                 "wind": sfx_wind, "ice": sfx_ice, "penguin": sfx_penguin, "snore": sfx_snore, "drip": sfx_drip,
                 "step_snow": sfx_step_snow, "lava": sfx_lava, "steam": sfx_steam, "hammer": sfx_hammer,
                 "tortoise": sfx_tortoise, "rumble": sfx_rumble, "frog": sfx_frog, "creak": sfx_creak, "sail": sfx_sail,
                 "cheer": sfx_cheer, "gust": sfx_gust, "fire_out": sfx_fire_out}
        for i in range(4):
            table["step_sand%d" % i] = (lambda k: lambda: sfx_step("sand", k))(i)

        table["chop"] = sfx_chop
        for i in range(3):
            table["pull%d" % i] = (lambda k: lambda: sfx_pull(k))(i)
        table["whoosh"] = sfx_whoosh
        music = {"eye": music_eye, "meeting": music_meeting, "sea": music_sea, "keeper": music_keeper}
        for name in only:
            if name.startswith("music_"):
                music[name[6:]]()
            else:
                write_wav("sfx_" + name, table[name]())
        print("audio:", only)
        return
    sfx = {
        "chop": sfx_chop(), "rock": sfx_rock(), "rustle": sfx_rustle(), "pickup": sfx_pickup(),
        "harvest": sfx_harvest(), "plant": sfx_plant(), "water": sfx_water(), "build": sfx_build(),
        "craft": sfx_craft(), "quest": sfx_quest(), "rare": sfx_rare(), "click": sfx_click(),
        "open": sfx_open(), "blip": sfx_blip(),
        "cluck": sfx_cluck(), "bleat": sfx_bleat(), "squawk": sfx_squawk(), "oink": sfx_oink(), "sleep": sfx_sleep(),
        "shake": sfx_shake(), "thud": sfx_thud(),
        "thunder0": sfx_thunder(0), "thunder1": sfx_thunder(1), "thunder2": sfx_thunder(2),
        "radio": sfx_radio(), "honk": sfx_honk(), "metal": sfx_metal(),
        "wind": sfx_wind(), "ice": sfx_ice(), "penguin": sfx_penguin(), "snore": sfx_snore(), "drip": sfx_drip(),
        "step_snow": sfx_step_snow(), "lava": sfx_lava(), "steam": sfx_steam(), "hammer": sfx_hammer(),
        "tortoise": sfx_tortoise(), "rumble": sfx_rumble(), "frog": sfx_frog(), "creak": sfx_creak(), "sail": sfx_sail(),
        "cheer": sfx_cheer(), "gust": sfx_gust(), "fire_out": sfx_fire_out(), "whoosh": sfx_whoosh(),
    }
    for i in range(4):
        sfx["bird%d" % i] = bird(100 + i)
        sfx["step_sand%d" % i] = sfx_step("sand", i)
        # шаги по траве и удары топора — записи Kenney (tools/import_sounds.py), здесь не синтезируем
        if i < 3:
            sfx["pull%d" % i] = sfx_pull(i)
    for name, x in sfx.items():
        write_wav("sfx_" + name, x)
    amb_ocean()
    amb_night()
    amb_rain()
    music_day()
    music_night()
    music_eye()
    music_meeting()
    music_sea()
    music_keeper()
    print("audio:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
