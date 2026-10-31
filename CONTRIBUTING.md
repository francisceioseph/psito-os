# Contribuindo com o Psito OS

Obrigado pelo interesse. O projeto é experimental e muda de direção a cada fase, então abra uma issue antes de começar algo grande.

## Como o projeto é organizado

- O [`README.md`](README.md) explica a ideia, a estrutura e como subir as VMs.
- O [`CLAUDE.md`](CLAUDE.md) é o guia detalhado do código: o que cada pasta faz, os comandos do host e as regras do projeto.

## Antes de mandar um pull request

1. Rode `./check.sh` (o `flutter analyze`) e o `./test.sh` (os testes de todos os projetos, ou só das pastas que você passar). O `./test.sh` limita os processos de teste e a memória, para caber no host com a VM ligada.
2. Se a mudança aparece na tela, diga como você testou: no laboratório do host (`PSITO_SERVICES=fake flutter run -d linux` em `system_shell/`) ou na VM (`./build.sh && ./deploy.sh`).
3. Mantenha o estilo do código em volta: os nomes, a densidade de comentários e o idioma (comentários e textos da interface em português).

## Regras do projeto

- **Sem emojis na interface,** porque a fonte da VM não tem esses glifos. Nos `debugPrint` eles podem ficar.
- **Hora:** use `ctx.now()` (apps) ou `TimeService.now` (shell), nunca `DateTime.now()`.
- **Atalhos globais** têm uma combinação nativa e uma de VM (`system_shell/lib/shell/shortcuts.dart`); o shell gera os atalhos do labwc a partir dela.
- **Apps** só importam Flutter, pacotes externos e o `psito_sdk`, e cabem na janela mínima de 240×160.
- **Nada de binários, discos ou ISOs** no git: `qemu/`, `debian/` e os `build/` ficam de fora.

## Commits

Mensagens em inglês, no formato `tipo: resumo` (`feat`, `fix`, `chore`, `docs`, `test`), com o porquê no corpo.

## Licença das contribuições

Ao enviar uma contribuição, você concorda que ela é licenciada sob a [Apache License 2.0](LICENSE), como diz a seção 5 da licença, e que tem o direito de enviá-la.
