# Psito OS

SO baseado em Linux cuja interface é feita em Flutter (ideia parecida com o Fuchsia). Hoje é um mock: Debian 13 numa VM QEMU, com `flutter-pi` desenhando direto no DRM/KMS (sem X11/Wayland), iniciado pelo systemd no tty1.

## Layout
- `system_shell/`: o shell em Flutter (app `system_shell`)
  - `lib/app.dart`: tema (amarelo `#FFC107`, laranja `#FF5722`, fundo `#12181B`)
  - `lib/screens/desktop_screen.dart`: desktop
  - `lib/widgets/`: `top_bar`, `psito_dock`, `desktop_background`
  - `lib/apps/`: "apps" de exemplo; hoje são widgets dentro do mesmo processo
  - `lib/models/psito_app_item.dart`: um item da dock/app
- `docs/ROADMAP.md`: roteiro por fases (local, fora do git). Consulte só quando a tarefa envolver planejamento.
- `vm/`: arquivos instalados na VM pelo `provision.sh` (serviço, script do guest)
- `patches/`: patches aplicados em dependências da VM (ex.: flutter-pi pro virtio-gpu)
- Raiz: scripts do host (QEMU, build, deploy). `qemu/` e `debian/` guardam o disco e a ISO (ignorados no git).

## Comandos (host)
- `./check.sh`: `flutter analyze` mostrando só os problemas. Rode depois de editar Dart.
- `./build.sh [release|profile|debug]`: `flutterpi_tool build --arch=x64` (padrão release/AOT). O bundle fica em `system_shell/build/flutter-pi/x64-generic`.
- `./deploy.sh`: rsync do bundle para `/opt/psito-app`, grava o modo em `/etc/default/psito-os` e reinicia `psito-os.service`
- `./provision.sh`: prepara a VM (deps, flutter-pi fixo + `patches/`, serviço de `vm/`). Pode ser rodado de novo.
- `./run.sh`: sobe a VM (SSH em `localhost:2222`, usuário `psito`)
- `./logs.sh [n]`: últimas n linhas (padrão 40) do `journalctl -u psito-os` na VM
- `./create-disk.sh`, `./install-os.sh`: só na primeira configuração

## Regras
- Não ler `build/`, `.dart_tool/`, `linux/flutter/ephemeral/`, `qemu/`, `debian/`.
- Prefira `./check.sh` e `./logs.sh` a builds e logs completos.
- Direção da arquitetura: shell como compositor Wayland em Flutter, com apps em processos separados. Evite acoplar os apps ao shell além do necessário.
