#!/bin/bash
# Instala na VM do spike as dependências do Zenith (wlroots 0.15.1, Flutter
# 3.10.6) e clona o Zenith em ~/vendor/zenith. Pode ser rodado de novo.
set -e

cd "$(dirname "$0")/.."

VM_PORT="${VM_PORT:-2223}"
STAGING="/tmp/psito-spike-provision"

ssh -p "$VM_PORT" psito@localhost "mkdir -p $STAGING"
rsync -az -e "ssh -p $VM_PORT" guest/zenith.sh "psito@localhost:$STAGING/"
ssh -t -p "$VM_PORT" psito@localhost "sudo APP_USER=psito bash $STAGING/zenith.sh"
