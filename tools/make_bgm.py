"""배경음악 4곡을 악보(이 파일)에서 만든다 (12-3단계, 사용자 선택 "A: 직접 작곡 + 실제 악기 소리").

    python tools/make_bgm.py            → assets/audio/music/*.mp3 + art/music/*.mid
    python tools/make_bgm.py day        → 한 곡만

흐름: 악보(멜로디는 손으로, 반주는 화음 진행에서 규칙으로) → MIDI → FluidSynth + GeneralUser GS 악기 소리로 WAV
     → 끊김 없는 반복 구간 자르기 → 음량 맞추기 → MP3 (Windows·웹·안드로이드 모두 재생).

끊김 없는 반복: 곡을 두 번 이어 연주해 녹음하고 **두 번째 바퀴만** 잘라 쓴다. 두 번째 바퀴 첫머리에는
첫 바퀴의 울림(리버브·음 꼬리)이 이미 겹쳐 있어서, 끝에서 처음으로 돌아갈 때 소리가 뚝 끊기지 않는다.

도구 (저장소에 넣지 않음, tools/.cache/):
  FluidSynth 2.6.1 (LGPL, 만들 때만 씀) — github.com/FluidSynth/fluidsynth/releases
  GeneralUser GS (S. Christian Collins, 상업적 음악 제작에 제한 없이 사용 가능, 표기 의무 없음)
    — github.com/mrbumpy409/GeneralUser-GS
"""
from __future__ import annotations

import struct
import subprocess
import sys
import wave
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
FLUIDSYNTH = CACHE / "fluidsynth" / "fluidsynth-v2.6.1-win10-x64-cpp11" / "bin" / "fluidsynth.exe"
SOUNDFONT = CACHE / "GeneralUser-GS.sf2"
OUT = ROOT / "assets" / "audio" / "music"
MIDI_OUT = ROOT / "art" / "music"
RATE = 44100
TPB = 480  # MIDI 한 박의 틱

# ── 음 이름 ─────────────────────────────────────────
_NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(name: str) -> int:
    """'C#5' → MIDI 번호 (C4 = 60)."""
    pitch = _NAMES[name[0]]
    rest = name[1:]
    while rest and rest[0] in "#b":
        pitch += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + pitch


def melody(text: str) -> list[tuple[int | None, float]]:
    """'C5:1 D5:0.5 r:1 |' → [(음, 박)], r은 쉼표, |는 마디 구분(무시)."""
    out = []
    for tok in text.split():
        if tok == "|":
            continue
        name, beats = tok.split(":")
        out.append((None if name == "r" else note(name), float(beats)))
    return out


def from_beat(mel, beat: float):
    """멜로디에서 [beat]박부터 뒤쪽 (음 경계에서 자른다)."""
    t = 0.0
    for i, (_, b) in enumerate(mel):
        if t >= beat - 1e-9:
            return mel[i:]
        t += b
    return []


# 화음: 이름 → 근음 + 구성음 (반음 간격)
_QUALITY = {"": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "m7": (0, 3, 7, 10), "dim": (0, 3, 6)}


def chord(name: str) -> tuple[int, tuple[int, ...]]:
    """'Am' → (근음 피치 클래스, 구성음 간격). 'C#m7'도 된다."""
    root = _NAMES[name[0]]
    rest = name[1:]
    if rest[:1] in ("#", "b"):
        root += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return root % 12, _QUALITY[rest]


def tones(name: str, low: int, count: int) -> list[int]:
    """[low] 이상에서 시작하는 화음 구성음 [count]개 (위로 쌓음)."""
    root, ivs = chord(name)
    out = []
    n = low
    while len(out) < count:
        if (n - root) % 12 in ivs:
            out.append(n)
        n += 1
    return out


def bass(name: str, octave: int) -> int:
    root, _ = chord(name)
    return 12 * (octave + 1) + root


