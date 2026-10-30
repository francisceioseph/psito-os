#!/bin/bash

set -e

echo "🦜 Install Basic do Psito OS (Debian + QEMU)..."

# Garantir que estamos na raiz do repositório
cd "$(dirname "$0")"

# Variáveis opcionais: DISK, SSH_PORT, MEM, PSITO_PASSWORD, SSH_PUBKEY
DISK="${DISK:-qemu/psito-disk.qcow2}"
SSH_PORT="${SSH_PORT:-2222}"
MEM="${MEM:-2048}"
ISO="debian/debian-netinst.iso"
INSTALLER_DIR="qemu/installer"
SSH_PUBKEY="${SSH_PUBKEY:-$(ls ~/.ssh/id_*.pub 2>/dev/null | head -n 1)}"

if [ ! -f "$DISK" ]; then
    echo "❌ Disco $DISK não existe. Rode antes: DISK=$DISK ./create-disk.sh"
    exit 1
fi
if [ ! -f "$SSH_PUBKEY" ]; then
    echo "❌ Chave SSH pública não encontrada. Crie com ssh-keygen ou passe SSH_PUBKEY."
    exit 1
fi

# Senha do psito: pergunta no terminal; sem terminal, gera uma e salva ao lado do disco
if [ -z "$PSITO_PASSWORD" ]; then
    if [ -t 0 ]; then
        read -rsp "🔑 Senha do usuário psito na VM: " PSITO_PASSWORD
        echo
    else
        PSITO_PASSWORD=$(openssl rand -base64 18)
        PASSWORD_FILE="${DISK%.qcow2}.password"
        (umask 077 && echo "$PSITO_PASSWORD" > "$PASSWORD_FILE")
        echo "🔑 Senha gerada e salva em $PASSWORD_FILE"
    fi
fi
PASSWORD_HASH=$(echo "$PSITO_PASSWORD" | openssl passwd -6 -stdin)

echo "📀 Preparando o instalador com as respostas automáticas..."
mkdir -p "$INSTALLER_DIR"
isoinfo -i "$ISO" -R -x /install.amd/vmlinuz > "$INSTALLER_DIR/vmlinuz"
isoinfo -i "$ISO" -R -x /install.amd/initrd.gz > "$INSTALLER_DIR/initrd.gz"

# O instalador lê /preseed.cfg da raiz do initrd: anexamos um segundo cpio com ele e a chave
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
sed "s|@PASSWORD_HASH@|$PASSWORD_HASH|" vm/preseed.cfg > "$STAGE/preseed.cfg"
cp "$SSH_PUBKEY" "$STAGE/authorized_keys"
cp "$INSTALLER_DIR/initrd.gz" "$INSTALLER_DIR/initrd-preseed.gz"
(cd "$STAGE" && printf 'preseed.cfg\nauthorized_keys\n' | cpio -H newc -o --quiet | gzip) >> "$INSTALLER_DIR/initrd-preseed.gz"

echo "⏳ Instalando sem interação (a janela fecha sozinha ao terminar)..."
QEMU_ARGS=(
    -m "$MEM"
    -smp 2
    -device virtio-vga-gl
    -display gtk,gl=on
    -drive "file=$DISK,format=qcow2"
    -cdrom "$ISO"
    -kernel "$INSTALLER_DIR/vmlinuz"
    -initrd "$INSTALLER_DIR/initrd-preseed.gz"
    -append "auto=true priority=critical locale=pt_BR.UTF-8 keymap=br"
    -no-reboot
    -netdev "user,id=net0,hostfwd=tcp::$SSH_PORT-:22"
    -device virtio-net-pci,netdev=net0
)

if [ -e /dev/kvm ]; then
    QEMU_ARGS+=(-enable-kvm -cpu host)
fi

qemu-system-x86_64 "${QEMU_ARGS[@]}"

echo "✅ Instalação concluída. Suba a VM com: DISK=$DISK SSH_PORT=$SSH_PORT ./run.sh"
