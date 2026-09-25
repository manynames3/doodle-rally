"""Generate three original, loop-ready Cat Racers arrangements with layered synthesis."""
from pathlib import Path
import wave

import numpy as np

RATE = 22050
BARS = 64
OUT = Path(__file__).parent

PROFILES = {
    "desk": {
        "bpm": 130,
        "roots": [60, 57, 53, 55],
        "quality": ["major", "minor", "major", "major"],
        "motif": [0, 4, 7, 12, 9, 7, 4, 2],
        "answer": [7, 9, 12, 16, 14, 12, 9, 7],
        "style": "workshop",
    },
    "castle": {
        "bpm": 122,
        "roots": [62, 65, 70, 60],
        "quality": ["minor", "major", "major", "major"],
        "motif": [0, 3, 7, 10, 12, 10, 7, 5],
        "answer": [7, 10, 14, 17, 15, 14, 10, 7],
        "style": "adventure",
    },
    "sky": {
        "bpm": 140,
        "roots": [57, 53, 60, 55],
        "quality": ["minor", "major", "major", "major"],
        "motif": [0, 7, 12, 10, 7, 3, 5, 7],
        "answer": [12, 15, 19, 22, 19, 17, 15, 12],
        "style": "arcade",
    },
}


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69.0) / 12.0)


def add_pan(mix: np.ndarray, start: float, signal: np.ndarray, gain: float, pan: float = 0.0) -> None:
    first = max(0, int(round(start * RATE)))
    if first >= len(mix):
        return
    source_first = max(0, -int(round(start * RATE)))
    count = min(len(signal) - source_first, len(mix) - first)
    if count <= 0:
        return
    theta = (np.clip(pan, -1.0, 1.0) + 1.0) * np.pi / 4.0
    segment = signal[source_first:source_first + count] * gain
    mix[first:first + count, 0] += segment * np.cos(theta)
    mix[first:first + count, 1] += segment * np.sin(theta)


def note(mix: np.ndarray, midi: float, start: float, length: float, gain: float,
         voice: str, pan: float, rng: np.random.Generator) -> None:
    count = max(2, min(round(length * RATE), len(mix) - round(start * RATE)))
    if count <= 1:
        return
    t = np.arange(count, dtype=np.float64) / RATE
    f = hz(midi)
    vibrato = 0.0
    if voice in ("flute", "brass", "synth"):
        vibrato = 0.0025 * np.sin(2.0 * np.pi * 5.2 * t)
    phase = 2.0 * np.pi * f * t * (1.0 + vibrato)
    if voice == "mallet":
        signal = (np.sin(phase) * np.exp(-t * 3.7)
                  + 0.34 * np.sin(phase * 2.01 + 0.1) * np.exp(-t * 7.0)
                  + 0.13 * np.sin(phase * 3.92) * np.exp(-t * 13.0))
        env = np.minimum(1.0, t / 0.002) * np.minimum(1.0, (length - t) / 0.025)
    elif voice == "pizz":
        signal = (np.sin(phase) * np.exp(-t * 2.9)
                  + 0.28 * np.sin(phase * 2.0) * np.exp(-t * 5.8)
                  + 0.11 * np.sin(phase * 3.0) * np.exp(-t * 9.5))
        env = np.minimum(1.0, t / 0.004) * np.minimum(1.0, (length - t) / 0.035)
        signal += rng.standard_normal(count) * np.exp(-t * 70.0) * 0.018
    elif voice == "flute":
        signal = (np.sin(phase) + 0.16 * np.sin(phase * 2.0) + 0.035 * np.sin(phase * 3.0))
        env = np.minimum(1.0, t / 0.045) * np.minimum(1.0, (length - t) / 0.09)
    elif voice == "brass":
        signal = sum(np.sin(phase * harmonic) / harmonic for harmonic in range(1, 7)) * 0.62
        env = np.minimum(1.0, t / 0.07) * np.minimum(1.0, (length - t) / 0.08)
    elif voice == "pad":
        signal = (np.sin(phase) + 0.38 * np.sin(phase * 1.003 + 0.2)
                  + 0.23 * np.sin(phase * 2.0) + 0.13 * np.sin(phase * 0.997 - 0.2))
        env = np.minimum(1.0, t / 0.10) * np.minimum(1.0, (length - t) / 0.14)
    elif voice == "bass":
        signal = (np.sin(phase) + 0.42 * np.sin(phase * 2.0) + 0.18 * np.sin(phase * 3.0)
                  + 0.08 * np.sin(phase * 4.0))
        env = np.minimum(1.0, t / 0.006) * np.minimum(1.0, (length - t) / 0.035)
        signal *= np.exp(-t * 0.5)
    elif voice == "synth":
        signal = (np.sin(phase) + 0.42 * np.sin(phase * 2.0) + 0.30 * np.sin(phase * 3.0)
                  + 0.18 * np.sin(phase * 4.0) + 0.09 * np.sin(phase * 5.0))
        env = np.minimum(1.0, t / 0.012) * np.minimum(1.0, (length - t) / 0.035)
        signal *= np.exp(-t * 0.8)
    else:
        signal = np.sin(phase)
        env = np.minimum(1.0, t / 0.01) * np.minimum(1.0, (length - t) / 0.05)
    add_pan(mix, start, signal * np.maximum(0.0, env), gain, pan)


