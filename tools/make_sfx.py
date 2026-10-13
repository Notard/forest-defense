"""효과음을 파이썬으로 합성해 assets/audio/*.wav로 저장한다 (plan.md 8단계). 외부 음원을 쓰지 않는다.

    python tools/make_sfx.py

22,050 Hz · 모노 · 16비트 WAV. 모든 소리는 앞뒤를 짧게 페이드해 딸깍 소리를 없애고 최대 -3 dB로 맞춘다.
같은 결과가 나오도록 잡음은 고정 시드로 만든다.
"""
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
RATE = 22050
rng = np.random.default_rng(7)


def t(seconds: float) -> np.ndarray:
    return np.arange(int(RATE * seconds)) / RATE


def env(n: int, attack: float = 0.005, decay: float = 8.0) -> np.ndarray:
    """짧게 올라갔다 지수로 사라지는 크기."""
    x = np.arange(n) / RATE
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x * decay)


def sweep(f0: float, f1: float, seconds: float) -> np.ndarray:
    """주파수가 f0 → f1로 미끄러지는 사인파."""
    x = t(seconds)
    f = f0 + (f1 - f0) * x / seconds
    return np.sin(2 * np.pi * np.cumsum(f) / RATE)


def tone(freq: float, seconds: float, partials=(1.0,), weights=(1.0,)) -> np.ndarray:
    x = t(seconds)
    return sum(w * np.sin(2 * np.pi * freq * p * x) for p, w in zip(partials, weights))


