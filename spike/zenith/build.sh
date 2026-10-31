#!/bin/bash
# Compila o Zenith na VM do spike, com o Flutter 3.10.6, aplicando os patches
# de spike/patches/zenith-*.patch. Uso: spike/zenith/build.sh [release|profile|debug]
set -e

cd "$(dirname "$0")/.."

VM_PORT="${VM_PORT:-2223}"
MODE="${1:-release}"

ssh -p "$VM_PORT" psito@localhost "mkdir -p /tmp/spike/patches && rm -f /tmp/spike/patches/zenith-*.patch"
if compgen -G "patches/zenith-*.patch" >/dev/null; then
    rsync -az -e "ssh -p $VM_PORT" patches/zenith-*.patch psito@localhost:/tmp/spike/patches/
fi

ssh -p "$VM_PORT" psito@localhost "bash -s" <<SCRIPT
set -e
export PATH=\$HOME/flutter-3.10.6/bin:\$PATH
cd ~/vendor/zenith
git checkout -q -f aa7df0f
for p in /tmp/spike/patches/zenith-*.patch; do
    [ -e "\$p" ] || continue
    echo "🩹 \$(basename \$p)"
    git apply "\$p"
done
flutter pub get >/dev/null
make ${MODE}_bundle -j4
echo "✅ Zenith em ~/vendor/zenith/build/zenith/$MODE/bundle"
SCRIPT
