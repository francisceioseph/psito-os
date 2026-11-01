#!/usr/bin/env bash
# vm/vpn-lab.sh: servidores de VPN de teste na VM, num namespace de rede ligado por
# um par veth. Só para desenvolvimento. Deixa os arquivos que o Psito importa em
# ~psito/vpn-lab/, e a VPN responde ao ping em 10.88.1.1 (WireGuard) e 10.88.2.1
# (OpenVPN), endereços que só existem com ela ligada. Ligado, o OpenVPN só passa
# tráfego depois de `sudo ip route del 10.88.0.1`: o NetworkManager manda o caminho
# até o servidor pelo cabo, e aqui ele está no veth. Isso é só da bancada.
#
#   sudo vm/vpn-lab.sh up      sobe os servidores
#   sudo vm/vpn-lab.sh down    derruba tudo
set -euo pipefail

export PATH="$PATH:/usr/sbin:/sbin"
RUN=/run/psito-vpn-lab
NS=psito-vpn-lab
OWNER=${SUDO_USER:-psito}
OUT=$(getent passwd "$OWNER" | cut -d: -f6)/vpn-lab
SERVER=10.88.0.1
CLIENT=10.88.0.2

wireguard() {
    local server_key client_key
    server_key=$(wg genkey)
    client_key=$(wg genkey)
    ip -n "$NS" link add wg0 type wireguard
    printf '%s\n' "$server_key" >"$RUN/wg-server.key"
    ip netns exec "$NS" wg set wg0 listen-port 51820 private-key "$RUN/wg-server.key" \
        peer "$(wg pubkey <<<"$client_key")" allowed-ips 10.88.1.2/32
    ip -n "$NS" addr add 10.88.1.1/24 dev wg0
    ip -n "$NS" link set wg0 up
    cat >"$OUT/psito-wg.conf" <<CONF
[Interface]
PrivateKey = $client_key
Address = 10.88.1.2/24

[Peer]
PublicKey = $(wg pubkey <<<"$server_key")
AllowedIPs = 10.88.1.0/24
Endpoint = $SERVER:51820
CONF
}

# Uma autoridade própria, um certificado para cada lado
openvpn_server() {
    local pki="$RUN/pki"
    mkdir -p "$pki"
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 2 \
        -subj /CN=psito-lab-ca -keyout "$pki/ca.key" -out "$pki/ca.crt" 2>/dev/null
    local who
    for who in server client; do
        openssl req -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
            -subj "/CN=psito-lab-$who" -keyout "$pki/$who.key" -out "$pki/$who.csr" 2>/dev/null
        printf 'keyUsage=digitalSignature,keyAgreement\nextendedKeyUsage=%s\n' \
            "$([ "$who" = server ] && echo serverAuth || echo clientAuth)" >"$pki/$who.ext"
        openssl x509 -req -in "$pki/$who.csr" -CA "$pki/ca.crt" -CAkey "$pki/ca.key" -CAcreateserial \
            -days 2 -extfile "$pki/$who.ext" -out "$pki/$who.crt" 2>/dev/null
    done
    ip netns exec "$NS" openvpn --daemon psito-vpn-lab --writepid "$RUN/openvpn.pid" --log "$RUN/openvpn.log" \
        --dev tun0 --proto udp --port 1194 --local "$SERVER" --topology subnet --server 10.88.2.0 255.255.255.0 \
        --ca "$pki/ca.crt" --cert "$pki/server.crt" --key "$pki/server.key" --dh none
    {
        echo "client"
        echo "dev tun"
        echo "proto udp"
        echo "remote $SERVER 1194"
        echo "remote-cert-tls server"
        echo "<ca>"; cat "$pki/ca.crt"; echo "</ca>"
        echo "<cert>"; cat "$pki/client.crt"; echo "</cert>"
        echo "<key>"; cat "$pki/client.key"; echo "</key>"
    } >"$OUT/psito-ovpn.ovpn"
}

up() {
    command -v wg >/dev/null || apt-get install -y --no-install-recommends wireguard-tools
    command -v openvpn >/dev/null || apt-get install -y --no-install-recommends openvpn
    systemctl mask --now openvpn.service >/dev/null 2>&1 || true
    mkdir -p "$RUN" "$OUT"
    ip netns add "$NS"
    ip link add psitovpn0 type veth peer name psitovpn1
    ip link set psitovpn1 netns "$NS"
    nmcli device set psitovpn0 managed no 2>/dev/null || true
    ip addr add "$CLIENT/24" dev psitovpn0
    ip link set psitovpn0 up
    ip -n "$NS" addr add "$SERVER/24" dev psitovpn1
    ip -n "$NS" link set psitovpn1 up
    ip -n "$NS" link set lo up
    wireguard
    openvpn_server
    chown -R "$OWNER:" "$OUT"
    chmod 600 "$OUT"/*
    echo "Servidores no ar: $OUT"
}

down() {
    [ -e "$RUN/openvpn.pid" ] && kill "$(cat "$RUN/openvpn.pid")" 2>/dev/null || true
    ip netns delete "$NS" 2>/dev/null || true
    ip link delete psitovpn0 2>/dev/null || true
    rm -rf "$RUN" "$OUT"
    echo "Bancada de VPN desligada."
}

case "${1:-}" in
    up) up ;;
    down) down ;;
    *) echo "Uso: $0 up|down" >&2; exit 2 ;;
esac
