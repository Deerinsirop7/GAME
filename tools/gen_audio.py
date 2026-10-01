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


def soft_note(freq, dur, kind="kalimba"):
    """Мягкие тембры: kalimba (щипок), bell (музыкальная шкатулка), pad (подушка)."""
    t = t_(dur)
    if kind == "kalimba":
        x = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t * 18)
        e = np.exp(-t * 3.2) * np.minimum(1.0, t / 0.004)
    elif kind == "bell":
        x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t * 6)
        e = np.exp(-t * 2.2) * np.minimum(1.0, t / 0.003)
    else:  # pad
        x = 0.5 * np.sin(2 * np.pi * freq * t) + 0.5 * np.sin(2 * np.pi * freq * 1.004 * t) + 0.15 * np.sin(2 * np.pi * freq * 2 * t)
        e = np.minimum(1.0, t / 0.8) * np.minimum(1.0, (dur - t) / 0.9)
    return x * e


def render_cozy(bpm, chords, seed, lead="kalimba", bars_per_chord=1, octave=72, density=0.55):
    """Неспешная пьеса без петли: подушка, тихий бас, редкая мелодия. Заканчивается затуханием."""
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * len(chords) * bars_per_chord + 4.0
    out = np.zeros(int(total * SR) + SR)

    def add(t0, sig, g):
        i = int(t0 * SR)
        out[i:i + len(sig)] += sig[: max(0, len(out) - i)] * g

    penta = [0, 2, 4, 7, 9]
    scale = [octave - 12 + p for p in penta] + [octave + p for p in penta]
    prev = scale[5]
    for ci, chord in enumerate(chords):
        t0 = ci * bar * bars_per_chord
        dur = bar * bars_per_chord
        for n in chord:
            add(t0, soft_note(midi(n), dur + 0.6, "pad"), 0.05)
        for k in range(bars_per_chord):
            add(t0 + k * bar, soft_note(midi(chord[0] - 12), beat * 2.5, "kalimba"), 0.16)
            add(t0 + k * bar + beat * 2, soft_note(midi(chord[2] - 12), beat * 2, "kalimba"), 0.09)
            # редкие арпеджио-капли
            for j in range(4):
                if rng.random() < 0.45:
                    n = chord[j % 3] + 12
                    add(t0 + k * bar + j * beat + beat / 2, soft_note(midi(n), 1.2, "bell"), 0.035)
            # мелодия
            pos = 0.0
            while pos < 4.0:
                d = float(rng.choice([1.0, 1.0, 2.0, 0.5, 1.5]))
                if rng.random() < density:
                    cands = sorted(scale, key=lambda n: abs(n - prev))[:4]
                    if pos == 0.0:
                        cands = [n for n in scale if n % 12 in [c % 12 for c in chord]] or cands
                        cands = sorted(cands, key=lambda n: abs(n - prev))[:2]
                    note = int(rng.choice(cands))
                    prev = note
                    add(t0 + k * bar + pos * beat, soft_note(midi(note), min(d * beat + 0.8, 2.5), lead), 0.12)
                pos += d
    out = lowpass(out, 0.22)
    fade = int(3.0 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def gen_music():
    C, Am, F, G = [60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]
    Em, Dm, Fm7 = [52, 55, 59], [50, 53, 57], [53, 57, 60]
    write("music_day_1.wav", render_cozy(72, [C, Am, F, G, C, Em, F, G, F, G, C, C], seed=4), 0.55)
    write("music_day_2.wav", render_cozy(68, [F, C, Dm, G, F, C, G, C, Am, F, G, C], seed=11, octave=74), 0.55)
    write("music_night_1.wav", render_cozy(58, [Am, F, C, G, Am, Dm, F, Em, Am, Am], seed=9, lead="bell", octave=69, density=0.4), 0.5)
    write("music_night_2.wav", render_cozy(56, [F, Em, Dm, C, F, G, C, C], seed=21, lead="bell", octave=72, density=0.35), 0.5)


def gen_ambient():
    rng = np.random.default_rng(1)
    dur = 30.0
    n = int(SR * dur)
    # день: лёгкий ветер + редкие птицы
    wind = lowpass(lowpass(noise(dur, 2), 0.02), 0.05) * 0.6
    day = wind.copy()
    for _ in range(14):
        t0 = rng.uniform(0.5, dur - 1.5)
        f = rng.uniform(2200, 3600)
        for k in range(int(rng.integers(2, 5))):
            seg = sweep(f * rng.uniform(0.9, 1.1), f * rng.uniform(1.15, 1.5), 0.07, "sine")
            seg = seg * env(len(seg), 0.005, 0.03, 0.5, 0.03)
            i = int((t0 + k * 0.11) * SR)
            day[i:i + len(seg)] += seg * 0.22
    write("ambient_day.wav", _loopable(day), 0.35)
    # ночь: сверчки
    night = wind * 0.5
    t = t_(dur)
    for base, rate, ph in [(4400, 3.1, 0.0), (4700, 2.6, 1.3)]:
        chirp = (np.sin(2 * np.pi * rate * t + ph) > 0.55).astype(float)
        trill = (np.sin(2 * np.pi * 38 * t) > 0).astype(float)
        night += np.sin(2 * np.pi * base * t) * chirp * trill * 0.12
    write("ambient_night.wav", _loopable(night), 0.25)
    # дождь
    rain = lowpass(noise(dur, 7), 0.35) * 0.5 + lowpass(noise(dur, 8), 0.08) * 0.8
    for _ in range(220):
        i = int(rng.uniform(0, n - 400))
        rain[i:i + 300] += noise(300 / SR, int(rng.integers(1e6))) * np.linspace(1, 0, 300) * 0.4
    write("ambient_rain.wav", _loopable(rain), 0.4)


def _loopable(x, fade_s=1.5):
    f = int(fade_s * SR)
    head = x[:f].copy()
    x = x[f:]
    x[-f:] = x[-f:] * np.linspace(1, 0, f) + head * np.linspace(0, 1, f)
    return x


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
    rng2 = np.random.default_rng(9)
    parts = []
    for i in range(10):
        f = rng2.uniform(1800, 3200)
        s_ = sweep(f, f * 0.8, 0.02, "sine") * env(int(0.02 * SR), 0.001, 0.01, 0.4, 0.008)
        parts += [s_, np.zeros(int(rng2.uniform(0.01, 0.03) * SR))]
    write("sfx_pour.wav", np.concatenate(parts), 0.4)
    sc = lowpass(noise(0.25, 31), 0.25) * env(int(0.25 * SR), 0.05, 0.1, 0.6, 0.08)
    write("sfx_scrub.wav", sc, 0.3)
    parts = []
    for i in range(6):
        n_ = lowpass(noise(0.06, 40 + i), 0.5) * env(int(0.06 * SR), 0.002, 0.03, 0.3, 0.02)
        parts += [n_, np.zeros(int(0.025 * SR))]
    write("sfx_shake.wav", np.concatenate(parts), 0.45)
    b_ = sweep(180, 90, 0.08, "sine")
    write("sfx_bounce.wav", b_ * env(len(b_), 0.002, 0.04, 0.3, 0.03), 0.5)
    bell = soft_note(midi(88), 0.5, "bell") + 0.6 * soft_note(midi(95), 0.5, "bell")
    write("sfx_bell.wav", bell, 0.4)
    t = t_(0.9)
    purr = np.sin(2 * np.pi * 26 * t) * lowpass(noise(0.9, 50), 0.08) * env(len(t), 0.1, 0.2, 0.8, 0.25)
    write("sfx_purr.wav", purr, 0.5)
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
    gen_ambient()
    print("done ->", os.path.normpath(ROOT))
