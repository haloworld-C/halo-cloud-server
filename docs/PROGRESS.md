# halo_server 项目进展

最后更新：2026-08-30

## 当前状态

WireGuard 单客户端生产基线已完成部署，项目进入多设备与客户端互通验证阶段。

## 已完成

- 建立 `halo_server` 统一部署项目结构。
- 将 Git 主分支设置为 `main`。
- 建立 `modules/wireguard` 子模块。
- WireGuard 模块支持：
  - Ubuntu/Debian 环境检查与软件安装；
  - 服务端密钥和配置生成；
  - IPv4 转发、iptables NAT 和 UFW 端口放行；
  - `wg-quick@wg0` 开机启动；
  - 客户端配置新增、撤销和状态检查；
  - 配置权限收紧及已有配置防覆盖。
- 增加 WireGuard shell 语法检查和 smoke test。
- 在 WSL Ubuntu 中执行 smoke test 并通过。
- 增加项目规划与进展文档。
- 设置 GitHub 远端仓库 `haloworld-C/halo-cloud-server`。
- 创建首次提交并成功推送 `main` 分支。
- 完成服务器普通 sudo 管理用户和 SSH 公钥登录验证。
- 关闭服务器 SSH 密码认证。
- 新增 WireGuard 正式部署、验收、回退与故障排查手册。
- 在 Debian 12 云服务器完成 WireGuard 首次部署：
  - `wg0` 使用 `10.66.66.0/24`，监听 UDP `51820`；
  - 公网出口接口为 `eth0`；
  - 云安全组已放行 WireGuard UDP 端口；
  - `client1` 已成功握手并能访问 VPN 服务端；
  - DNS 与 IPv4 全隧道公网出口验证通过；
  - IPv4 转发已持久化启用。
- 根据精简 Debian 实机结果补充 `procps` 依赖和 IPv4 转发显式校验。

## 仓库状态

- 主分支：`main`
- 远端：`https://github.com/haloworld-C/halo-cloud-server.git`
- 同步方式：本地分支跟踪 `origin/main`

## 下一步

1. 为手机、电脑和平板分别创建独立客户端配置。
2. 在不同运营商、Wi-Fi 和移动网络下验证握手、DNS 与全隧道路由。
3. 验证客户端到服务端以及客户端之间的双向连通性。
4. 验证客户端撤销、服务器重启恢复和设备遗失处置流程。
5. 配置云服务器的只读 GitHub Deploy Key。
6. 设计根目录统一部署入口与模块生命周期接口。

## 已知限制

- WireGuard 安装脚本当前只负责首次安装，不负责原地升级。
- 当前仅配置 IPv4 全隧道，不包含 IPv6 路由和 NAT。
- 当前仅完成单客户端实机验证，尚未完成跨设备和客户端互通矩阵。
- 尚未提供统一卸载和自动回滚脚本。
