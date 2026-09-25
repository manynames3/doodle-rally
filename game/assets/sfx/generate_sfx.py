"""Small original, deterministic synthesised sounds for Cat Racers."""
from pathlib import Path
import wave

import numpy as np

RATE = 22050
OUT = Path(__file__).parent


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


class Clip:
    def __init__(self, duration: float, seed: int):
        self.duration = duration
        self.samples = np.zeros((round(duration * RATE), 2), dtype=np.float64)
        self.rng = np.random.default_rng(seed)

    def _add(self, start: float, signal: np.ndarray, gain: float, pan: float) -> None:
        first = round(start * RATE)
        if first >= len(self.samples):
            return
        src = max(0, -first)
        dst = max(0, first)
        count = min(len(signal) - src, len(self.samples) - dst)
        if count <= 0:
            return
        angle = (np.clip(pan, -1.0, 1.0) + 1.0) * np.pi / 4.0
        part = signal[src:src + count] * gain
        self.samples[dst:dst + count, 0] += part * np.cos(angle)
        self.samples[dst:dst + count, 1] += part * np.sin(angle)

    def tone(self, start: float, duration: float, midi: float, gain: float,
             voice: str = "bell", pan: float = 0.0, slide: float = 0.0) -> None:
        count = max(2, round(duration * RATE))
        t = np.arange(count, dtype=np.float64) / RATE
        base = hz(midi)
        if abs(slide) > 0.01:
            exponent = np.log(2.0) * slide / duration
            phase = 2.0 * np.pi * base * np.expm1(exponent * t) / exponent
        else:
            phase = 2.0 * np.pi * base * t
        if voice == "bell":
            signal = (np.sin(phase) + 0.38 * np.sin(phase * 2.72 + 0.4) * np.exp(-t * 7.0)
                      + 0.17 * np.sin(phase * 5.4 + 0.2) * np.exp(-t * 16.0))
            env = np.exp(-t * 4.5)
        elif voice == "wood":
            signal = (np.sin(phase) + 0.3 * np.sin(phase * 2.03) + 0.1 * np.sin(phase * 3.7)) * np.exp(-t * 17.0)
            env = np.ones_like(t)
        elif voice == "spring":
            signal = (np.sin(phase) + 0.43 * np.sin(phase * 2.0) + 0.18 * np.sin(phase * 3.0)) * np.exp(-t * 5.0)
            env = 0.84 + 0.16 * np.sin(2.0 * np.pi * 13.0 * t)
        elif voice == "warm":
            signal = (np.sin(phase) + 0.30 * np.sin(phase * 2.0) + 0.12 * np.sin(phase * 3.0)
                      + 0.06 * np.sin(phase * 4.0))
            env = np.minimum(1.0, t / 0.008) * np.minimum(1.0, (duration - t) / 0.06)
        elif voice == "brass":
            signal = sum(np.sin(phase * h) / h for h in range(1, 7)) * 0.62
            env = np.minimum(1.0, t / 0.045) * np.minimum(1.0, (duration - t) / 0.10)
        elif voice == "laser":
            signal = np.sin(phase) + 0.32 * np.sin(phase * 2.0) + 0.12 * np.sin(phase * 4.0)
            env = np.exp(-t * 2.8) * np.minimum(1.0, (duration - t) / 0.04)
        else:
            signal = np.sin(phase)
            env = np.minimum(1.0, t / 0.006) * np.minimum(1.0, (duration - t) / 0.04)
        env = np.maximum(0.0, env)
        self._add(start, signal * env, gain, pan)

    def noise(self, start: float, duration: float, gain: float, pan: float = 0.0,
              color: str = "air", attack: float = 0.005, decay: float = 5.0) -> None:
        count = max(2, round(duration * RATE))
        white = self.rng.standard_normal(count)
        # A 14-sample box filter gives warm air; the difference signal is airy/high.
        smooth = np.convolve(white, np.ones(14, dtype=np.float64) / 14.0, mode="same")
        signal = smooth if color == "warm" else white - smooth
        if color == "crackle":
            signal = white * 0.72 + (white - smooth) * 0.45
        t = np.arange(count, dtype=np.float64) / RATE
        env = np.minimum(1.0, t / attack) * np.exp(-t * decay)
        env *= np.minimum(1.0, (duration - t) / 0.02)
        self._add(start, signal * np.maximum(0.0, env), gain, pan)

    def finish(self, name: str, seed_offset: int = 0) -> None:
        dry = self.samples.copy()
        for delay_s, amount, swap in [(0.043, 0.09, True), (0.091, 0.05, False), (0.137, 0.025, True)]:
            delay = round(delay_s * RATE)
            if delay < len(dry):
                if swap:
                    self.samples[delay:, 0] += dry[:-delay, 1] * amount
                    self.samples[delay:, 1] += dry[:-delay, 0] * amount
                else:
                    self.samples[delay:, :] += dry[:-delay, :] * amount
        peak = float(np.max(np.abs(self.samples)))
        if peak > 0.92:
            self.samples *= 0.92 / peak
        pcm = np.asarray(np.clip(self.samples, -0.999, 0.999) * 32767.0, dtype="<i2")
        with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(RATE)
            output.writeframes(pcm.tobytes())


