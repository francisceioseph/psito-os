#!/usr/bin/env python3
"""PSS de um processo separado pelo tipo de mapeamento, em KiB.

Roda dentro da VM. Serve para ver de onde vem a memória do shell: o heap do C
(malloc), a memória anônima sem nome (o heap do Dart e os buffers do Impeller
caem aqui), os mapeamentos da GPU (/dev/dri), o código do Flutter e o resto.
O smaps por mapeamento não tem Pss_Anon; o Anonymous é a memória anônima
residente (privada, no caso do shell).
Uso: python3 smaps_by_kind.py <pid>   Saída: tipo,pss_kib,anonima_kib
"""
import sys
from collections import defaultdict


def kind(name: str) -> str:
    if name == "[heap]":
        return "heap_c"
    if name == "" or name.startswith("[anon"):
        return "anonima"
    if name.startswith("/dev/dri") or "drm" in name:
        return "gpu"
    if "libflutter" in name:
        return "libflutter"
    if name.endswith("libapp.so"):
        return "libapp_dart"
    if "gallium" in name or "/dri/" in name or "libGL" in name or "libEGL" in name:
        return "mesa"
    if name.startswith("[stack"):
        return "pilhas"
    if name.startswith("["):
        return "outros"
    return "outras_libs"


pss = defaultdict(int)
anon = defaultdict(int)
current = "outros"
with open(f"/proc/{sys.argv[1]}/smaps") as smaps:
    for line in smaps:
        parts = line.split()
        if "-" in parts[0] and len(parts) >= 5 and ":" not in parts[0]:
            current = kind(parts[5] if len(parts) > 5 else "")
        elif parts[0] == "Pss:":
            pss[current] += int(parts[1])
        elif parts[0] == "Anonymous:":
            anon[current] += int(parts[1])
for k in sorted(pss, key=pss.get, reverse=True):
    print(f"{k},{pss[k]},{anon[k]}")
