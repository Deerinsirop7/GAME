#!/usr/bin/env python3
"""Синтез музыки и звуковых эффектов для Pixel Pet (numpy -> WAV).

Запуск:  python tools/gen_audio.py
Всё генерируется детерминированно, внешние сэмплы не нужны.
"""
import os
import wave
import numpy as np

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


def write(name, x, vol=0.9):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * vol
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(ROOT, exist_ok=True)
    with wave.open(os.path.join(ROOT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def osc(freq, dur, kind="tri", duty=0.5):
    t = t_(dur)
    ph = (np.cumsum(np.full_like(t, 1.0) * freq) / SR) if np.isscalar(freq) else np.cumsum(freq) / SR
    ph = ph % 1.0
    if kind == "sine":
        return np.sin(2 * np.pi * ph)
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "saw":
        return 2 * ph - 1
    raise ValueError(kind)


def env(n, a=0.005, d=0.1, s=0.6, r=0.1, dur=None):
    """ADSR по числу сэмплов n."""
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1)),
        np.linspace(1, s, max(d_n, 1)),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    return e[:n] if len(e) >= n else np.pad(e, (0, n - len(e)))


def lowpass(x, k=0.2):
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += k * (x[i] - acc)
        y[i] = acc
    return y


def noise(dur, seed=0):
    return np.random.default_rng(seed).uniform(-1, 1, int(SR * dur))


# ---------------------------------------------------------------- музыка
def render_song(bpm, chords, melody, bass_pattern, lead="tri", arp_kind="square", pad=False, seed=1, bars_repeat=2):
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * len(chords) * bars_repeat
    n_total = int(total * SR)
    out = np.zeros(n_total + SR * 2)

    def add(start_s, sig, gain):
        i = int(start_s * SR)
        out[i:i + len(sig)] += sig * gain

    rng = np.random.default_rng(seed)
    for rep in range(bars_repeat):
        for bi, chord in enumerate(chords):
            t0 = (rep * len(chords) + bi) * bar
            root = chord[0]
            # бас
            for step, dur_b in bass_pattern:
                d = dur_b * beat
                s = osc(midi(root - 12), d * 0.95, "tri")
                add(t0 + step * beat, s * env(len(s), 0.005, 0.1, 0.7, 0.08), 0.35)
            # арпеджио восьмыми
            for k in range(8):
                note = chord[[0, 1, 2, 1][k % 4]] + (12 if k >= 4 and rep % 2 else 0)
                d = beat / 2
                s = osc(midi(note + 12), d * 0.9, arp_kind, duty=0.25)
                s = s * env(len(s), 0.003, 0.08, 0.2, 0.05)
                add(t0 + k * d, s, 0.07)
            if pad:
                for note in chord:
                    s = osc(midi(note), bar, "sine") * env(int(bar * SR), 0.4, 0.3, 0.7, 0.6)
                    add(t0, s, 0.08)
            # лёгкий шейкер
            for k in range(8):
                s = noise(0.03, seed=int(rng.integers(1e6))) * env(int(0.03 * SR), 0.001, 0.02, 0.1, 0.005)
                add(t0 + k * beat / 2, s, 0.03 if k % 2 else 0.05)
        # мелодия: список (доля_от_начала_цикла, длительность_в_долях, midi или None)
    cycle = bar * len(chords)
    for rep in range(bars_repeat):
        for start_b, dur_b, note in melody:
            if note is None:
                continue
            d = dur_b * beat
            s = osc(midi(note + (12 if rep == 1 and lead == "tri" else 0)), d, lead)
            s = s * env(len(s), 0.01, 0.12, 0.55, min(0.12, d * 0.4))
            # лёгкое вибрато для длинных нот
            add(rep * cycle + start_b * beat, s, 0.16)
    out = lowpass(out, 0.35)
    # хвост заворачиваем в начало — петля без щелчка
    tail = out[n_total:]
    out = out[:n_total]
    out[:len(tail)] += tail
    return out


def make_melody(chords, seed, density=0.7, octave=72):
    """Пентатоническая мелодия, опирающаяся на аккордовые тоны на сильных долях."""
    rng = np.random.default_rng(seed)
    penta = [0, 2, 4, 7, 9]
    scale = [octave - 12 + p for p in penta] + [octave + p for p in penta] + [octave + 12]
    mel = []
    beat = 0.0
    prev = scale[5]
    for chord in chords:
        for k in range(4):
            pattern = rng.choice(["q", "ee", "h", "e_"], p=[0.35, 0.35, 0.15, 0.15])
            if pattern == "h" and k % 2 == 1:
                pattern = "q"
            if pattern == "q":
                durs = [1.0]
            elif pattern == "ee":
                durs = [0.5, 0.5]
            elif pattern == "h":
                durs = [2.0]
            else:
                durs = [0.5, -0.5]
            for d in durs:
                if d < 0:
                    beat += -d
                    continue
                if k == 0 or rng.random() < 0.3:
                    cands = [n for n in scale if (n % 12) in [c % 12 for c in chord]]
                else:
                    cands = scale
                cands = sorted(cands, key=lambda n: abs(n - prev))[:3]
                note = int(rng.choice(cands))
                if rng.random() < density:
                    mel.append((beat, d, note))
                prev = note
                beat += d
            if pattern == "h":
                break
        beat = round(beat / 4 + 0.4999) * 4 if beat % 4 else beat
    return mel