# ── 곡 ─────────────────────────────────────────────
@dataclass
class Song:
    name: str
    title: str
    tempo: float
    beats_per_bar: int
    bars: int
    notes: list[tuple[int, float, int, float, int]] = field(default_factory=list)  # (채널, 시작 박, 음, 길이 박, 세기)
    programs: dict[int, int] = field(default_factory=dict)  # 채널 → GM 악기 번호
    volumes: dict[int, int] = field(default_factory=dict)  # 채널 → CC7

    @property
    def beats(self) -> float:
        return self.bars * self.beats_per_bar

    def inst(self, ch: int, program: int, volume: int = 100) -> int:
        self.programs[ch] = program
        self.volumes[ch] = volume
        return ch

    def add(self, ch: int, start: float, pitch: int, length: float, vel: int) -> None:
        self.notes.append((ch, start, pitch, length, max(1, min(127, vel))))

    def line(self, ch: int, start: float, mel, vel: int = 90, transpose: int = 0, legato: float = 0.95) -> float:
        t = start
        for i, (p, b) in enumerate(mel):
            if p is not None:
                # 마디 첫 박을 살짝 세게
                accent = 8 if abs((t / self.beats_per_bar) - round(t / self.beats_per_bar)) < 1e-6 else 0
                self.add(ch, t, p + transpose, b * legato, vel + accent)
            t += b
        return t


DRUMS = 9  # GM 타악기 채널


def title_song() -> Song:
    """메인 화면·지도: '숲속 아침'. F장조 3/4 왈츠. 오르골 멜로디, 하프 분산화음, 현 바탕, 피치카토 베이스.
    뒤 8마디는 플루트가 한 옥타브 아래에서 함께 분다."""
    s = Song("title", "숲속 아침", tempo=100, beats_per_bar=3, bars=16)
    box, harp, pad, pizz, flute = (s.inst(0, 10, 92), s.inst(1, 46, 78), s.inst(2, 49, 52), s.inst(3, 45, 84), s.inst(4, 73, 64))
    chords = ["F", "C", "Dm", "Bb", "F", "Gm", "C", "C7", "F", "A7", "Dm", "Bb", "Gm", "C7", "F", "C7"]
    mel = melody("""
        C6:1.5 A5:0.5 F5:1 | G5:1.5 E5:0.5 C5:1 | D5:1 F5:1 A5:1 | G5:2 F5:1 |
        C6:1.5 A5:0.5 F5:1 | Bb5:1.5 A5:0.5 G5:1 | E5:1 G5:1 C6:1 | Bb5:2 r:1 |
        A5:1 C6:1 F6:1 | E6:1.5 C#6:0.5 A5:1 | D6:1.5 C6:0.5 A5:1 | Bb5:1 A5:1 G5:1 |
        G5:1 Bb5:1 D6:1 | C6:1.5 Bb5:0.5 G5:1 | A5:1 F5:2 | E5:1 G5:1 Bb5:1
    """)
    s.line(box, 0, mel, vel=88)
    s.line(flute, 24, from_beat(mel, 24), vel=70, transpose=-12)
    for bar, c in enumerate(chords):
        t = bar * 3
        arp = tones(c, 53, 4)  # F3 위로 네 음
        for k, p in enumerate([arp[0], arp[1], arp[2], arp[3], arp[2], arp[1]]):
            s.add(harp, t + k * 0.5, p, 0.9, 62 if k else 72)
        for p in tones(c, 60, 3):
            s.add(pad, t, p, 2.95, 46)
        s.add(pizz, t, bass(c, 2), 0.8, 88)
        for p in tones(c, 57, 3):
            s.add(pizz, t + 1, p, 0.5, 52)
            s.add(pizz, t + 2, p, 0.5, 48)
    return s


