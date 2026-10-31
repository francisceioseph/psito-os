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
      - `audio_service` (PipeWire pelo `wpctl` e pelo `pactl subscribe`, só do shell);
      - `battery_service` (UPower) e `session_service` (logind: desligar, reiniciar, suspender), também só do shell;
      - `time_service` (timedated: fuso e NTP).
    - O estado de cada serviço é um tipo do SDK (`PsitoSystemInfo`, `PsitoNetworkState`), que os apps leem pelo `PsitoAppContext`.
  - `lib/widgets/`:
    - `psito_window` (a moldura), `top_bar`, `psito_dock`, `desktop_background`;
    - `launcher`, `notification_toasts`, `notification_panel`, `window_switcher_overlay`;
    - `network_indicator` e `network_panel`;
    - `volume_indicator`, `volume_panel` e `volume_osd`;
    - `battery_indicator`, `battery_panel`, `power_panel` e `power_confirm_dialog`.
    - Os painéis da top bar abrem um de cada vez, pelo `_Overlay` do `DesktopScreen`. A barreira deles deixa a top bar clicável, para trocar de painel.
  - `lib/apps/`: apps de exemplo, ainda no mesmo processo. Cada arquivo tem o widget `XxxView` e a classe `XxxApp extends PsitoApp`. O app de Configurações é o único com `canChangeSettings`.
  - `test/`: testes de unidade e widget (`flutter test` em `system_shell/`). Os serviços reais são testados num barramento D-Bus privado (`test/services/dbus_test_bus.dart`). O apoio comum fica em `test/helpers.dart`: `FakeApp`, `pumpDesktop` e `pumpOS`.
- `packages/psito_sdk/`: contrato shell↔apps (`PsitoApp`, `PsitoAppContext`, `PsitoNotification`, `PsitoSettings`, papéis de parede, cores e a tabela `psitoShortcuts`). Os apps só podem importar Flutter, pacotes externos e o `psito_sdk`. `test/app_boundary_test.dart` garante isso.
- `docs/ROADMAP.md`: roteiro por fases (local, fora do git). `docs/FASE-1.md` detalha a fase atual. Consulte só quando a tarefa envolver planejamento.
- `spike/`: bancada da fase 3 (`docs/FASE-3.md`): escolha do compositor base e o shell como cliente, numa VM própria (`qemu/psito-spike.qcow2`, SSH na 2223) sem o `psito-os.service`.
  - `probe/`: app Flutter Linux de referência, compilado dentro da VM;
  - `tools/`: injetor de teclas, amostragem de memória e CPU, cálculo de latência e fps;
  - `guest/`: o que o `spike/provision.sh` instala na VM;
  - `guest/labwc/`, `guest/wayfire.ini` e `guest/waybar/`: a configuração de cada candidato, instalada no `~/.config` do `psito`;
  - `shell_client/`: o shell como cliente layer-shell. São quatro views do Flutter num engine, uma por superfície (fundo, top bar, dock, sobreposição), com os widgets do `system_shell` por dependência de caminho. A dock, os toasts e o OSD têm o tamanho que o Dart mede (`resize` no canal `psito/surfaces`): as views dimensionadas pelo conteúdo do embedder não funcionam sobre o layer-shell. O runner em C tem o layer-shell, a ponte do foreign-toplevel (`toplevels.cc`, canal `psito/toplevels`) e os ícones do tema.
    - O compositor chama o shell pelo D-Bus da sessão (`org.psito.Shell.Run '<ShellAction>'`), e o shell é o servidor `org.freedesktop.Notifications`.
    - `lib/bridge/`: a ponte. A `shellBindings` vira os atalhos do labwc (seção `<keyboard>` do `rc.xml` e `--reconfigure`) ou do Wayfire (IPC), e as cores viram a moldura e o tema GTK (`~/.config/gtk-3.0` e `gtk-4.0`).
    - Roda como unidade do systemd do usuário (`guest/systemd/psito-shell.service`, com `Restart`), subida pelo `psito-shell-start` no `autostart`. Log: `journalctl --user -u psito-shell` na VM;
  - `zenith/`: instala as dependências do Zenith e compila (wlroots 0.15.1 e Flutter 3.10.6 na VM); `patches/`: os patches dele. As fontes de terceiros ficam em `~/vendor/` na VM;
  - `notas/` e `results/`: o que cada candidato mostrou e os números (`results/raw/` e `vendor/` ficam fora do git).
- `vm/`: arquivos instalados na VM pelo `provision.sh`: o serviço, o script do guest e `polkit/`, com as permissões D-Bus do usuário `psito`
- `patches/`: patches aplicados no flutter-pi da VM: virtio-gpu e text input (escape de JSON e offsets UTF-16)
- Raiz: scripts do host (QEMU, build, deploy). `qemu/` e `debian/` guardam o disco e a ISO (ignorados no git).

