#!/bin/bash
#==========================================================================
# Debian distro include — 提供 distro 特定函数和变量
# 被 common 主体脚本 source，不直接执行
#==========================================================================

DISTRO_ID="debian"
SSH_SERVICE="ssh"
# /etc/ophub-release is always written by rebuild's refactor_rootfs and contains
# BOARD, BOARDFAMILY, BOARD_NAME, etc. Using it keeps behavior consistent across
# distros (Debian's /etc/debian-release lacks board info).
RELEASE_FILE="/etc/ophub-release"
RAMLOG_NAME="debian-ramlog"
LOG_FILE="/var/log/debian-hardware-monitor.log"

# 检查包是否安装
check_if_installed() {
    local DPKG_Status="$(dpkg -s "$1" 2>/dev/null | awk -F": " '/^Status/ {print $2}')"
    if [[ "X${DPKG_Status}" = "X" || "${DPKG_Status}" = *deinstall* ]]; then
        return 1
    else
        return 0
    fi
}

# 获取内核分支（current/legacy/edge）
get_kernel_branch() {
    dpkg -l | grep -E "linux-image" | grep -E "current|legacy|edge" | \
        awk '{print $2}' | cut -d'-' -f3 | head -1
}

# 安装包
install_packages() {
    apt-get update -qq
    apt-get install -y "$@"
}

# 版本比较：compare_versions v1 op v2 (op: gt/lt/eq/ge/le)
# 返回 0=true, 1=false
compare_versions() {
    dpkg --compare-versions "$1" "$2" "$3"
}

# 重新生成 SSH host keys
regenerate_ssh_keys() {
    dpkg-reconfigure openssh-server >/dev/null 2>&1 || ssh-keygen -A >/dev/null 2>&1 || true
}

# 获取架构
get_arch() {
    dpkg --print-architecture
}

# 检查 growroot 是否可用
growroot_check() {
    [[ -f /usr/share/initramfs-tools/hooks/growroot ]] || \
    [[ -f /usr/share/initramfs-tools/scripts/local-bottom/growroot ]]
}

# ramlog RecreateLogs 中的服务检查列表（distro 特定包名）
RAMLOG_SERVICE_CHECKS=(
    "apache2:/var/log/apache2"
    "cron-apt:/var/log/cron-apt/log"
    "proftpd-basic:/var/log/proftpd/controls.log"
    "nginx:/var/log/nginx/access.log:/var/log/nginx/error.log"
    "lighttpd:/var/log/lighttpd/access.log:/var/log/lighttpd/error.log"
    "samba:/var/log/samba"
    "unattended-upgrades:/var/log/unattended-upgrades"
)