def drum(mix: np.ndarray, start: float, kind: str, gain: float, pan: float,
         rng: np.random.Generator) -> None:
    duration = {"kick": 0.30, "snare": 0.24, "hat": 0.085, "open_hat": 0.28,
                "tom": 0.34, "clap": 0.19, "wood": 0.12, "crash": 0.82}[kind]
    count = round(duration * RATE)
    t = np.arange(count, dtype=np.float64) / RATE
    noise = rng.standard_normal(count)
    high_noise = np.diff(noise, prepend=noise[0])
    if kind == "kick":
        phase = 2.0 * np.pi * (54.0 * t + 38.0 * (1.0 - np.exp(-t * 22.0)) / 22.0)
        signal = np.sin(phase) * np.exp(-t * 11.5) + high_noise * np.exp(-t * 115.0) * 0.11
    elif kind == "tom":
        phase = 2.0 * np.pi * (112.0 * t + 44.0 * (1.0 - np.exp(-t * 10.0)) / 10.0)
        signal = np.sin(phase) * np.exp(-t * 7.5) + high_noise * np.exp(-t * 45.0) * 0.10
    elif kind in ("snare", "clap"):
        decay = 24.0 if kind == "snare" else 18.0
        signal = (noise * np.exp(-t * decay) * (0.62 if kind == "snare" else 0.48)
                  + np.sin(2.0 * np.pi * 185.0 * t) * np.exp(-t * 19.0) * 0.28)
        if kind == "clap":
            for delay in (0.0, 0.012, 0.026):
                pulse = np.exp(-np.maximum(0.0, t - delay) * 48.0) * (t >= delay)
                signal += high_noise * pulse * 0.16
    elif kind in ("hat", "open_hat", "crash"):
        decay = {"hat": 70.0, "open_hat": 13.0, "crash": 4.2}[kind]
        signal = high_noise * np.exp(-t * decay)
        if kind == "crash":
            signal += (noise - high_noise * 0.7) * np.exp(-t * 5.2) * 0.36
        signal *= 0.36
    else:  # wooden click / rim tap
        signal = (np.sin(2.0 * np.pi * 940.0 * t) + 0.28 * np.sin(2.0 * np.pi * 1840.0 * t)) * np.exp(-t * 34.0)
        signal += high_noise * np.exp(-t * 62.0) * 0.12
    add_pan(mix, start, signal, gain, pan)


