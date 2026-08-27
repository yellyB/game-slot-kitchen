import wave, struct, math

SR = 44100

# 글로켄슈필: 금속 막대 타격음. 순음에 가깝되 비조화(inharmonic) 고배음이
# 짧게 반짝이며 감쇠. (막대 자유모드 비율 1, 2.76, 5.40, 8.93 근사)
PARTIALS = [
    (1.00, 1.00, 6.0),    # (배음비, 진폭, 감쇠율/초) 기음: 오래 남음
    (2.76, 0.55, 9.0),    # 금속 반짝임
    (5.40, 0.30, 16.0),   # 고역 쨍(빨리 사라짐)
    (8.93, 0.14, 24.0),
]

def note(freq, dur, amp=1.0):
    n = int(SR * dur)
    out = [0.0] * n
    atk = int(SR * 0.002)   # 2ms 어택(딱 치는 느낌)
    for i in range(n):
        t = i / SR
        s = 0.0
        for ratio, pa, dec in PARTIALS:
            s += pa * math.sin(2 * math.pi * freq * ratio * t) * math.exp(-dec * t)
        env = min(1.0, i / atk) if atk else 1.0   # 어택 램프
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

# 음정(글로켄슈필은 고음역): C7=2093, E7=2637, G7=3136, C8=4186
C7, E7, G7, C8 = 2093.0, 2637.0, 3136.0, 4186.0

# 후보 1: 단발 별 딩 (짧고 맑게)
b1 = [0.0] * int(SR * 0.55)
mix_at(b1, note(C7, 0.55), 0)
norm_write("star_ding.wav", b1)

# 후보 2: 3음 상승 반짝임 (도-미-솔, 아주 빠르게)
b2 = [0.0] * int(SR * 0.6)
for k, f in enumerate([C7, E7, G7]):
    mix_at(b2, note(f, 0.45, amp=0.9), int(SR * 0.045 * k))
norm_write("star_rise.wav", b2)

# 후보 3: 4음 상승 + 옥타브 반짝 (도-미-솔-도', 별 우수수 느낌)
b3 = [0.0] * int(SR * 0.65)
for k, f in enumerate([C7, E7, G7, C8]):
    mix_at(b3, note(f, 0.42, amp=0.85), int(SR * 0.038 * k))
norm_write("star_sparkle.wav", b3)
