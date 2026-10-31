# Psito OS

SO baseado em Linux cuja interface é feita em Flutter (ideia parecida com o Fuchsia). Hoje é um mock: Debian 13 numa VM QEMU, com `flutter-pi` desenhando direto no DRM/KMS (sem X11/Wayland), iniciado pelo systemd no tty1.

## Layout
- `system_shell/`: o shell em Flutter (app `system_shell`)
  - `lib/main.dart`: carrega as configurações e sobe o `PsitoOSApp`. `lib/app.dart` monta o tema a partir da cor de destaque salva (o padrão é amarelo `#FFC107` com fundo `#12181B`).
  - `lib/screens/desktop_screen.dart`: só composição, com as camadas e os atalhos globais do `_onKey`.
  - `lib/shell/`: lógica sem UI.
    - `app_registry`: os apps da dock;
    - `window_manager`: foco, z-order, snap, resize e o `PsitoAppContext` de cada janela;
    - `window_switcher`: o seletor de janelas do Alt+Tab;
    - `shortcuts`: as combinações nativas e de VM;
    - `notification_center`;
    - `settings_store`: o JSON em `~/.config/psito/settings.json`;
    - `app_search`.
  - `lib/services/`: os serviços do sistema que o shell consome.
    - Reais via D-Bus (`dbus`) e falsos (`Fake*`), juntos em `SystemServices`.
    - Começam indisponíveis e carregam em segundo plano, então nunca seguram o boot.
    - `PSITO_SERVICES=fake` força os falsos.
    - Hoje:
      - `system_info_service` (hostnamed);
      - `network_service` (NetworkManager pelo pacote `nm`);
      - `audio_service` (PipeWire pelo `wpctl` e pelo `pactl subscribe`, só do shell).
    - O estado de cada serviço é um tipo do SDK (`PsitoSystemInfo`, `PsitoNetworkState`), que os apps leem pelo `PsitoAppContext`.
  - `lib/widgets/`:
    - `psito_window` (a moldura), `top_bar`, `psito_dock`, `desktop_background`;
    - `launcher`, `notification_toasts`, `notification_panel`, `window_switcher_overlay`;
    - `network_indicator` e `network_panel`;
    - `volume_indicator`, `volume_panel` e `volume_osd`.
    - Os painéis da top bar abrem um de cada vez, pelo `_Overlay` do `DesktopScreen`. A barreira deles deixa a top bar clicável, para trocar de painel.
  - `lib/apps/`: apps de exemplo, ainda no mesmo processo. Cada arquivo tem o widget `XxxView` e a classe `XxxApp extends PsitoApp`. O app de Configurações é o único com `canChangeSettings`.
  - `test/`: testes de unidade e widget (`flutter test` em `system_shell/`). Os serviços reais são testados num barramento D-Bus privado (`test/services/dbus_test_bus.dart`). O apoio comum fica em `test/helpers.dart`: `FakeApp`, `pumpDesktop` e `pumpOS`.
- `packages/psito_sdk/`: contrato shell↔apps (`PsitoApp`, `PsitoAppContext`, `PsitoNotification`, `PsitoSettings`, papéis de parede, cores e a tabela `psitoShortcuts`). Os apps só podem importar Flutter, pacotes externos e o `psito_sdk`. `test/app_boundary_test.dart` garante isso.
- `docs/ROADMAP.md`: roteiro por fases (local, fora do git). `docs/FASE-1.md` detalha a fase atual. Consulte só quando a tarefa envolver planejamento.
- `vm/`: arquivos instalados na VM pelo `provision.sh`: o serviço, o script do guest e `polkit/`, com as permissões D-Bus do usuário `psito`
- `patches/`: patches aplicados no flutter-pi da VM: virtio-gpu e text input (escape de JSON e offsets UTF-16)
- Raiz: scripts do host (QEMU, build, deploy). `qemu/` e `debian/` guardam o disco e a ISO (ignorados no git).

## Comandos (host)
- `./check.sh`: `flutter analyze` mostrando só os problemas. Rode depois de editar Dart, junto com `flutter test` (em `system_shell/`).
- `./build.sh [release|profile|debug]`: `flutterpi_tool build --arch=x64` (padrão release/AOT). O bundle fica em `system_shell/build/flutter-pi/x64-generic`.
- `./deploy.sh`: rsync do bundle para `/opt/psito-app`, grava o modo em `/etc/default/psito-os` e reinicia `psito-os.service`
- `./provision.sh`: prepara a VM (deps, flutter-pi fixo + `patches/`, serviço de `vm/`). Pode ser rodado de novo.
- `./run.sh`: sobe a VM (SSH em `localhost:2222`, usuário `psito`), com placa de som (`AUDIO=pipewire|pa|none`) e monitor em `qemu/monitor.sock`
- `./vm-ctl.sh link off|on`, `wakeup` ou `raw "<cmd>"`: comandos ao monitor do QEMU da VM em execução. Por exemplo, `link off` derruba a rede.
- `./logs.sh [n]`: últimas n linhas (padrão 40) do `journalctl -u psito-os` na VM
- `./create-disk.sh`, `./install-os.sh`: criam e instalam a VM sem interação (`vm/preseed.cfg`). Todos os scripts aceitam `DISK`, `SSH_PORT`/`VM_PORT`, `MEM` (ex.: VM de teste na 2223).

## Regras
- Não ler `build/`, `.dart_tool/`, `linux/flutter/ephemeral/`, `qemu/`, `debian/`.
- Prefira `./check.sh` e `./logs.sh` a builds e logs completos.
- A UI não tem emojis, porque a fonte da VM não tem esses glifos. Nos `debugPrint` eles podem ficar.
- Todo atalho global tem uma combinação nativa e uma de VM (`lib/shell/shortcuts.dart`, mais `psitoShortcuts` no SDK). O host Cinnamon fica com Super, Alt+Tab, Alt+\`, Ctrl+Alt+setas e Ctrl+Alt+Shift+setas, e o QEMU fica com Ctrl+Alt+G/F/Q/M/1–9. A lista completa está em `docs/FASE-1.md`.
- Apps precisam caber no tamanho mínimo de janela (240×160). O `desktop_test` verifica todos.
- Direção da arquitetura: shell como compositor Wayland em Flutter, com apps em processos separados. Evite acoplar os apps ao shell além do necessário.
