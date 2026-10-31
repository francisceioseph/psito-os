# Psito OS

SO baseado em Linux cuja interface é feita em Flutter (ideia parecida com o Fuchsia). Hoje é um mock: Debian 13 numa VM QEMU, com o labwc no tty1 (`psito-os.service`) e o shell em Flutter como cliente layer-shell dele. Cada app do Psito roda no próprio processo. A decisão está em `docs/decisao-compositor.md`.

## Layout
- `shell/`: o shell do Psito (`psito_shell`), cliente layer-shell do labwc. São seis views do Flutter num engine, uma por superfície (fundo, top bar, dock, sobreposição, toasts, OSD), com os widgets e os serviços do `system_shell` por dependência de caminho.
  - A dock, os toasts e o OSD têm o tamanho que o Dart mede (`resize` no canal `psito/surfaces`): as views dimensionadas pelo conteúdo do embedder não funcionam sobre o layer-shell.
  - O runner em C tem o layer-shell, a ponte do foreign-toplevel (`toplevels.cc`, canal `psito/toplevels`) e os ícones do tema.
  - O compositor chama o shell pelo D-Bus da sessão (`org.psito.Shell.Run '<ShellAction>'`), e o shell é o servidor `org.freedesktop.Notifications`.
  - `lib/bridge/`: a ponte. A `shellBindings` vira os atalhos do labwc (seção `<keyboard>` do `rc.xml` e `--reconfigure`) ou do Wayfire (IPC), e as cores viram a moldura e o tema GTK (`~/.config/gtk-3.0` e `gtk-4.0`).
  - Os apps `org.psito.<id>` aparecem com o ícone e a cor do `PsitoApp` (`app_icon.dart`); os de fora, com o ícone do tema.
  - Roda como a unidade `psito-shell` do systemd do usuário (`Restart`), subida pelo `psito-shell-start` no `autostart` do labwc. Log: `journalctl --user -u psito-shell` na VM.
- `apps/`: o host dos apps do Psito (`psito_apps <id>`). Roda um `PsitoApp` do `system_shell` numa janela comum, com o `app_id` `org.psito.<id>`; o canal `psito/window` define o título e o tamanho e fecha. O `ProcessAppContext` usa os serviços do D-Bus, manda as notificações ao shell e lê e grava o `settings.json`. `desktop/` tem um `.desktop` por app (o teste confere com o registro).
- `system_shell/`: os widgets, os serviços, os apps e o laboratório de UX no host (app `system_shell`, com janelas dentro do processo)
  - `lib/main.dart`: carrega as configurações e sobe o `PsitoOSApp`. `lib/app.dart` monta o tema a partir da cor de destaque salva (o padrão é amarelo `#FFC107` com fundo `#12181B`).
  - `lib/screens/desktop_screen.dart`: só composição, com as camadas e os atalhos globais do `_onKey`.
  - `lib/shell/`: lógica sem UI.
    - `app_registry`: os apps da dock;
    - `window_manager`: foco, z-order, snap, resize e o `PsitoAppContext` de cada janela;
    - `window_switcher`: o seletor de janelas do Alt+Tab;
    - `shortcuts`: as combinações nativas e de VM;
    - `notification_center`;
    - `settings_store`: o JSON em `~/.config/psito/settings.json`. O `watch` relê quando outro processo grava (as Configurações em `apps/`);
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
  - `lib/apps/`: apps de exemplo. No laboratório rodam no mesmo processo; na VM, cada um no seu, pelo `apps/`. Cada arquivo tem o widget `XxxView` e a classe `XxxApp extends PsitoApp`. O app de Configurações é o único com `canChangeSettings`.
  - `test/`: testes de unidade e widget (`flutter test` em `system_shell/`). Os serviços reais são testados num barramento D-Bus privado (`test/services/dbus_test_bus.dart`). O apoio comum fica em `test/helpers.dart`: `FakeApp`, `pumpDesktop` e `pumpOS`.
- `packages/psito_sdk/`: contrato shell↔apps (`PsitoApp`, `PsitoAppContext`, `PsitoNotification`, `PsitoSettings`, papéis de parede, cores e a tabela `psitoShortcuts`). Os apps só podem importar Flutter, pacotes externos e o `psito_sdk`. `test/app_boundary_test.dart` garante isso.
- `docs/ROADMAP.md`: roteiro por fases (local, fora do git). `docs/FASE-3.md` detalha a última fase, e `docs/decisao-compositor.md` a base escolhida. Consulte só quando a tarefa envolver planejamento.
- `spike/`: bancada da fase 3 (`docs/FASE-3.md`): a comparação dos compositores, numa VM própria (`qemu/psito-spike.qcow2`, SSH na 2223) em que o `session.sh` escolhe o compositor.
  - `probe/`: app Flutter Linux de referência, compilado dentro da VM;
  - `tools/`: injetor de teclas, amostragem de memória e CPU, cálculo de latência e fps;
  - `guest/`: o que o `spike/provision.sh` instala na VM;
  - `guest/wayfire.ini`, `guest/weston.ini` e `guest/waybar/`: a configuração dos outros candidatos (a do labwc é a de `vm/session/`);
  - `zenith/`: instala as dependências do Zenith e compila (wlroots 0.15.1 e Flutter 3.10.6 na VM); `patches/`: os patches dele. As fontes de terceiros ficam em `~/vendor/` na VM;
  - `notas/` e `results/`: o que cada candidato mostrou e os números (`results/raw/` e `vendor/` ficam fora do git).
