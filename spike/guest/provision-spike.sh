#!/bin/bash
# Roda DENTRO da VM do spike, como root, chamado pelo spike/provision.sh.
set -e

SRC="$(dirname "$(readlink -f "$0")")"
APP_USER="${APP_USER:-psito}"

echo "📦 [spike] Pacotes..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    weston foot gtk-4-examples \
    mesa-utils wayland-utils python3-evdev \
    clang cmake ninja-build libgtk-3-dev curl unzip xz-utils >/dev/null
# O labwc, o Flutter e o shell vêm do provision.sh da raiz. Aqui: as outras
# bases, o waybar como painel de teste e um app GTK 3 para o tema da ponte.
# Sem recomendados: o wayfire puxaria o wf-shell.
apt-get install -y -qq --no-install-recommends \
    wayfire wlrctl waybar >/dev/null
apt-get install -y -qq gtk-3-examples >/dev/null

echo "⚙️  [spike] Sessão do spike no tty1..."
# O spike escolhe o compositor pelo session.sh: a sessão do labwc do
# A sessão de uso (o greetd) não sobe sozinha nesta VM
systemctl disable -q --now greetd.service 2>/dev/null || true
install -m 644 "$SRC/psito-spike.service" /etc/systemd/system/psito-spike.service
install -d -m 755 /etc/psito-spike
install -m 644 "$SRC/weston.ini" /etc/psito-spike/weston.ini
systemctl daemon-reload

echo "🪟 [spike] Configuração do Wayfire e do waybar..."
# A do labwc e a unidade do shell vêm do provision.sh da raiz (vm/session/)
CONF="/home/$APP_USER/.config"
install -d -o "$APP_USER" -g "$APP_USER" "$CONF/waybar"
install -o "$APP_USER" -g "$APP_USER" -m 644 "$SRC"/waybar/* "$CONF/waybar/"
install -o "$APP_USER" -g "$APP_USER" -m 644 "$SRC/wayfire.ini" "$CONF/wayfire.ini"

echo "✅ [spike] Pronto. Suba um compositor com spike/session.sh weston|labwc|wayfire."
