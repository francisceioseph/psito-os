#!/usr/bin/env python3
"""fps e p95 do tempo de build + raster a partir das linhas frame do probe.

Uso: fps.py <probe.csv> <prefixo>  Saída: <prefixo>_fps, <prefixo>_frame_p95_ms
"""
import sys


def main(path, prefix):
    frames = []
    with open(path) as f:
        for line in f:
            parts = line.strip().split(",")
            if parts[0] == "frame":
                frames.append((int(parts[1]), int(parts[2])))
    frames.sort()
    if len(frames) < 2:
        print(f"{prefix}_fps,0")
        return
    span = (frames[-1][0] - frames[0][0]) / 1e6
    durations = sorted((r - b) / 1000 for b, r in frames)
    p95 = durations[min(len(durations) - 1, round(0.95 * (len(durations) - 1)))]
    print(f"{prefix}_fps,{(len(frames) - 1) / span:.1f}")
    print(f"{prefix}_frame_p95_ms,{p95:.2f}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
