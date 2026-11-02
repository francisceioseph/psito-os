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
    libgtk-3-dev libgtk-layer-shell-dev libwayland-bin libpam0g-dev >/dev/null
# Para empacotar o shell e os apps (tools/psito-deb)
apt-get install -y -qq --no-install-recommends patchelf >/dev/null

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

echo "🪟 [VM] Sessão: o greetd com o labwc..."
# A sessão (psito-session, a unidade psito-shell, o sandbox e os portais) vem
# do pacote psito-shell, que o deploy.sh instala. O que as versões antigas
# punham à mão sai, para não ganhar do pacote.
rm -f /usr/local/bin/flutter-pi /etc/default/psito-os \
    /usr/local/bin/psito-shell-start /usr/local/bin/psito-sandbox \
    "$CONF/systemd/user/psito-shell.service" \
    "$CONF/xdg-desktop-portal/labwc-portals.conf"
rm -rf /opt/psito-app /opt/psito
# O virtio-gpu prefere um modo pequeno, e quem aplica a resolução é o shell
# (docs/FASE-12.md). O que já está gravado continua valendo.
sed -i '/wlr-randr/d;/virtio-gpu anuncia/d' "$CONF/labwc/autostart" 2>/dev/null || true
if [ ! -e "$CONF/psito/monitors.json" ]; then
    sudo -u "$APP_USER" mkdir -p "$CONF/psito"
    sudo -u "$APP_USER" tee "$CONF/psito/monitors.json" >/dev/null <<'MONITORS'
{
  "monitors": {
    "Red Hat, Inc.|QEMU Monitor|Virtual-1": {"width": 1440, "height": 900}
  }
}
MONITORS
fi
# A sessão é do greetd (pacote psito-greeter), com o login automático na VM para
# os scripts acharem o shell de pé. Antes do primeiro deploy.sh o greetd falha, e
# é o deploy que sobe ele.
systemctl disable -q --now psito-os.service 2>/dev/null || true
rm -f /etc/systemd/system/psito-os.service
apt-get install -y -qq greetd cage >/dev/null
install -D -m 644 "$SRC/greetd-autologin.toml" /etc/psito/greetd-autologin.toml
install -D -m 644 "$SRC/greetd-autologin.conf" /etc/systemd/system/greetd.service.d/zz-autologin.conf
systemctl daemon-reload
systemctl enable -q greetd.service
systemctl reset-failed greetd.service 2>/dev/null || true
systemctl restart greetd.service

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
# Saiu quando o shell ganhou o agente do polkit: valem os padrões
rm -f /etc/polkit-1/rules.d/50-psito.rules

if [ "$NEED_REBOOT" = 1 ]; then
    systemd-run -q --on-active=3 systemctl reboot
    echo "🔁 [VM] A rede passou para o NetworkManager: reiniciando em 3 s."
fi

echo "✅ [VM] Provisionamento concluído."
