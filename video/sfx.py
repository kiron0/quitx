import json
import os
import subprocess
import sys
import wave

import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 48000
rng = np.random.default_rng(7)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def env(n, attack, release, shape=4.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.exp(-shape * t / max(release, 1e-4))
    return a * r


def band(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x)


def lowpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def highpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def note(freq, seconds, decay, partials=((1, 1.0), (2, 0.35), (3, 0.12), (4.2, 0.06))):
    t = t_axis(seconds)
    y = sum(a * np.sin(2 * np.pi * freq * m * t) * np.exp(-t * (decay * (1 + 0.6 * m))) for m, a in partials)
    return y * np.clip(t / 0.004, 0, 1)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def click():
    n = int(0.05 * SR)
    noise = highpass(rng.standard_normal(n), 1800) * env(n, 0.0005, 0.006, 1.0)
    body = np.sin(2 * np.pi * 1450 * t_axis(0.05)) * env(n, 0.0005, 0.012, 1.0)
    thump = np.sin(2 * np.pi * 180 * t_axis(0.05)) * env(n, 0.001, 0.02, 1.0)
    return 0.35 * noise + 0.25 * body + 0.35 * thump


def tick():
    return 0.3 * note(2637, 0.08, 60, ((1, 1.0), (2.01, 0.2)))


def sweep(seconds, f0, f1, gain):
    n = int(seconds * SR)
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    steps = 24
    edges = np.linspace(0, n, steps + 1, dtype=int)
    for i in range(steps):
        f = f0 * (f1 / f0) ** (i / (steps - 1))
        seg = band(noise, max(60, f * 0.6), min(SR / 2 - 100, f * 1.6))
        out[edges[i]:edges[i + 1]] = seg[edges[i]:edges[i + 1]]
    shape = np.sin(np.linspace(0, np.pi, n)) ** 1.6
    return gain * out * shape


def whoosh():
    return sweep(0.42, 350, 2600, 0.22)


def swoosh():
    return sweep(0.36, 2400, 420, 0.18)


PENTA = [88, 86, 83, 81, 79, 76, 74, 71, 69, 67, 64, 62, 59, 57]


def pop(k):
    f = hz(PENTA[k % len(PENTA)])
    t = t_axis(0.18)
    glide = f * (1 + 0.18 * np.exp(-t * 60))
    phase = 2 * np.pi * np.cumsum(glide) / SR
    y = np.sin(phase) * np.exp(-t * 26) + 0.25 * np.sin(2 * phase) * np.exp(-t * 40)
    return 0.16 * y * np.clip(t / 0.002, 0, 1)


def chime(notes, gap, decay, gain):
    parts = [(gap * i, note(hz(m), 1.8, decay)) for i, m in enumerate(notes)]
    n = int((gap * len(notes) + 1.8) * SR)
    out = np.zeros(n)
    for start, y in parts:
        s = int(start * SR)
        out[s:s + len(y)] += y
    return gain * out


def success():
    return chime([76, 83, 88], 0.07, 3.0, 0.14)


def notify():
    return chime([79, 84], 0.12, 2.2, 0.17)


def download():
    seconds = 2.2
    t = t_axis(seconds)
    rise = np.sin(2 * np.pi * np.cumsum(220 + 220 * (t / seconds) ** 2) / SR)
    shimmer = band(rng.standard_normal(len(t)), 3000, 9000) * 0.25
    shape = (t / seconds) ** 1.5 * np.clip((seconds - t) / 0.12, 0, 1)
    return 0.06 * (rise + shimmer) * shape


def swell():
    seconds = 1.1
    t = t_axis(seconds)
    n = band(rng.standard_normal(len(t)), 1500, 12000)
    return 0.12 * n * (t / seconds) ** 3


def logo():
    chord = [57, 64, 69, 71, 73, 76, 81]
    out = np.zeros(int(3.2 * SR))
    for i, m in enumerate(chord):
        y = note(hz(m), 3.2, 1.1 + 0.15 * i, ((1, 1.0), (2, 0.25), (3, 0.08)))
        s = int(i * 0.018 * SR)
        out[s:] += y[: len(out) - s]
    sub = np.sin(2 * np.pi * hz(45) * t_axis(3.2)) * np.exp(-t_axis(3.2) * 1.4)
    return 0.07 * out + 0.12 * sub


def bed(total):
    t = t_axis(total)
    chords = [[45, 52, 57, 59, 64], [41, 48, 53, 57, 64], [43, 50, 55, 59, 62], [45, 52, 57, 61, 64]]
    bar = total / len(chords)
    out = np.zeros(len(t))
    for c, chord in enumerate(chords):
        s0, s1 = int(c * bar * SR), int(min(total, (c + 1) * bar + 0.8) * SR)
        seg_t = t[: s1 - s0]
        seg = np.zeros(len(seg_t))
        for m in chord:
            for d in (-0.08, 0.08):
                f = hz(m) * 2 ** (d / 12)
                seg += np.sin(2 * np.pi * f * seg_t + rng.uniform(0, 6.28))
        shape = np.clip(seg_t / 0.9, 0, 1) * np.clip((seg_t[-1] - seg_t) / 0.9, 0, 1)
        out[s0:s1] += seg * shape
    out = lowpass(out, 1400) * 0.012
    beat = 60 / 96
    arp = [69, 76, 81, 83, 81, 76]
    k = 0
    pos = 2.2
    while pos < total - 2.6:
        y = note(hz(arp[k % len(arp)] + 0), 0.6, 7.0, ((1, 1.0), (2, 0.15)))
        s = int(pos * SR)
        out[s:s + len(y)] += 0.018 * y[: max(0, len(out) - s)]
        k += 1
        pos += beat / 2
    fade = np.clip(t / 1.5, 0, 1) * np.clip((total - t) / 1.8, 0, 1)
    return out * fade


def reverb(x, seconds=1.1, mix=0.18):
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * 5.5)
    ir = lowpass(ir, 6000)
    wet = fftconvolve(x, ir)[: len(x)]
    wet *= np.max(np.abs(x)) / (np.max(np.abs(wet)) + 1e-9)
    return (1 - mix) * x + mix * wet


