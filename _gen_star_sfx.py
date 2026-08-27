import wave, struct, math

SR = 44100

PARTIALS = [
    (1.00, 1.00, 6.0),
    (2.76, 0.55, 9.0),
    (5.40, 0.30, 16.0),
    (8.93, 0.14, 24.0),
]

def note(freq, dur, amp=1.0):
    n = int(SR * dur)
    out = [0.0] * n
    atk = int(SR * 0.002)
    for i in range(n):
        t = i / SR
        s = 0.0
        for ratio, pa, dec in PARTIALS:
            s += pa * math.sin(2 * math.pi * freq * ratio * t) * math.exp(-dec * t)
        env = min(1.0, i / atk) if atk else 1.0
        out[i] = s * env * amp
    return out

def mix_at(buf, src, start):
    for i, v in enumerate(src):
        j = start + i
        if j < len(buf):
            buf[j] += v

def norm_write(path, buf, peak=0.9):
    m = max(1e-9, max(abs(v) for v in buf))
    g = peak / m
    with wave.open(path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for v in buf:
            s = int(max(-1.0, min(1.0, v * g)) * 32767)
            frames += struct.pack("<hh", s, s)
        w.writeframes(bytes(frames))
    print("wrote", path)

C7, E7, G7, C8 = 2093.0, 2637.0, 3136.0, 4186.0

b1 = [0.0] * int(SR * 0.55)
mix_at(b1, note(C7, 0.55), 0)
norm_write("star_ding.wav", b1)

b2 = [0.0] * int(SR * 0.6)
for k, f in enumerate([C7, E7, G7]):
    mix_at(b2, note(f, 0.45, amp=0.9), int(SR * 0.045 * k))
norm_write("star_rise.wav", b2)

b3 = [0.0] * int(SR * 0.65)
for k, f in enumerate([C7, E7, G7, C8]):
    mix_at(b3, note(f, 0.42, amp=0.85), int(SR * 0.038 * k))
norm_write("star_sparkle.wav", b3)
