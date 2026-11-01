#!/usr/bin/env bash
# vm/wifi-lab.sh: redes Wi-Fi de teste na VM, com rádios virtuais (mac80211_hwsim).
# Só para desenvolvimento. O wlan0 fica com o NetworkManager, como um adaptador
# de verdade, e cada um dos outros rádios é um ponto de acesso, num namespace de
# rede próprio. Fora dele, o NetworkManager e o wpa_supplicant disputam o rádio.
#
#   sudo vm/wifi-lab.sh up      sobe as redes
#   sudo vm/wifi-lab.sh down    derruba tudo e tira os rádios
#
# Os pontos não dão rota padrão: a internet da VM continua no cabo. Desligar o
# Wi-Fi na interface bloqueia todos os rádios, os pontos também: depois disso,
# é preciso um down e um up.
set -euo pipefail

RUN=/run/psito-wifi-lab
NS=psito-wifi-lab
# rádio|nome|segurança|senha de teste|oculta
NETWORKS=(
    "wlan1|Psito Aberta|open||0"
    "wlan2|Psito WPA2|wpa2|psito-lab-wpa2|0"
    "wlan3|Psito WPA3|sae|psito-lab-wpa3|0"
    "wlan4|Psito Oculta|wpa2|psito-lab-oculta|1"
)

up() {
    export PATH="$PATH:/usr/sbin:/sbin"
    command -v hostapd >/dev/null || apt-get install -y --no-install-recommends hostapd iw
    systemctl mask --now hostapd.service >/dev/null 2>&1 || true
    modprobe mac80211_hwsim radios=$((${#NETWORKS[@]} + 1))
    mkdir -p "$RUN"
    ip netns add "$NS"
    # O udev e o NetworkManager precisam ver os rádios antes de eles saírem
    sleep 2
    local n=0 entry iface ssid security password hidden
    for entry in "${NETWORKS[@]}"; do
        IFS='|' read -r iface ssid security password hidden <<<"$entry"
        n=$((n + 1))
        iw phy "$(cat "/sys/class/net/$iface/phy80211/name")" set netns name "$NS"
        {
            echo "interface=$iface"
            echo "driver=nl80211"
            echo "ssid=$ssid"
            echo "utf8_ssid=1"
            echo "hw_mode=g"
            echo "channel=$(((n - 1) % 3 * 5 + 1))"
            echo "ignore_broadcast_ssid=$hidden"
            case "$security" in
                wpa2)
                    echo "wpa=2"
                    echo "wpa_key_mgmt=WPA-PSK"
                    echo "rsn_pairwise=CCMP"
                    echo "wpa_passphrase=$password"
                    ;;
                sae)
                    echo "wpa=2"
                    echo "wpa_key_mgmt=SAE"
                    echo "rsn_pairwise=CCMP"
                    echo "ieee80211w=2"
                    echo "sae_password=$password"
                    ;;
            esac
        } >"$RUN/$iface.conf"
        ip netns exec "$NS" hostapd -B -P "$RUN/$iface.hostapd.pid" -f "$RUN/$iface.hostapd.log" "$RUN/$iface.conf"
        ip -n "$NS" addr add "10.77.$n.1/24" dev "$iface"
        ip netns exec "$NS" dnsmasq --interface="$iface" --bind-interfaces --port=0 --no-resolv \
            --dhcp-range="10.77.$n.10,10.77.$n.50,1h" --dhcp-option=3 --dhcp-option=6 \
            --dhcp-leasefile="$RUN/$iface.leases" --pid-file="$RUN/$iface.dnsmasq.pid"
    done
    echo "Redes no ar: wlan0 é o adaptador do NetworkManager."
}

down() {
    export PATH="$PATH:/usr/sbin:/sbin"
    local pid
    for pid in "$RUN"/*.pid; do
        [ -e "$pid" ] && kill "$(cat "$pid")" 2>/dev/null || true
    done
    rm -rf "$RUN"
    ip netns delete "$NS" 2>/dev/null || true
    sleep 1
    modprobe -r mac80211_hwsim 2>/dev/null || true
    echo "Bancada desligada."
}

case "${1:-}" in
    up) up ;;
    down) down ;;
    *) echo "Uso: $0 up|down" >&2; exit 2 ;;
esac
