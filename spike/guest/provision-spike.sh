#!/bin/bash
# Roda DENTRO da VM do spike, como root, chamado pelo spike/provision.sh.
set -e

SRC="$(dirname "$(readlink -f "$0")")"
APP_USER="${APP_USER:-psito}"
FLUTTER_VERSION="${FLUTTER_VERSION:?}"
FLUTTER_DIR="/home/$APP_USER/flutter"

echo "📦 [spike] Pacotes..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    weston foot gtk-4-examples \
    mesa-utils wayland-utils python3-evdev \
    clang cmake ninja-build libgtk-3-dev curl unzip xz-utils >/dev/null
# Etapa 3: as bases candidatas, o waybar como painel layer-shell de teste e um
# app comum pesado. Sem recomendados: o wayfire puxaria o wf-shell.
apt-get install -y -qq --no-install-recommends \
    labwc wayfire wlr-randr wlrctl waybar firefox-esr fonts-dejavu >/dev/null
# Etapa 4: o shell como cliente layer-shell (spike/shell_client)
apt-get install -y -qq libgtk-layer-shell-dev libwayland-bin >/dev/null
# Etapa 5: notify-send, um app GTK 3 para o tema da ponte e o grim (capturas)
apt-get install -y -qq libnotify-bin gtk-3-examples grim >/dev/null

echo "🐦 [spike] Flutter $FLUTTER_VERSION..."
if [ ! -d "$FLUTTER_DIR/.git" ]; then
    sudo -u "$APP_USER" git clone -q --depth 1 -b "$FLUTTER_VERSION" \
        https://github.com/flutter/flutter "$FLUTTER_DIR"
fi
sudo -u "$APP_USER" -H "$FLUTTER_DIR/bin/flutter" --disable-analytics >/dev/null
sudo -u "$APP_USER" -H "$FLUTTER_DIR/bin/flutter" precache --linux >/dev/null

echo "⚙️  [spike] Sessão do spike no tty1..."
# O spike usa o tty1 e o DRM: o shell da fase 2 não sobe nesta VM
systemctl disable -q --now psito-os.service 2>/dev/null || true
install -m 644 "$SRC/psito-spike.service" /etc/systemd/system/psito-spike.service
install -d -m 755 /etc/psito-spike
install -m 644 "$SRC/weston.ini" /etc/psito-spike/weston.ini
systemctl daemon-reload

echo "🪟 [spike] Configuração do labwc, do Wayfire e do waybar..."
# No home, e não no /etc: a ponte edita com o compositor rodando
CONF="/home/$APP_USER/.config"
install -d -o "$APP_USER" -g "$APP_USER" "$CONF" "$CONF/labwc" "$CONF/waybar"
install -o "$APP_USER" -g "$APP_USER" -m 644 "$SRC"/labwc/* "$CONF/labwc/"
install -o "$APP_USER" -g "$APP_USER" -m 644 "$SRC"/waybar/* "$CONF/waybar/"
install -o "$APP_USER" -g "$APP_USER" -m 644 "$SRC/wayfire.ini" "$CONF/wayfire.ini"

echo "🦜 [spike] O shell como unidade do systemd do usuário..."
install -m 755 "$SRC/psito-shell-start" /usr/local/bin/psito-shell-start
install -d -o "$APP_USER" -g "$APP_USER" "$CONF/systemd" "$CONF/systemd/user"
install -o "$APP_USER" -g "$APP_USER" -m 644 "$SRC/systemd/psito-shell.service" \
    "$CONF/systemd/user/psito-shell.service"
sudo -u "$APP_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$APP_USER")" \
    systemctl --user daemon-reload 2>/dev/null || true

echo "✅ [spike] Pronto. Suba um compositor com spike/session.sh weston|labwc|wayfire."
