# halo_server

云服务器统一部署与运维项目。各项服务以独立模块组织，模块之间默认不共享密钥或运行时配置。

## 项目文档

- [项目规划](docs/PROJECT_PLAN.md)
- [当前进展](docs/PROGRESS.md)

## 模块

| 模块 | 状态 | 用途 |
|---|---|---|
| [WireGuard](modules/wireguard/README.md) | 可部署 | 云服务器 VPN、客户端配置与访问撤销 |

## 目录约定

```text
halo_server/
├── modules/
│   └── wireguard/
│       ├── deploy.env.example
│       ├── scripts/
│       └── tests/
└── README.md
```

每个模块维护自己的配置模板、部署脚本、测试和使用说明。真实环境配置与密钥不提交到 Git。

## 使用 WireGuard 模块

```bash
cd modules/wireguard
cp deploy.env.example deploy.env
# 编辑 deploy.env 后，将模块上传到服务器并执行：
sudo ./scripts/install.sh ./deploy.env
```

详细说明见 [WireGuard 子模块文档](modules/wireguard/README.md)。
