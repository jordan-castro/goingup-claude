#!/usr/bin/env python3
"""Generates goingUP's three music loops: assets/audio/day.wav, dusk.wav and night.wav.

The game plays all three together and crossfades between them as the run gets darker:
  day   - bright plucked arpeggios, a bouncy bass and soft ticks
  dusk  - a warm pad with a slow arpeggio
  night - a low drone, a dark pad, wind and echoing bells

They share one tempo, one key and one chord progression (Am - F - C - G, two bars each) and are
exactly the same length, so they stay in step. Every note's tail wraps around to the start of
the buffer, and the drone's frequencies are tuned to whole cycles per loop, so each file loops
without a click.

Plain Python (no numpy); takes under a minute. Run from the project root:
    python tool/make_music.py
"""

import math
import os
import random
import struct
import wave

SR = 22050  # sample rate
BPM = 100
BEAT = 60 / BPM
LOOP_BEATS = 32  # 8 bars of 4/4
LOOP_S = LOOP_BEATS * BEAT  # 19.2 s
N = round(LOOP_S * SR)
TAU = 2 * math.pi

# Am - F - C - G, two bars (8 beats) each: (bass root, chord tones), as MIDI note numbers
CHORDS = [
    (45, [57, 60, 64]),  # A minor
    (41, [53, 57, 60]),  # F major
    (48, [60, 64, 67]),  # C major
    (43, [55, 59, 62]),  # G major
]


def chord_at(beat):
    return CHORDS[int(beat // 8) % len(CHORDS)]


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def loop_freq(f):
    """Nearest frequency with a whole number of cycles per loop, so a held tone loops cleanly."""
    return round(f * LOOP_S) / LOOP_S


def tone(buf, start_s, f, amp, partials, attack, tau, length_s, hold_s=None):
    """Adds one note to buf, wrapping its tail around to the start of the loop.

    partials: (frequency ratio, gain, decay multiplier) tuples.
    The note rises over `attack`, then either decays straight away (pluck, bell) or holds for
    `hold_s` and then decays (pad). `tau` is the decay time constant in seconds.
    """
    s0 = round(start_s * SR)
    n = round(length_s * SR)
    att = max(1, round(attack * SR))
    hold = round(hold_s * SR) if hold_s is not None else 0
    for ratio, gain, decay_mult in partials:
        w = TAU * f * ratio / SR
        if f * ratio >= SR / 2:
            continue  # above what the file can hold
        d = math.exp(-1.0 / (tau * decay_mult * SR))
        env = 1.0
        a = amp * gain
        for k in range(n):
            if k < att:
                e = k / att
            elif k < att + hold:
                e = 1.0
            else:
                env *= d
                e = env
            buf[(s0 + k) % N] += a * e * math.sin(w * k)


def normalise(buf, peak=0.85):
    top = max(abs(x) for x in buf) or 1.0
    return [x * peak / top for x in buf]


def write(path, buf):
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(x * 32767)))) for x in buf))
    seam = abs(buf[-1] - buf[0])
    print(f"wrote {path}: {len(buf) / SR:.1f} s, loop seam jump {seam:.4f}")


TRIANGLE = [(1, 1.0, 1.0), (2, 0.15, 0.6), (3, 0.11, 0.5), (5, 0.04, 0.4)]
SOFT = [(1, 1.0, 1.0), (2, 0.25, 0.7)]
WARM = [(1, 1.0, 1.0), (2, 0.35, 0.9), (3, 0.15, 0.8)]
BELL = [(1, 1.0, 1.0), (2.756, 0.45, 0.6), (5.404, 0.25, 0.4), (8.933, 0.12, 0.25)]


def make_day():
    """Bright plucked arpeggios in eighths, a bouncy bass and soft off-beat ticks."""
    buf = [0.0] * N
    pattern = [0, 1, 2, 3, 2, 1, 0, 1]  # 3 = root up an octave
    for eighth in range(LOOP_BEATS * 2):
        beat = eighth / 2
        root, tones = chord_at(beat)
        notes = tones + [tones[0] + 12]
        midi = notes[pattern[eighth % 8]] + 12
        tone(buf, beat * BEAT, freq(midi), 0.22, TRIANGLE, 0.004, 0.16, 0.9)
    for beat in range(0, LOOP_BEATS, 2):
        root, _ = chord_at(beat)
        tone(buf, beat * BEAT, freq(root), 0.32, SOFT, 0.006, 0.35, 1.3)
    rng = random.Random(7)
    for eighth in range(1, LOOP_BEATS * 2, 2):  # the "and" of each beat
        s0 = round(eighth / 2 * BEAT * SR)
        env, prev = 1.0, 0.0
        for k in range(round(0.06 * SR)):
            x = rng.uniform(-1, 1)
            buf[(s0 + k) % N] += 0.05 * env * (x - prev)  # crude high-pass: a soft tick
            prev = x
            env *= math.exp(-1 / (0.012 * SR))
    return normalise(buf)


