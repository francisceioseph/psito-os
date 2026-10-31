#!/usr/bin/env python3
"""Ponteiro virtual absoluto (uinput), para testar cliques e o arrastar.

Roda dentro da VM, com sudo. As coordenadas são da tela (o tamanho vem de
--screen, padrão 1440x900). Cada argumento é um passo:
  move:x,y        vai até o ponto
  down / up       aperta ou solta o botão esquerdo
  click:x,y       vai, aperta e solta
  rclick:x,y      o mesmo com o botão direito
  drag:x,y        vai até o ponto em passos, com o botão apertado
  sleep:<ms>      espera
Uso: sudo python3 pointer.py move:100,100 down drag:700,860 sleep:500 up
"""
import sys
import time

from evdev import AbsInfo, UInput, ecodes as e

MAX = 32767

args = sys.argv[1:]
width, height = 1440, 900
if args and args[0].startswith("--screen="):
    width, height = (int(v) for v in args.pop(0)[9:].split("x"))

caps = {
    # Como o tablet USB do QEMU: botões e eixos absolutos, sem caneta
    e.EV_KEY: [e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE],
    e.EV_ABS: [
        (e.ABS_X, AbsInfo(0, 0, MAX, 0, 0, 0)),
        (e.ABS_Y, AbsInfo(0, 0, MAX, 0, 0, 0)),
    ],
}
with UInput(caps, name="psito-spike-pointer") as ui:
    # O compositor precisa de um tempo para abrir o dispositivo novo
    time.sleep(1.5)
    pos = [width // 2, height // 2]

    def move(x: int, y: int) -> None:
        pos[:] = [x, y]
        ui.write(e.EV_ABS, e.ABS_X, x * MAX // width)
        ui.write(e.EV_ABS, e.ABS_Y, y * MAX // height)
        ui.syn()

    def button(value: int, code: int = e.BTN_LEFT) -> None:
        ui.write(e.EV_KEY, code, value)
        ui.syn()
        time.sleep(0.05)

    for step in args:
        name, _, value = step.partition(":")
        if name == "sleep":
            time.sleep(int(value) / 1000)
        elif name == "down":
            button(1)
        elif name == "up":
            button(0)
        elif name in ("move", "click", "rclick", "drag"):
            x, y = (int(v) for v in value.split(","))
            if name == "drag":
                x0, y0 = pos
                for i in range(1, 41):
                    move(x0 + (x - x0) * i // 40, y0 + (y - y0) * i // 40)
                    time.sleep(0.02)
            else:
                move(x, y)
                time.sleep(0.05)
            if name == "click":
                button(1)
                button(0)
            elif name == "rclick":
                button(1, e.BTN_RIGHT)
                button(0, e.BTN_RIGHT)
        else:
            sys.exit(f"passo desconhecido: {step}")
