# 🦜 Psito OS — Embedded Kiosk Development Environment

Este repositório contém os scripts para compilar, implantar e executar a interface gráfica do **Psito OS** em modo kiosk usando `flutter-pi` sobre DRM/KMS e aceleração por hardware VirGL em uma VM Debian minimalista via QEMU.

---

## 🛠️ Requisitos do Sistema

* **Host:** Linux (ex: Linux Mint / Ubuntu) com QEMU, KVM, `rsync` e SDK do Flutter instalado.
* **flutterpi_tool** no host, instalado do git (a versão do pub.dev não compila com Flutter 3.47+):

  ```bash
  flutter pub global activate --source git https://github.com/ardera/flutterpi_tool
  ```

* **Target:** VM Debian 13 (Trixie) Minimal/CLI, com servidor SSH e um usuário `psito` com sudo.

---

## 📐 Arquitetura da Solução

* **Aceleração 3D:** QEMU com `-device virtio-vga-gl` e `-display gtk,gl=on`, repassando DRM/KMS para o driver VirGL no Debian.
* **Embedder:** `flutter-pi` compilado na VM (`/usr/local/bin/flutter-pi`) com o patch `patches/flutter-pi-virtio-gpu-modifiers.patch`. Sem ele o virtio-gpu recusa os framebuffers e a tela fica preta.
* **App:** bundle gerado pelo `flutterpi_tool` (AOT em release), com o `app.so` e o `libflutter_engine.so` do mesmo modo. O serviço carrega o engine do próprio bundle.
* **Boot Autônomo:** `systemd` assume o `/dev/tty1` na inicialização, sem tela de login nem gerenciador de sessão. O `flutter-pi` roda como o usuário `psito`, numa sessão do logind (`PAMName=login`) que dá acesso à GPU e ao input sem root.

---

## 🚀 Guia Passo a Passo

### 1. Criar e instalar a VM (uma vez)

```bash
./create-disk.sh     # cria qemu/psito-disk.qcow2 (20G)
./install-os.sh      # instala o Debian sem interação a partir de debian/debian-netinst.iso
```

O `install-os.sh` embute `vm/preseed.cfg` e sua chave SSH pública no instalador. A instalação cria o usuário `psito` (pede a senha no terminal) com sudo sem senha e servidor SSH, e a janela do QEMU fecha sozinha ao terminar.

Todos os scripts aceitam variáveis para trabalhar com outra VM, por exemplo uma de teste ao lado da principal:

```bash
DISK=qemu/psito-test.qcow2 ./create-disk.sh
DISK=qemu/psito-test.qcow2 SSH_PORT=2223 MEM=1536 ./install-os.sh
DISK=qemu/psito-test.qcow2 SSH_PORT=2223 ./run.sh
VM_PORT=2223 ./provision.sh && VM_PORT=2223 ./deploy.sh
```

> Ao reinstalar uma VM na mesma porta, a chave do host SSH muda: rode `ssh-keygen -R "[localhost]:2222"`.

### 2. Provisionar a VM

Instala as dependências, compila o `flutter-pi` (commit fixo + patches de `patches/`) e instala o serviço `psito-os`. Pode ser rodado de novo sem problemas.

```bash
./run.sh             # em outro terminal
./provision.sh
```

### 3. Build e deploy

```bash
./build.sh           # release (padrão); também aceita: profile, debug
./deploy.sh          # envia o bundle para /opt/psito-app e reinicia o serviço
```

O modo do build é repassado ao `flutter-pi` pelo `/etc/default/psito-os`.

### 4. Depuração

```bash
./check.sh           # flutter analyze, só os problemas
./logs.sh 100        # últimas 100 linhas do journal do serviço na VM
```

Para rodar manualmente na VM:

```bash
sudo systemctl stop psito-os
LD_LIBRARY_PATH=/opt/psito-app /usr/local/bin/flutter-pi --release /opt/psito-app   # no console tty1, como psito
```

---

## 📁 Estrutura

* `system_shell/`: o shell em Flutter
* `vm/`: arquivos da VM (`preseed.cfg` da instalação; `psito-os.service` e `provision-guest.sh` do provisionamento)
* `patches/`: patches aplicados em dependências da VM