def noise(seconds: float) -> np.ndarray:
    return rng.uniform(-1, 1, int(RATE * seconds))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    """한 극 저역 통과 (부드러운 잡음용)."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    prev = 0.0
    for i, v in enumerate(x):
        prev = (1 - a) * v + a * prev
        y[i] = prev
    return y


def pad(x: np.ndarray, seconds: float) -> np.ndarray:
    n = int(RATE * seconds)
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def notes(freqs, each: float, gap: float, decay: float, bell=False) -> np.ndarray:
    total = gap * (len(freqs) - 1) + each
    out = np.zeros(int(RATE * total))
    for i, f in enumerate(freqs):
        s = tone(f, each, (1, 2, 3), (1, 0.35, 0.15) if not bell else (1, 0.5, 0.25)) * env(int(RATE * each), 0.004, decay)
        start = int(RATE * gap * i)
        out[start:start + len(s)] += s
    return out


# ── 소리 정의 ─────────────────────────────────────────
def pickup():  # 도토리 줍기: 맑은 "띠링" 두 음
    return notes([1318.5, 1975.5], 0.22, 0.07, 14, bell=True)


def place():  # 동물 놓기: 부드러운 "퐁"
    n = int(RATE * 0.16)
    body = sweep(260, 120, 0.16) * env(n, 0.003, 22)
    click = lowpass(noise(0.16), 2500) * env(n, 0.001, 90) * 0.6
    return body + click


def shot():  # 여우불 발사: "화르륵" 위로
    n = int(RATE * 0.22)
    whoosh = lowpass(noise(0.22), 1800) * env(n, 0.02, 12)
    rise = sweep(300, 760, 0.22) * env(n, 0.01, 14) * 0.5
    return whoosh * 1.2 + rise


def hit():  # 여우불 명중: 짧은 "툭"
    n = int(RATE * 0.12)
    return lowpass(noise(0.12), 1200) * env(n, 0.001, 40) * 1.4 + tone(170, 0.12) * env(n, 0.001, 30) * 0.7


def slime_die():  # 몬스터 쓰러짐: 출렁이며 내려가는 "뾰옹"
    x = t(0.38)
    f = 620 * np.exp(-x * 4) + 140 + 30 * np.sin(2 * np.pi * 18 * x)
    s = np.sin(2 * np.pi * np.cumsum(f) / RATE)
    return s * env(len(x), 0.005, 7)


def bite():  # 갉아먹기: "냠" 두 번
    out = np.zeros(int(RATE * 0.18))
    for start in (0.0, 0.08):
        n = int(RATE * 0.07)
        s = lowpass(noise(0.07), 900) * env(n, 0.002, 45) * 1.6 + tone(120, 0.07) * env(n, 0.002, 40) * 0.5
        i = int(RATE * start)
        out[i:i + n] += s
    return out


def boom():  # 스컨크 폭발: 낮은 "펑" + "푸슈우"
    n = int(RATE * 0.9)
    low = sweep(90, 40, 0.9) * env(n, 0.002, 5)
    crack = lowpass(noise(0.9), 1400) * env(n, 0.001, 9) * 1.3
    hiss = lowpass(noise(0.9), 4000) * env(n, 0.08, 3.5) * 0.35
    return low * 1.2 + crack + hiss


def log_roll():  # 통나무 굴러감: "드르르르"
    x = t(0.9)
    rumble = lowpass(noise(0.9), 300) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * x))
    knock = lowpass(noise(0.9), 900) * (np.sin(2 * np.pi * 7 * x) > 0.85) * 0.8
    fade = np.clip((0.9 - x) / 0.25, 0, 1) * np.clip(x / 0.04, 0, 1)
    return (rumble * 2.2 + knock) * fade


def warning():  # 큰 무리 경고: 두 음 뿔피리 두 번
    out = np.zeros(int(RATE * 1.15))
    for i, f in enumerate([440, 330, 440, 330]):
        n = int(RATE * 0.26)
        s = tone(f, 0.26, (1, 2, 3, 4), (1, 0.5, 0.3, 0.15))
        e = np.clip(np.arange(n) / (RATE * 0.02), 0, 1) * np.clip((n - np.arange(n)) / (RATE * 0.05), 0, 1)
        start = int(RATE * 0.28 * i)
        out[start:start + n] += s * e
    return out


def win():  # 클리어: 올라가는 종소리
    return pad(notes([523.25, 659.25, 783.99, 1046.5], 0.6, 0.13, 4.5, bell=True), 1.3)


def lose():  # 게임오버: 내려가는 세 음
    return pad(notes([392.0, 329.63, 261.63], 0.55, 0.28, 3.5), 1.3)


def helmet():  # 투구 깨짐: 쇳소리 "땡"
    n = int(RATE * 0.45)
    s = tone(880, 0.45, (1, 2.76, 5.4, 8.9), (1, 0.6, 0.35, 0.2))
    return s * env(n, 0.001, 9)


def tick():  # 카운트다운 3·2·1: 나무 토막 "톡"
    n = int(RATE * 0.12)
    return tone(1046.5, 0.12, (1, 2.4, 4.1), (1, 0.4, 0.2)) * env(n, 0.001, 38) + lowpass(noise(0.12), 3000) * env(n, 0.0005, 120) * 0.4


def go():  # 카운트다운 시작!: 밝은 두 음 "띵-딩"
    return pad(notes([1046.5, 1568.0], 0.5, 0.1, 6, bell=True), 0.7)


def hoot():  # 부엉이 감속: 낮고 둥근 "부-엉" (10단계)
    out = np.zeros(int(RATE * 0.62))
    for start, f0, f1, dur in ((0.0, 420, 400, 0.18), (0.24, 470, 360, 0.36)):
        x = t(dur)
        f = np.linspace(f0, f1, len(x)) * (1 + 0.02 * np.sin(2 * np.pi * 6 * x))
        ph = 2 * np.pi * np.cumsum(f) / RATE
        s = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
        e = np.clip(x / 0.04, 0, 1) * np.clip((dur - x) / 0.08, 0, 1)
        i = int(RATE * start)
        out[i:i + len(x)] += s * e
    return out


def swipe():  # 곰 앞발 내려치기: "휙" + "쿵" (10단계)
    n = int(RATE * 0.3)
    x = t(0.3)
    whoosh = lowpass(noise(0.3), 2200) * np.exp(-((x - 0.08) / 0.05) ** 2) * 1.2
    thud = (sweep(140, 60, 0.3) * 0.9 + lowpass(noise(0.3), 500) * 0.8) * env(n, 0.002, 18) * (x > 0.1)
    return whoosh + thud


def spine():  # 고슴도치 가시에 찔림: 짧고 높은 "칙" (10단계)
    n = int(RATE * 0.09)
    hiss = noise(0.09) - lowpass(noise(0.09), 3000)
    return hiss * env(n, 0.001, 55) * 1.5 + tone(2400, 0.09) * env(n, 0.001, 70) * 0.3


SOUNDS = {
    "pickup": (pickup, "도토리 줍기"),
    "place": (place, "동물 놓기"),
    "shot": (shot, "여우불 발사"),
    "hit": (hit, "여우불 명중"),
    "slime_die": (slime_die, "몬스터 쓰러짐"),
    "bite": (bite, "갉아먹기"),
    "boom": (boom, "스컨크 폭발"),
    "log": (log_roll, "통나무 굴러감"),
    "warning": (warning, "큰 무리 경고"),
    "win": (win, "클리어"),
    "lose": (lose, "게임오버"),
    "helmet": (helmet, "투구 깨짐"),
    "tick": (tick, "카운트다운"),
    "go": (go, "시작!"),
    "hoot": (hoot, "부엉이 감속"),
    "swipe": (swipe, "곰 내려치기"),
    "spine": (spine, "가시 찔림"),
}


def save(name: str, x: np.ndarray) -> Path:
    # 앞뒤 5ms 페이드, 최대 -3 dB
    f = min(len(x) // 4, int(RATE * 0.005))
    ramp = np.linspace(0, 1, f)
    x = x.copy()
    x[:f] *= ramp
    x[-f:] *= ramp[::-1]
    x = x / (np.abs(x).max() or 1) * 10 ** (-3 / 20)
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    return path


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, (make, label) in SOUNDS.items():
        x = make()
        path = save(name, x)
        total += path.stat().st_size
        print(f"{name:10} {label:8} {len(x) / RATE:4.2f}초  {path.stat().st_size / 1024:4.0f} KB")
    print(f"합계 {total / 1024:.0f} KB")


if __name__ == "__main__":
    main()
