# halo_server 项目进展

最后更新：2026-08-30

## 当前状态

项目处于阶段一：仓库与 WireGuard 基线建设。

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

## 仓库状态

- 主分支：`main`
- 远端：`https://github.com/haloworld-C/halo-cloud-server.git`
- 同步方式：本地分支跟踪 `origin/main`

## 下一步

1. 按正式部署手册在 Debian 云服务器执行 WireGuard 首次安装。
2. 验证握手、全隧道路由、DNS、重启恢复及客户端撤销。
3. 根据实机结果补充诊断和安全回退流程。
4. 配置云服务器的只读 GitHub Deploy Key。
5. 设计根目录统一部署入口与模块生命周期接口。

## 已知限制

- WireGuard 安装脚本当前只负责首次安装，不负责原地升级。
- 当前仅配置 IPv4 全隧道，不包含 IPv6 路由和 NAT。
- 尚未在真实云厂商安全组和公网网络环境中验证。
- 尚未提供统一卸载和自动回滚脚本。
