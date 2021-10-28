#!/bin/bash

# SafeVPN Script (Simplified for TryHackMe - IP only)
# Author: Nisrin Ahmed aka Wh1teDrvg0n (modified and upgraded by Miguel Ángel Villalobos)
#
# Description:
# This script configures iptables to restrict traffic to a specific IP, 
# improving security when connecting to TryHackMe. It dynamically extracts the 
# VPN server IP and port from the .ovpn file.
#
# Usage:
# 1. Save this code as safevpn.sh.
# 2. Make it executable: chmod +x safevpn.sh
# 3. Run BEFORE connecting the VPN:
#    sudo ./safevpn.sh <target_machine_IP>
#    Example: sudo ./safevpn.sh 10.10.10.10
# 4. Connect to the VPN with OpenVPN:
#    sudo openvpn YourFile.ovpn (replace YourFile.ovpn with your .ovpn file)
# 5. To clear iptables rules created by this script:
#    sudo ./safevpn.sh --flush
#    or to attempt restore first:
#    sudo ./safevpn.sh --flush restore
#
# Important notes:
# - Replace "YourFile.ovpn" with the actual name of your .ovpn file.
# - Obtain the target machine IP from the TryHackMe page (it changes!).
# - Run the script with the correct IP every time you change machines on TryHackMe.
# - This script blocks all IPv6 traffic.
# - This script saves the current iptables rules before applying new ones and restores them when using --flush restore.
# - Verify the applied iptables rules with: sudo iptables -L -n -v
# - If you encounter issues, check the OpenVPN logs for troubleshooting.

OVPN_FILE="YourFile.ovpn"

# Detect default interface automatically
DEFAULT_INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n 1)

# Function: Show usage instructions
usage() {
    echo "Usage: $0 <IP> [--flush [restore]]"
    echo "    <IP>           IP address of the machine to allow on tun0."
    echo "    --flush        Flush rules completely (recommended)."
    echo "    --flush restore Attempt to restore previous iptables rules if backups exist."
    exit 1
}

# Function: Validate an IP address
valid_ip() {
    local ip=$1
    local stat=1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        if [[ ${octets[0]} -le 255 && ${octets[1]} -le 255 && ${octets[2]} -le 255 && ${octets[3]} -le 255 ]]; then
            stat=0
        fi
    fi
    return $stat
}

# Function: Perform a full flush of iptables
full_flush() {
    echo "Performing a full flush of all iptables rules..."
    iptables -F
    iptables -X
    iptables -Z
    ip6tables -F
    ip6tables -X
    ip6tables -Z
    echo "All iptables rules flushed."
}

# Function: Attempt to restore saved iptables rules
restore_rules() {
    if [[ -f /tmp/iptables.rules && -f /tmp/ip6tables.rules ]]; then
        echo "Restoring previous iptables rules..."
        iptables-restore < /tmp/iptables.rules
        ip6tables-restore < /tmp/ip6tables.rules
        rm /tmp/iptables.rules
        rm /tmp/ip6tables.rules
        echo "Rules restored."
        return 0
    else
        echo "No iptables backup files found."
        return 1
    fi
}

# Function: Flush rules with options (full flush or restore)
flush_rules() {
  # Check if tun0 interface is active
  if ip link show tun0 &> /dev/null; then
    echo "The tun0 interface seems to be active. It is recommended to close the VPN connection before flushing."
    read -p "Do you want to continue anyway? (y/n): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
      echo "Aborting iptables flush."
      exit 1
    fi
  fi

  # If user specified restore, try to restore first
  if [[ $1 == "restore" ]]; then
    if ! restore_rules; then
      # If restoration fails, ask whether to do a full flush
      echo "No previous rules to restore. Do you want to do a full flush instead? (y/n): "
      read -p "" confirm_flush
      if [[ $confirm_flush == "y" || $confirm_flush == "Y" ]]; then
        full_flush
      else
        echo "Aborting operation. No changes made."
        exit 1
      fi
    fi
  else
    # Default to full flush
    full_flush
  fi
}


# Function: Configure iptables rules for a specific IP
configure_rules() {
    local ip=$1
    echo "Configuring iptables for IP: $ip..."

    # Save current rules
    iptables-save > /tmp/iptables.rules
    ip6tables-save > /tmp/ip6tables.rules

    # Check if OVPN_FILE exists
    if [[ ! -f "$OVPN_FILE" ]]; then
        echo "Error: File $OVPN_FILE not found."
        exit 1
    fi

    # Extract VPN server IP and port
    REMOTE_IP=$(awk '/^remote / {print $2; exit}' "$OVPN_FILE")
    REMOTE_PORT=$(awk '/^remote / {print $3; exit}' "$OVPN_FILE")

    # Validate extraction
    if [[ -z "$REMOTE_IP" || -z "$REMOTE_PORT" ]]; then
        echo "Error: Could not extract IP address or port from .ovpn file."
        exit 1
    fi

    echo "VPN Server: $REMOTE_IP:$REMOTE_PORT"
    echo "Default Interface: $DEFAULT_INTERFACE"

    # Flush existing rules to start from scratch
    iptables -F
    iptables -X
    iptables -Z
    ip6tables -F
    ip6tables -X
    ip6tables -Z

    # IPv6 rules (drop everything)
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT DROP

    # Allow all loopback traffic
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Allow established and related connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Allow traffic to the VPN server on the main interface
    iptables -A OUTPUT -o "${DEFAULT_INTERFACE}" -d "$REMOTE_IP" -p udp --dport "$REMOTE_PORT" -j ACCEPT
    iptables -A INPUT -i "${DEFAULT_INTERFACE}" -s "$REMOTE_IP" -p udp --sport "$REMOTE_PORT" -j ACCEPT

    # Allow traffic to/from the specified machine via tun0
    iptables -A INPUT -i "tun0" -p icmp -s "$ip" --icmp-type echo-request -j ACCEPT
    iptables -A INPUT -i "tun0" -p icmp -s "$ip" --icmp-type echo-reply -j ACCEPT
    iptables -A OUTPUT -o "tun0" -p icmp -d "$ip" --icmp-type echo-reply -j ACCEPT
    iptables -A OUTPUT -o "tun0" -p icmp -d "$ip" --icmp-type echo-request -j ACCEPT

    iptables -A INPUT -i "tun0" -p tcp -s "$ip" -j ACCEPT
    iptables -A OUTPUT -o "tun0" -p tcp -d "$ip" -j ACCEPT
    iptables -A INPUT -i "tun0" -p udp -s "$ip" -j ACCEPT
    iptables -A OUTPUT -o "tun0" -p udp -d "$ip" -j ACCEPT

    # Block everything else on tun0
    iptables -A INPUT -i "tun0" -j DROP
    iptables -A OUTPUT -o "tun0" -j DROP

    echo "Firewall rules applied. Connect to your VPN now."
}

# Main script logic
main() {
    if [[ $1 == "--flush" ]]; then
        flush_rules "$2"
        exit 0
    fi

    if [[ -z $1 ]]; then
        usage
    fi

    if ! valid_ip "$1"; then
        echo "Error: The IP '$1' is not valid."
        usage
    fi

    configure_rules "$1"
}

main "$@"
