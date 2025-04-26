#!/bin/bash
# UFW Manager
# Developed by HodaCloud (hodacloud.com)
# ──── Global Settings ────
COL_HDR="\033[1;36m"
COL_MENU="\033[38;5;39m"
COL_ACT="\033[38;5;214m"
COL_OK="\033[1;32m"
COL_ERR="\033[1;31m"
COL_RST="\033[0m"

declare -A MENU=(
    [1]="Status Dashboard"
    [2]="Port Analysis"
    [3]="Auto-Configure"
    [4]="ICMP Control"
    [5]="Live Traffic"
    [6]="Disable FW"
    [7]="Exit"
)

# ──── Core Functions ────
show_header() {
    clear
    echo -e "${COL_HDR}"
    echo "▛▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜"
    printf "▌%-40s   ▐\n" "             UFW Guardian v2.4"
    printf "▌%-40s   ▐\n" "           Developed by HodaCloud"
    echo "▙▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▟"
}

fw_status() {
    echo -e "\n${COL_HDR}◈ Firewall Status ◈${COL_RST}"
    local status=$(sudo ufw status | grep "Status")
    printf "%22s: %s\n" "Protection" "${status/* /}"
    
    if [[ $status == *"active"* ]]; then
        echo -e "\n${COL_HDR}◈ Active Rules ◈${COL_RST}"
        printf "%-8s %-12s %-18s %s\n" "PORT" "PROTO" "SOURCE" "ACTION"
        sudo ufw status | grep ALLOW | awk '{printf "%-8s %-12s %-18s %s\n", $1, $2, $3, $4}'
    fi
}

port_analysis() {
    echo -e "\n${COL_HDR}◈ Network Matrix ◈${COL_RST}"
    printf "%-12s %-8s %-10s %s\n" "PROTO" "PORT" "PID" "SERVICE"
    sudo netstat -tulnp 2>/dev/null | awk 'NR>2 {
        split($4,p,":"); split($7,pid,"/");
        printf "%-12s %-8s %-10s %s\n", $1, p[length(p)], pid[1], pid[2]
    }' | sort -k2n
}

auto_configure_ufw() {
    echo -e "\n${COL_HDR}◈ Smart Configuration ◈${COL_RST}"
    sudo ufw --force reset
    sudo ufw default deny incoming
    
    echo -e "${COL_OK}■ Detecting listening ports...${COL_RST}"
    sudo netstat -tuln | grep 'LISTEN' | awk '{print $4}' | awk -F':' '{print $NF}' | sort -u | while read port; do
        sudo ufw allow "$port"
        echo "  Allowed port: $port"
    done
    
    sudo ufw --force enable
    echo -e "\n${COL_OK}✓ Firewall reconfigured successfully${COL_RST}"
}

icmp_control() {
    local current=$(sysctl -n net.ipv4.icmp_echo_ignore_all)
    echo -e "\n${COL_HDR}◈ ICMP Manager ◈${COL_RST}"
    echo -e "Current State: $([ $current -eq 1 ] && echo "${COL_ERR}Blocked" || echo "${COL_OK}Allowed")${COL_RST}"

    if [ $current -eq 1 ]; then
        read -p "$(echo -e "${COL_ACT}"$'\n'" Enable ping? [Y/n]: "${COL_RST})" ans
        if [[ "${ans:-Y}" =~ [Yy] ]]; then
            # Remove existing setting and add new value
            sudo sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
            echo "net.ipv4.icmp_echo_ignore_all = 0" | sudo tee -a /etc/sysctl.conf
        fi
    else
        read -p "$(echo -e "${COL_ACT}"$'\n'" Disable ping? [Y/n]: "${COL_RST})" ans
        if [[ "${ans:-Y}" =~ [Yy] ]]; then
            # Remove existing setting and add new value
            sudo sed -i '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
            echo "net.ipv4.icmp_echo_ignore_all = 1" | sudo tee -a /etc/sysctl.conf
        fi
    fi

    # Apply changes and verify
    sudo sysctl -p >/dev/null
    new_state=$(sysctl -n net.ipv4.icmp_echo_ignore_all)
    echo -e "\n${COL_OK}✓ New State: $([ $new_state -eq 1 ] && echo "Blocked" || echo "Allowed")${COL_RST}"
}

live_traffic() {
    command -v iftop >/dev/null || {
        echo -e "${COL_ERR}iftop missing! Install? [Y/n]:${COL_RST}"
        read -n1 ans
        [[ "${ans:-Y}" =~ [Yy] ]] && sudo apt install -y iftop
    }
    echo -e "\n${COL_HDR}◈ Live Traffic Monitor ◈${COL_RST}"
    sudo iftop -P -n -N -i $(ip route | awk '/default/{print $5}')
}

# ──── Menu System ────
show_menu() {
    echo -e "\n${COL_MENU}▌ Select Operation:${COL_RST}"
    for i in {1..7}; do
        if ((i <= 6)); then
            printf "  ${COL_ACT}%d.${COL_RST} %-18s" "$i" "${MENU[$i]}"
            ((i%2 == 0)) && echo
        else
            echo -e "  ${COL_ACT}7.${COL_RST} ${MENU[7]}"
        fi
    done
}

# ──── Main Execution ────
while true; do
    show_header
    show_menu
    echo -en "\n${COL_ACT}➤ Enter choice [1-7]:${COL_RST} "
    read -n1 choice
    echo
    
    case $choice in
        1) fw_status ;;
        2) port_analysis ;;
        3) auto_configure_ufw ;;
        4) icmp_control ;;
        5) live_traffic ;;
        6) echo -e "\n${COL_ERR}■ Disabling firewall...${COL_RST}" && sudo ufw disable ;;
        7) echo -e "\n${COL_OK}■ Thank you for using HodaCloud's solution! ■${COL_RST}\n"; exit 0 ;;
        *) echo -e "\n${COL_ERR}■ Invalid selection! ■${COL_RST}" ;;
    esac
    
    echo -en "\n${COL_ACT}↵ Press Enter to continue...${COL_RST}"
    read -r
done
