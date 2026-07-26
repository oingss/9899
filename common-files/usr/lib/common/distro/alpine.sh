#!/bin/bash
#==========================================================================
# Alpine Linux distro include — 提供 distro 特定函数和变量
# 被 common 主体脚本 source，不直接执行
# Alpine 使用 OpenRC（非 systemd），service_ctl 函数封装 rc-service/rc-update
#==========================================================================

DISTRO_ID="alpine"
SSH_SERVICE="sshd"
# /etc/ophub-release is always written by rebuild's refactor_rootfs and contains
# BOARD, BOARDFAMILY, BOARD_NAME, etc. Using it keeps behavior consistent across
# distros (Alpine's /etc/alpine-release lacks board info).
RELEASE_FILE="/etc/ophub-release"
RAMLOG_NAME="alpine-ramlog"
LOG_FILE="/var/log/alpine-hardware-monitor.log"

# ── 服务控制抽象 ──────────────────────────────────────────────────
# 统一接口：service_ctl <action> <service> [extra...]
# action: start/stop/restart/enable/disable/is-enabled
# Alpine 用 rc-service / rc-update，其他 distro 用 systemctl
service_ctl() {
    local action="$1" svc="$2"
    shift 2
    case "${action}" in
        start)
            rc-service "${svc}" start >/dev/null 2>&1
            ;;
        stop)
            rc-service "${svc}" stop >/dev/null 2>&1
            ;;
        restart)
            rc-service "${svc}" restart >/dev/null 2>&1
            ;;
        enable)
            rc-update add "${svc}" default >/dev/null 2>&1
            ;;
        disable)
            rc-update del "${svc}" default 2>/dev/null
            rc-update del "${svc}" default 2>/dev/null
            # Also remove from other runlevels just in case
            rc-update del "${svc}" 2>/dev/null || true
            ;;
        is-enabled)
            rc-update show default 2>/dev/null | grep -q "${svc}"
            ;;
        *)
            return 1
            ;;
    esac
}

# 检查包是否安装
check_if_installed() {
    apk -e info "$1" >/dev/null 2>&1
}

# 获取内核分支（current/legacy/edge）
# Alpine 上 ophub 注入的内核是裸文件，不通过 apk 安装，从 /lib/modules/$(uname -r) 推断
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
    apk update -q
    apk add --no-cache "$@"
}

# 版本比较：compare_versions v1 op v2 (op: gt/lt/eq/ge/le)
# 返回 0=true, 1=false
# Alpine 的 apk version 可比较版本
compare_versions() {
    local v1="$1" op="$2" v2="$3"
    local result
    # apk version: 输出 "<" / "=" / ">"
    result=$(apk version -t "${v1}" "${v2}" 2>/dev/null || echo "=")
    case "${op}" in
        gt) [[ "${result}" == ">" ]] ;;
        lt) [[ "${result}" == "<" ]] ;;
        eq) [[ "${result}" == "=" ]] ;;
        ge) [[ "${result}" == ">" || "${result}" == "=" ]] ;;
        le) [[ "${result}" == "<" || "${result}" == "=" ]] ;;
        *)  return 2 ;;
    esac
}

# 重新生成 SSH host keys
# Alpine 的 openssh 用 ssh-keygen -A
regenerate_ssh_keys() {
    ssh-keygen -A >/dev/null 2>&1 || true
}

# 获取架构
get_arch() {
    uname -m
}

# 检查 growroot 是否可用
# Alpine 用 mkinitfs 而非 initramfs-tools；ophub 注入的内核依赖 initramfs-tools 钩子
# Alpine 默认不装 growroot，统一脚本有 fdisk 回退逻辑
growroot_check() {
    [[ -f /etc/mkinitfs/mkinitfs.conf ]] && grep -q growroot /etc/mkinitfs/mkinitfs.conf 2>/dev/null
}

# ramlog RecreateLogs 中的服务检查列表（distro 特定包名）
# Alpine 包名：apache2（非 apache），无 cron-apt/proftpd-basic/unattended-upgrades
RAMLOG_SERVICE_CHECKS=(
    "apache2:/var/log/apache2"
    "nginx:/var/log/nginx/access.log:/var/log/nginx/error.log"
    "lighttpd:/var/log/lighttpd/access.log:/var/log/lighttpd/error.log"
    "samba:/var/log/samba"
)
