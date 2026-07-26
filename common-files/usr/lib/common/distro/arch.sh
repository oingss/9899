#!/bin/bash
#==========================================================================
# Arch Linux ARM distro include — 提供 distro 特定函数和变量
# 被 common 主体脚本 source，不直接执行
#==========================================================================

DISTRO_ID="arch"
SSH_SERVICE="sshd"
# /etc/ophub-release is always written by rebuild's refactor_rootfs and contains
# BOARD, BOARDFAMILY, BOARD_NAME, etc. Using it keeps behavior consistent across
# distros (Arch has no /etc/armbian-release, and /etc/arch-release lacks board info).
RELEASE_FILE="/etc/ophub-release"
RAMLOG_NAME="arch-ramlog"
LOG_FILE="/var/log/arch-hardware-monitor.log"

# 检查包是否安装
check_if_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# ── 服务控制抽象 ──────────────────────────────────────────────────
# 统一接口：service_ctl <action> <service> [extra...]
# Arch 用 systemctl
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
# Arch 上 ophub 注入的内核是裸文件，不通过 pacman 安装，从 /lib/modules/$(uname -r) 推断
get_kernel_branch() {
    local KVER BRANCH=""
    if [[ -d "/lib/modules/$(uname -r)" ]]; then
        KVER="$(uname -r)"
        case "${KVER}" in
            *-current*) BRANCH="current" ;;
            *-legacy*)  BRANCH="legacy"  ;;
            *-edge*)    BRANCH="edge"    ;;
            *)          BRANCH="current" ;;
        esac
    fi
    echo "${BRANCH}"
}

# 安装包
install_packages() {
    pacman -Sy --noconfirm --needed "$@"
}

# 版本比较：compare_versions v1 op v2 (op: gt/lt/eq/ge/le)
# 返回 0=true, 1=false
# 使用 Arch 的 vercmp 工具
compare_versions() {
    local v1="$1" op="$2" v2="$3"
    local result
    result=$(vercmp "${v1}" "${v2}" 2>/dev/null || echo "0")
    case "${op}" in
        gt) [[ "${result}" -gt 0 ]] ;;
        lt) [[ "${result}" -lt 0 ]] ;;
        eq) [[ "${result}" -eq 0 ]] ;;
        ge) [[ "${result}" -ge 0 ]] ;;
        le) [[ "${result}" -le 0 ]] ;;
        *)  return 2 ;;
    esac
}

# 重新生成 SSH host keys
# Arch 上不依赖 dpkg-reconfigure，直接用 ssh-keygen -A
regenerate_ssh_keys() {
    ssh-keygen -A >/dev/null 2>&1 || true
}

# 获取架构
get_arch() {
    uname -m
}

# 检查 growroot 是否可用
# Arch 用 mkinitcpio 而非 initramfs-tools
growroot_check() {
    [[ -f /etc/mkinitcpio.conf.d/growroot.conf ]] || \
    [[ -d /usr/lib/initcpio/install/growroot ]]
}

# ramlog RecreateLogs 中的服务检查列表（distro 特定包名）
# Arch 上包名不同：apache（非 apache2），无 cron-apt/proftpd-basic/unattended-upgrades
RAMLOG_SERVICE_CHECKS=(
    "apache:/var/log/httpd"
    "nginx:/var/log/nginx/access.log:/var/log/nginx/error.log"
    "lighttpd:/var/log/lighttpd/access.log:/var/log/lighttpd/error.log"
    "samba:/var/log/samba"
)