## Comandos (host)
- `PSITO_SERVICES=fake flutter run -d linux` (em `system_shell/`): roda o shell no host, com os serviços falsos. Sem a variável, usa os serviços reais do host.
- `./check.sh`: `flutter analyze` mostrando só os problemas. Rode depois de editar Dart, junto com `flutter test` (em `system_shell/`).
- `./build.sh [release|profile|debug]`: `flutterpi_tool build --arch=x64` (padrão release/AOT). O bundle fica em `system_shell/build/flutter-pi/x64-generic`.
- `./deploy.sh`: rsync do bundle para `/opt/psito-app`, grava o modo em `/etc/default/psito-os` e reinicia `psito-os.service`
- `./provision.sh`: prepara a VM (deps, flutter-pi fixo + `patches/`, serviço de `vm/`). Pode ser rodado de novo.
- `./run.sh`: sobe a VM (SSH em `localhost:2222`, usuário `psito`), com placa de som (`AUDIO=pipewire|pa|none`) e monitor em `qemu/monitor.sock`
- `./vm-ctl.sh link off|on`, `wakeup` ou `raw "<cmd>"`: comandos ao monitor do QEMU da VM em execução. Por exemplo, `link off` derruba a rede.
- Spike (fase 3):
  - `spike/vm.sh <script da raiz>` roda `create-disk.sh`, `install-os.sh`, `provision.sh` ou `run.sh` na VM do spike; `spike/vm.sh ssh` entra nela. Depois do `provision.sh`, rode `spike/provision.sh`.
  - `spike/session.sh weston|labwc|wayfire|zenith|stop|status` sobe um compositor no tty1; `spike/client.sh <cmd>` abre um cliente nele; `spike/probe/build.sh` compila o probe; `spike/shell_client/build.sh` compila o shell na VM, e o `autostart` do labwc e do Wayfire sobe ele.
  - `spike/measure.sh <candidato> <processo>` mede e grava `spike/results/<candidato>.csv`; `spike/measure-shell.sh` mede o shell no labwc (`results/shell.csv`).
  - `sudo python3 /tmp/spike/tools/keys.py hold:leftctrl tab release` (na VM) aperta combinações; `grim` captura a tela.
  - `ssh -p 2223 psito@localhost 'bash -s' < spike/tools/protocols.sh` lista os protocolos que o compositor rodando anuncia.
  - Não suba as duas VMs ao mesmo tempo.
- `./logs.sh [n]`: últimas n linhas (padrão 40) do `journalctl -u psito-os` na VM
- `./create-disk.sh`, `./install-os.sh`: criam e instalam a VM sem interação (`vm/preseed.cfg`). Todos os scripts aceitam `DISK`, `SSH_PORT`/`VM_PORT`, `MEM` (ex.: VM de teste na 2223). O `run.sh` aceita `TABLET=1` (ponteiro absoluto, ligado na VM do spike).

## Regras
- Não ler `build/`, `.dart_tool/`, `linux/flutter/ephemeral/`, `qemu/`, `debian/`.
- Prefira `./check.sh` e `./logs.sh` a builds e logs completos.
- Para mostrar a hora, use `ctx.now()` (apps) ou `TimeService.now` (shell), nunca `DateTime.now()`. O fuso do `DateTime.now()` fica congelado depois que o processo começa, porque o glibc não relê o `/etc/localtime`.
- A UI não tem emojis, porque a fonte da VM não tem esses glifos. Nos `debugPrint` eles podem ficar.
- Todo atalho global tem uma combinação nativa e uma de VM (`lib/shell/shortcuts.dart`, mais `psitoShortcuts` no SDK). O host Cinnamon fica com Super, Alt+Tab, Alt+\`, Ctrl+Alt+setas e Ctrl+Alt+Shift+setas, e o QEMU fica com Ctrl+Alt+G/F/Q/M/1–9. A lista completa está em `docs/FASE-1.md`.
- Apps precisam caber no tamanho mínimo de janela (240×160). O `desktop_test` verifica todos.
- Direção da arquitetura: tudo que é do Psito em Flutter (shell, Configurações, apps do sistema), rodando como cliente privilegiado de um compositor Wayland maduro (layer-shell, foreign-toplevel e IPC), com apps em processos separados. O compositor não é escrito em Flutter: o modelo é o Budgie 10.10 (painel como cliente layer-shell sobre o labwc, com as Configurações gerando a configuração do compositor). A decisão está em `docs/FASE-3.md`. Evite acoplar os apps ao shell além do necessário.
