#!/bin/bash
# Sobe um compositor do spike no tty1 da VM do spike.
# Uso: spike/session.sh weston | stop | status
set -e

VM_PORT="${VM_PORT:-2223}"
vm() { ssh -p "$VM_PORT" psito@localhost "$@"; }

case "$1" in
    weston)
        CMD="weston --backend=drm --config=/etc/psito-spike/weston.ini"
        ;;
    stop)
        vm "sudo systemctl stop psito-spike.service"
        exit 0
        ;;
    status)
        vm "systemctl status --no-pager -n 20 psito-spike.service" || true
        exit 0
        ;;
    *)
        echo "Uso: spike/session.sh weston | stop | status"
        exit 1
        ;;
esac

echo "🖥️  Subindo $1 no tty1..."
vm "mkdir -p /tmp/spike && echo 'SPIKE_CMD=$CMD' | sudo tee /etc/default/psito-spike >/dev/null && sudo systemctl restart psito-spike.service"

# Espera o socket do Wayland aparecer
for _ in $(seq 20); do
    if vm 'ls /run/user/1000/wayland-* 2>/dev/null | grep -qv lock'; then
        echo "✅ $1 rodando."
        exit 0
    fi
    sleep 0.5
done
echo "❌ $1 não criou o socket do Wayland. Veja: spike/session.sh status"
exit 1
