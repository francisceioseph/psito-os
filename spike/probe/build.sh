#!/bin/bash
# Compila o probe dentro da VM do spike (o binário do host pode exigir um glibc
# mais novo que o do Debian 13). O bundle fica em /home/psito/probe/probe.
set -e

cd "$(dirname "$0")"

VM_PORT="${VM_PORT:-2223}"

echo "📦 Enviando o probe..."
rsync -az --delete --exclude build/ --exclude .dart_tool/ --exclude linux/flutter/ephemeral/ \
    -e "ssh -p $VM_PORT" ./ psito@localhost:probe-src/

echo "🔨 flutter build linux --release na VM..."
ssh -p "$VM_PORT" psito@localhost '
    set -e
    cd probe-src
    ~/flutter/bin/flutter build linux --release 2>&1 | tail -n 3
    rsync -a --delete build/linux/x64/release/bundle/ ~/probe/
'
echo "✅ Probe em /home/psito/probe/probe"
