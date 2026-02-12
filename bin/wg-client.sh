#!/bin/bash
#
# wg-client.sh - WireGuard client management for Raspberry Pi
# Usage: wg-client.sh <command>
#

# --- Configuration ---
WG_INTERFACE="${WG_INTERFACE:-wg0}"
VPN_SERVER_IP="10.0.0.1"
CHECK_URL="https://ifconfig.me"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helpers ---
print_ok()   { echo -e "${GREEN}✔${NC} $1"; }
print_fail() { echo -e "${RED}✘${NC} $1"; }
print_info() { echo -e "${CYAN}ℹ${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

need_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "This command requires sudo. Re-running with sudo..."
        exec sudo "$0" "$@"
    fi
}

is_up() {
    ip link show "$WG_INTERFACE" &>/dev/null
}

# --- Commands ---

cmd_status() {
    echo -e "${CYAN}=== WireGuard Client Status ===${NC}"
    echo

    if is_up; then
        print_ok "Interface ${WG_INTERFACE} is UP"
    else
        print_fail "Interface ${WG_INTERFACE} is DOWN"
        return 1
    fi

    echo
    sudo wg show "$WG_INTERFACE"

    echo
    echo -e "${CYAN}--- Interface Details ---${NC}"
    ip -brief addr show "$WG_INTERFACE"
}

cmd_up() {
    if is_up; then
        print_warn "${WG_INTERFACE} is already up"
        return 0
    fi
    need_root "$@"
    wg-quick up "$WG_INTERFACE"
    if is_up; then
        print_ok "${WG_INTERFACE} is up"
    else
        print_fail "Failed to bring up ${WG_INTERFACE}"
        return 1
    fi
}

cmd_down() {
    if ! is_up; then
        print_warn "${WG_INTERFACE} is already down"
        return 0
    fi
    need_root "$@"
    wg-quick down "$WG_INTERFACE"
    if ! is_up; then
        print_ok "${WG_INTERFACE} is down"
    else
        print_fail "Failed to bring down ${WG_INTERFACE}"
        return 1
    fi
}

cmd_restart() {
    need_root "$@"
    echo "Restarting ${WG_INTERFACE}..."
    if is_up; then
        wg-quick down "$WG_INTERFACE" 2>/dev/null
        sleep 1
    fi
    wg-quick up "$WG_INTERFACE"
    if is_up; then
        print_ok "${WG_INTERFACE} restarted"
    else
        print_fail "Failed to restart ${WG_INTERFACE}"
        return 1
    fi
}

cmd_ip() {
    echo "Checking public IP..."
    local ip
    ip=$(curl -s --max-time 10 "$CHECK_URL")
    if [[ -n "$ip" ]]; then
        print_info "Public IP: ${GREEN}${ip}${NC}"
    else
        print_fail "Could not determine public IP"
        return 1
    fi
}

cmd_ping() {
    echo "Pinging VPN server (${VPN_SERVER_IP})..."
    if ping -c 3 -W 2 "$VPN_SERVER_IP"; then
        echo
        print_ok "VPN server is reachable"
    else
        echo
        print_fail "VPN server is unreachable"
        return 1
    fi
}

cmd_dns() {
    echo "Testing DNS resolution..."
    local domains=("google.com" "github.com" "xfinity.com")
    local ok=true
    for domain in "${domains[@]}"; do
        if result=$(dig +short "$domain" 2>/dev/null | head -1) && [[ -n "$result" ]]; then
            print_ok "${domain} → ${result}"
        else
            print_fail "${domain} — resolution failed"
            ok=false
        fi
    done
    if ! $ok; then
        print_warn "Some DNS lookups failed. Check /etc/resolv.conf or VPN DNS settings."
    fi
}

cmd_check() {
    echo -e "${CYAN}=== Full Connectivity Check ===${NC}"
    echo

    # Interface
    if is_up; then
        print_ok "Interface ${WG_INTERFACE} is UP"
    else
        print_fail "Interface ${WG_INTERFACE} is DOWN"
        echo "Run: $(basename "$0") up"
        return 1
    fi

    # Handshake
    local handshake
    handshake=$(sudo wg show "$WG_INTERFACE" latest-handshakes 2>/dev/null | awk '{print $2}')
    if [[ -n "$handshake" && "$handshake" != "0" ]]; then
        local now age
        now=$(date +%s)
        age=$(( now - handshake ))
        if (( age < 180 )); then
            print_ok "Latest handshake: ${age}s ago"
        else
            print_warn "Latest handshake: ${age}s ago (stale — may need restart)"
        fi
    else
        print_warn "No handshake recorded"
    fi

    # Ping VPN server
    if ping -c 1 -W 2 "$VPN_SERVER_IP" &>/dev/null; then
        print_ok "VPN server (${VPN_SERVER_IP}) reachable"
    else
        print_fail "VPN server (${VPN_SERVER_IP}) unreachable"
    fi

    # DNS
    if dig +short google.com &>/dev/null; then
        print_ok "DNS resolution working"
    else
        print_fail "DNS resolution failed"
    fi

    # Public IP
    local ip
    ip=$(curl -s --max-time 10 "$CHECK_URL")
    if [[ -n "$ip" ]]; then
        print_ok "Public IP: ${ip}"
    else
        print_fail "Could not determine public IP"
    fi

    # Transfer stats
    echo
    echo -e "${CYAN}--- Transfer Stats ---${NC}"
    sudo wg show "$WG_INTERFACE" transfer | while read -r key rx tx; do
        echo "  Peer: ${key:0:8}..."
        echo "  ↓ Received: $(numfmt --to=iec "$rx" 2>/dev/null || echo "${rx} bytes")"
        echo "  ↑ Sent:     $(numfmt --to=iec "$tx" 2>/dev/null || echo "${tx} bytes")"
    done
}

cmd_config() {
    local conf="/etc/wireguard/${WG_INTERFACE}.conf"
    if [[ -f "$conf" ]]; then
        print_info "Config: ${conf}"
        echo
        sudo cat "$conf"
    else
        print_fail "Config file not found: ${conf}"
        return 1
    fi
}

cmd_log() {
    local lines="${1:-20}"
    echo -e "${CYAN}=== Recent WireGuard Logs ===${NC}"
    sudo journalctl -u "wg-quick@${WG_INTERFACE}" -n "$lines" --no-pager
}

cmd_help() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  status    Show WireGuard interface status and peer info
  up        Bring the VPN interface up
  down      Bring the VPN interface down
  restart   Restart the VPN interface
  ip        Show your current public IP address
  ping      Ping the VPN server
  dns       Test DNS resolution
  check     Full connectivity diagnostic
  config    Show WireGuard config file
  log [n]   Show recent WireGuard logs (default: 20 lines)
  help      Show this help message

Environment:
  WG_INTERFACE   WireGuard interface name (default: wg0)

Examples:
  $(basename "$0") check
  $(basename "$0") restart
  WG_INTERFACE=wg1 $(basename "$0") status
EOF
}

# --- Main ---
case "${1:-help}" in
    status)  cmd_status ;;
    up)      cmd_up "$@" ;;
    down)    cmd_down "$@" ;;
    restart) cmd_restart "$@" ;;
    ip)      cmd_ip ;;
    ping)    cmd_ping ;;
    dns)     cmd_dns ;;
    check)   cmd_check ;;
    config)  cmd_config ;;
    log)     cmd_log "$2" ;;
    help|-h|--help) cmd_help ;;
    *)
        print_fail "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac
