#!/bin/bash
# A bancada de monitores (na VM, com a sessão gráfica de pé): uma segunda tela
# virtual do labwc, ligada e desligada a quente, sem reiniciar a VM.
#   monitor-lab.sh up     põe os atalhos de teste (Super+F9 e Super+F10) no rc.xml
#   monitor-lab.sh add    liga a tela virtual, de 1920x1080, à direita
#   monitor-lab.sh del    desliga a tela virtual
#   monitor-lab.sh down   tira a tela e os atalhos
# Com a tela ligada, o pointer.py cobre as duas: as coordenadas mudam.
set -e
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export LABWC_PID="$(pidof labwc)"
RC="$HOME/.config/labwc/rc.xml"
KEYS="sudo -n python3 /tmp/spike/tools/keys.py"
NAME=PSITO-LAB

case "$1" in
    up)
        grep -q "$NAME" "$RC" || sed -i "s|^  <keyboard>|  <keyboard>\n<keybind key=\"W-F9\"><action name=\"VirtualOutputAdd\" output_name=\"$NAME\"/></keybind>\n<keybind key=\"W-F10\"><action name=\"VirtualOutputRemove\" output_name=\"$NAME\"/></keybind>|" "$RC"
        labwc --reconfigure
        ;;
    add) $KEYS hold:leftmeta f9 release ;;
    del) $KEYS hold:leftmeta f10 release ;;
    down)
        $KEYS hold:leftmeta f10 release
        sed -i "/$NAME/d" "$RC"
        labwc --reconfigure
        ;;
    *)
        sed -n '2,7p' "$0" | sed 's/^# \?//'
        exit 1
        ;;
esac
