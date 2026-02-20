#!/usr/bin/env bash
# =============================================================================
# 脚本名称: install.sh
# 用    途: 在干净的 Linux 服务器上一键部署 sing-box VLESS + Reality 代理
# 适用系统: Debian 10+、Ubuntu 20.04+、CentOS 8+（需 systemd）
# 架    构: amd64 / arm64
# 版    本: 1.0.0
# 更新日期: 2026-02
# 用    法: curl -fsSL https://raw.githubusercontent.com/你的用户名/你的仓库/main/install.sh | bash
# 风险提示: 本脚本将占用 443 端口，并修改内核网络参数（BBR），请在了解风险后使用
#           请确保服务器防火墙已放行 TCP 443 端口
#           本脚本仅供学习与研究使用，请遵守当地法律法规
# =============================================================================

set -euo pipefail

# ---------- 路径与常量 ----------
BIN="/usr/local/bin/sing-box"
CONFIG_DIR="/etc/sing-box"
CONFIG="${CONFIG_DIR}/config.json"
SERVICE="/etc/systemd/system/sing-box.service"
SERVICE_NAME="sing-box"
PORT=443
SNI="www.microsoft.com"
ARCH=$(uname -m)

# ---------- 辅助函数 ----------

# 打印带前缀的信息
info()    { echo "[INFO] $*"; }
success() { echo "[OK]   $*"; }
error()   { echo "[ERR]  $*" >&2; exit 1; }
warn()    { echo "[WARN] $*"; }

# 检查是否以 root 运行
check_root() {
    [ "$(id -u)" -eq 0 ] || error "请使用 root 权限运行本脚本（sudo 或 su -）"
}

# 检测公网 IP（多服务容错，超时4秒）
fetch_ip() {
    local proto="$1"  # -4 或 -6
    local result=""
    for url in "https://icanhazip.com" "https://ifconfig.co" "https://api.ipify.org" "https://checkip.amazonaws.com"; do
        result=$(curl -s "${proto}" --max-time 4 "${url}" 2>/dev/null | tr -d '[:space:]') || true
        [ -n "${result}" ] && echo "${result}" && return 0
    done
    return 1
}

# 检测可用 IP 并让用户选择
detect_ip() {
    info "正在检测公网 IP 地址..."
    IPV4=$(fetch_ip "-4") || IPV4=""
    IPV6=$(fetch_ip "-6") || IPV6=""

    [ -z "${IPV4}" ] && [ -z "${IPV6}" ] && error "无法获取公网 IP，请检查网络连接"

    if [ -n "${IPV4}" ] && [ -n "${IPV6}" ]; then
        echo ""
        info "检测到双栈网络："
        echo "  [1] IPv4: ${IPV4}"
        echo "  [2] IPv6: ${IPV6}"
        read -rp "请选择使用哪个 IP（输入 1 或 2，默认 1）: " ip_choice
        ip_choice="${ip_choice:-1}"
        if [ "${ip_choice}" = "2" ]; then
            SERVER_IP="${IPV6}"
        else
            SERVER_IP="${IPV4}"
        fi
    elif [ -n "${IPV4}" ]; then
        SERVER_IP="${IPV4}"
        info "仅检测到 IPv4: ${SERVER_IP}"
    else
        SERVER_IP="${IPV6}"
        info "仅检测到 IPv6: ${SERVER_IP}"
    fi

    success "将使用 IP: ${SERVER_IP}"
}

# 检查 443 端口是否已被占用
check_port() {
    info "检查 ${PORT} 端口占用情况..."
    if command -v ss &>/dev/null; then
        ss -tlnp "sport = :${PORT}" 2>/dev/null | grep -q ":${PORT}" && \
            error "端口 ${PORT} 已被占用，请先释放该端口后再运行本脚本"
    elif command -v netstat &>/dev/null; then
        netstat -tlnp 2>/dev/null | grep -q ":${PORT} " && \
            error "端口 ${PORT} 已被占用，请先释放该端口后再运行本脚本"
    else
        warn "未找到 ss/netstat，跳过端口检测"
    fi
    success "端口 ${PORT} 可用"
}

# 安装依赖
install_deps() {
    info "安装基础依赖..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq curl wget tar uuid-runtime 2>/dev/null || \
        apt-get install -y -qq curl wget tar 2>/dev/null
    elif command -v yum &>/dev/null; then
        yum install -y -q curl wget tar util-linux 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        dnf install -y -q curl wget tar util-linux 2>/dev/null || true
    fi
}

# 下载并安装最新版 sing-box
install_singbox() {
    info "获取 sing-box 最新版本..."
    local latest
    latest=$(curl -fsSL --max-time 10 \
        "https://api.github.com/repos/SagerNet/sing-box/releases/latest" \
        | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')
    [ -z "${latest}" ] && error "无法获取 sing-box 最新版本，请检查网络"

    # 标准化版本号（去掉 v 前缀用于文件名）
    local ver="${latest#v}"

    # 映射架构
    case "${ARCH}" in
        x86_64)  GOARCH="amd64" ;;
        aarch64) GOARCH="arm64" ;;
        armv7l)  GOARCH="armv7" ;;
        *)       error "不支持的架构: ${ARCH}" ;;
    esac

    local pkg="sing-box-${ver}-linux-${GOARCH}"
    local url="https://github.com/SagerNet/sing-box/releases/download/${latest}/${pkg}.tar.gz"

    info "下载 ${url}..."
    local tmpdir
    tmpdir=$(mktemp -d)
    trap 'rm -rf "${tmpdir}"' EXIT

    curl -fsSL --max-time 60 -o "${tmpdir}/${pkg}.tar.gz" "${url}" || \
        error "下载 sing-box 失败，请检查网络或手动下载"

    tar -xzf "${tmpdir}/${pkg}.tar.gz" -C "${tmpdir}"
    install -m 755 "${tmpdir}/${pkg}/sing-box" "${BIN}"
    success "sing-box ${latest} 安装完成 -> ${BIN}"
}

