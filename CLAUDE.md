# Psito OS

SO baseado em Linux cuja interface é feita em Flutter (ideia parecida com o Fuchsia). Hoje é um mock: Debian 13 numa VM QEMU, com `flutter-pi` desenhando direto no DRM/KMS (sem X11/Wayland), iniciado pelo systemd no tty1.

## Layout
- `system_shell/`: o shell em Flutter (app `system_shell`)
  - `lib/app.dart`: tema (amarelo `#FFC107`, laranja `#FF5722`, fundo `#12181B`)
  - `lib/screens/desktop_screen.dart`: desktop
  - `lib/widgets/`: `top_bar`, `psito_dock`, `desktop_background`
  - `lib/apps/`: "apps" de exemplo; hoje são widgets dentro do mesmo processo
  - `lib/models/psito_app_item.dart`: um item da dock/app
- `patches/`: patches aplicados em dependências da VM (ex.: flutter-pi pro virtio-gpu)
- Raiz: scripts do host (QEMU, build, deploy). `qemu/` e `debian/` guardam o disco e a ISO (ignorados no git).

## Comandos (host)
- `./check.sh`: `flutter analyze` mostrando só os problemas. Rode depois de editar Dart.
- `./build.sh`: `flutter build bundle` + copia `icudtl.dat`
- `./deploy.sh`: rsync para `/opt/psito-app` na VM e reinicia `psito-os.service`
- `./run.sh`: sobe a VM (SSH em `localhost:2222`, usuário `psito`)
- `./logs.sh [n]`: últimas n linhas (padrão 40) do `journalctl -u psito-os` na VM
- `./create-disk.sh`, `./install-os.sh`: só na primeira configuração

## Regras
- Não ler `build/`, `.dart_tool/`, `linux/flutter/ephemeral/`, `qemu/`, `debian/`.
- Prefira `./check.sh` e `./logs.sh` a builds e logs completos.
- Direção da arquitetura: shell como compositor Wayland em Flutter, com apps em processos separados. Evite acoplar os apps ao shell além do necessário.
