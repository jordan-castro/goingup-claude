#!/usr/bin/env python3
"""Generates goingUP's sound effects into assets/audio/sfx/.

  shield          - an airy breath swelling over a low, warm hum
  bump            - a rubbery boing when the shield takes a hit
  crash           - a wooden bonk and a sad slide down
  takeoff         - a quick upward swoosh when a run starts
  ghost           - a soft sparkle when you fly past the last crash
  milestone       - a two-note chime every 100 meters
  new_best        - a little fanfare
  hollow_pop      - a Hollow One torn apart by the shield
  realm           - a slow mystic chime when the climb enters a darker realm
  memory          - a music box, slightly out of tune, when a memory comes back
  glitch          - a crackle of static when the picture tears in the deepest realms
  click, buy, nope - shop buttons: a tap, a ka-ching, a "can't afford"

Everything is in A minor like the music (tool/make_music.py), so the effects sit in the mix.
Plain Python (no numpy); takes a few seconds. Run from the project root:
    python tool/make_sfx.py
"""

import math
import os
import random
import struct
import wave

SR = 22050  # sample rate, same as the music
TAU = 2 * math.pi

BRIGHT = [(1, 1.0, 1.0), (2, 0.3, 0.7), (3, 0.18, 0.5), (4, 0.06, 0.4)]
SOFT = [(1, 1.0, 1.0), (2, 0.25, 0.7)]
WARM = [(1, 1.0, 1.0), (2, 0.35, 0.9), (3, 0.15, 0.8)]
BELL = [(1, 1.0, 1.0), (2.756, 0.45, 0.6), (5.404, 0.25, 0.4), (8.933, 0.12, 0.25)]
WOOD = [(1, 1.0, 1.0), (2.3, 0.5, 0.5), (4.1, 0.2, 0.3)]


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def blank(seconds):
    return [0.0] * round(seconds * SR)


def tone(buf, start_s, f, amp, partials, attack, tau, glide_to=None, glide_s=None, vibrato=0.0, hold_s=0.0):
    """Adds one note to buf, cut off at the buffer's end.

    partials: (frequency ratio, gain, decay multiplier) tuples. The pitch can glide from f to
    `glide_to` over `glide_s` seconds (exponentially, so it sounds even), and wobble by
    `vibrato` semitones. The note rises over `attack`, holds for `hold_s`, then decays with
    time constant `tau`.
    """
    s0 = round(start_s * SR)
    att = max(1, round(attack * SR))
    hold = round(hold_s * SR)
    glide_n = round((glide_s or 0) * SR)
    for ratio, gain, decay_mult in partials:
        phase = 0.0
        d = math.exp(-1.0 / (tau * decay_mult * SR))
        env = 1.0
        a = amp * gain
        for k in range(len(buf) - s0):
            if k < att:
                e = k / att
            elif k < att + hold:
                e = 1.0
            else:
                env *= d
                e = env
            if e < 1e-4 and k > att + hold:
                break
            f_now = f
            if glide_to is not None and glide_n > 0:
                t = min(1.0, k / glide_n)
                f_now = f * (glide_to / f) ** t
            if vibrato:
                f_now *= 2 ** (vibrato * math.sin(TAU * 6 * k / SR) / 12)
            fr = f_now * ratio
            if fr >= SR / 2:
                break  # above what the file can hold
            phase += TAU * fr / SR
            buf[s0 + k] += a * e * math.sin(phase)


def noise(buf, start_s, length_s, amp, tau, smooth=0.0, seed=1):
    """Adds a burst of noise. `smooth` (0..1) low-passes it: 0 is a hiss, 0.9 a soft thud."""
    rng = random.Random(seed)
    s0 = round(start_s * SR)
    y = 0.0
    d = math.exp(-1.0 / (tau * SR))
    env = 1.0
    for k in range(min(round(length_s * SR), len(buf) - s0)):
        y += (1 - smooth) * (rng.uniform(-1, 1) - y)
        buf[s0 + k] += amp * env * y
        env *= d


