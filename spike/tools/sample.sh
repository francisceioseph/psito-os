#!/bin/bash
# Roda dentro da VM, com sudo (o smaps_rollup do compositor exige). Para cada
# pid: PSS total e anônimo (KiB) e CPU (% de um núcleo) em N segundos.
# O PSS total divide as bibliotecas compartilhadas (Mesa) entre os processos,
# então cai quando abrem mais clientes; o anônimo é a memória própria.
# Uso: sample.sh <segundos> <pid>...   Saída: pid,comm,pss_kib,pss_anon_kib,cpu_pct
set -e
# A CPU sai com ponto decimal, não com a vírgula do pt_BR (o CSV usa vírgula)
export LC_ALL=C

secs="$1"
shift
hz=$(getconf CLK_TCK)

ticks() { awk '{print $14 + $15}' "/proc/$1/stat"; }

declare -A before
for pid in "$@"; do before[$pid]=$(ticks "$pid"); done
sleep "$secs"
for pid in "$@"; do
    after=$(ticks "$pid")
    pss=$(awk '/^Pss:/ {print $2}' "/proc/$pid/smaps_rollup")
    anon=$(awk '/^Pss_Anon:/ {print $2}' "/proc/$pid/smaps_rollup")
    comm=$(cat "/proc/$pid/comm")
    cpu=$(awk -v d="$((after - ${before[$pid]}))" -v hz="$hz" -v s="$secs" \
        'BEGIN {printf "%.2f", 100 * d / hz / s}')
    echo "$pid,$comm,$pss,$anon,$cpu"
done
