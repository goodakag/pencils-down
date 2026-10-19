"""Synthesizes the placeholder school bells (an electric bell heard down a hallway).

Run: python tools/make_bells.py  → assets/audio/placeholder/bell_start.wav, bell_end.wav
Generated audio, released as CC0 with the project. Plan 4 may swap in recorded CC0 bells.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "placeholder"


def bell(duration: float, seed: int) -> list:
    rnd = random.Random(seed)
    n = int(duration * RATE)
    partials = [(850.0, 1.0), (1700.0, 0.55), (2550.0, 0.35), (3410.0, 0.15)]
    samples = []
    # Simple hallway echo: a few delayed, quieter copies.
    echoes = [(0.0, 1.0), (0.043, 0.35), (0.091, 0.2), (0.157, 0.12)]
    dry = []
    for i in range(n):
        t = i / RATE
        # The clapper hits the gong ~20 times a second.
        strike = 0.55 + 0.45 * max(0.0, math.sin(2 * math.pi * 20.0 * t))
        env = min(1.0, t / 0.02) * (1.0 if t < duration - 0.6 else max(0.0, (duration - t) / 0.6))
        v = sum(a * math.sin(2 * math.pi * f * t + rnd.random() * 0.002) for f, a in partials)
        dry.append(v * strike * env * 0.22)
    for i in range(n):
        v = 0.0
        for d, g in echoes:
            j = i - int(d * RATE)
            if j >= 0:
                v += dry[j] * g
        samples.append(max(-1.0, min(1.0, v)))
    return samples


def write(path: Path, samples: list) -> None:
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in samples))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    write(OUT / "bell_start.wav", bell(2.4, 1))
    write(OUT / "bell_end.wav", bell(3.2, 2))
    print("bells written to", OUT)


if __name__ == "__main__":
    main()
