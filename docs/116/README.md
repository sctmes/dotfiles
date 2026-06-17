# 116 服务器说明

`116` 是一台无头 GPU 服务器，由本仓库通过 NixOS 管理。日常操作以
SSH、Nushell、systemd、Docker 和文本配置为主，不假设有图形界面。

## 用户和权限

- `ysun` 是当前运维用户，负责 secrets、重装、系统 rebuild 和生产服务
  重启。
- `zky` 和 `wangrongfeng` 是研究用户，有 Docker 权限，没有 sudo。
- 长期依赖和服务变更都应该通过本仓库 PR 进入声明式配置，不要依赖手工
  安装。

## 日常使用

登录后常用检查命令：

```nu
systemctl --failed
systemctl status docker.service
systemctl status mihomo-compose.service
```

修改本仓库后，由运维用户执行：

```nu
maint-check
maint-switch
```

`maint-switch` 只应用当前仓库状态，不会自动更新 flake inputs。需要更新依赖
时先开 PR，由 `ysun` 确认后再 rebuild。

## 主要服务

- Mihomo: `mihomo-compose.service`
  - 网页界面：`http://192.168.0.116:9090/ui/`
  - 运行配置在 `/persist/mihomo/config.yaml`
  - 真实订阅 URL 不进仓库
- Label Studio: `label-studio-compose.service`
  - 公网入口: `https://label.bigdick.live:2053`
  - 对外 HTTPS 依赖 Cloudflare 代理和 Caddy
  - 初始密码来自 SOPS，上线后应在 Label Studio 内轮换
- 助手服务栈: `jarvis-vllm-compose.service`
  - `8080`: 兼容 OpenAI 的 API
  - `8090`: 转录兼容服务

## 存储约定

`/data1` 是慢速 RAID1 备份盘，不作为 Docker、模型服务或日常开发的热路径。

运行数据放在系统 SSD 上：

- `/var/lib/docker`
- `/var/lib/ai-serving/models`
- `/var/lib/label-studio`
- `/var/lib/caddy`

这些路径通过 `/persist` 持久化。重装系统 SSD 时，不要假设旧 `/home` 会被
保留；需要保留的个人数据应提前备份或迁移。

## 重装流程

重装会重建系统 SSD，`/data1` 应保持为已有备份盘。执行前确认：

- `hosts/116/disko-config.nix` 指向正确的系统盘。
- SOPS age 私钥在运维机的 `/persist/var/lib/sops-nix/key.txt`。
- 运维 SSH key 可用。
- 模型文件可恢复到 `/var/lib/ai-serving/models`。
- 安装现场有可访问 GitHub/Nix cache 的局域网 HTTP 代理。
- Cloudflare、Label Studio、Mihomo 相关 secrets 已在 SOPS 中。

从本仓库运行：

```nu
nu ./scripts/install-116.nu root@192.168.0.116 --proxy http://<lan-proxy>:<port>
```

安装完成后：

1. 用 `ysun` 登录。
2. 打开 Mihomo 网页界面，导入或替换 `/persist/mihomo/config.yaml`。
3. 恢复模型文件到 `/var/lib/ai-serving/models`。
4. 检查核心服务：

   ```nu
   systemctl status mihomo-compose.service
   systemctl status cloudflare-ddns-compose.service
   systemctl status caddy.service
   systemctl status label-studio-compose.service
   ```

5. 在 `https://label.bigdick.live:2053` 登录 Label Studio 并轮换初始密码。
6. 克隆本仓库到 `/home/ysun/github.com/sctmes/dotfiles`。

## 无头开发环境

`zky` 和 `wangrongfeng` 继承 upstream 的无头开发工具集，包括 `gh`、
Codex、Context7 MCP、Playwright skill、stop-slop skill、Nushell、Helix、
Yazi、ripgrep 等。

每个用户的 Codex memory 和 trusted project 都使用自己的 home 目录，不共享
`ysun` 的运行状态。

## GitHub 认证

只使用 `gh` CLI 时，每个用户自己运行：

```nu
gh auth login
```

如果需要 Codex GitHub MCP 也稳定使用个人 token，则通过 PR 注册流程：

1. 在 `hosts/116/default.nix` 的 `githubMcpTokenUsers` 中加入用户名。
2. 新增 per-user SOPS 文件：

   ```text
   secrets/hosts/116/github-mcp-token-<user>.yaml
   ```

3. 用 SOPS 创建文件：

   ```nu
   sops secrets/hosts/116/github-mcp-token-<user>.yaml
   ```

4. 明文编辑时只写：

   ```yaml
   github-mcp-token: <github token>
   ```

保存后文件应是 SOPS 加密内容。不要把 token 加进共享
`secrets/hosts/116.yaml`，也不要提交明文 token。

审查这类 PR 时只看：用户名、文件名、SOPS 加密是否正确，以及 token 是否只
路由给同一个 Unix 用户。
