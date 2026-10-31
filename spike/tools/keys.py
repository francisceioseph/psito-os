#!/usr/bin/env python3
"""Teclado virtual (uinput) que aperta combinações, para testar os atalhos.

Roda dentro da VM, com sudo. Cada argumento é uma combinação com as teclas do
evdev sem o KEY_, separadas por +; "hold:" segura os modificadores entre as
combinações seguintes até um "release", e "sleep:<ms>" espera.
Uso: sudo python3 keys.py leftctrl+tab
     sudo python3 keys.py hold:leftctrl tab tab sleep:500 release
"""
import sys
import time

from evdev import UInput, ecodes as e


def code(name: str) -> int:
    return getattr(e, "KEY_" + name.upper())


steps = sys.argv[1:]
names = {n for step in steps if ":" not in step or step.startswith("hold:")
         for n in step.split(":")[-1].split("+") if n and n != "release"}
with UInput({e.EV_KEY: [code(n) for n in names]}, name="psito-spike-keys") as ui:
    # O compositor precisa de um tempo para abrir o dispositivo novo
    time.sleep(1.5)
    held: list[int] = []

    def press(keys: list[int], value: int) -> None:
        for key in keys if value else reversed(keys):
            ui.write(e.EV_KEY, key, value)
            ui.syn()
            time.sleep(0.02)

    for step in steps:
        if step.startswith("sleep:"):
            time.sleep(int(step[6:]) / 1000)
        elif step.startswith("hold:"):
            held = [code(n) for n in step[5:].split("+")]
            press(held, 1)
        elif step == "release":
            press(held, 0)
            held = []
        else:
            keys = [code(n) for n in step.split("+")]
            press(keys, 1)
            press(keys, 0)
        time.sleep(0.15)
    press(held, 0)
