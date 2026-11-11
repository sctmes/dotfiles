# 贡献说明

本仓库管理共享基础设施。所有改动都按运维变更处理，不按个人 dotfiles 小改动处理。

## 依赖和服务变更

如果需要新增系统依赖、长期服务或会影响其他用户的配置：

1. 向本仓库提交 PR。
2. 说明用户需求，以及具体要改的包、服务或配置。
3. 等待对应主机的运维用户 review。
4. 通过后由运维用户执行 rebuild、服务重启或重装。

不要在机器上手工安装长期依赖并假设它们会在 rebuild 后保留。

已有主机的日常维护、rebuild 和重装说明见对应主机文档；当前可参考 [docs/116/README.md](./docs/116/README.md)。

## 维护和版本来源

依赖更新通过人工 PR 审查；Renovate 已禁用，不再自动创建更新或自动合并。
CI 的 `maintenance gate` 状态名称保留，但内容改为实际 `116` 配置、三个用户的
Home Manager activation 和针对 headless/cache 配置的检查，不再按 cache miss
拒绝改动，也不执行部署。

版本来源仍分层管理：

- upstream-owned 工具、Codex 运行包选择、skills/MCP 和 headless 开发工具声明来自
  `bioinformatist/dotfiles`。Codex CLI 来自 upstream 锁定的 `llm-agents.nix`，
  配置、Improve 和 skills 来自 Codex Base。
- `116` 的 `nixpkgs`、`home-manager`、`sops-nix`、`disko`、`impermanence`
  以及 `dotlink` 和 downstream 服务继续由本仓库的 lock 管理。
- `Yazelix/nova/edge` 仍是仅供 `ysun` 使用的 downstream 实验，安装
  `yazelix-no-rio`，入口为 `yzx enter`；不会提供给其他用户或 upstream 通用配置。

只更新所需 input，不顺便刷新所有依赖：

```nu
nix flake update upstream
git diff flake.lock
git add flake.lock
git commit -m "chore: update upstream dotfiles"
```

提交 PR、审查并合并后，由运维用户在目标机器上显式准备干净的最新 `main`，
再执行 `maint-switch`。该命令只消费当前 checkout，不会 pull、更新 inputs 或改写
lock，不再支持 `--no-pull`。先完整构建，再通过 `nixos-rebuild --store-path`
激活同一个 closure。构建失败不激活；kernel 或 NVIDIA userspace 变化时自动改用
boot-only activation，安排维护窗口并另行确认 reboot，不能把 boot 成功当成运行系统已更新。

```nu
git switch main
git pull --ff-only
git status --short
maint-switch
```

`git status --short` 必须为空，且 HEAD 必须是已审查的目标提交。
多用户服务或 GPU 负载活跃时先协调切换；需要只准备下次启动时使用 `maint-switch --boot`。

### 首次迁移旧 helper

旧 shell 中的 `maint-switch` 仍会调用已经退休的 cache gate；只删除 CI 不会更新
正在运行的 helper。首次部署本次迁移时，从当前已审查 lock 获取 upstream 路径，
在临时 Nushell 中加载新 helper，仍保留完整构建和 kernel/NVIDIA 风险判断：

```nu
let repo = (pwd)
let upstream = (nix flake archive --json --no-update-lock-file | from json | get inputs.upstream.path)
nu --no-config-file -c $'source ($upstream)/home/shell/nushell/maint.nu; maint-switch --repo "($repo)"'
```

这里复用已安装的 `dotfiles/maint.nuon` 主机设置；`--repo` 显式选择当前 checkout。
激活新 Home Manager 配置后重新打开 Nushell，后续直接使用 `maint-switch`。
如果此次是 boot-only activation，运行环境和旧 helper 要等另行 reboot 后才改变。

### Cache 和更新边界

继承 upstream 的明确优先级：USTC `priority=10`，官方 `cache.nixos.org`
`priority=40`，headless Numtide `priority=60`；downstream 的 Yazelix Cachix
同为 `priority=60`。数字越小越优先。安装脚本也采用此顺序；不复制 workstation-only
缓存，不重复加入不带 priority 的官方缓存。保持 `require-sigs = true` 和现有公开
签名公钥。cache miss 可以本机构建，是否执行长时间构建由运维用户根据负载判断，
不再通过 derivation 名称 allowlist 决定。

此次更新只刷新 `upstream` 及其传递 inputs。downstream 顶层 inputs 保持原锁定版本，
但继承的 Codex CLI 会更新；Helix/Yazi 从 upstream 独立工具包集合迁回 downstream
`nixpkgs`，可能出现版本变化。upstream 的桌面 inputs 仍出现在 lock 图中，
不等于为 `116` 启用桌面或构建所有桌面包。更轻的 headless flake 边界属于后续独立工作。

如果 live daemon 尚未信任 Numtide/Yazelix，先由运维用户检查已声明的 URL 和公钥，
不要关闭签名检查。网络问题按 Nix cache、GitHub release/direct fetch、npm/node-gyp、
Cargo 和运行时代理分别诊断。

回退边界是已审查的 `flake.lock` 和 main 提交；恢复上一份已审查状态后重新构建、
检查风险并激活。针对 Yazelix `edge` 的问题报告同时附上
`open flake.lock | get nodes.yazelix.locked.rev` 和脱敏复现信息，不把 channel 名当作精确版本。

## 责任边界

- 运维用户负责 secret 管理、重装、系统 rebuild 和生产服务重启。
- 研究或业务用户可以提交 PR 申请依赖、服务或 token 接入变更。
- 非运维用户不要依赖手工安装的长期状态，也不要把个人 secret 放进共享 secret 文件。
- 具体用户名、权限和主机约定以对应主机文档为准。

## 主机文档

- 每台主机应在 `docs/<host>/README.md` 记录日常使用、维护、重装、存储和权限边界。
- 主机特有的磁盘、网络、服务和用户细节应留在对应主机文档，不要写成全仓库规则。
- 当前已有主机文档：[docs/116/README.md](./docs/116/README.md)。
