#!/bin/bash
#==========================================================================
# Ubuntu distro include — 提供 distro 特定函数和变量
# 被 common 主体脚本 source，不直接执行
#==========================================================================

DISTRO_ID="ubuntu"
SSH_SERVICE="ssh"
# /etc/ophub-release is always written by rebuild's refactor_rootfs and contains
# BOARD, BOARDFAMILY, BOARD_NAME, etc. Using it keeps behavior consistent across
# distros (Ubuntu has no /etc/ubuntu-release, and /etc/os-release lacks board info).
RELEASE_FILE="/etc/ophub-release"
RAMLOG_NAME="ubuntu-ramlog"
LOG_FILE="/var/log/ubuntu-hardware-monitor.log"

# 检查包是否安装
check_if_installed() {
    local DPKG_Status="$(dpkg -s "$1" 2>/dev/null | awk -F": " '/^Status/ {print $2}')"
    if [[ "X${DPKG_Status}" = "X" || "${DPKG_Status}" = *deinstall* ]]; then
        return 1
    else
        return 0
    fi
}

# ── 服务控制抽象 ──────────────────────────────────────────────────
# 统一接口：service_ctl <action> <service> [extra...]
# Ubuntu 用 systemctl
service_ctl() {
    local action="$1" svc="$2"
    shift 2
    case "${action}" in
        start|stop|restart)
            systemctl "${action}" "${svc}" "$@" 2>/dev/null
            ;;
        enable)
            systemctl enable "${svc}" "$@" 2>/dev/null
            ;;
        disable)
            systemctl disable "${svc}" "$@" 2>/dev/null
            ;;
        is-enabled)
            systemctl is-enabled "${svc}" "$@" 2>/dev/null
            ;;
        *)
            return 1
            ;;
    esac
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