def write_track(name: str, profile: dict) -> None:
    bpm = profile["bpm"]
    beat = 60.0 / bpm
    bar_time = 4.0 * beat
    duration = BARS * bar_time
    frames = round(duration * RATE)
    mix = np.zeros((frames, 2), dtype=np.float64)
    rng = np.random.default_rng(260913 + ["desk", "castle", "sky"].index(name) * 97)

    for bar in range(BARS):
        section = bar // 16
        reprise = bar >= 60
        root_index = (bar // 2) % 4
        root = profile["roots"][root_index]
        quality = profile["quality"][root_index]
        chord = [0, 4, 7] if quality == "major" else [0, 3, 7]
        if section == 3 and not reprise:
            chord.append(10)
        at_bar = bar * bar_time
        intensity = [0.82, 0.93, 1.0, 0.88][section]
        if reprise:
            intensity = 0.78

        if profile["style"] == "workshop":
            # Toy piano, struck wood, plucked bass and a loping hand-played kit.
            for beat_index in range(4):
                at = at_bar + beat_index * beat
                if beat_index in (0, 2) or (bar % 4 == 3 and beat_index == 3):
                    drum(mix, at, "kick", 0.19 * intensity, 0.0, rng)
                if beat_index in (1, 3):
                    drum(mix, at, "snare" if beat_index == 3 else "wood", 0.11 * intensity, -0.08, rng)
                note(mix, root - 12 + (7 if beat_index == 2 else 0), at, beat * 0.58, 0.17 * intensity, "bass", -0.06, rng)
                for half in range(2):
                    drum(mix, at + half * beat * 0.5, "hat", 0.036 * intensity, 0.35 if half else -0.35, rng)
            motif = profile["motif"] if (bar // 4 + section) % 2 == 0 or reprise else list(reversed(profile["motif"]))
            for step, degree in enumerate(motif):
                if step in (3, 7) and bar % 2 == 1:
                    continue
                swing = 0.045 * beat if step % 2 else 0.0
                note(mix, root + 12 + degree, at_bar + step * beat * 0.5 + swing,
                     beat * (0.32 if step % 2 else 0.53), 0.12 * intensity, "mallet", 0.22 if step % 2 else -0.12, rng)
            if section >= 1 and bar % 2 == 0 and not reprise:
                for step in (1, 5):
                    note(mix, root + 24 + profile["answer"][step], at_bar + step * beat * 0.5,
                         beat * 0.25, 0.035 * intensity, "mallet", 0.55, rng)
            if bar % 2 == 0:
                for degree in chord:
                    note(mix, root + 12 + degree, at_bar, bar_time * 0.82,
                         0.022 * intensity, "pad", -0.40 + chord.index(degree) * 0.38, rng)

        elif profile["style"] == "adventure":
            # Pizzicato strings and bright brass answer a woodwind lead; toms lift the fills.
            for beat_index in range(4):
                at = at_bar + beat_index * beat
                if beat_index in (0, 2):
                    drum(mix, at, "kick", 0.18 * intensity, -0.1, rng)
                if beat_index in (1, 3):
                    drum(mix, at, "snare" if bar % 2 else "tom", 0.12 * intensity, 0.12, rng)
                if beat_index == 0 or beat_index == 2:
                    note(mix, root - 12, at, beat * 0.86, 0.15 * intensity, "bass", -0.15, rng)
                if beat_index in (1, 3):
                    note(mix, root + chord[1] + 12, at, beat * 0.30, 0.055 * intensity, "pizz", 0.22, rng)
                drum(mix, at + beat * 0.5, "hat", 0.026 * intensity, 0.38, rng)
            motif = profile["motif"] if (bar // 4 + section) % 2 == 0 or reprise else profile["answer"]
            for step, degree in enumerate(motif):
                if step in (2, 6) and bar % 4 == 3:
                    continue
                note(mix, root + 12 + degree, at_bar + step * beat * 0.5,
                     beat * (0.52 if step % 2 == 0 else 0.34), 0.105 * intensity, "flute", 0.22, rng)
            if section >= 1 and bar % 2 == 0 and not reprise:
                note(mix, root + 12, at_bar, beat * 1.55, 0.075 * intensity, "brass", -0.30, rng)
                note(mix, root + chord[2] + 12, at_bar + beat * 2.0, beat * 1.35,
                     0.055 * intensity, "brass", 0.35, rng)
            if bar % 2 == 0:
                for voice_index, degree in enumerate(chord):
                    note(mix, root + 24 + degree, at_bar, bar_time * 0.86,
                         0.018 * intensity, "pad", -0.4 + voice_index * 0.4, rng)
            if bar % 8 == 7:
                drum(mix, at_bar + bar_time - 0.20, "crash", 0.10, 0.25, rng)

        else:
            # Four-on-the-floor pulse, rubbery bass, bright arps and a neon lead.
            for beat_index in range(4):
                at = at_bar + beat_index * beat
                drum(mix, at, "kick", 0.17 * intensity, 0.0, rng)
                if beat_index in (1, 3):
                    drum(mix, at, "clap", 0.105 * intensity, 0.12, rng)
                note(mix, root - 12 + (12 if beat_index % 2 else 0), at, beat * 0.48,
                     0.16 * intensity, "bass", -0.08, rng)
                for sixteenth in range(4):
                    hat_gain = 0.042 if sixteenth in (0, 2) else 0.024
                    drum(mix, at + sixteenth * beat * 0.25, "hat", hat_gain * intensity,
                         -0.35 if sixteenth % 2 == 0 else 0.35, rng)
            motif = profile["motif"] if (bar // 4 + section) % 2 == 0 or reprise else profile["answer"]
            for step, degree in enumerate(motif):
                if step in (3, 7) and bar % 2 == 0:
                    continue
                note(mix, root + 12 + degree, at_bar + step * beat * 0.5,
                     beat * 0.28, 0.095 * intensity, "synth", 0.18 if step % 2 else -0.15, rng)
            if section >= 1 and not reprise:
                arp = chord + [12]
                for step in range(8):
                    degree = arp[step % len(arp)]
                    note(mix, root + 24 + degree, at_bar + step * beat * 0.5 + beat * 0.25,
                         beat * 0.18, 0.045 * intensity, "synth", 0.5 if step % 2 else -0.5, rng)
            if bar % 4 == 3:
                drum(mix, at_bar + bar_time - 0.08, "open_hat", 0.085 * intensity, 0.3, rng)
            if bar % 2 == 0:
                for voice_index, degree in enumerate(chord):
                    note(mix, root + 12 + degree, at_bar, bar_time * 0.9,
                         0.025 * intensity, "pad", -0.4 + voice_index * 0.4, rng)

    # Short stereo reflections make the tiny instruments feel like a shared space.
    dry = mix.copy()
    for delay_s, amount, swap in [(0.087, 0.095, True), (0.151, 0.055, False), (0.233, 0.028, True)]:
        delay = round(delay_s * RATE)
        if swap:
            mix[delay:, 0] += dry[:-delay, 1] * amount
            mix[delay:, 1] += dry[:-delay, 0] * amount
        else:
            mix[delay:, :] += dry[:-delay, :] * amount

    # The ending returns to the opening tonality and motif; this gentle blend hides the loop seam.
    fade = min(round(0.9 * RATE), frames // 4)
    for index in range(fade):
        weight = (index + 1) / float(fade)
        mix[frames - fade + index] = mix[frames - fade + index] * (1.0 - weight) + mix[index] * weight
    mix = np.tanh(mix * 1.18)
    peak = float(np.max(np.abs(mix)))
    rms_before_gain = float(np.sqrt(np.mean(mix * mix)))
    # Match average level across courses while retaining ample peak headroom.
    target_rms = 0.13
    if peak > 0 and rms_before_gain > 0:
        mix *= min(target_rms / rms_before_gain, 0.90 / peak)
    output_peak = float(np.max(np.abs(mix)))
    seam_step = float(np.max(np.abs(mix[0] - mix[-1])))
    if seam_step > 0.08:
        raise RuntimeError(f"{name} loop seam is too abrupt: {seam_step:.3f}")
    pcm = np.asarray(mix * 32767.0, dtype="<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    rms = float(np.sqrt(np.mean(mix * mix)))
    print(f"{name}: {duration:.1f}s, {bpm} BPM, output peak {output_peak:.3f}, loop seam {seam_step:.3f}, matched RMS {rms:.3f}")


if __name__ == "__main__":
    for track, settings in PROFILES.items():
        write_track(track, settings)
