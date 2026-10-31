#!/bin/bash
# Roda DENTRO da VM, como root, chamado pelo provision.sh do host.
# Pode ser rodado de novo: cada passo verifica o estado antes de agir.
set -e

SRC="$(dirname "$(readlink -f "$0")")"
APP_USER="${APP_USER:-psito}"
FLUTTER_VERSION="${FLUTTER_VERSION:?}"
FLUTTER_DIR="/home/$APP_USER/flutter"
CONF="/home/$APP_USER/.config"

echo "📦 [VM] Dependências..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
# O labwc e o que o shell usa na sessão (cursor, modo da tela, capturas)
apt-get install -y -qq --no-install-recommends \
    labwc wlr-randr libgl1-mesa-dri mesa-vulkan-drivers fontconfig fonts-dejavu \
    libnotify-bin grim foot firefox-esr >/dev/null
# Para compilar o shell e os apps (Flutter Linux, GTK 3 e gtk-layer-shell)
apt-get install -y -qq \
    git rsync curl unzip xz-utils clang cmake ninja-build pkg-config \
    libgtk-3-dev libgtk-layer-shell-dev libwayland-bin >/dev/null

# Serviços que o shell consome via D-Bus (fase 2)
apt-get install -y -qq \
    network-manager upower polkitd \
    pipewire wireplumber pipewire-pulse pulseaudio-utils >/dev/null

echo "🐦 [VM] Flutter $FLUTTER_VERSION..."
if [ ! -d "$FLUTTER_DIR/.git" ]; then
    sudo -u "$APP_USER" git clone -q --depth 1 -b "$FLUTTER_VERSION" \
        https://github.com/flutter/flutter "$FLUTTER_DIR"
fi
sudo -u "$APP_USER" -H "$FLUTTER_DIR/bin/flutter" --disable-analytics >/dev/null
sudo -u "$APP_USER" -H "$FLUTTER_DIR/bin/flutter" precache --linux >/dev/null

echo "🪟 [VM] Sessão: labwc e o shell como unidade do usuário..."
# O flutter-pi das versões antigas sai
rm -f /usr/local/bin/flutter-pi /etc/default/psito-os
rm -rf /opt/psito-app
install -d -o "$APP_USER" -g "$APP_USER" /opt/psito
install -m 755 "$SRC/session/psito-shell-start" /usr/local/bin/psito-shell-start
# No home, e não no /etc: a ponte edita o rc.xml com o labwc rodando
install -d -o "$APP_USER" -g "$APP_USER" "$CONF" "$CONF/labwc" "$CONF/systemd" "$CONF/systemd/user"
# A seção <keyboard> e o tema voltam ao neutro; o shell aplica de novo ao subir
install -o "$APP_USER" -g "$APP_USER" -m 644 "$SRC"/session/labwc/* "$CONF/labwc/"
install -o "$APP_USER" -g "$APP_USER" -m 644 "$SRC/session/psito-shell.service" \
    "$CONF/systemd/user/psito-shell.service"
install -m 644 "$SRC/psito-os.service" /etc/systemd/system/psito-os.service
systemctl daemon-reload
systemctl enable -q psito-os.service

echo "🌐 [VM] Rede e permissões..."
# O NetworkManager ignora interfaces do ifupdown: o ens3 sai do interfaces.
# Derrubar o ens3 agora cortaria este SSH, então a troca vale no próximo boot.
NEED_REBOOT=0
if grep -q '^[^#]*ens3' /etc/network/interfaces; then
    cp /etc/network/interfaces /etc/network/interfaces.bak
    cat > /etc/network/interfaces <<'IFACES'
# A rede é gerida pelo NetworkManager (provision-guest.sh do Psito OS).
# Configuração anterior em interfaces.bak.
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
IFACES
    NEED_REBOOT=1
fi
install -d -m 755 /etc/polkit-1/rules.d
install -m 644 "$SRC/polkit/50-psito.rules" /etc/polkit-1/rules.d/50-psito.rules

if [ "$NEED_REBOOT" = 1 ]; then
    systemd-run -q --on-active=3 systemctl reboot
    echo "🔁 [VM] A rede passou para o NetworkManager: reiniciando em 3 s."
fi

echo "✅ [VM] Provisionamento concluído."