def engine_loop() -> None:
    duration = 1.0  # Exactly 55 cycles at the idle pitch keeps the loop phase-aligned.
    t = np.arange(RATE, dtype=np.float64) / RATE
    phase = 2.0 * np.pi * 55.0 * t
    pulse = 0.77 + 0.23 * np.maximum(0.0, np.sin(phase * 0.5)) ** 2.5
    rng = np.random.default_rng(4501)
    noise = rng.standard_normal(RATE)
    hiss = noise - np.convolve(noise, np.ones(30) / 30.0, mode="same")
    mono = pulse * (0.46 * np.sin(phase) + 0.25 * np.sin(phase * 2.0)
                    + 0.16 * np.sin(phase * 3.0) + 0.10 * np.sin(phase * 4.0)
                    + 0.055 * np.sin(phase * 5.0)) + hiss * 0.012
    # Blend only the stochastic component at the loop join; the engine harmonics already align.
    fade = round(0.035 * RATE)
    w = np.linspace(0.0, 1.0, fade, endpoint=False)
    mono[-fade:] = mono[-fade:] * (1.0 - w) + mono[:fade] * w
    stereo = np.column_stack((mono, np.roll(mono, round(0.006 * RATE)) * 0.90))
    pcm = np.asarray(np.clip(stereo, -0.90, 0.90) * 32767.0, dtype="<i2")
    with wave.open(str(OUT / "engine_loop.wav"), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def make_clips() -> None:
    seed = 7301

    clip = Clip(0.58, seed); seed += 1
    for i, pitch in enumerate([76, 81, 85, 88]): clip.tone(i * 0.075, 0.31, pitch, 0.20, "bell", -0.45 + i * 0.30)
    clip.noise(0.01, 0.28, 0.12, 0.1, "air", decay=19)
    clip.finish("pickup")

    clip = Clip(0.76, seed); seed += 1
    clip.tone(0.00, 0.58, 43, 0.29, "warm", 0.0, 7)
    clip.tone(0.08, 0.48, 55, 0.13, "spring", -0.18, 12)
    clip.noise(0.0, 0.55, 0.18, -0.12, "air", decay=3.1)
    clip.tone(0.35, 0.25, 83, 0.08, "bell", 0.25, 5)
    clip.finish("boost")

    clip = Clip(0.54, seed); seed += 1
    clip.noise(0.0, 0.53, 0.18, 0.0, "air", decay=1.6)
    clip.tone(0.03, 0.49, 76, 0.10, "laser", 0.1, 4)
    clip.finish("drift")

    clip = Clip(0.80, seed); seed += 1
    for i, pitch in enumerate([60, 64, 67, 72, 76]): clip.tone(i * 0.095, 0.28, pitch, 0.12, "wood", -0.45 + i * 0.22)
    clip.noise(0.48, 0.16, 0.08, 0.2, "crackle", decay=24)
    clip.finish("item")

    clip = Clip(0.39, seed); seed += 1
    clip.tone(0.00, 0.30, 38, 0.31, "warm", -0.05, -8)
    clip.noise(0.00, 0.20, 0.22, 0.0, "crackle", decay=20)
    clip.tone(0.025, 0.27, 62, 0.14, "spring", 0.17, -12)
    clip.finish("hit")

    clip = Clip(0.42, seed); seed += 1
    clip.tone(0.00, 0.34, 43, 0.26, "warm", -0.24, -5)
    clip.noise(0.00, 0.35, 0.19, 0.18, "crackle", decay=8)
    clip.tone(0.07, 0.20, 50, 0.09, "wood", 0.3, 7)
    clip.finish("wall")

    clip = Clip(0.20, seed); seed += 1
    clip.tone(0.00, 0.17, 59, 0.19, "wood", -0.2, -2)
    clip.noise(0.00, 0.13, 0.11, 0.2, "crackle", decay=24)
    clip.finish("bump")

    clip = Clip(0.96, seed); seed += 1
    for i, pitch in enumerate([72, 76, 79, 84]): clip.tone(i * 0.14, 0.56, pitch, 0.17, "brass", -0.35 + i * 0.22)
    clip.tone(0.47, 0.48, 60, 0.12, "warm", -0.2)
    clip.tone(0.47, 0.48, 67, 0.11, "warm", 0.2)
    clip.finish("lap")

    clip = Clip(1.56, seed); seed += 1
    for i, pitch in enumerate([67, 72, 76, 79, 84]): clip.tone(i * 0.12, 1.02, pitch, 0.16, "brass", -0.45 + i * 0.22)
    for pitch in [48, 55, 60, 64]: clip.tone(0.42, 1.03, pitch, 0.105, "warm", -0.38 + (pitch % 4) * 0.24)
    clip.noise(0.40, 0.62, 0.08, 0.0, "air", decay=4)
    clip.finish("finish")

    clip = Clip(0.30, seed); seed += 1
    clip.tone(0.00, 0.22, 71, 0.15, "wood", 0.0)
    clip.noise(0.0, 0.09, 0.055, 0.0, "crackle", decay=35)
    clip.finish("countdown")

    clip = Clip(0.77, seed); seed += 1
    for i, pitch in enumerate([67, 72, 76, 79]): clip.tone(i * 0.055, 0.63, pitch, 0.18, "brass", -0.35 + i * 0.22)
    clip.tone(0.02, 0.61, 48, 0.16, "warm", -0.2, 3)
    clip.noise(0.0, 0.38, 0.07, 0.15, "air", decay=6)
    clip.finish("go")

    clip = Clip(0.15, seed); seed += 1
    clip.tone(0.00, 0.10, 77, 0.14, "wood")
    clip.noise(0.0, 0.045, 0.045, 0.0, "crackle", decay=40)
    clip.finish("click")

    clip = Clip(0.72, seed); seed += 1
    for i, pitch in enumerate([72, 79, 84, 88, 91]): clip.tone(i * 0.075, 0.48, pitch, 0.11, "bell", -0.4 + i * 0.19, -2)
    clip.tone(0.0, 0.30, 55, 0.07, "warm")
    clip.finish("shield")

    clip = Clip(0.78, seed); seed += 1
    clip.tone(0.0, 0.72, 34, 0.28, "warm", 0.0, -9)
    clip.tone(0.04, 0.60, 46, 0.18, "spring", -0.1, -6)
    for i, pitch in enumerate([55, 58, 62]): clip.tone(0.08 + i * 0.035, 0.51, pitch, 0.055, "warm", -0.4 + i * 0.4)
    clip.noise(0.0, 0.66, 0.085, 0.0, "warm", decay=3)
    clip.finish("purr_wave")

    clip = Clip(0.77, seed); seed += 1
    for i, pitch in enumerate([88, 84, 81]):
        clip.noise(i * 0.075, 0.47, 0.105, -0.5 + i * 0.5, "air", attack=0.015, decay=3.0)
        clip.tone(i * 0.075, 0.37, pitch, 0.06, "laser", -0.45 + i * 0.42, -5)
    clip.finish("feather_fan")

    clip = Clip(0.62, seed); seed += 1
    clip.tone(0.00, 0.43, 86, 0.11, "spring", -0.18, 9)
    clip.tone(0.12, 0.42, 79, 0.10, "bell", 0.18, -4)
    clip.noise(0.0, 0.35, 0.09, 0.0, "warm", decay=8)
    clip.finish("treat")

    clip = Clip(0.64, seed); seed += 1
    clip.tone(0.00, 0.42, 91, 0.17, "bell", 0.0, -5)
    clip.tone(0.04, 0.38, 78, 0.12, "wood", -0.18, 8)
    clip.tone(0.13, 0.42, 98, 0.09, "bell", 0.22, 5)
    clip.noise(0.0, 0.35, 0.09, 0.0, "crackle", decay=11)
    clip.finish("paw_parry")

    clip = Clip(0.54, seed); seed += 1
    clip.tone(0.00, 0.47, 55, 0.21, "spring", 0.0, 14)
    clip.tone(0.07, 0.39, 67, 0.11, "spring", -0.15, -18)
    clip.noise(0.0, 0.36, 0.075, 0.1, "warm", decay=7)
    clip.finish("yarn")

    clip = Clip(0.61, seed); seed += 1
    clip.noise(0.0, 0.37, 0.12, 0.0, "air", decay=5)
    clip.tone(0.0, 0.50, 83, 0.10, "laser", 0.12, -10)
    clip.tone(0.17, 0.28, 71, 0.10, "bell", -0.15, -7)
    clip.finish("fish")

    clip = Clip(0.46, seed); seed += 1
    clip.tone(0.00, 0.40, 79, 0.13, "spring", 0.0, -24)
    clip.noise(0.10, 0.30, 0.075, 0.0, "air", decay=6)
    clip.finish("reset")


def main() -> None:
    engine_loop()
    make_clips()
    print("Generated engine loop and 20 original, individually designed sound effects.")


if __name__ == "__main__":
    main()
