#!/bin/bash
# Roda DENTRO da VM do spike, como root, chamado pelo spike/zenith/install.sh.
# Instala o que o Zenith pedia em 2023: wlroots 0.15.1 e Flutter 3.10.6.
set -e

APP_USER="${APP_USER:-psito}"
HOME_DIR="/home/$APP_USER"
WLROOTS_VERSION="0.15.1"
FLUTTER_VERSION="3.10.6"
# Último commit do Zenith; o código é o de agosto de 2023 (f38f553)
ZENITH_COMMIT="aa7df0f"
as_user() { sudo -u "$APP_USER" -H "$@"; }

echo "📦 [zenith] Pacotes..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq \
    libgl-dev libegl-dev libgles-dev libepoxy-dev libwayland-dev libxkbcommon-dev \
    libpixman-1-dev libinput-dev libpam0g-dev seatd \
    meson wayland-protocols libseat-dev libdrm-dev libgbm-dev libudev-dev \
    libxcb1-dev libxcb-composite0-dev libxcb-icccm4-dev libxcb-render0-dev \
    libxcb-res0-dev libxcb-xfixes0-dev xwayland >/dev/null

echo "🔨 [zenith] wlroots $WLROOTS_VERSION em /usr/local..."
# O Zenith inclui wlr/xwayland.h: o wlroots precisa do Xwayland
if [ "$(pkg-config --modversion wlroots 2>/dev/null)" != "$WLROOTS_VERSION" ] ||
    [ ! -f /usr/local/include/wlr/xwayland.h ]; then
    src="$HOME_DIR/vendor/wlroots-$WLROOTS_VERSION"
    [ -d "$src" ] || as_user git clone -q --depth 1 -b "$WLROOTS_VERSION" \
        https://gitlab.freedesktop.org/wlroots/wlroots.git "$src"
    cd "$src"
    as_user meson setup --wipe build --prefix=/usr/local --buildtype=release \
        -Dwerror=false -Dexamples=false -Dxwayland=enabled \
        -Dbackends=drm,libinput -Drenderers=gles2 >/dev/null
    as_user ninja -C build >/dev/null
    ninja -C build install >/dev/null
    ldconfig
fi

echo "🐦 [zenith] Flutter $FLUTTER_VERSION..."
flutter_dir="$HOME_DIR/flutter-$FLUTTER_VERSION"
if [ ! -d "$flutter_dir/.git" ]; then
    as_user git clone -q --depth 1 -b "$FLUTTER_VERSION" \
        https://github.com/flutter/flutter "$flutter_dir"
fi
as_user "$flutter_dir/bin/flutter" config --no-analytics >/dev/null
as_user "$flutter_dir/bin/flutter" config --enable-linux-desktop >/dev/null
as_user "$flutter_dir/bin/flutter" precache --linux >/dev/null

echo "📥 [zenith] Zenith $ZENITH_COMMIT..."
zenith="$HOME_DIR/vendor/zenith"
if [ ! -d "$zenith/.git" ]; then
    as_user git clone -q https://github.com/roscale/zenith "$zenith"
fi
as_user git -C "$zenith" checkout -q -f "$ZENITH_COMMIT"

echo "🔐 [zenith] PAM..."
# O Zenith autentica a tela de bloqueio pelo serviço PAM "zenith"
if [ -f "$zenith/dpkg/etc/pam.d/zenith" ]; then
    install -m 644 "$zenith/dpkg/etc/pam.d/zenith" /etc/pam.d/zenith
else
    printf '@include common-auth\n@include common-account\n' > /etc/pam.d/zenith
fi

echo "✅ [zenith] Dependências prontas. Compile com spike/zenith/build.sh."
