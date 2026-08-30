# WireGuard 正式部署手册

本文用于在 Ubuntu 22.04/24.04 或 Debian 12 云服务器上部署本项目的 WireGuard 模块。默认模式为 IPv4 全隧道：客户端的全部 IPv4 流量通过云服务器访问互联网。

> 部署过程中始终保留一个已验证可用的 SSH 会话。确认 WireGuard 和普通 sudo 用户均工作正常前，不要收紧或删除现有的应急登录通道。

## 1. 部署前检查

### 1.1 云平台规则

在云厂商安全组或云防火墙中配置：

| 协议 | 端口 | 来源 | 用途 |
|---|---:|---|---|
| TCP | 22 | 管理员可信公网 IP | SSH 管理 |
| UDP | 51820 | `0.0.0.0/0` | WireGuard |

如果更改了 `WG_PORT`，安全组中的 UDP 端口必须同步修改。

### 1.2 登录服务器

从管理终端使用普通 sudo 用户登录：

```bash
ssh <管理用户>@<服务器公网IP或SSH别名>
```

确认身份和 sudo：

```bash
id
sudo whoami
```

`sudo whoami` 应输出 `root`。

### 1.3 检查服务器环境

```bash
cat /etc/os-release
uname -r
ip -4 route show default
ip -4 address
```

记录默认路由中的出口网卡名，例如 `eth0`、`ens3`。服务器需要具备可用的公网 IPv4，或由云平台把公网 IPv4 映射到该服务器。

确认目标未被占用：

```bash
sudo test ! -e /etc/wireguard/wg0.conf && echo 'wg0 config available'
sudo ss -lunp | grep ':51820 ' || true
ip link show wg0 2>/dev/null || true
```

如果已经存在 `/etc/wireguard/wg0.conf` 或 `wg0` 接口，停止部署并先确认其来源。安装脚本不会覆盖已有配置。

## 2. 获取部署代码

首次部署：

```bash
cd ~
git clone --branch main --single-branch \
  https://github.com/haloworld-C/halo-cloud-server.git \
  halo_server
cd ~/halo_server
```

若服务器已经存在仓库：

```bash
cd ~/halo_server
git status --short --branch
git pull --ff-only
```

确认当前版本：

```bash
git log -3 --oneline
```

服务器只需要仓库读取权限。私有仓库应使用只读 Deploy Key，不要在服务器保存个人 GitHub 密码或可写访问令牌。

## 3. 运行模块测试

```bash
cd ~/halo_server/modules/wireguard
bash -n scripts/*.sh tests/*.sh
bash tests/smoke.sh
```

预期最后显示：

```text
smoke tests passed
```

## 4. 创建服务器配置

```bash
cd ~/halo_server/modules/wireguard
cp deploy.env.example deploy.env
chmod 600 deploy.env
nano deploy.env
```

全隧道推荐配置：

```bash
SERVER_ENDPOINT=<服务器公网IP或域名>

WG_INTERFACE=wg0
WG_PORT=51820
WG_SUBNET_PREFIX=10.66.66
SERVER_VPN_HOST=1
FIRST_CLIENT_NAME=client1
CLIENT_DNS="1.1.1.1, 1.0.0.1"
CLIENT_ALLOWED_IPS="0.0.0.0/0"

# 留空时通过默认路由自动探测
PUBLIC_INTERFACE=
```

配置说明：

- `SERVER_ENDPOINT` 不包含 `https://` 和端口。
- `WG_SUBNET_PREFIX` 对应 `10.66.66.0/24`；如果与客户端本地网络冲突，应在首次安装前更换。
- `PUBLIC_INTERFACE` 通常留空。自动探测失败时，填写默认路由显示的出口网卡。
- `CLIENT_ALLOWED_IPS="0.0.0.0/0"` 表示全隧道；只访问 VPN 内网时改为 `10.66.66.0/24`。
- `deploy.env` 含真实基础设施信息，已被 Git 忽略，不得提交。

检查配置内容和 Git 状态：

```bash
sed -n '1,120p' deploy.env
git status --short
```

`deploy.env` 不应出现在 `git status` 输出中。

## 5. 执行首次安装

```bash
cd ~/halo_server/modules/wireguard
sudo ./scripts/install.sh ./deploy.env
```

脚本将：

1. 安装 `wireguard`、`iptables`、`procps` 和 `qrencode`；
2. 生成服务器密钥；
3. 创建 `/etc/wireguard/wg0.conf`；
4. 开启 IPv4 转发；
5. 配置转发和 NAT；
6. 启动并启用 `wg-quick@wg0`；
7. 创建首个客户端 `client1`。

密钥和运行时配置位于 `/etc/wireguard`，权限仅开放给 root。不要复制到项目仓库。