- `vm/`: arquivos instalados na VM pelo `provision.sh`: o `psito-os.service` (o labwc no tty1), o script do guest, `polkit/` (as permissões D-Bus do usuário `psito`) e `session/` (a configuração do labwc, o `psito-shell-start` e a unidade `psito-shell`)
- Raiz: scripts do host (QEMU, build, deploy). `qemu/` e `debian/` guardam o disco e a ISO (ignorados no git).

## Comandos (host)
- `PSITO_SERVICES=fake flutter run -d linux` (em `system_shell/`): o laboratório de UX no host, com os serviços falsos. Sem a variável, usa os serviços reais do host. Em `apps/`, `flutter run -d linux -a <id>` abre um app sozinho.
- `./check.sh`: `flutter analyze` nos `packages/`, no `system_shell/`, no `shell/` e no `apps/`, mostrando só os problemas. Rode depois de editar Dart, junto com o `./test.sh`.
- `./test.sh [pasta...]`: o `flutter test` de cada projeto (ou só dos indicados), mostrando só as falhas. São 2 processos de teste (`TEST_JOBS`) num escopo do systemd com 2G de limite e sem swap (`TEST_MEM`; `0` tira o limite). Assim cabe no host com a VM ligada, e se estourar só os testes morrem. Não rode o `flutter test` direto com a VM ligada: ele abre um processo por núcleo.
- `./build.sh [release|profile|debug]`: envia o código e compila o `shell/` e o `apps/` dentro da VM (padrão release), com o Flutter dela.
- `./deploy.sh`: instala o shell em `/opt/psito/shell`, os apps em `/opt/psito/apps` e os `.desktop` no `~/.local/share/applications`, e reinicia a unidade `psito-shell`
- `./provision.sh`: prepara a VM (labwc, `gtk-layer-shell`, Flutter 3.47.4, os serviços da fase 2 e a sessão de `vm/`). Pode ser rodado de novo.
- `./run.sh`: sobe a VM (SSH em `localhost:2222`, usuário `psito`, 3 GB), com tablet USB, placa de som (`AUDIO=pipewire|pa|none`) e monitor em `qemu/monitor.sock`
- `./vm-ctl.sh link off|on`, `wakeup` ou `raw "<cmd>"`: comandos ao monitor do QEMU da VM em execução. Por exemplo, `link off` derruba a rede.
- Spike (fase 3):
  - `spike/vm.sh <script da raiz>` roda `create-disk.sh`, `install-os.sh`, `provision.sh` ou `run.sh` na VM do spike; `spike/vm.sh ssh` entra nela. Depois do `provision.sh`, rode `spike/provision.sh`.
  - `spike/session.sh weston|labwc|wayfire|zenith|stop|status` sobe um compositor no tty1; `spike/client.sh <cmd>` abre um cliente nele; `spike/probe/build.sh` compila o probe; `VM_PORT=2223 ./build.sh` e `./deploy.sh` instalam o shell nela, e o `autostart` do labwc e do Wayfire sobe ele.
  - `spike/measure.sh <candidato> <processo>` mede e grava `spike/results/<candidato>.csv`; `spike/measure-shell.sh` mede o shell no labwc (`results/shell.csv`).
  - `sudo python3 /tmp/spike/tools/keys.py hold:leftctrl tab release` (na VM) aperta combinações; `grim` captura a tela.
  - `ssh -p 2223 psito@localhost 'bash -s' < spike/tools/protocols.sh` lista os protocolos que o compositor rodando anuncia.
  - Não suba as duas VMs ao mesmo tempo.
- `./logs.sh [n]`: últimas n linhas (padrão 40) do log do shell (`journalctl --user -u psito-shell`) na VM; `LOG=psito-os` mostra o do labwc
- `./create-disk.sh`, `./install-os.sh`: criam e instalam a VM sem interação (`vm/preseed.cfg`). Todos os scripts aceitam `DISK`, `SSH_PORT`/`VM_PORT`, `MEM` (ex.: VM de teste na 2223). O `run.sh` aceita `TABLET=0` (mouse PS/2 relativo).

## Regras
- Não ler `build/`, `.dart_tool/`, `linux/flutter/ephemeral/`, `qemu/`, `debian/`.
- Prefira `./check.sh` e `./logs.sh` a builds e logs completos.
- Para mostrar a hora, use `ctx.now()` (apps) ou `TimeService.now` (shell), nunca `DateTime.now()`. O fuso do `DateTime.now()` fica congelado depois que o processo começa, porque o glibc não relê o `/etc/localtime`.
- A UI não tem emojis, porque a fonte da VM não tem esses glifos. Nos `debugPrint` eles podem ficar.
- Todo atalho global tem uma combinação nativa e uma de VM (`lib/shell/shortcuts.dart`, mais `psitoShortcuts` no SDK). O host Cinnamon fica com Super, Alt+Tab, Alt+\`, Ctrl+Alt+setas e Ctrl+Alt+Shift+setas, e o QEMU fica com Ctrl+Alt+G/F/Q/M/1–9. A lista completa está em `docs/FASE-1.md`.
- Apps precisam caber no tamanho mínimo de janela (240×160). O `desktop_test` verifica todos.
- Direção da arquitetura: tudo que é do Psito em Flutter (shell, Configurações, apps do sistema), rodando como cliente privilegiado de um compositor Wayland maduro (layer-shell, foreign-toplevel e IPC), com apps em processos separados. O compositor não é escrito em Flutter: o modelo é o Budgie 10.10 (painel como cliente layer-shell sobre o labwc, com as Configurações gerando a configuração do compositor). A decisão está em `docs/decisao-compositor.md`. Evite acoplar os apps ao shell além do necessário.