def day_song() -> Song:
    """낮 전투: '도토리 행진'. C장조 4/4, 116. 마림바 A → 플루트 B → 마림바 + 플루트 3도 화음 A.
    피치카토 뒷박, 베이스 1·3박, 셰이커·우드블록으로 가볍게."""
    s = Song("day", "도토리 행진", tempo=116, beats_per_bar=4, bars=24)
    marimba, flute, pizz, bassist = (s.inst(0, 12, 100), s.inst(1, 73, 80), s.inst(2, 45, 80), s.inst(3, 32, 96))
    a_chords = ["C", "Am", "F", "G", "C", "Am", "Dm|G", "C"]
    b_chords = ["F", "G", "Em", "Am", "F", "G", "Dm", "G7"]
    a = melody("""
        E5:0.5 G5:0.5 C6:1 B5:0.5 G5:0.5 E5:1 | A5:1 C6:0.5 A5:0.5 E5:1 r:1 |
        F5:0.5 A5:0.5 C6:1 D6:0.5 C6:0.5 A5:1 | G5:1.5 F5:0.5 E5:1 D5:1 |
        E5:0.5 G5:0.5 C6:1 D6:0.5 E6:0.5 C6:1 | A5:1 G5:0.5 E5:0.5 C5:1 E5:1 |
        F5:1 A5:1 G5:1 B5:1 | C6:1 G5:1 C6:1 r:1
    """)
    b = melody("""
        A5:2 C6:1 A5:1 | B5:2 D6:1 B5:1 | G5:1.5 A5:0.5 G5:1 E5:1 | C6:2 B5:1 A5:1 |
        A5:1 G5:1 F5:1 A5:1 | G5:2 B5:1 D6:1 | F6:1.5 E6:0.5 D6:1 A5:1 | B5:1 D6:1 F6:0.5 E6:0.5 D6:1
    """)
    s.line(marimba, 0, a, vel=96, legato=0.9)
    s.line(flute, 32, b, vel=88)
    s.line(marimba, 64, a, vel=96, legato=0.9)
    s.line(flute, 64, [(None if p is None else _third_below(p), d) for p, d in a], vel=66)
    for bar, c in enumerate(a_chords + b_chords + a_chords):
        t = bar * 4
        halves = c.split("|")
        for h, name in enumerate(halves):
            span = 4 / len(halves)
            t0 = t + h * span
            s.add(bassist, t0, bass(name, 2), 0.9, 96)
            if span >= 4:
                s.add(bassist, t0 + 2, bass(name, 2) + 7, 0.9, 84)
            for off in (1, 3) if span >= 4 else (1,):
                for p in tones(name, 60, 3):
                    s.add(pizz, t0 + off, p, 0.4, 70)
        # 타악기: 셰이커 8분음표, 우드블록 2·4박, 작은 북 1박
        for k in range(8):
            s.add(DRUMS, t + k * 0.5, 82, 0.25, 54 if k % 2 else 70)
        s.add(DRUMS, t + 1, 76, 0.25, 72)
        s.add(DRUMS, t + 3, 77, 0.25, 66)
        s.add(DRUMS, t, 36, 0.25, 70)
    s.volumes[DRUMS] = 84
    return s


def _third_below(p: int) -> int:
    """C장조 안에서 3도 아래 음 (플루트 화음용)."""
    scale = [0, 2, 4, 5, 7, 9, 11]
    pc = p % 12
    if pc not in scale:
        return p - 3
    i = scale.index(pc)
    j = (i - 2) % 7
    down = (pc - scale[j]) % 12
    return p - down