# 生成配置文件
generate_config() {
    info "生成 Reality 密钥对..."
    mkdir -p "${CONFIG_DIR}"

    # 生成 Reality 密钥对
    local keypair
    keypair=$("${BIN}" generate reality-keypair)
    PRIVATE_KEY=$(echo "${keypair}" | grep "PrivateKey" | awk '{print $2}')
    PUBLIC_KEY=$(echo  "${keypair}" | grep "PublicKey"  | awk '{print $2}')

    # 生成 UUID
    if command -v uuidgen &>/dev/null; then
        UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        UUID=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
    fi

    # 生成 short_id（8字节 hex = 16字符）
    SHORT_ID=$(openssl rand -hex 8)

    info "写入配置文件 ${CONFIG}..."
    cat > "${CONFIG}" <<EOF
{
  "log": { "level": "warn" },
  "inbounds": [
    {
      "type": "vless",
      "listen": "::",
      "listen_port": ${PORT},
      "users": [
        { "uuid": "${UUID}", "flow": "xtls-rprx-vision" }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${SNI}",
        "reality": {
          "enabled": true,
          "handshake": { "server": "${SNI}", "server_port": 443 },
          "private_key": "${PRIVATE_KEY}",
          "short_id": ["${SHORT_ID}"]
        }
      }
    }
  ],
  "outbounds": [
    { "type": "direct" }
  ]
}
EOF
    success "配置文件生成完毕"
}

# 创建 systemd 服务
create_service() {
    info "创建 systemd 服务..."
    cat > "${SERVICE}" <<EOF
[Unit]
Description=sing-box VLESS Reality Service
After=network.target

[Service]
Type=simple
ExecStart=${BIN} run -c ${CONFIG}
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}" --quiet
    systemctl start  "${SERVICE_NAME}"

    # 等待服务启动
    info "等待服务启动（5 秒）..."
    sleep 5

    if systemctl is-active --quiet "${SERVICE_NAME}"; then
        success "sing-box 服务已启动并运行"
    else
        warn "sing-box 服务启动失败，请查看日志："
        echo "  journalctl -u ${SERVICE_NAME} -n 50 --no-pager"
        exit 1
    fi
}

# 启用 TCP BBR
enable_bbr() {
    info "启用 TCP BBR 拥塞控制..."

    # 幂等写入（避免重复添加）
    grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null || \
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null || \
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

    sysctl -p &>/dev/null || true

    # 验证是否生效
    local cc
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
    if [ "${cc}" = "bbr" ]; then
        success "BBR 已成功启用"
    else
        warn "BBR 设置写入完成，可能需要重启后生效（当前: ${cc}）"
    fi
}

# 打印最终节点信息和 vless 链接
print_result() {
    # 构建 vless 链接（IPv6 需加方括号）
    local ip_str="${SERVER_IP}"
    if echo "${SERVER_IP}" | grep -q ":"; then
        ip_str="[${SERVER_IP}]"
    fi

    local vless_link="vless://${UUID}@${ip_str}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp#sing-box-reality"

    echo ""
    echo "============================================================"
    echo "  部署完成！节点信息如下："
    echo "============================================================"
    echo "  地址(IP)  : ${SERVER_IP}"
    echo "  端口      : ${PORT}"
    echo "  UUID      : ${UUID}"
    echo "  流控      : xtls-rprx-vision"
    echo "  SNI       : ${SNI}"
    echo "  公钥(pbk) : ${PUBLIC_KEY}"
    echo "  ShortID   : ${SHORT_ID}"
    echo "  指纹(fp)  : chrome"
    echo "============================================================"
    echo "  VLESS 链接（可直接导入客户端）："
    echo ""
    echo "  ${vless_link}"
    echo ""
    echo "============================================================"
    echo "  常用管理命令："
    echo "    查看状态  : systemctl status sing-box"
    echo "    重启服务  : systemctl restart sing-box"
    echo "    停止服务  : systemctl stop sing-box"
    echo "    查看日志  : journalctl -u sing-box -f"
    echo "    查看BBR   : sysctl net.ipv4.tcp_congestion_control"
    echo "============================================================"
    echo "  卸载方法："
    echo "    systemctl stop sing-box && systemctl disable sing-box"
    echo "    rm -f ${BIN} ${SERVICE} && rm -rf ${CONFIG_DIR}"
    echo "    systemctl daemon-reload"
    echo "============================================================"
    echo "  更新方法："
    echo "    重新运行本脚本即可（会覆盖旧的二进制，保留配置可手动备份）"
    echo "============================================================"
}

# ---------- 主流程 ----------
main() {
    echo "============================================================"
    echo "  sing-box VLESS + Reality 一键部署脚本 v1.0.0 (2026-02)"
    echo "============================================================"

    check_root
    check_port
    detect_ip
    install_deps
    install_singbox
    generate_config
    enable_bbr
    create_service
    print_result
}

main "$@"
