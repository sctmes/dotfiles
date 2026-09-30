# 116 服务器说明

`116` 是一台 headless GPU 服务器，由本仓库通过 NixOS 管理。

## headless 开发环境

`116` 通过本仓库锁定的 `upstream` flake input 继承 headless 开发工具集。Codex 独立 CLI 来自 upstream 锁定的 `llm-agents.nix` 社区包；配置、Improve 和共享 skills 来自 Codex Base，并由 `bioinformatist/dotfiles` 导出。Improve 和 doctor 使用同一份 CLI，服务器不安装桌面应用。使用说明见 Codex Base 的[中文使用文档](https://github.com/bioinformatist/codex-base/blob/main/README.zh-CN.md)、[能力目录](https://github.com/bioinformatist/codex-base/blob/main/docs/capabilities.zh-CN.md)和[配置说明](https://github.com/bioinformatist/codex-base/blob/main/docs/configuration.zh-CN.md)。

`proxyRecovery` 策略由 Codex Base 提供，downstream 在两个 Home Manager 入口通过 `dotfiles.codex.proxyRecovery.enable = lib.mkDefault true;` 启用：`homes/ysun/default.nix` 管理 `ysun` 的个人配置；`homes/headless-dev/default.nix` 管理共享开发用户 `zky` 和 `wangrongfeng` 的配置。用户可以在自己的配置中设置 `dotfiles.codex.proxyRecovery.enable = false;` 关闭该策略。

Codex 配置变更经过不同阶段：先由 upstream 合并，再由本仓库更新 `flake.lock` 消费该版本，然后由运维用户 rebuild `116`。upstream 合并或下游锁更新本身都不会部署配置；rebuild 更新安装文件，但不会让已连接到旧后台的 Codex 客户端自动切换。对于通过客户端连接 SSH 后台的会话，还需受控重连后台，并在新会话中确认加载的配置。

## 用户和权限

- `ysun` 是当前运维用户，负责 secrets、重装、系统 rebuild 和生产服务重启。
- `zky` 和 `wangrongfeng` 是研究用户，有 Docker 权限，没有 sudo。
- 长期依赖和服务变更都应该通过本仓库 PR 进入声明式配置，不要依赖手工安装。

## 日常使用

登录后常用检查命令：

```nu
systemctl --failed
systemctl status docker.service
systemctl status mihomo-compose.service
```

修改本仓库后，由运维用户执行：

```nu
maint-switch
```

`maint-switch` 只应用当前仓库状态，不会自动更新 flake inputs。依赖更新和 rebuild 流程见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

### Yazelix Nova

`116` 只为 `ysun` 从 `Yazelix/nova/edge` 安装适合 SSH/headless 环境的 `yazelix-no-rio`，入口是 `yzx enter`。`ysun` 将它作为日常 SSH 工作的 edge canary，但每次更新仍由运维用户审查后手动激活；`zky`、`wangrongfeng` 和 upstream 通用配置不会获得 Yazelix 或通用 Zellij。Renovate、maintenance gate、条件式 Cachix bootstrap、手动应用和 lock-based rollback 的责任边界见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

Nova 管理的 Atuin 只在本机记录历史并保留 `Ctrl+r` 搜索，不登录账户或同步；Up-arrow 仍使用 shell 原生历史。进入敏感目录工作前应先检查 history filters。Carapace 为 Nova 管理的 Nushell 提供外部命令补全，本身不保存命令历史。Ratconfig 是 `yzx config` 的 UI 和配置校验层；当前 downstream Home Manager 只选择 `yazelix-no-rio` package，不接管 Nova 的详细 overrides。

激活后先运行：

```nu
which yzx
yzx --version
yzx status --json
yzx doctor
yzx enter
```

在交互会话中至少检查 managed Nushell 启动、Carapace Tab 补全、Atuin `Ctrl+r` 与原生 Up-arrow、`yzx config` 编辑和 reset、managed Helix、Yazi、LazyGit 与 agent popups、session 创建/attach/exit，以及 SSH 断线行为；同时确认 Atuin 没有 account 或 sync 配置。`yazelix-no-rio` 作为 capability variant 当前不会获得完整 `yazelix-edge` 的 channel-qualified identity，因此向 Nova 报告 `edge` 问题时必须附上 `open flake.lock | get nodes.yazelix.locked.rev` 得到的精确锁定 revision，以及经过脱敏的 `yzx status --json`、`yzx doctor` 和复现上下文。

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

这些路径通过 `/persist` 持久化。重装系统 SSD 时，不要假设旧 `/home` 会被保留；需要保留的个人数据应提前备份或迁移。

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
2. 克隆本仓库到 `/home/ysun/github.com/sctmes/dotfiles`。
3. 打开 Mihomo 网页界面，导入或替换 `/persist/mihomo/config.yaml`。
4. 在执行 `maint-switch` 前，先备份当前运行配置并记录上下文，保留 SSH 回退通道：

   ```nu
   let rollback_dir = (sudo mktemp -d /persist/mihomo/rollback-github.XXXXXX | str trim)
   sudo cp --preserve=mode,ownership /persist/mihomo/config.yaml $"($rollback_dir)/config.yaml"
   let deploy_commit = (git rev-parse HEAD)
   let current_system = (readlink -f /run/current-system)
   echo $"rollback_dir=($rollback_dir)"
   echo $"deploy_commit=($deploy_commit)"
   echo $"current_system=($current_system)"
   ```

5. 应用仓库声明的系统配置，再显式重跑 Mihomo bootstrap unit，确保 controller 仍使用 `sops` 的 `mihomo-controller-secret`，不在日志/终端打印 secret：

   ```nu
   nu --login -c 'maint-switch --no-pull --repo /home/ysun/github.com/sctmes/dotfiles'
   sudo systemctl restart mihomo-config-bootstrap.service
   ```

   `mihomo-config-bootstrap` 是 `RemainAfterExit` 的 oneshot。导入运行配置后，即使目标 generation 没有变化，也要显式重跑该 unit 才能保证执行归一化。
6. 确认归一化目标：

   - `Proxy` 仍是依次包含 `WestWorld Auto` 与 `YToo Backup` 的 `fallback`，沿用 gstatic URL、300秒间隔和8000ms超时。
   - `WestWorld Auto` 只选 `WestWorld` 中严格匹配日本的节点，以 `https://github.com/robots.txt`、`expected-status: 200` 测速；保留1800秒间隔、8000ms超时、`tolerance: 100` 和 `lazy: true`。
   - `lazy: true` 允许跳过空闲周期，100ms容差减少频繁切换。此指标衡量 GitHub 请求延迟和可达性，不代表 API/raw/release 的全部质量。
   - `YToo Backup` 保持使用 `YToo` provider 的 `select` 组，不参与自动节点测速。
   - WestWorld provider 的 `health-check` 保持 enable=false/url=""/interval=0/timeout=8000/lazy=true；清空默认 URL，避免对全部节点进行默认探测，由日本组注册测速任务。
7. 验证配置并重启 Mihomo：

   ```nu
   docker exec mihomo /mihomo -t -d /root/.config/mihomo -f /root/.config/mihomo/config.yaml
   sudo systemctl restart mihomo-compose.service
   ```
8. 重启后验证：

   - 确认 Mihomo 服务与 SSH 正常。
   - 通过 controller `/providers/proxies/WestWorld` 查看上述 GitHub URL 的新测速记录，日本节点至少一个成功；沿用 SOPS `mihomo-controller-secret` 认证，不打印 secret，不手动全部测速制造结果。
   - 确认 `YToo Backup` 和外层 `Proxy` 仍符合第6项。下面 curl 的最终 HTTP 状态应为200，`CONNECT` 200不等于目标站点成功。

   ```nu
   curl --proxy http://127.0.0.1:7890 --noproxy "" --head --connect-timeout 5 --max-time 15 https://github.com/
   ```

   不得使用 `PUT /configs?force=true`。重启会短暂删除并重新创建 `Meta` TUN 接口；无需额外等待 30 分钟，恢复后按正常使用观察。
9. 恢复模型文件到 `/var/lib/ai-serving/models`。
10. 检查核心服务：

    ```nu
    systemctl status mihomo-compose.service
    systemctl status cloudflare-ddns-compose.service
    systemctl status caddy.service
    systemctl status label-studio-compose.service
    ```

11. 如需回退 Mihomo 路由策略，按以下顺序操作：

    1. 恢复此前已审核的仓库源码/检查点。
    2. 从该版本运行 `nu --login -c 'maint-switch --no-pull --repo /home/ysun/github.com/sctmes/dotfiles'`。
    3. 用本次备份（`$rollback_dir/config.yaml`）恢复运行时 `/persist/mihomo/config.yaml`，并保留 owner、group 和 mode，确认 `WestWorld Auto` 与 `YToo Backup` 已恢复到原策略。
       固定文件 `/persist/mihomo/config.yaml.before-westworld-japan-policy` 可能过期，不直接作为本次默认回退来源。
    4. 运行 `docker exec mihomo /mihomo -t -d /root/.config/mihomo -f /root/.config/mihomo/config.yaml` 验证配置。
    5. 运行 `sudo systemctl restart mihomo-compose.service`。

12. 在 `https://label.bigdick.live:2053` 登录 Label Studio 并轮换初始密码。

## GitHub 认证

只使用 `gh` CLI 时，每个用户自己运行：

```nu
gh auth login
```

如果需要 Codex GitHub MCP 也稳定使用个人 token，请按 [CONTRIBUTING.md](../../CONTRIBUTING.md) 提交 PR；这里记录 token 文件的具体要求：

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

保存后文件应是 SOPS 加密内容。不要把 token 加进共享 `secrets/hosts/116.yaml`，也不要提交明文 token。

审查这类 PR 时只看：用户名、文件名、SOPS 加密是否正确，以及 token 是否只路由给同一个 Unix 用户。

## Context7 认证

所有 headless dev 用户默认都可以使用匿名 `context7` MCP。登记了个人 Context7 API key 的用户会额外得到自己的 `context7_auth` MCP server；匿名额度不可用时，再改用这个认证 server。当前这是两套 server 的手动/agent 层 fallback，不是同一个 server 自动捕获 429 后透明重试。`ysun` 已登记自己的 encrypted SOPS 文件；其他用户不要共享这个 key。

如果需要 Codex Context7 MCP 也稳定使用个人 API key，请按 GitHub MCP token 的同类规则提交 PR：

1. 在 `hosts/116/default.nix` 的 `context7ApiKeyUsers` 中加入用户名。
2. 新增 per-user SOPS 文件：

   ```text
   secrets/hosts/116/context7-api-key-<user>.yaml
   ```

3. 用 SOPS 创建文件：

   ```nu
   sops secrets/hosts/116/context7-api-key-<user>.yaml
   ```

4. 明文编辑时只写：

   ```yaml
   context7-api-key: <Context7 API key>
   ```

保存后文件应是 SOPS 加密内容。不要把 Context7 API key 加进共享 `secrets/hosts/116.yaml`，也不要提交明文 key。

审查这类 PR 时只看：用户名、文件名、SOPS 加密是否正确，以及 API key 是否只路由给同一个 Unix 用户。
