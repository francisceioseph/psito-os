# Segurança

O Psito OS é experimental e roda em VMs de desenvolvimento. Ainda não há versões com suporte.

## Como relatar uma falha

Não abra uma issue pública. Use o [relato privado de vulnerabilidades do GitHub](https://github.com/francisceioseph/psito-os/security/advisories/new) e descreva:

- o que acontece e o que você esperava;
- como reproduzir (o commit, e se foi no host ou na VM);
- o impacto que você vê.

A resposta é feita com o melhor esforço, sem prazo garantido.

## O que interessa

- Os serviços que o shell expõe no D-Bus (`org.psito.Shell` e `org.freedesktop.Notifications`) e as regras do polkit em `vm/polkit/`.
- Os scripts que configuram a VM (`provision.sh`, `vm/`, `spike/guest/`).
- O host dos apps (`apps/`), que lê e grava o `settings.json`.
- A ponte que escreve a configuração do compositor e do GTK (`shell/lib/bridge/`).
