#!/bin/bash
# Abre um cliente no compositor que estiver rodando na VM do spike e imprime o pid.
# Ex.: spike/client.sh foot
#      PROBE_NAME=probe1 spike/client.sh /home/psito/probe/probe
# Variáveis PROBE_* e WAYLAND_DEBUG passam para o cliente.
set -e

VM_PORT="${VM_PORT:-2223}"
if [ -z "$1" ]; then
    echo "Uso: spike/client.sh <comando> [args]"
    exit 1
fi

ENV=""
for var in $(compgen -e | grep -E '^(PROBE_|WAYLAND_DEBUG$)'); do
    ENV+="$var=$(printf %q "${!var}") "
done

ssh -p "$VM_PORT" psito@localhost "bash -s -- $(printf '%q ' "$@")" <<SCRIPT
export XDG_RUNTIME_DIR=/run/user/1000
socket=\$(ls \$XDG_RUNTIME_DIR | grep -E '^wayland-[0-9]+$' | head -n 1)
if [ -z "\$socket" ]; then
    echo "❌ Nenhum compositor rodando (spike/session.sh weston)." >&2
    exit 1
fi
export WAYLAND_DISPLAY=\$socket GDK_BACKEND=wayland $ENV
mkdir -p /tmp/spike
log=/tmp/spike/\$(basename "\$1")-\$\$.log
setsid nohup "\$@" >"\$log" 2>&1 </dev/null &
echo \$!
SCRIPT
