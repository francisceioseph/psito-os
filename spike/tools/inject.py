#!/usr/bin/env python3
"""Teclado virtual (uinput) que aperta A N vezes e imprime inject,<seq>,<t_ns>.

Roda dentro da VM, com sudo. O instante é CLOCK_MONOTONIC, o mesmo relógio que
o probe usa ao receber a tecla.
Uso: sudo python3 inject.py [N=200] [intervalo_ms=50]
"""
import sys
import time

from evdev import UInput, ecodes as e

count = int(sys.argv[1]) if len(sys.argv) > 1 else 200
interval = (int(sys.argv[2]) if len(sys.argv) > 2 else 50) / 1000

with UInput({e.EV_KEY: [e.KEY_A]}, name="psito-spike-inject") as ui:
    # O compositor precisa de um tempo para abrir o dispositivo novo
    time.sleep(1.5)
    for seq in range(count):
        t = time.clock_gettime_ns(time.CLOCK_MONOTONIC)
        ui.write(e.EV_KEY, e.KEY_A, 1)
        ui.syn()
        print(f"inject,{seq},{t}", flush=True)
        time.sleep(0.01)
        ui.write(e.EV_KEY, e.KEY_A, 0)
        ui.syn()
        time.sleep(interval)