def make_dusk():
    """A warm detuned pad holding each chord, a slow arpeggio and a soft bass."""
    buf = [0.0] * N
    for i, (root, tones) in enumerate(CHORDS):
        start = i * 8 * BEAT
        for midi in tones + [root + 12]:
            for detune in (0.9975, 1.0025):
                tone(buf, start, freq(midi) * detune, 0.07, WARM, 1.0, 0.8, 8 * BEAT + 4.0, hold_s=8 * BEAT - 1.0)
    for beat in range(LOOP_BEATS):
        _, tones = chord_at(beat)
        midi = tones[[0, 1, 2, 1][beat % 4]]
        tone(buf, beat * BEAT, freq(midi), 0.16, SOFT, 0.01, 0.5, 2.6)
    for beat in range(0, LOOP_BEATS, 4):
        root, _ = chord_at(beat)
        tone(buf, beat * BEAT, freq(root), 0.26, SOFT, 0.02, 1.2, 3.2)
    return normalise(buf)


def make_night():
    """A low drone that breathes, a dark pad an octave down, wind, and sparse echoing bells."""
    buf = [0.0] * N
    # drone on A and E, with slow tremolo and vibrato that repeat exactly within the loop
    for f, amp in ((loop_freq(55.0), 0.20), (loop_freq(freq(40)), 0.15)):
        for k in range(N):
            t = k / SR
            trem = 0.75 + 0.25 * math.sin(TAU * t / (LOOP_S / 2))
            phase = TAU * f * t + 0.6 * math.sin(TAU * t / (LOOP_S / 4))
            buf[k] += amp * trem * (math.sin(phase) + 0.4 * math.sin(2 * phase) + 0.12 * math.sin(3 * phase))
    # dark pad, an octave below the chords, fading in slowly
    for i, (_, tones) in enumerate(CHORDS):
        for midi in tones:
            tone(buf, i * 8 * BEAT, freq(midi - 12), 0.05, SOFT, 2.0, 1.5, 8 * BEAT + 5.0, hold_s=8 * BEAT - 2.0)
    # wind: low-passed noise swelling twice per loop (silent at the seam)
    rng = random.Random(11)
    y = 0.0
    for k in range(N):
        y += 0.02 * (rng.uniform(-1, 1) - y)
        swell = math.sin(math.pi * k / (N / 2)) ** 2
        buf[k] += 0.25 * swell * y
    # bells: two or three per bar on chord tones and their ninths, with a darker flat sixth
    # over A minor, each echoed twice
    rng = random.Random(3)
    for bar in range(LOOP_BEATS // 4):
        beat0 = bar * 4
        _, tones = chord_at(beat0)
        choices = [m + 12 for m in tones] + [tones[0] + 14, tones[0] + 24]
        if bar // 2 == 0:
            choices.append(tones[0] + 13)  # B flat over A minor: the mystic note
        for offset in sorted(rng.sample([0, 1.5, 2.5, 3], rng.choice([2, 3]))):
            midi = rng.choice(choices) + 12
            start = (beat0 + offset) * BEAT
            for echo, gain in ((0.0, 1.0), (0.75 * BEAT, 0.4), (1.5 * BEAT, 0.16)):
                tone(buf, start + echo, freq(midi), 0.12 * gain, BELL, 0.003, 2.2, 5.0)
    return normalise(buf)


def main():
    out_dir = os.path.join("assets", "audio")
    os.makedirs(out_dir, exist_ok=True)
    for name, make in (("day", make_day), ("dusk", make_dusk), ("night", make_night)):
        write(os.path.join(out_dir, f"{name}.wav"), make())


if __name__ == "__main__":
    main()
