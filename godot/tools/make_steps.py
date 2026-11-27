"""Soft footfalls for Cold Glitter Creek (the player heard the old ones as clicking: 80 ms bursts of bright noise with
an instant start). Each step is a heel then a toe a few hundredths later, low-passed noise with a gentle 6-9 ms
rise and a smooth fall, no sharp edge anywhere. Writes assets/baked/sound/step_<surface>_<n>.wav (44.1 kHz, 16-bit
stereo, as the rest of the bank). Run: python tools/make_steps.py"""
import numpy as np, wave, os

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'baked', 'sound')

def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR); y = np.zeros_like(x); s = 0.0
    for i in range(len(x)): s = (1 - a) * x[i] + a * s; y[i] = s
    return y

def onepole_hp(x, fc): return x - onepole_lp(x, fc)

def touch(n, rise, fall, lp, hp, rng):
    t = np.arange(n) / SR
    env = np.minimum(1.0, t / rise) ** 2 * np.exp(-np.maximum(0.0, t - rise) / fall)
    x = rng.standard_normal(n)
    x = onepole_lp(onepole_lp(x, lp), lp * 1.4)
    if hp: x = onepole_hp(x, hp)
    return x * env

def step(kind, seed):
    rng = np.random.default_rng(seed)
    p = {"grass": (0.17, 0.007, 0.030, 700, 120, 0.035),   # length, rise, fall, low-pass, high-pass, heel->toe
         "snow":  (0.22, 0.009, 0.045, 1100, 200, 0.045),
         "water": (0.26, 0.012, 0.070, 900, 90, 0.055),
         "wood":  (0.16, 0.006, 0.028, 420, 60, 0.030)}[kind]
    n = int(p[0] * SR)
    heel = touch(n, p[1], p[2], p[3] * (0.9 + 0.2 * rng.random()), p[4], rng)
    toe = touch(n, p[1], p[2] * 0.8, p[3] * 1.15, p[4], rng)
    off = int((p[5] + 0.01 * rng.random()) * SR)
    y = heel.copy(); y[off:] += 0.6 * toe[:n - off]
    if kind == "wood": # (a dull board under the boot: a low body under the touch)
        t = np.arange(n) / SR
        y += 0.5 * np.sin(2 * np.pi * (95 + 15 * rng.random()) * t) * np.minimum(1.0, t / 0.006) ** 2 * np.exp(-t / 0.04)
    fade = int(0.02 * SR); y[-fade:] *= np.linspace(1, 0, fade) ** 2 # (to silence: no edge at the end)
    y = y / (np.max(np.abs(y)) + 1e-9) * 0.063 # (a soft footfall, -24 dBFS at its peak: heard, not a tick)
    return y

def write(path, y):
    s = np.clip(y * 32767, -32768, 32767).astype(np.int16)
    st = np.repeat(s[:, None], 2, axis=1).reshape(-1)
    with wave.open(path, 'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(st.tobytes())

for kind, count in [("grass", 4), ("snow", 3), ("water", 3), ("wood", 3)]:
    for i in range(count):
        write(os.path.join(OUT, f"step_{kind}_{i}.wav"), step(kind, {"grass": 11, "snow": 23, "water": 37, "wood": 53}[kind] * 100 + i))
print("wrote soft footfalls")