## 6. 服务端验收

逐项执行：

```bash
sudo systemctl is-enabled wg-quick@wg0
sudo systemctl is-active wg-quick@wg0
sudo wg show
ip address show wg0
sudo sysctl net.ipv4.ip_forward
sudo ss -lunp | grep ':51820 '
sudo ./scripts/status.sh
```

预期：

- 服务为 `enabled` 和 `active`；
- `wg0` 地址为 `10.66.66.1/24`；
- `net.ipv4.ip_forward = 1`；
- UDP 51820 正在监听；
- `wg show` 中存在 `client1` peer。

查看服务日志：

```bash
sudo journalctl -u wg-quick@wg0 --no-pager -n 100
```

## 7. 导入首个客户端

客户端配置位于：

```text
/etc/wireguard/clients/client1.conf
```

### 7.1 手机扫码

在可信 SSH 终端显示二维码：

```bash
sudo sh -c 'qrencode -t ansiutf8 < /etc/wireguard/clients/client1.conf'
```

使用 WireGuard 客户端扫描。二维码包含客户端私钥，不要截图或分享。

### 7.2 安全下载配置文件

先在服务器创建属于当前管理用户的临时副本：

```bash
sudo install -m 600 -o "$USER" -g "$USER" \
  /etc/wireguard/clients/client1.conf \
  "$HOME/client1.conf"
```

在本地 WSL 下载：

```bash
scp <管理用户>@<服务器公网IP或SSH别名>:~/client1.conf \
  ~/client1.conf
chmod 600 ~/client1.conf
```

确认客户端成功导入后，在服务器删除临时副本：

```bash
rm -f -- "$HOME/client1.conf"
```

## 8. 客户端验收

启用客户端隧道后执行：

```bash
ping 10.66.66.1
curl -4 https://ifconfig.me
```

`curl` 应返回云服务器的公网 IPv4。

服务器端检查：

```bash
sudo wg show
```

客户端 peer 应出现最近握手时间和收发流量。完成下列检查：

- [ ] 客户端能够建立握手
- [ ] 客户端能够访问 `10.66.66.1`
- [ ] 客户端能够解析 DNS
- [ ] 客户端公网出口变为服务器公网 IP
- [ ] SSH 管理连接保持正常
- [ ] 服务器重启后 WireGuard 自动恢复

重启验证应在其他项目部署完成且具备云控制台应急连接能力后进行：

```bash
sudo reboot
```

## 9. 日常管理

```bash
cd ~/halo_server/modules/wireguard

# 新增客户端
sudo ./scripts/add-client.sh phone

# 查看状态
sudo ./scripts/status.sh

# 撤销客户端
sudo ./scripts/remove-client.sh phone
```

每台设备使用独立客户端配置。设备遗失或配置泄露时，应立即撤销该客户端，不要在多台设备间共用私钥。

## 10. 更新代码

```bash
cd ~/halo_server
git status --short --branch
git pull --ff-only
```

当前 `install.sh` 仅用于首次安装。更新仓库后不要再次运行它；日常变更使用对应的客户端管理脚本。后续若项目增加 `update.sh`，再按版本文档执行升级。

## 11. 暂停与恢复

需要临时停用 WireGuard 时：

```bash
sudo systemctl disable --now wg-quick@wg0
```

这会关闭接口并执行配置中的 `PostDown` 规则，但保留配置和密钥。恢复：

```bash
sudo systemctl enable --now wg-quick@wg0
```

不要手工删除 `/etc/wireguard`。项目当前尚未提供经过验证的卸载脚本。

## 12. 常见故障

### 无法握手

检查：

```bash
sudo wg show
sudo ss -lunp | grep ':51820 '
sudo journalctl -u wg-quick@wg0 --no-pager -n 100
```

确认云安全组和服务器防火墙均允许所配置的 UDP 端口，并确认客户端 `Endpoint` 使用正确公网地址。

### 有握手但无法访问互联网

```bash
sudo sysctl net.ipv4.ip_forward
ip -4 route show default
sudo iptables -t nat -S POSTROUTING
sudo iptables -S FORWARD
```

重点检查 IPv4 转发、自动探测的公网出口网卡和 NAT 规则。

### 客户端连接后本地网络异常

检查客户端本地网络是否也使用 `10.66.66.0/24`。若发生冲突，应停用当前部署并规划新的 VPN 网段；不要直接修改已分发客户端的地址而不更新服务端 peer。

## 13. 部署记录

部署完成后记录非敏感信息：

```text
部署日期：
系统版本：
项目提交：
WireGuard 端口：
VPN 网段：
出口网卡：
首个客户端名称：
服务端验收：通过 / 未通过
客户端验收：通过 / 未通过
```

不要记录私钥、完整客户端配置或管理用户密码。
