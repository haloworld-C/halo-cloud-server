# OpenVPN TCP 测试模块

此模块用于对照家庭网络到云服务器的 UDP 丢包问题。在 Debian 12 或 Ubuntu
22.04/24.04 上并行部署一个 OpenVPN TCP 实例。默认使用 TCP 1194 和
10.66.67.0/24，不改动现有 WireGuard、SSH 或客户端默认路由。客户端之间可在
OpenVPN 测试网段内互通；本模块不提供公网出口/NAT。

这是测试配置：首次安装生成无口令的独立 CA、服务端证书和每客户端证书。
所有私钥保存在服务器的 /etc/openvpn/halo-tcp 中，客户端配置只允许通过可信
通道下载。不要把真实 deploy.env、证书、私钥或 .ovpn 文件提交到 Git。

## 部署

先确认云安全组允许测试客户端的公网 IP 访问 TCP 1194，并保留 SSH 管理端口。
如果服务器启用了 UFW，还需要单独放行 TCP 1194。本模块不会自动修改云安全组
或系统防火墙。

在服务器上更新仓库并进入模块目录：

    cd ~/workspace/halo_server
    git pull --ff-only
    cd modules/openvpn-tcp
    cp deploy.env.example deploy.env
    chmod 600 deploy.env
    nano deploy.env

把 SERVER_ENDPOINT 改成服务器公网 IP 或域名。安装前检查 TCP 端口和测试网段
没有与其他服务重叠，再执行：

    bash -n scripts/*.sh tests/*.sh
    bash tests/smoke.sh
    sudo ./scripts/install.sh ./deploy.env
    sudo ./scripts/status.sh

脚本安装 openvpn 与 easy-rsa，配置 systemd 服务 openvpn-server@halo-tcp，并创建
第一个客户端。安装脚本拒绝覆盖已有测试实例。若中途失败，检查
systemctl status openvpn-server@halo-tcp 与 journalctl -u openvpn-server@halo-tcp；
不要直接重跑安装脚本覆盖已生成的 CA。

## WSL 客户端

在服务器上为当前普通管理用户创建私有下载副本：

    sudo install -m 600 -o "$USER" -g "$USER" \
      /etc/openvpn/halo-tcp/clients/wsl-test.ovpn "$HOME/wsl-test.ovpn"

在本地 WSL 中下载（SSH 别名按当前环境调整）：

    install -d -m 700 ~/.config/openvpn
    scp halo-cloud-server:~/wsl-test.ovpn ~/.config/openvpn/halo-tcp-test.ovpn
    chmod 600 ~/.config/openvpn/halo-tcp-test.ovpn

下载后删除服务器普通用户主目录中的临时副本：

    ssh halo-cloud-server 'rm -f -- ~/wsl-test.ovpn'

在本地 WSL 安装客户端并启动前台测试：

    sudo apt-get install openvpn
    sudo openvpn --config ~/.config/openvpn/halo-tcp-test.ovpn

另开 WSL 终端验证到服务端的连通性：

    ping 10.66.67.1

测试服务端带宽时，先在服务器的另一个 SSH 会话运行：

    iperf3 -s -B 10.66.67.1 -p 5202 -1

然后在 WSL 执行：

    iperf3 -c 10.66.67.1 -p 5202 -t 20 -M 1300
    iperf3 -c 10.66.67.1 -p 5202 -t 20 -M 1300 -R

iperf3 的 -1 参数让服务端完成一次连接后退出；做反向测试前需重新启动一次。
记录两次 sender/receiver 汇总、重传次数和实际文件传输体验，与 WireGuard
同网络、同目标的结果比较。OpenVPN TCP 可能避免这条 UDP 路径的问题，但不保证
达到普通 SSH 的速度。

## 增加客户端与清理

每台设备使用不同的证书。新增客户端：

    sudo ./scripts/add-client.sh office-test

新增的 .ovpn 文件同样位于 /etc/openvpn/halo-tcp/clients，权限为 600。
不要在多个设备上复用同一个客户端配置。

测试结束后先断开客户端，再在服务器执行：

    sudo ./scripts/remove-test.sh --confirm-remove-test-vpn

该命令停用测试服务，删除本模块在 /etc/openvpn 下生成的配置、CA 和所有测试
客户端证书；保留 apt 软件包，不影响 WireGuard。随后在云安全组删除 TCP 1194
测试入站规则，并删除手动下载到设备上的测试配置。
