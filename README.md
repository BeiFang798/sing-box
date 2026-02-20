# 🚀 sing-box-reality-onekey

> 一键部署 sing-box VLESS + Reality 节点，自动检测 IPv4/IPv6，BBR 加速，systemd 托管，部署完即用。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/BeiFang798/sing-box?style=flat-square)](https://github.com/BeiFang798/sing-box/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/BeiFang798/sing-box?style=flat-square)](https://github.com/BeiFang798/sing-box/network/members)
[![GitHub Release](https://img.shields.io/github/v/release/SagerNet/sing-box?label=sing-box&style=flat-square)](https://github.com/SagerNet/sing-box/releases/latest)
[![Platform](https://img.shields.io/badge/platform-amd64%20%7C%20arm64-blue?style=flat-square)](https://github.com/BeiFang798/sing-box)

---

## ✨ 功能亮点

- 🌐 **双栈自动检测**：自动识别服务器公网 IPv4 / IPv6 可用性，双栈时交互选择，多服务容错探测
- 🔒 **443 端口 + Reality 协议**：默认使用 443 端口，uTLS 指纹支持 `chrome`，流控 `xtls-rprx-vision`，伪装效果优秀
- 📦 **自动下载最新 sing-box**：从 GitHub Releases 获取最新版，自动适配 `amd64` / `arm64` 架构
- 🔑 **密钥全自动生成**：自动生成随机 UUID、8 字节 shortId、Reality 密钥对，无需手动操作
- ⚡ **TCP BBR 加速**：自动启用 `fq + bbr` 拥塞控制，弱网环境下显著提升速度
- 🔄 **systemd 全托管**：开机自启、崩溃自动重启，所有操作通过 `systemctl` 管理，不使用 nohup
- 🧹 **极简配置**：只保留必要的 inbound / outbound，配置文件清晰易读
- 📋 **一键输出 vless 链接**：部署完成后直接打印完整 vless:// 链接，可直接导入 v2rayN、Nekobox、Shadowrocket 等主流客户端
- 🛡️ **安全检测**：启动前检查端口占用，启动后验证服务状态，失败时提供 journalctl 日志指引

---

## 📸 截图预览

> 待补充：节点部署成功截图 & 客户端连接成功截图

---

## ⚡ 快速开始

只需一条命令，全程自动完成：

```bash
curl -fsSL https://raw.githubusercontent.com/BeiFang798/sing-box/main/install.sh | bash
```

> ⚠️ 请确保以 **root 权限** 运行，且服务器防火墙已放行 **TCP 443** 端口。

安装完成后，脚本会在终端输出类似以下内容：

```
============================================================
  部署完成！节点信息如下：
============================================================
  地址(IP)  : 1.2.3.4
  端口      : 443
  UUID      : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  流控      : xtls-rprx-vision
  SNI       : www.microsoft.com
  公钥(pbk) : xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  ShortID   : xxxxxxxxxxxxxxxx
  指纹(fp)  : chrome
============================================================
  VLESS 链接（可直接导入客户端）：

  vless://UUID@IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&...
============================================================
```

复制 vless 链接，导入你的客户端即可使用。

---

## 📋 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Debian 10+、Ubuntu 20.04+、CentOS 8+（需 systemd） |
| 架构 | x86_64（amd64）、aarch64（arm64） |
| 权限 | **必须 root** 或具有 sudo 权限 |
| 端口 | TCP **443** 未被占用 |
| 网络 | 可访问 GitHub（用于下载 sing-box 二进制） |
| 内存 | ≥ 128 MB 可用内存 |

---

## 🔧 详细安装步骤

> 大多数情况下直接使用上方一键命令即可，以下为手动安装参考。

**1. 克隆仓库（或直接下载脚本）**

```bash
wget -O install.sh https://raw.githubusercontent.com/BeiFang798/sing-box/main/install.sh
chmod +x install.sh
```

**2. 检查并放行防火墙**

```bash
# Ubuntu/Debian（ufw）
ufw allow 443/tcp

# CentOS（firewalld）
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload
```

**3. 运行脚本**

```bash
bash install.sh
```

**4. 按提示操作**

若检测到双栈网络，脚本会询问使用 IPv4 还是 IPv6，输入对应数字后全程自动完成。

---

## ⚙️ 配置与管理

### 服务管理

```bash
# 查看运行状态
systemctl status sing-box

# 重启服务
systemctl restart sing-box

# 停止服务
systemctl stop sing-box

# 启动服务
systemctl start sing-box

# 查看实时日志
journalctl -u sing-box -f

# 查看最近 50 条日志
journalctl -u sing-box -n 50 --no-pager
```

### 查看 BBR 状态

```bash
# 查看当前拥塞控制算法（应显示 bbr）
sysctl net.ipv4.tcp_congestion_control

# 查看队列调度器（应显示 fq）
sysctl net.core.default_qdisc
```

### 配置文件位置

| 路径 | 说明 |
|------|------|
| `/etc/sing-box/config.json` | 主配置文件 |
| `/usr/local/bin/sing-box` | 二进制文件 |
| `/etc/systemd/system/sing-box.service` | systemd 服务文件 |

修改配置后需重启服务：

```bash
# 验证配置语法
/usr/local/bin/sing-box check -c /etc/sing-box/config.json

# 重启生效
systemctl restart sing-box
```

---

## 📱 客户端连接示例

部署完成后，脚本输出的 vless 链接格式如下：

```
vless://<UUID>@<IP>:<PORT>?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=<公钥>&sid=<shortId>&type=tcp#sing-box-reality
```

### 主流客户端导入方式

| 客户端 | 平台 | 导入方式 |
|--------|------|----------|
| **v2rayN** | Windows | 从剪贴板导入 → 粘贴 vless 链接 |
| **Nekobox** | Windows/Android | 从剪贴板导入 |
| **Shadowrocket** | iOS | 扫描二维码或复制链接后打开 App |
| **Sing-box（官方）** | Android/iOS | 支持导入 vless 链接 |
| **Clash Meta** | 全平台 | 需手动转换为 YAML 格式 |

> 💡 推荐将 vless 链接转为二维码分享，可使用 [qrcode.show](https://qrcode.show) 在线生成。

---

## ❓ 常见问题（FAQ）

**Q：443 端口被占用怎么办？**

> 脚本会自动检测并提示。请先找出占用端口的进程并停止：
> ```bash
> ss -tlnp sport = :443
> # 或
> netstat -tlnp | grep :443
> ```
> 停止冲突服务（如 Nginx、Apache）后重新运行脚本。
> 本脚本目前固定使用 443 端口，如需更改请手动编辑 `install.sh` 中的 `PORT` 变量。

---

**Q：服务启动失败怎么办？**

> 首先查看详细日志：
> ```bash
> journalctl -u sing-box -n 50 --no-pager
> ```
> 常见原因：
> - 配置文件语法错误 → 运行 `/usr/local/bin/sing-box check -c /etc/sing-box/config.json`
> - 443 端口仍被占用 → 参考上一条
> - 系统不支持 Reality → 需内核 ≥ 5.4，运行 `uname -r` 检查

---

**Q：如何更换 SNI（伪装域名）？**

> 编辑配置文件：
> ```bash
> nano /etc/sing-box/config.json
> ```
> 将 `"server_name"` 和 `"handshake"` 中的 `www.microsoft.com` 替换为目标域名（需真实存在且支持 TLS 443）。
> 修改后重启：`systemctl restart sing-box`

---

**Q：如何更新 sing-box 到最新版？**

> 重新运行安装脚本即可，新的二进制会覆盖旧版，配置文件不会被修改：
> ```bash
> curl -fsSL https://raw.githubusercontent.com/BeiFang798/sing-box/main/install.sh | bash
> ```
> 或手动下载最新版替换二进制后重启服务。

---

**Q：BBR 启用后没有立即生效？**

> 部分内核版本需要重启后 BBR 才能加载：
> ```bash
> reboot
> # 重启后验证
> sysctl net.ipv4.tcp_congestion_control
> ```

---

**Q：支持 IPv6 Only 的 VPS 吗？**

> 支持。脚本会自动检测到仅有 IPv6，并使用 IPv6 地址生成配置和 vless 链接（地址会自动加上方括号）。请确保客户端所在网络支持 IPv6 访问。

---

## 🗑️ 卸载方法

完全移除所有相关文件：

```bash
# 停止并禁用服务
systemctl stop sing-box
systemctl disable sing-box

# 删除服务文件
rm -f /etc/systemd/system/sing-box.service
systemctl daemon-reload

# 删除二进制和配置
rm -f /usr/local/bin/sing-box
rm -rf /etc/sing-box

echo "sing-box 已完全卸载"
```

> BBR 配置写入了 `/etc/sysctl.conf`，如需还原请手动删除其中的 `net.core.default_qdisc=fq` 和 `net.ipv4.tcp_congestion_control=bbr` 两行，然后运行 `sysctl -p`。

---

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源，你可以自由使用、修改和分发。

```
MIT License

Copyright (c) 2026 BeiFang798

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction...
```

---

## 🙏 致谢与免责声明

### 致谢

- [SagerNet/sing-box](https://github.com/SagerNet/sing-box) — 优秀的开源代理内核，本项目基于其构建
- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) — Reality 协议的先驱实现，为社区提供了宝贵参考
- 所有为网络自由做出贡献的开发者与维护者

### ⚠️ 免责声明

> **请在使用本项目前仔细阅读以下声明：**
>
> 1. 本项目仅供**学习、研究和技术交流**使用，作者不对任何使用行为负责。
> 2. 使用本脚本部署代理节点前，请确保**符合你所在地区的法律法规**。在某些国家和地区，运营或使用代理服务可能受到限制或禁止。
> 3. 本项目不提供任何代理服务，不鼓励任何违法行为。
> 4. 因使用本脚本导致的任何直接或间接后果，**由使用者自行承担**，与本项目作者无关。
> 5. 如果你所在地区对此类技术有法律限制，请**立即停止使用**本项目。

---

## 👤 作者

**BeiFang798**

- GitHub: [@BeiFang798](https://github.com/BeiFang798)
- 项目地址: [https://github.com/BeiFang798/sing-box](https://github.com/BeiFang798/sing-box)

> 如有问题或建议，欢迎提交 [Issue](https://github.com/BeiFang798/sing-box/issues) 或 [Pull Request](https://github.com/BeiFang798/sing-box/pulls)。
> 如果本项目对你有帮助，欢迎点一个 ⭐ Star，这是对作者最大的支持！

---

<div align="center">
  <sub>Made with ❤️ for the open internet · 2026</sub>
</div>