def finish(buf, peak=0.8):
    """Normalises, and fades the last few milliseconds so nothing clicks at the end."""
    top = max(abs(x) for x in buf) or 1.0
    out = [x * peak / top for x in buf]
    fade = min(len(out), round(0.01 * SR))
    for i in range(fade):
        out[-1 - i] *= i / fade
    return out


def write(path, buf):
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(x * 32767)))) for x in buf))
    print(f"wrote {path}: {len(buf) / SR:.2f} s")


def make_shield():
    """A hush rather than a fanfare: an airy breath swelling up over a low, warm hum."""
    buf = blank(1.0)
    rng = random.Random(15)
    n = round(0.8 * SR)
    y = 0.0
    for k in range(n):
        y += 0.06 * (rng.uniform(-1, 1) - y)
        buf[k] += 0.5 * math.sin(math.pi * k / n) ** 2 * y
    tone(buf, 0.05, freq(57), 0.25, SOFT, 0.25, 0.3, hold_s=0.2)
    tone(buf, 0.05, freq(64), 0.12, SOFT, 0.3, 0.3, hold_s=0.15)
    return finish(buf, 0.45)


def make_bump():
    buf = blank(0.5)
    tone(buf, 0.0, freq(64), 0.6, SOFT, 0.003, 0.18, glide_to=freq(52), glide_s=0.3, vibrato=1.2)
    noise(buf, 0.0, 0.05, 0.25, 0.012, smooth=0.5, seed=3)
    return finish(buf)


def make_crash():
    buf = blank(1.0)
    tone(buf, 0.0, freq(52), 0.6, WOOD, 0.001, 0.06)  # bonk
    tone(buf, 0.0, freq(64), 0.35, WOOD, 0.001, 0.04)
    noise(buf, 0.0, 0.2, 0.35, 0.05, smooth=0.85, seed=4)  # thud
    tone(buf, 0.12, freq(76), 0.35, SOFT, 0.01, 0.3, glide_to=freq(57), glide_s=0.6, vibrato=0.5)  # sad slide
    return finish(buf)


def make_takeoff():
    buf = blank(0.45)
    rng = random.Random(8)
    s0, n = 0, round(0.4 * SR)
    y = 0.0
    for k in range(n):
        t = k / n
        cutoff = 0.05 + 0.6 * t  # the hiss brightens as it rises
        y += cutoff * (rng.uniform(-1, 1) - y)
        buf[s0 + k] += 0.3 * math.sin(math.pi * t) ** 2 * y
    tone(buf, 0.05, freq(69), 0.25, SOFT, 0.05, 0.12, glide_to=freq(81), glide_s=0.25)
    return finish(buf, 0.6)


def make_ghost():
    buf = blank(0.9)
    for i, midi in enumerate([88, 91, 93, 96]):
        tone(buf, i * 0.07, freq(midi), 0.2, BELL, 0.003, 0.3)
    return finish(buf, 0.55)


def make_milestone():
    buf = blank(0.9)
    tone(buf, 0.0, freq(81), 0.4, BELL, 0.002, 0.35)
    tone(buf, 0.12, freq(88), 0.45, BELL, 0.002, 0.45)
    return finish(buf, 0.7)


def make_new_best():
    buf = blank(1.2)
    for i, midi in enumerate([72, 76, 79]):
        tone(buf, i * 0.1, freq(midi), 0.35, BRIGHT, 0.003, 0.12)
    for midi in (84, 88, 91):
        tone(buf, 0.3, freq(midi), 0.25, BRIGHT, 0.004, 0.35, hold_s=0.15)
    return finish(buf)


def make_hollow_pop():
    """A Hollow One torn apart by the shield: a ragged rip of cloth and a shriek that falls away."""
    buf = blank(0.7)
    rng = random.Random(9)
    n = round(0.25 * SR)
    for k in range(n):  # the rip: noise in stuttering bursts
        gate = 1.0 if rng.random() < 0.7 else 0.2
        buf[k] += 0.45 * gate * rng.uniform(-1, 1) * (1 - k / n)
    tone(buf, 0.02, freq(88), 0.3, BRIGHT, 0.004, 0.25, glide_to=freq(64), glide_s=0.5, vibrato=1.5)  # shriek
    tone(buf, 0.02, freq(89), 0.2, BRIGHT, 0.004, 0.25, glide_to=freq(65), glide_s=0.5, vibrato=1.8)  # off-key twin
    return finish(buf, 0.7)


