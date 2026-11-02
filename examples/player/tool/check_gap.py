#!/usr/bin/env python3
"""Mede a emenda num seno gravado da saída de som (pw-record), em WAV de 16 bits.

Diz o maior silêncio entre o começo e o fim do tom, onde ele está, e quantos saltos
há no sinal.
"""
import struct
import sys
import wave


def main(path):
    with wave.open(path) as w:
        rate, channels = w.getframerate(), w.getnchannels()
        raw = w.readframes(w.getnframes())
    samples = struct.unpack(f"<{len(raw) // 2}h", raw)[::channels]
    peak = max((abs(s) for s in samples), default=0)
    if not peak:
        print("sem sinal")
        return
    threshold = peak * 0.1
    loud = [i for i, s in enumerate(samples) if abs(s) > threshold]
    start, end = loud[0], loud[-1]
    # Um período de 440 Hz cruza o limiar a cada poucas amostras: o resto é buraco
    gap, where = max((b - a, a) for a, b in zip(loud, loud[1:]))
    clicks = 0
    jump = peak * 0.05
    for i in range(start + 2, end):
        if abs(samples[i] - 2 * samples[i - 1] + samples[i - 2]) > jump:
            clicks += 1
    print(
        f"tom {(end - start) / rate:.2f} s, pico {peak}, "
        f"maior buraco {gap / rate * 1000:.1f} ms em {(where - start) / rate:.2f} s, "
        f"saltos {clicks}"
    )


if __name__ == "__main__":
    main(sys.argv[1])