def night_song() -> Song:
    """밤 전투: '달빛 숲'. A단조 4/4, 92. 첼레스타 멜로디, 하프 오르내림, 낮은 현·콘트라베이스,
    콩가 심장 소리, 두 마디마다 트라이앵글 별빛. 뒤 8마디는 합창 '아-'가 바탕에 깔린다."""
    s = Song("night", "달빛 숲", tempo=92, beats_per_bar=4, bars=16)
    celesta, harp, pad, contra, choir = (s.inst(0, 8, 100), s.inst(1, 46, 74), s.inst(2, 49, 50), s.inst(3, 43, 80), s.inst(4, 52, 44))
    chords = ["Am", "F", "G", "Em", "Am", "F", "Dm", "E7", "F", "G", "Em", "Am", "Dm", "Am", "F", "E7"]
    mel = melody("""
        E5:1.5 A5:0.5 C6:1 B5:1 | A5:3 r:1 | G5:1.5 B5:0.5 D6:1 C6:1 | B5:3 r:1 |
        E6:1.5 D6:0.5 C6:1 A5:1 | C6:1 A5:1 F5:2 | D5:1 F5:1 A5:1 D6:1 | B5:1 G#5:1 E5:2 |
        A5:1 C6:1 F6:2 | E6:1 D6:1 B5:2 | G5:1 B5:1 E6:1.5 D6:0.5 | C6:3 r:1 |
        F5:1 A5:1 D6:1 C6:1 | C6:1 B5:0.5 A5:0.5 E5:2 | F5:1 A5:1 C6:1 B5:1 | D6:1 B5:1 G#5:2
    """)
    s.line(celesta, 0, mel, vel=92)
    for bar, c in enumerate(chords):
        t = bar * 4
        arp = tones(c, 45, 4)
        for k, p in enumerate(arp + arp[2:0:-1] + arp[:2]):
            s.add(harp, t + k * 0.5, p, 1.2, 60 if k else 70)
        for p in tones(c, 52, 3):
            s.add(pad, t, p, 3.95, 44)
        if bar >= 8:
            for p in tones(c, 60, 3):
                s.add(choir, t, p, 3.95, 40)
        s.add(contra, t, bass(c, 1), 3.9, 82)
        s.add(DRUMS, t, 64, 0.3, 64)
        s.add(DRUMS, t + 2.5, 64, 0.3, 50)
        s.add(DRUMS, t + 3, 63, 0.3, 40)
        if bar % 2 == 0:
            s.add(DRUMS, t, 81, 1, 46)
    s.volumes[DRUMS] = 76
    return s


def boss_song() -> Song:
    """보스: '왕 슬라임'. D단조 4/4, 140. 호른 멜로디 + 실로폰 한 옥타브 위(통통 튀는 슬라임),
    현 8분음표 반복, 튜바 4분음표, 팀파니, 작은 드럼 세트."""
    s = Song("boss", "왕 슬라임", tempo=140, beats_per_bar=4, bars=16)
    horn, xylo, strings, tuba, timp = (s.inst(0, 60, 100), s.inst(1, 13, 70), s.inst(2, 48, 84), s.inst(3, 58, 92), s.inst(4, 47, 90))
    chords = ["Dm", "Dm", "Bb", "A", "Dm", "Dm", "Gm", "A7", "Bb", "C", "Am", "Dm", "Gm", "Bb", "A", "A7"]
    mel = melody("""
        D5:1.5 A4:0.5 D5:1 F5:1 | E5:1 D5:1 C#5:1 A4:1 | D5:1.5 F5:0.5 Bb5:1 A5:1 | A5:2 E5:1 C#5:1 |
        D5:1.5 A4:0.5 D5:1 F5:1 | A5:1 G5:1 F5:1 E5:1 | G5:1 Bb5:1 D6:1 C6:0.5 Bb5:0.5 | A5:3 r:1 |
        F5:1 Bb5:1 D6:1 Bb5:1 | E5:1 G5:1 C6:1 G5:1 | A5:1 C6:1 E6:1 C6:1 | D6:2 A5:2 |
        Bb5:1 A5:1 G5:1 D5:1 | F5:1 E5:1 D5:1 Bb4:1 | C#5:1 E5:1 A5:1 G5:1 | E5:1 C#5:1 A4:2
    """)
    s.line(horn, 0, mel, vel=94, transpose=-12, legato=0.9)
    s.line(xylo, 0, mel, vel=70, legato=0.5)
    for bar, c in enumerate(chords):
        t = bar * 4
        r, _ = chord(c)
        third = tones(c, 62, 3)
        pattern = [bass(c, 3), bass(c, 3), third[0], bass(c, 3), third[1], bass(c, 3), third[0], bass(c, 3)]
        for k, p in enumerate(pattern):
            s.add(strings, t + k * 0.5, p, 0.3, 78 if k % 2 == 0 else 62)
        for k, off in enumerate((0, 1, 2, 3)):
            s.add(tuba, t + off, bass(c, 1) + (7 if k == 2 else 0), 0.5, 92 if k == 0 else 78)
        s.add(timp, t, bass(c, 2), 1, 96)
        if bar in (7, 15):
            for k in range(8):
                s.add(timp, t + 2 + k * 0.25, bass("A", 2), 0.25, 60 + k * 5)
        s.add(DRUMS, t, 36, 0.25, 92)
        s.add(DRUMS, t + 2, 36, 0.25, 86)
        s.add(DRUMS, t + 1, 38, 0.25, 84)
        s.add(DRUMS, t + 3, 38, 0.25, 88)
        for k in range(8):
            s.add(DRUMS, t + k * 0.5, 42, 0.2, 50 if k % 2 else 62)
    s.volumes[DRUMS] = 88
    return s


