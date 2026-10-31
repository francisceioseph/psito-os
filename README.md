# 🦜 Psito OS

Um sistema operacional baseado em Linux cuja interface inteira é feita em **Flutter**: o shell, as Configurações e os apps do sistema.

> **Estado:** experimental. Hoje o Psito roda numa VM QEMU com Debian 13 e serve para desenvolver e medir a arquitetura. Não é para uso em produção.

---

## 💡 A ideia

A ideia é parecida com a do Fuchsia: tudo que é do Psito é Flutter. Mas o Psito não reescreve o que já é maduro no Linux:

- **O compositor é maduro e não é escrito em Flutter.** O shell do Psito é um cliente Wayland privilegiado do [labwc](https://labwc.github.io/): top bar, dock, launcher, notificações e o Alt+Tab são superfícies layer-shell. O modelo é o Budgie 10.10, cujo painel é um cliente layer-shell sobre o labwc.
- **As Configurações geram a configuração do compositor.** Atalhos, cores da moldura e o tema GTK saem das configurações do Psito, por uma ponte em Dart.
- **Os apps rodam em processos separados.** O contrato entre o shell e os apps é o pacote `psito_sdk`.
- **Os serviços do sistema são os de sempre,** pelo D-Bus: NetworkManager, PipeWire, UPower, logind, hostnamed e timedated.

## 🗺️ Onde o projeto está

| Fase | O quê | Estado |
|---|---|---|
| 0 | Fundação: a VM, o `flutter-pi` direto no DRM/KMS (sem Wayland) e o boot no tty1 | feita |
| 1 | O shell como laboratório de UX: janelas, dock, launcher, notificações e Alt+Tab | feita |
| 2 | Os serviços do sistema pelo D-Bus: rede, áudio, bateria, energia, hora e Configurações | feita |
| 3 | A base do compositor e o shell como cliente layer-shell (`spike/`) | em andamento |
| 4 | Apps em processos separados | planejada |
| 5 | Imagem do sistema | planejada |
| 6 | Hardware real | planejada |

Os números da fase 3 (memória, CPU e latência de cada compositor e do shell) ficam em [`spike/results/`](spike/results/), e as leituras em [`spike/notas/`](spike/notas/).

---

## 📁 Estrutura

| Pasta | O que tem |
|---|---|
| `system_shell/` | O shell em Flutter: camadas da área de trabalho, gerenciador de janelas, serviços D-Bus, widgets e os apps de exemplo |
| `packages/psito_sdk/` | O contrato entre o shell e os apps (`PsitoApp`, `PsitoAppContext`, notificações, configurações e atalhos) |
| `spike/` | A bancada da fase 3: o shell como cliente layer-shell (`shell_client/`), o app de referência (`probe/`), as medições e a configuração de cada compositor |
| `vm/` | O que vai para a VM: `preseed.cfg`, o serviço `psito-os` e as regras do polkit |
| `patches/` | Patches do `flutter-pi` (virtio-gpu e entrada de texto) |
| Raiz | Scripts do host: criar, instalar e subir a VM, compilar, publicar e ver os logs |

---

## 🛠️ Requisitos

- **Host:** Linux com QEMU e KVM, `rsync`, `openssl` e o SDK do Flutter.
- **`flutterpi_tool`**, instalado do git (a versão do pub.dev não compila com o Flutter 3.47+):

  ```bash
  flutter pub global activate --source git https://github.com/ardera/flutterpi_tool
  ```

- **ISO do Debian 13** (netinst) em `debian/debian-netinst.iso`.

## 🚀 Começando

### Rodar o shell no próprio host

Sem VM, com os serviços do sistema falsos:

```bash
cd system_shell
PSITO_SERVICES=fake flutter run -d linux
```

### A VM da fase 1 (flutter-pi no DRM/KMS)

```bash
./create-disk.sh     # cria qemu/psito-disk.qcow2
./install-os.sh      # instala o Debian sem interação (vm/preseed.cfg + sua chave SSH)
./run.sh             # sobe a VM (SSH em localhost:2222), em outro terminal
./provision.sh       # dependências, flutter-pi com os patches e o serviço psito-os
./build.sh           # release (padrão), profile ou debug
./deploy.sh          # envia o bundle e reinicia o serviço
```

O `install-os.sh` pede a senha do usuário `psito` no terminal, ou gera uma e a guarda em `qemu/` (fora do git).

### A bancada da fase 3 (o shell sobre o labwc)

```bash
DISK=qemu/psito-spike.qcow2 ./create-disk.sh
spike/vm.sh install-os.sh
spike/vm.sh run.sh             # em outro terminal (SSH em localhost:2223)
spike/vm.sh provision.sh && spike/provision.sh
spike/shell_client/build.sh    # compila o shell dentro da VM
spike/session.sh labwc         # sobe o labwc no tty1, com o shell
```

Não suba as duas VMs ao mesmo tempo num host com pouca memória.

### Testes e análise

```bash
./check.sh                              # flutter analyze, só os problemas
(cd system_shell && flutter test)
(cd spike/shell_client && flutter test)
```

---

## 🤝 Contribuindo

Veja o [`CONTRIBUTING.md`](CONTRIBUTING.md). Para falhas de segurança, veja o [`SECURITY.md`](SECURITY.md). A participação segue o [Código de Conduta](CODE_OF_CONDUCT.md).

## ⚖️ Licença e termos de uso

- O código é licenciado sob a [Apache License 2.0](LICENSE). Os patches de terceiros seguem a licença do projeto que modificam (veja o [`NOTICE`](NOTICE)).
- **Sem garantia:** o software é fornecido "como está" (Apache-2.0, seções 7 e 8). Os scripts criam discos, instalam sistemas e mudam configurações *dentro das VMs*; leia antes de rodar fora delas.
- **Nome:** a licença não dá o direito de usar o nome "Psito" ou a identidade visual em outros produtos. Forks são bem-vindos com outro nome.