HERE = os.path.dirname(os.path.abspath(__file__))
LASER_SOURCES = [os.path.join(HERE, "sounds", "quit-all.aiff"), os.path.join(HERE, "..", "Support", "Sounds", "quit-all.aiff")]
_laser = None


def laser():
    global _laser
    if _laser is None:
        path = next((p for p in LASER_SOURCES if os.path.exists(p)), None)
        if path is None:
            _laser = sweep(0.3, 3000, 300, 0.2)
        else:
            raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
            _laser = np.frombuffer(raw, dtype="<f4").astype(float) * 0.85
    return _laser


def key():
    n = int(0.06 * SR)
    thock = np.sin(2 * np.pi * 140 * t_axis(0.06)) * env(n, 0.001, 0.03, 1.0)
    clack = highpass(rng.standard_normal(n), 2500) * env(n, 0.0005, 0.008, 1.0)
    return 0.3 * thock + 0.18 * clack


def zap():
    t = t_axis(0.25)
    f = 900 * np.exp(-t * 9) + 180
    y = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * np.exp(-t * 14)
    return 0.05 * lowpass(y, 3500)


def shimmer():
    return chime([84, 88, 91, 96], 0.05, 4.0, 0.08)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def lock():
    return mix(0.6 * click(), chime([67, 74], 0.06, 6.0, 0.1))


def blip():
    return 0.12 * note(1320, 0.12, 30, ((1, 1.0), (2, 0.1)))


def alarm():
    out = np.zeros(int(0.7 * SR))
    for k in range(3):
        y = 0.07 * note(hz(81), 0.2, 18, ((1, 1.0), (3, 0.2)))
        s0 = int(k * 0.16 * SR)
        out[s0:s0 + len(y)] += y[: len(out) - s0]
    return out


def sleep_tone():
    t = t_axis(1.6)
    y = sum(np.sin(2 * np.pi * hz(m) * t) for m in (57, 64, 69))
    return 0.05 * y * np.clip(t / 0.05, 0, 1) * np.exp(-t * 1.6) * (1 - t / 1.6)


def wake():
    return chime([69, 73, 76, 81], 0.09, 2.5, 0.1)


def glass():
    return mix(chime([88, 95, 100], 0.03, 5.0, 0.07), sweep(0.4, 4000, 9000, 0.05))


SOUNDS = {
    "laser": lambda a: laser(), "key": lambda a: key(), "zap": lambda a: zap(), "shimmer": lambda a: shimmer(),
    "lock": lambda a: lock(), "blip": lambda a: blip(), "alarm": lambda a: alarm(), "sleep": lambda a: sleep_tone(),
    "wake": lambda a: wake(), "glass": lambda a: glass(),
    "click": lambda a: click(), "tick": lambda a: tick(), "whoosh": lambda a: whoosh(), "swoosh": lambda a: swoosh(),
    "pop": lambda a: pop(a), "success": lambda a: success(), "notify": lambda a: notify(),
    "download": lambda a: download(), "swell": lambda a: swell(), "logo": lambda a: logo(),
}

PAN = {"laser": 0.2, "click": 0.15, "tick": 0.2, "pop": 0.25, "notify": 0.3, "whoosh": 0.1, "swoosh": -0.1}


def main():
    events = json.load(open(sys.argv[1]))
    total = float(sys.argv[2])
    out_path = sys.argv[3]
    n = int(total * SR)
    left = np.zeros(n)
    right = np.zeros(n)
    b = bed(total)
    left += b
    right += np.roll(b, 240)
    for ev in events:
        start, name = ev[0], ev[1]
        arg = ev[2] if len(ev) > 2 else 0
        y = SOUNDS[name](arg)
        s = int(start * SR)
        if s >= n:
            continue
        y = y[: n - s]
        p = PAN.get(name, 0.0)
        if name == "pop":
            p = -0.35 + 0.7 * ((arg % 14) / 13)
        left[s:s + len(y)] += y * np.sqrt((1 - p) / 2) * 1.414
        right[s:s + len(y)] += y * np.sqrt((1 + p) / 2) * 1.414
    left, right = reverb(left), reverb(right)
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)))
    gain = 0.89 / peak
    stereo = np.stack([left * gain, right * gain], axis=1)
    stereo = np.tanh(stereo * 1.1) / np.tanh(1.1)
    pcm = (stereo * 32767).astype("<i2")
    with wave.open(out_path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    main()
