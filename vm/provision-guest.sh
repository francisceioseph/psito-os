#!/bin/bash
# Roda DENTRO da VM, como root, chamado pelo provision.sh do host.
# Pode ser rodado de novo: cada passo verifica o estado antes de agir.
set -e

SRC="$(dirname "$(readlink -f "$0")")"
APP_USER="${APP_USER:-psito}"
FLUTTER_PI_DIR="/home/$APP_USER/flutter-pi"
FLUTTER_PI_REPO="https://github.com/ardera/flutter-pi"
FLUTTER_PI_COMMIT="${FLUTTER_PI_COMMIT:?}"

echo "📦 [VM] Dependências..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    build-essential cmake git pkg-config rsync fontconfig \
    libgl1-mesa-dev libgles2-mesa-dev libegl1-mesa-dev libgl1-mesa-dri mesa-vulkan-drivers \
    libdrm-dev libgbm-dev libinput-dev libudev-dev libxkbcommon-dev \
    libsystemd-dev libseat-dev >/dev/null

echo "🔨 [VM] flutter-pi ($FLUTTER_PI_COMMIT)..."
if [ ! -d "$FLUTTER_PI_DIR/.git" ]; then
    sudo -u "$APP_USER" git clone -q "$FLUTTER_PI_REPO" "$FLUTTER_PI_DIR"
fi
cd "$FLUTTER_PI_DIR"
if ! sudo -u "$APP_USER" git cat-file -e "$FLUTTER_PI_COMMIT^{commit}" 2>/dev/null; then
    sudo -u "$APP_USER" git fetch -q origin
fi
sudo -u "$APP_USER" git checkout -q -f "$FLUTTER_PI_COMMIT"
for p in "$SRC"/patches/flutter-pi-*.patch; do
    sudo -u "$APP_USER" git apply "$p"
done
sudo -u "$APP_USER" cmake -S . -B build -DCMAKE_BUILD_TYPE=Release >/dev/null
sudo -u "$APP_USER" cmake --build build -j"$(nproc)" >/dev/null
install -m 755 build/flutter-pi /usr/local/bin/flutter-pi

echo "⚙️  [VM] Serviço e diretório do app..."
mkdir -p /opt/psito-app
chown -R "$APP_USER:$APP_USER" /opt/psito-app
install -m 644 "$SRC/psito-os.service" /etc/systemd/system/psito-os.service
systemctl daemon-reload
systemctl enable -q psito-os.service

echo "✅ [VM] Provisionamento concluído."
