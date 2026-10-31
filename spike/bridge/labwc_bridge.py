#!/usr/bin/env python3
"""Esboço da ponte do labwc: as configurações do Psito viram a do compositor.

Lê ~/.config/psito/settings.json (o mesmo do system_shell), reescreve o
themerc-override e a seção <keyboard> do rc.xml em ~/.config/labwc e manda o
labwc recarregar. A ponte de verdade vai ser Dart, no shell (fase 4); este
script só valida a ideia, no modelo da ponte do labwc do Budgie 10.10.

Uso: labwc_bridge.py [--config-home DIR] [--no-reload]
"""
import argparse
import json
import os
import re
import subprocess
from pathlib import Path

DEFAULT_ACCENT = 0xFFFFC107
BACKGROUND = "#12181B"
TEXT = "#E0E0E0"

# Espelha a shellBindings de system_shell/lib/shell/shortcuts.dart:
# combinação do labwc -> ação do Psito. As nativas e as de VM.
BINDINGS = [
    ("A-Tab", "switchNext"),
    ("A-S-Tab", "switchPrev"),
    ("A-F4", "closeWindow"),
    ("W-q", "closeWindow"),
    ("W-Up", "maximize"),
    ("W-Left", "snapLeft"),
    ("W-Right", "snapRight"),
    ("W-Down", "minimize"),
    ("XF86AudioRaiseVolume", "volumeUp"),
    ("XF86AudioLowerVolume", "volumeDown"),
    ("XF86AudioMute", "volumeMute"),
    ("C-space", "launcher"),
    ("C-Tab", "switchNext"),
    ("C-S-Tab", "switchPrev"),
    ("C-A-w", "closeWindow"),
    ("A-S-Up", "maximize"),
    ("A-S-Left", "snapLeft"),
    ("A-S-Right", "snapRight"),
    ("A-S-Down", "minimize"),
    ("A-S-Prior", "volumeUp"),
    ("A-S-Next", "volumeDown"),
    ("A-S-m", "volumeMute"),
]

# Ação do Psito -> ação do labwc. O que é do shell vira Execute de um comando:
# o launcher chama o shell pelo D-Bus da sessão (spike/shell_client); o volume
# ainda vai direto ao wpctl.
ACTIONS = {
    "switchNext": '<action name="NextWindow" />',
    "switchPrev": '<action name="PreviousWindow" />',
    "closeWindow": '<action name="Close" />',
    "maximize": '<action name="ToggleMaximize" />',
    "snapLeft": '<action name="SnapToEdge" direction="left" />',
    "snapRight": '<action name="SnapToEdge" direction="right" />',
    "minimize": '<action name="Iconify" />',
    "launcher": '<action name="Execute" command="gdbus call --session --dest org.psito.Shell --object-path /org/psito/Shell --method org.psito.Shell.ToggleLauncher" />',
    "volumeUp": '<action name="Execute" command="wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" />',
    "volumeDown": '<action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" />',
    "volumeMute": '<action name="Execute" command="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" />',
}


def read_accent(settings_file: Path) -> str:
    accent = DEFAULT_ACCENT
    try:
        data = json.loads(settings_file.read_text())
        if isinstance(data.get("accent"), int):
            accent = data["accent"]
    except (OSError, ValueError):
        pass
    return "#%06X" % (accent & 0xFFFFFF)


def themerc(accent: str) -> str:
    return f"""# Gerado pela ponte do Psito (spike/bridge/labwc_bridge.py). Não edite.
border.width: 1
window.titlebar.padding.height: 4
window.active.title.bg.color: {accent}
window.active.label.text.color: {BACKGROUND}
window.active.button.unpressed.image.color: {BACKGROUND}
window.active.border.color: {accent}
window.inactive.title.bg.color: {BACKGROUND}
window.inactive.label.text.color: {TEXT}
window.inactive.button.unpressed.image.color: {TEXT}
window.inactive.border.color: {BACKGROUND}
osd.bg.color: {BACKGROUND}
osd.border.color: {accent}
osd.label.text.color: {TEXT}
osd.window-switcher.item.active.border.color: {accent}
"""


def keyboard() -> str:
    lines = ["  <keyboard>", "    <!-- Gerado pela ponte do Psito. Não edite. -->", "    <default />"]
    for key, action in BINDINGS:
        lines.append(f'    <keybind key="{key}">{ACTIONS[action]}</keybind>')
    lines.append("  </keyboard>")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config-home", type=Path,
                        default=Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")))
    parser.add_argument("--no-reload", action="store_true")
    args = parser.parse_args()

    labwc = args.config_home / "labwc"
    accent = read_accent(args.config_home / "psito" / "settings.json")
    (labwc / "themerc-override").write_text(themerc(accent))

    rc = labwc / "rc.xml"
    text = rc.read_text()
    text, n = re.subn(r"  <keyboard>.*?</keyboard>", lambda _: keyboard(), text, flags=re.S)
    if n != 1:
        raise SystemExit(f"rc.xml sem uma seção <keyboard>: {rc}")
    rc.write_text(text)
    print(f"ponte: destaque {accent}, {len(BINDINGS)} atalhos em {labwc}")

    if not args.no_reload:
        # O --reconfigure acha o labwc pelo LABWC_PID, que só existe nos filhos
        # dele; de fora da sessão (ssh), o pid vem do pgrep
        env = dict(os.environ)
        if "LABWC_PID" not in env:
            env["LABWC_PID"] = subprocess.run(["pgrep", "-o", "-x", "labwc"], check=True,
                                              capture_output=True, text=True).stdout.strip()
        subprocess.run(["labwc", "--reconfigure"], check=True, env=env)


if __name__ == "__main__":
    main()