SONGS = {"title": title_song, "day": day_song, "night": night_song, "boss": boss_song}


# ── MIDI 파일 ───────────────────────────────────────
def _varlen(n: int) -> bytes:
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    return bytes(reversed(out))


def write_midi(song: Song, path: Path, repeats: int, tail_beats: float) -> int:
    """곡을 [repeats]번 이어 쓴 MIDI. 돌려주는 값은 한 박의 마이크로초 (실제 길이 계산용)."""
    us_per_beat = round(60_000_000 / song.tempo)
    events: list[tuple[int, int, bytes]] = []  # (틱, 순서, 데이터) — 같은 틱이면 끄기 먼저
    events.append((0, 0, b"\xff\x51\x03" + us_per_beat.to_bytes(3, "big")))
    for ch, prog in song.programs.items():
        events.append((0, 1, bytes([0xC0 | ch, prog])))
        events.append((0, 1, bytes([0xB0 | ch, 7, song.volumes.get(ch, 100)])))
        events.append((0, 1, bytes([0xB0 | ch, 91, 60])))  # 리버브 보내기
    if DRUMS in song.volumes:
        events.append((0, 1, bytes([0xB0 | DRUMS, 7, song.volumes[DRUMS]])))
    for r in range(repeats):
        base = r * song.beats
        for ch, start, pitch, length, vel in song.notes:
            on = round((base + start) * TPB)
            off = round((base + start + length) * TPB)
            events.append((on, 3, bytes([0x90 | ch, pitch, vel])))
            events.append((max(on + 1, off), 2, bytes([0x80 | ch, pitch, 0])))
    end = round((repeats * song.beats + tail_beats) * TPB)
    events.sort(key=lambda e: (e[0], e[1]))
    track = bytearray()
    last = 0
    for tick, _, data in events:
        track += _varlen(tick - last) + data
        last = tick
    track += _varlen(end - last) + b"\xff\x2f\x00"
    path.write_bytes(b"MThd" + struct.pack(">IHHH", 6, 0, 1, TPB) + b"MTrk" + struct.pack(">I", len(track)) + track)
    return us_per_beat


# ── 녹음·자르기·음량 ────────────────────────────────
def render(midi: Path, wav: Path) -> np.ndarray:
    subprocess.run(
        [str(FLUIDSYNTH), "-ni", "-q", "-g", "0.5", "-r", str(RATE), "-T", "wav", "-F", str(wav),
         "-o", "synth.reverb.room-size=0.6", "-o", "synth.reverb.level=0.6", "-o", "synth.chorus.active=0",
         str(SOUNDFONT), str(midi)],
        check=True,
    )
    with wave.open(str(wav)) as w:
        raw = w.readframes(w.getnframes())
        width, channels = w.getsampwidth(), w.getnchannels()
    dtype = {2: np.int16, 4: np.int32}[width]
    x = np.frombuffer(raw, dtype=dtype).astype(np.float64) / np.iinfo(dtype).max
    return x.reshape(-1, channels)


