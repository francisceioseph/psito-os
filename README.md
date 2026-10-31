# 🦜 Psito OS

Um sistema operacional baseado em Linux cuja interface inteira é feita em **Flutter**: o shell, as Configurações e os apps do sistema.

> **Estado:** experimental. Hoje o Psito roda numa VM QEMU com Debian 13: o labwc no tty1, o shell em Flutter por cima e cada app do Psito no seu processo, instalado como pacote `.deb` e aberto num sandbox. Não é para uso em produção.

---

## 💡 A ideia

A ideia é parecida com a do Fuchsia: tudo que é do Psito é Flutter. Mas o Psito não reescreve o que já é maduro no Linux:

- **O compositor é maduro e não é escrito em Flutter.** O shell do Psito é um cliente Wayland privilegiado do [labwc](https://labwc.github.io/): top bar, dock, launcher, notificações e o Alt+Tab são superfícies layer-shell. O modelo é o Budgie 10.10, cujo painel é um cliente layer-shell sobre o labwc.
- **As Configurações geram a configuração do compositor.** Atalhos, cores da moldura e o tema GTK saem das configurações do Psito, por uma ponte em Dart.
- **Os apps rodam em processos separados,** cada um num sandbox (`bubblewrap`, com o D-Bus filtrado pelo `xdg-dbus-proxy`) e com as permissões que o manifesto pede. O contrato entre o shell e os apps é o pacote `psito_sdk`.
- **Os apps são pacotes `.deb`,** instalados com o apt, sobre um runtime do Flutter só (`psito-flutter-runtime`).
- **Os serviços do sistema são os de sempre,** pelo D-Bus: NetworkManager, PipeWire, UPower, logind, hostnamed e timedated.

## 🗺️ Onde o projeto está

| Fase | O quê | Estado |
|---|---|---|
| 0 | Fundação: a VM, o `flutter-pi` direto no DRM/KMS (sem Wayland) e o boot no tty1 | feita |
| 1 | O shell como laboratório de UX: janelas, dock, launcher, notificações e Alt+Tab | feita |
| 2 | Os serviços do sistema pelo D-Bus: rede, áudio, bateria, energia, hora e Configurações | feita |
| 3 | A base do compositor (o labwc) e o shell como cliente layer-shell | feita |
| 4 | Apps em processos separados: pacotes `.deb`, manifesto, sandbox e portais | feita |
| 5 | O shell como pacote (`psito-shell` e o metapacote `psito-desktop`) | planejada |
| 6 | O Psito Files, um gerenciador de arquivos como o Finder | em andamento |
| 7 | Uma dock de verdade: pôr e tirar apps, pastas, arquivos e a lixeira | planejada |
| 8 | A área de trabalho com arquivos e atalhos de programas | planejada |
| 9 | Imagem do sistema | planejada |
| 10 | Hardware real | planejada |

Os números da fase 3 (memória, CPU e latência de cada compositor e do shell) ficam em [`spike/results/`](spike/results/), e as leituras em [`spike/notas/`](spike/notas/). A fase 0 usava o `flutter-pi` direto no DRM/KMS; ele saiu na fase 3.

---

## 📁 Estrutura

| Pasta | O que tem |
|---|---|
| `shell/` | O shell do Psito: top bar, dock, launcher, notificações, Alt+Tab e OSD como superfícies layer-shell do labwc, mais a ponte que gera a configuração do compositor e o tema GTK. Com a sessão (`session/`: o labwc, o sandbox dos apps e os portais), vira o pacote `psito-shell` |
| `apps/<id>/` | Os apps do Psito, um projeto Flutter por app, cada um no próprio processo e numa janela comum. O `.desktop` de cada um é o manifesto (cor, ícone e permissões) |
| `examples/` | Um app de terceiro (`hello_psito`), fora da árvore do sistema, instalado sem recompilar o shell |
| `tools/` | O `psito-deb` (empacota um app, o shell, o runtime ou o metapacote) e a medição dos apps na VM |
| `system_shell/` | Os widgets e um laboratório de UX que roda no host, com os apps dentro do processo |
| `packages/psito_sdk/` | O contrato entre o shell e os apps (`PsitoApp`, `PsitoAppContext`, notificações, configurações e atalhos) |
| `packages/psito_runtime/` | O runtime dos apps: `runPsitoApp` e o canal da janela |
| `packages/psito_services/` | Os serviços do sistema pelo D-Bus (rede, áudio, bateria, energia, hora e o cliente das configurações) |
| `spike/` | A bancada da fase 3: o app de referência (`probe/`), as medições e a configuração de cada compositor comparado |
| `vm/` | O que vai para a VM de desenvolvimento: `preseed.cfg`, o serviço `psito-os` (a sessão no tty1) e as regras do polkit |
| Raiz | Scripts do host: criar, instalar e subir a VM, compilar, publicar e ver os logs |

---

## 🛠️ Requisitos

- **Host:** Linux com QEMU e KVM, `rsync`, `openssl` e o SDK do Flutter (3.47). O shell e os apps são compilados dentro da VM, com o Flutter que o `provision.sh` instala nela.

- **ISO do Debian 13** (netinst) em `debian/debian-netinst.iso`.

## 🚀 Começando

### O laboratório de UX no host

Sem VM, com as janelas dentro do processo e os serviços do sistema falsos:

```bash
cd system_shell
PSITO_SERVICES=fake flutter run -d linux
```

### A VM

```bash
./create-disk.sh     # cria qemu/psito-disk.qcow2
./install-os.sh      # instala o Debian sem interação (vm/preseed.cfg + sua chave SSH)
./run.sh             # sobe a VM (SSH em localhost:2222), em outro terminal
./provision.sh       # labwc, gtk-layer-shell, Flutter e a sessão do Psito
./build.sh           # compila o shell e os apps dentro da VM
./deploy.sh          # instala o shell e os apps como pacotes (psito-desktop) e reinicia o shell
./logs.sh            # o log do shell na VM
```

O `install-os.sh` pede a senha do usuário `psito` no terminal, ou gera uma e a guarda em `qemu/` (fora do git). Depois do `provision.sh`, a VM sobe direto no labwc com o shell.

### Um app de terceiro

Um app do Psito é um projeto Flutter Linux que depende do `psito_sdk` e do `psito_runtime`, com um `.desktop` que é o manifesto:

```ini
[Desktop Entry]
Type=Application
Name=Hello Psito
Exec=/usr/lib/psito/apps/com.example.hello_psito/hello_psito
Icon=com.example.hello_psito
X-Psito-App=hello_psito
X-Psito-Color=#9C27B0
X-Psito-Permissions=network;notifications;
```

As permissões são `network`, `settings`, `files:home` e `notifications`. Sem nenhuma, o app tem um `$HOME` só dele, não tem rede e só lê as configurações. O [`examples/hello_psito`](examples/hello_psito/) é um exemplo completo:

```bash
./install-app.sh examples/hello_psito   # compila, empacota (tools/psito-deb) e instala na VM
```

O app aparece no launcher sem reiniciar o shell.

Para abrir arquivos, o app declara os tipos no `MimeType=` e o código de campo no `Exec` (`%f` ou `%U`); os caminhos chegam em `context.openedPaths`. Um app sem `files:home` recebe só o arquivo aberto, montado pelo shell no sandbox. Para abrir um arquivo em outro app, o app chama `context.open(paths)`, e o shell escolhe o padrão.

### A bancada da fase 3

```bash
DISK=qemu/psito-spike.qcow2 ./create-disk.sh
spike/vm.sh install-os.sh
spike/vm.sh run.sh             # em outro terminal (SSH em localhost:2223)
spike/vm.sh provision.sh && spike/provision.sh
VM_PORT=2223 ./build.sh && VM_PORT=2223 ./deploy.sh
spike/session.sh labwc         # ou wayfire, weston
```

Não suba as duas VMs ao mesmo tempo num host com pouca memória.

### Testes e análise

```bash
./check.sh          # flutter analyze, só os problemas
./test.sh           # flutter test de todos os projetos, só as falhas
```

O `test.sh` roda 2 processos de teste num escopo do systemd com 2 GB de limite (`TEST_JOBS` e `TEST_MEM`), para não esgotar a memória do host com a VM ligada.

---

## 🤝 Contribuindo

Veja o [`CONTRIBUTING.md`](CONTRIBUTING.md). Para falhas de segurança, veja o [`SECURITY.md`](SECURITY.md). A participação segue o [Código de Conduta](CODE_OF_CONDUCT.md).

## ⚖️ Licença e termos de uso

- O código é licenciado sob a [Apache License 2.0](LICENSE). Os patches de terceiros (os do Zenith, em `spike/patches/`) seguem a licença do projeto que modificam (veja o [`NOTICE`](NOTICE)).
- **Sem garantia:** o software é fornecido "como está" (Apache-2.0, seções 7 e 8). Os scripts criam discos, instalam sistemas e mudam configurações *dentro das VMs*; leia antes de rodar fora delas.
- **Nome:** a licença não dá o direito de usar o nome "Psito" ou a identidade visual em outros produtos. Forks são bem-vindos com outro nome.