def gen_music():
    C, Am, F, G = [60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]
    Em, Dm = [52, 55, 59], [50, 53, 57]
    day_chords = [C, Am, F, G, C, Em, F, G]
    mel = make_melody(day_chords, seed=4, density=0.8)
    day = render_song(104, day_chords, mel, [(0, 1), (1.5, 0.5), (2, 1), (3, 1)], lead="tri", arp_kind="square", seed=2)
    write("music_day.wav", day, 0.7)

    night_chords = [Am, F, C, G, Am, Dm, F, Em]
    mel_n = make_melody(night_chords, seed=9, density=0.55, octave=69)
    night = render_song(78, night_chords, mel_n, [(0, 2), (2, 2)], lead="sine", arp_kind="tri", pad=True, seed=3)
    write("music_night.wav", night, 0.6)


# ---------------------------------------------------------------- эффекты
def seq(notes, kind="square", step=0.07, duty=0.5, rel=0.05):
    parts = []
    for n in notes:
        s = osc(midi(n), step, kind, duty)
        parts.append(s * env(len(s), 0.002, 0.03, 0.6, rel))
    return np.concatenate(parts)


def sweep(f0, f1, dur, kind="square", duty=0.5):
    f = np.geomspace(f0, f1, int(SR * dur))
    return osc(f, dur, kind, duty)


def gen_sfx():
    write("sfx_click.wav", seq([84], "square", 0.03, 0.25), 0.4)
    write("sfx_coin.wav", seq([83, 88], "square", 0.07, 0.25), 0.5)
    write("sfx_buy.wav", seq([72, 76, 79, 84, 88], "square", 0.06, 0.25), 0.55)
    write("sfx_error.wav", seq([55, 50], "tri", 0.1), 0.5)
    # хруст: несколько шумовых всплесков
    parts = []
    for i in range(4):
        n = noise(0.05, seed=i) * env(int(0.05 * SR), 0.001, 0.03, 0.2, 0.01)
        parts += [lowpass(n, 0.5), np.zeros(int(0.04 * SR))]
    write("sfx_eat.wav", np.concatenate(parts), 0.5)
    b = sweep(200, 700, 0.12, "tri")
    b2 = sweep(250, 800, 0.12, "tri")
    write("sfx_play.wav", np.concatenate([b * env(len(b), 0.002, 0.05, 0.5, 0.05), np.zeros(800), b2 * env(len(b2), 0.002, 0.05, 0.5, 0.05)]), 0.5)
    parts = []
    rng = np.random.default_rng(3)
    for i in range(7):
        f = rng.uniform(500, 1100)
        s = sweep(f, f * 1.8, 0.05, "sine")
        parts += [s * env(len(s), 0.002, 0.02, 0.5, 0.02), np.zeros(int(rng.uniform(0.01, 0.04) * SR))]
    write("sfx_wash.wav", np.concatenate(parts), 0.5)
    s = sweep(600, 300, 0.6, "sine")
    write("sfx_sleep.wav", s * env(len(s), 0.05, 0.2, 0.5, 0.3), 0.4)
    write("sfx_pet.wav", seq([79, 84, 91], "sine", 0.09, rel=0.08), 0.45)
    write("sfx_levelup.wav", seq([72, 76, 79, 84, 79, 84, 88], "square", 0.08, 0.25), 0.5)
    # голоса питомцев
    bark = sweep(420, 300, 0.12, "saw")
    bark = lowpass(bark * env(len(bark), 0.005, 0.05, 0.4, 0.04), 0.3) + 0.3 * lowpass(noise(0.12, 5), 0.3) * env(len(bark), 0.002, 0.05, 0.2, 0.03)
    write("pet_dog.wav", np.concatenate([bark, np.zeros(1500), bark]), 0.55)
    f = np.concatenate([np.geomspace(500, 900, int(0.15 * SR)), np.geomspace(900, 600, int(0.25 * SR))])
    meow = osc(f, len(f) / SR, "saw")
    write("pet_cat.wav", lowpass(meow * env(len(meow), 0.03, 0.1, 0.6, 0.12), 0.25), 0.5)
    chirp = np.concatenate([sweep(1800, 3000, 0.06, "sine"), np.zeros(600), sweep(2000, 3400, 0.05, "sine"), np.zeros(400), sweep(2600, 1800, 0.08, "sine")])
    write("pet_parrot.wav", chirp * env(len(chirp), 0.002, 0.05, 0.7, 0.03), 0.4)
    blub = np.concatenate([sweep(300, 700, 0.07, "sine"), np.zeros(1500), sweep(350, 800, 0.06, "sine")])
    write("pet_fish.wav", blub * env(len(blub), 0.002, 0.03, 0.6, 0.03), 0.5)


if __name__ == "__main__":
    gen_sfx()
    gen_music()
    print("done ->", os.path.normpath(ROOT))
