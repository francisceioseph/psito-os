#!/usr/bin/env python3
"""Junta o CSV do injetor com o do probe e calcula a latência de entrada.

Para cada tecla:
  entrega = chegada no probe - injeção   (compositor + GTK + engine)
  frame   = rasterFinish do primeiro frame construído depois da chegada
            - injeção                    (até o frame ficar pronto no cliente)
A apresentação na tela, depois do rasterFinish, não entra.
Uso: latency.py <inject.csv> <probe.csv>  Saída: métrica,valor (ms)
"""
import statistics
import sys


def read(path, kind):
    rows = []
    with open(path) as f:
        for line in f:
            parts = line.strip().split(",")
            if parts[0] == kind:
                rows.append([int(p) for p in parts[1:]])
    return rows


def percentile(values, p):
    values = sorted(values)
    return values[min(len(values) - 1, round(p / 100 * (len(values) - 1)))]


def main(inject_path, probe_path):
    injected = {seq: t for seq, t in read(inject_path, "inject")}
    received = read(probe_path, "recv")
    # FrameTiming é em µs; o resto em ns
    frames = sorted((b * 1000, r * 1000) for b, r in read(probe_path, "frame"))

    delivery, frame = [], []
    # O probe numera as teclas na ordem em que chegam, como o injetor
    for seq, t_recv in received:
        t_inj = injected.get(seq)
        if t_inj is None:
            continue
        delivery.append((t_recv - t_inj) / 1e6)
        ready = next((r for b, r in frames if b >= t_recv), None)
        if ready is not None:
            frame.append((ready - t_inj) / 1e6)

    print(f"latencia_teclas_injetadas,{len(injected)}")
    print(f"latencia_teclas_recebidas,{len(delivery)}")
    for name, values in (("entrega", delivery), ("frame", frame)):
        if values:
            print(f"latencia_{name}_mediana_ms,{statistics.median(values):.2f}")
            print(f"latencia_{name}_p95_ms,{percentile(values, 95):.2f}")


if __name__ == "__main__":
    main(*sys.argv[1:3])
