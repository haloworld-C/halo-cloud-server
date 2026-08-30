# WireGuard 子模块

面向 Ubuntu 22.04/24.04、Debian 12 的轻量部署脚本。默认把客户端全部流量（IPv4）经由云服务器转发。

正式部署请按 [WireGuard 正式部署手册](DEPLOYMENT.md) 逐项执行。

## 1. 云平台准备

- 在安全组/云防火墙放行 `UDP 51820` 入站。
- 保留 SSH 管理端口，切勿在确认 VPN 可用前关闭 SSH。
- 服务器需要公网 IPv4；若使用域名，请先把 A 记录指向服务器。

## 2. 配置

```bash
cp deploy.env.example deploy.env
nano deploy.env
```

至少设置 `SERVER_ENDPOINT`。它可以是服务器公网 IP 或域名，不要带协议或端口。

## 3. 上传并安装

把本目录上传到服务器后执行：

```bash
chmod +x scripts/*.sh
sudo ./scripts/install.sh ./deploy.env
```

安装过程会：

1. 安装 `wireguard`、`iptables`，可选安装 `qrencode`；
2. 创建服务器密钥和 `/etc/wireguard/wg0.conf`；
3. 开启 IPv4 转发并配置 NAT；
4. 启动并设置 `wg-quick@wg0` 开机自启；
5. 创建第一个客户端配置。

客户端配置保存在 `/etc/wireguard/clients/`，其中包含私钥，务必安全传输并及时删除不需要的副本。

## 4. 日常操作

```bash
# 添加客户端
sudo ./scripts/add-client.sh phone

# 删除客户端
sudo ./scripts/remove-client.sh phone

# 查看状态
sudo ./scripts/status.sh

# 在终端显示客户端二维码（安装了 qrencode 时）
sudo qrencode -t ansiutf8 < /etc/wireguard/clients/phone.conf
```

将 `.conf` 文件导入 Windows、macOS、Linux、iOS 或 Android 的 WireGuard 客户端即可。

## 重要配置项

| 变量 | 默认值 | 说明 |
|---|---:|---|
| `WG_INTERFACE` | `wg0` | WireGuard 接口名 |
| `WG_PORT` | `51820` | UDP 监听端口 |
| `WG_SUBNET_PREFIX` | `10.66.66` | VPN IPv4 `/24` 网段前三段 |
| `SERVER_VPN_HOST` | `1` | 服务器在 VPN 网段内的主机号 |
| `FIRST_CLIENT_NAME` | `client1` | 首个客户端名称 |
| `CLIENT_DNS` | `1.1.1.1, 1.0.0.1` | 下发给客户端的 DNS |
| `CLIENT_ALLOWED_IPS` | `0.0.0.0/0` | 客户端经 VPN 路由的网段 |
| `PUBLIC_INTERFACE` | 自动探测 | 云服务器公网出口网卡 |

若只想访问 VPN 内网，把 `CLIENT_ALLOWED_IPS` 改为 `10.66.66.0/24`。

## 验证与排障

连接客户端后执行：

```bash
ping 10.66.66.1
curl -4 https://ifconfig.me
sudo wg show
sudo journalctl -u wg-quick@wg0 --no-pager -n 100
```

常见问题：

- 无握手：检查云安全组和系统防火墙是否允许 WireGuard UDP 端口。
- 有握手但不能上网：检查 `net.ipv4.ip_forward=1`、出口网卡名和 NAT 规则。
- 客户端已有相同网段：修改 `WG_SUBNET_PREFIX` 后重新部署。

本地修改脚本后可在本模块目录运行 `bash tests/smoke.sh` 做基础回归检查。

参考：[WireGuard 官方 Quick Start](https://www.wireguard.com/quickstart/)、[Ubuntu WireGuard 文档](https://ubuntu.com/server/docs/how-to/wireguard-vpn/)。
