# halo_server 项目进展

最后更新：2026-09-26

## 当前状态

WireGuard 已部署并完成多设备互通测试。家庭网络到云服务器的 UDP 上行
存在明显丢包；OpenVPN TCP 并行测试模块已编写，尚未在云服务器部署。

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

- 完成手机、WSL 笔记本及办公室电脑的 WireGuard 互通与双向带宽测试。
- 对比家中有线、移动热点、普通 SSH/TCP 和两个 UDP 端口：
  - 到同一 VPS 的普通 SSH/TCP 上行约 82 Mbps；
  - 家中到 VPS 的 UDP 上行在 10 Mbps 发包时，实例公网网卡仅收到约 6 Mbps；
  - UDP 51820 与 51921 均出现类似现象，VPS 网卡和 UDP 缓冲区无对应错误。
- 增加独立的 OpenVPN TCP 测试模块，使用 TCP 1194 与 10.66.67.0/24；
  提供安装、增加客户端、状态检查、测试和确认后清理脚本。

## 仓库状态

- 主分支：`main`
- 远端：`https://github.com/haloworld-C/halo-cloud-server.git`
- 同步方式：本地分支跟踪 `origin/main`

## 下一步

1. 在云服务器并行部署 OpenVPN TCP 测试实例，先接入 WSL 笔记本。
2. 在相同家庭网络下对比 OpenVPN TCP 与 WireGuard 的双向吞吐和稳定性。
3. 如果结果可接受，再给手机和办公室电脑分别生成证书并验证客户端互通。
4. 验证客户端撤销、服务器重启恢复和设备遗失处置流程。
5. 配置云服务器的只读 GitHub Deploy Key。
6. 设计根目录统一部署入口与模块生命周期接口。

## 已知限制

- WireGuard 安装脚本当前只负责首次安装，不负责原地升级。
- 当前仅配置 IPv4 全隧道，不包含 IPv6 路由和 NAT。
- WireGuard 已完成基础跨设备互通，但尚未验证客户端撤销和服务器重启恢复。
- 尚未提供统一卸载和自动回滚脚本。
- OpenVPN TCP 模块目前仅通过静态检查和本地 smoke test，尚未实机验收。