def find_loop(x: np.ndarray, guess: int, search: int = 256) -> int:
    """한 바퀴의 실제 샘플 수. FluidSynth는 음을 64샘플 단위로 시작시키므로 계산한 길이와 몇십 샘플 어긋날 수 있다.
    1바퀴 끝과 2바퀴 끝(마지막 0.5초)이 가장 똑같아지는 길이를 [guess] 근처에서 찾는다."""
    n = RATE // 2
    m = x.mean(axis=1)
    best, best_err = guess, float("inf")
    for p in range(guess - search, guess + search + 1):
        err = float(np.mean((m[p - n:p] - m[2 * p - n:2 * p]) ** 2))
        if err < best_err:
            best, best_err = p, err
    return best


SEAM = int(RATE * 0.08)


def seamless(x: np.ndarray, p: int) -> np.ndarray:
    """두 번째 바퀴 x[p:2p]를 잘라 반복용으로 만든다.

    FluidSynth는 음마다 시작을 64샘플 단위로 맞추므로 두 바퀴가 음악으로는 같아도 샘플까지 같지는 않다.
    그래서 끝 [SEAM] 샘플을 '녹음에서 x[p] 바로 앞에 있던 소리'(1바퀴의 끝)로 서서히 바꾼다.
    그러면 반복할 때 마지막 샘플 → 첫 샘플이 원래 녹음처럼 이어진다."""
    y = x[p:2 * p].copy()
    r = (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, SEAM)))[:, None]
    y[-SEAM:] = y[-SEAM:] * (1 - r) + x[p - SEAM:p] * r
    return y


TARGET_RMS_DB = -19.0
PEAK_DB = -1.0


def master(x: np.ndarray) -> np.ndarray:
    """곡마다 크기를 맞춘다: RMS를 목표로, 넘치는 봉우리는 부드럽게 눌러 −1 dB 안에."""
    rms = np.sqrt(np.mean(x ** 2)) or 1e-9
    x = x * (10 ** (TARGET_RMS_DB / 20) / rms)
    ceiling = 10 ** (PEAK_DB / 20)
    return np.tanh(x / ceiling) * ceiling


def save_mp3(x: np.ndarray, path: Path, tmp: Path) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(tmp), "wb") as w:
        w.setnchannels(x.shape[1])
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-c:a", "libmp3lame", "-b:a", "112k", str(path)], check=True)


def build(song: Song) -> None:
    MIDI_OUT.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    tmp = CACHE / "bgm_tmp"
    tmp.mkdir(parents=True, exist_ok=True)
    write_midi(song, MIDI_OUT / f"{song.name}.mid", repeats=1, tail_beats=4)  # 사람이 들어 보는 악보
    us = write_midi(song, tmp / f"{song.name}_x2.mid", repeats=2, tail_beats=8)
    x = render(tmp / f"{song.name}_x2.mid", tmp / f"{song.name}_x2.wav")
    loop = find_loop(x, round(song.beats * us / 1_000_000 * RATE))
    one = master(seamless(x, loop))
    path = OUT / f"{song.name}.mp3"
    save_mp3(one, path, tmp / f"{song.name}.wav")
    print(f"{song.name:6} {song.title:8} {song.tempo:5.0f} BPM {song.bars:2}마디  {loop / RATE:5.1f}초  {path.stat().st_size / 1024:4.0f} KB")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if not FLUIDSYNTH.exists() or not SOUNDFONT.exists():
        sys.exit(f"도구가 없습니다: {FLUIDSYNTH} / {SOUNDFONT} (파일 위 설명 참고)")
    names = sys.argv[1:] or list(SONGS)
    for n in names:
        build(SONGS[n]())


if __name__ == "__main__":
    main()
