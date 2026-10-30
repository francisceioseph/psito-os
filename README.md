# 🦜 Psito OS — Embedded Kiosk Development Environment

Este repositório contém as instruções e scripts para compilar, implantar e executar a interface gráfica do **Psito OS** em modo kiosk de alto desempenho usando `flutter-pi` sobre DRM/KMS e aceleração por hardware VirGL em uma VM Debian minimalista via QEMU.

---

## 🛠️ Requisitos do Sistema

* **Host:** Linux (ex: Linux Mint / Ubuntu) com QEMU, KVM e SDK do Flutter instalado.
* **Target:** VM Debian 12 (Bookworm) Minimal/CLI.
* **Embedder:** `flutter-pi` pré-compilado na VM target (`/usr/local/bin/flutter-pi`).

---

## 📐 Arquitetura da Solução

* **Aceleração 3D:** QEMU configurado com `-display gtk,gl=on` e `-vga virtio` repassando DRM/KMS para o driver VirGL no Debian.
* **Engine & Assets:** Execução do bundle gerado por `flutter build bundle` carregado via `flutter-pi` no framebuffer sem dependência de X11 ou Wayland.
* **Boot Autônomo:** Gerenciado pelo `systemd`, assumindo o `/dev/tty1` diretamente na inicialização do sistema (sem tela de login ou gerenciador de sessão).

---

## 🚀 Guia Passo a Passo

### 1. Preparação da VM Debian (Target)

Na VM Debian, instale os artefatos de renderização 3D, suporte a DRM e `libseat`:

```bash
sudo apt update && sudo apt install -y \
  libgl1-mesa-dri \
  mesa-vulkan-drivers \
  virglserver \
  libseat-dev \
  libsystemd-dev

```

Crie o diretório de destino e ajuste as permissões para o usuário `psito`:

```bash
sudo mkdir -p /opt/psito-app
sudo chown -R psito:psito /opt/psito-app
sudo chmod -R 755 /opt/psito-app

```

---

### 2. Inicialização da VM (Host Script)

Para subir a VM no Host com aceleração de hardware completa e repasse SSH na porta `2222`:

```bash
#!/bin/bash
set -e

echo "🦜 Subindo o Psito OS (Debian + QEMU)..."

DISK="qemu/psito-disk.qcow2"

QEMU_ARGS=(
    -m 2048
    -smp 2
    -drive "file=$DISK,format=qcow2"
    -vga virtio
    -display gtk,gl=on
    -netdev user,id=net0,hostfwd=tcp::2222-:22
    -device virtio-net-pci,netdev=net0
)

if [ -e /dev/kvm ]; then
    QEMU_ARGS+=(-enable-kvm -cpu host)
    echo "-> Aceleração KVM e repasse de CPU ativados!"
fi

qemu-system-x86_64 "${QEMU_ARGS[@]}"

```

---

### 3. Automação de Build e Deploy

#### `build.sh` (Host)

Entra no subdiretório `system_shell`, compila os assets e copia o arquivo `icudtl.dat` exigido pelo runtime do `flutter-pi`:

```bash
#!/bin/bash
set -e

echo "🔨 [Psito OS] Iniciando compilação do bundle Flutter..."

# Garantir execução na raiz do projeto
cd "$(dirname "$0")"

# Entrar no diretório da aplicação Flutter
cd ./system_shell

# Buscar dependências e compilar o bundle
flutter pub get
flutter build bundle

echo "📦 Copiando icudtl.dat para o bundle de assets..."
FLUTTER_BIN=$(which flutter)
FLUTTER_DIR=$(dirname "$FLUTTER_BIN")

cp "$FLUTTER_DIR/cache/artifacts/engine/linux-x64/icudtl.dat" build/flutter_assets/ 2>/dev/null || \
find ~/ -name "icudtl.dat" 2>/dev/null | head -n 1 | xargs -I {} cp {} build/flutter_assets/

echo "✅ [Psito OS] Build concluído com sucesso!"

```

#### `deploy.sh` (Host)

Sincroniza os assets compilados diretamente para a VM Debian e reinicia o serviço do sistema:

```bash
#!/bin/bash
set -e

echo "🚀 [Psito OS] Iniciando deploy para a VM Debian..."

# Garantir execução na raiz do projeto
cd "$(dirname "$0")"

VM_USER="psito"
VM_HOST="localhost"
VM_PORT="2222"
DEST_DIR="/opt/psito-app"

# Verificar se o bundle existe
if [ ! -d "system_shell/build/flutter_assets" ]; then
    echo "⚠️  [Psito OS] Bundle não encontrado! Rodando build.sh..."
    ./build.sh
fi

echo "📦 Sincronizando assets via rsync..."
rsync -avz --delete -e "ssh -p $VM_PORT" system_shell/build/flutter_assets/ "$VM_USER@$VM_HOST:$DEST_DIR/"

echo "🔄 Reiniciando o serviço Psito OS..."
ssh -p "$VM_PORT" "$VM_USER@$VM_HOST" "sudo systemctl restart psito-os.service 2>/dev/null || true"

echo "✨ [Psito OS] Deploy finalizado com sucesso!"

```

Torne os scripts executáveis:

```bash
chmod +x build.sh deploy.sh

```

---

### 4. Execução Manual (VM)

Para rodar a aplicação manualmente via SSH no terminal da VM Debian (útil para depuração):

```bash
sudo /usr/local/bin/flutter-pi /opt/psito-app

```

---

### 5. Configuração do Boot Autônomo (Systemd)

Para fazer o **Psito OS** iniciar automaticamente na VM como um appliance kiosk sem interface desktop:

1. Crie o arquivo `/etc/systemd/system/psito-os.service` na VM Debian:

```ini
[Unit]
Description=Psito OS Kiosk Engine
After=systemd-user-sessions.service multi-user.target
Conflicts=getty@tty1.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/psito-app
ExecStart=/usr/local/bin/flutter-pi /opt/psito-app
Restart=always
RestartSec=2
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target

```

2. Recarregue o daemon e ative o serviço:

```bash
sudo systemctl daemon-reload
sudo systemctl enable psito-os.service
sudo systemctl start psito-os.service

```

3. Para verificar os logs da aplicação em tempo real na VM:

```bash
sudo journalctl -u psito-os -f

```

```