def make_realm():
    """A low swell under rising bells on A, C, E, F, A: A minor with the darker flat sixth."""
    buf = blank(2.6)
    tone(buf, 0.0, freq(45), 0.35, WARM, 0.5, 0.7, hold_s=0.5)
    tone(buf, 0.0, freq(52), 0.2, WARM, 0.6, 0.7, hold_s=0.4)
    for i, midi in enumerate([81, 84, 88, 89, 93]):
        start = 0.12 + i * 0.16
        for echo, gain in ((0.0, 1.0), (0.3, 0.35), (0.6, 0.12)):
            tone(buf, start + echo, freq(midi), 0.14 * gain, BELL, 0.003, 0.8)
    noise(buf, 0.0, 1.6, 0.03, 0.6, smooth=0.6, seed=12)  # a breath of wind
    return finish(buf, 0.7)


def make_memory():
    """A little music-box tune, falling, each note doubled a hair out of tune, over a soft swell."""
    buf = blank(3.0)
    noise(buf, 0.0, 0.6, 0.04, 0.4, smooth=0.7, seed=13)
    for i, midi in enumerate([88, 84, 83, 81, 76, 77, 76]):
        start = 0.05 + i * 0.26
        for detune in (1.0, 1.006):
            tone(buf, start, freq(midi) * detune, 0.12, BELL, 0.002, 0.6)
    tone(buf, 0.0, freq(45), 0.25, WARM, 0.8, 0.9, hold_s=0.6)
    return finish(buf, 0.7)


def make_glitch():
    """Static chopped into stutters, over a pitch that drops in jagged steps."""
    buf = blank(0.3)
    rng = random.Random(14)
    n = len(buf)
    for k in range(n):
        gate = 1.0 if (k // 180) % 3 != 1 else 0.0
        buf[k] += 0.4 * gate * rng.uniform(-1, 1) * (1 - k / n)
    for i, midi in enumerate([84, 77, 71, 66]):
        s0 = round(i * 0.06 * SR)
        f = freq(midi)
        for k in range(round(0.05 * SR)):
            if s0 + k < n:
                buf[s0 + k] += 0.3 * (1 if math.sin(TAU * f * k / SR) > 0 else -1)  # square: harsh
    return finish(buf, 0.6)


def make_click():
    buf = blank(0.08)
    tone(buf, 0.0, freq(84), 0.5, WOOD, 0.001, 0.015)
    return finish(buf, 0.5)


def make_buy():
    buf = blank(0.8)
    noise(buf, 0.0, 0.06, 0.2, 0.015, smooth=0.0, seed=10)  # ka-
    for i, midi in enumerate([88, 93]):
        tone(buf, 0.05 + i * 0.08, freq(midi), 0.4, BELL, 0.002, 0.3)  # -ching
    tone(buf, 0.05, freq(81), 0.2, BRIGHT, 0.003, 0.25)
    return finish(buf)


def make_nope():
    buf = blank(0.35)
    tone(buf, 0.0, freq(57), 0.4, SOFT, 0.003, 0.06)
    tone(buf, 0.1, freq(53), 0.45, SOFT, 0.003, 0.1)
    return finish(buf, 0.6)


def main():
    out_dir = os.path.join("assets", "audio", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    makers = dict(
        shield=make_shield,
        bump=make_bump,
        crash=make_crash,
        takeoff=make_takeoff,
        ghost=make_ghost,
        milestone=make_milestone,
        new_best=make_new_best,
        hollow_pop=make_hollow_pop,
        realm=make_realm,
        memory=make_memory,
        glitch=make_glitch,
        click=make_click,
        buy=make_buy,
        nope=make_nope,
    )
    for name, make in makers.items():
        write(os.path.join(out_dir, f"{name}.wav"), make())


if __name__ == "__main__":
    main()
