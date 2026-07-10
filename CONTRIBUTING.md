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

日常维护入口只有一个：

```nu
maint-switch
```

`maint-switch` 消费当前仓库已经提交的状态，执行网络门控、构建和系统切换。它不负责更新 flake inputs；依赖更新本身也应按贡献流程提交和审查。

版本来源是混合的：

- upstream-owned 工具、Codex release pin、Codex skills/MCP、headless 开发工具声明和维护门控策略来自 `bioinformatist/dotfiles`。这些更新先进入 upstream，再通过更新本仓库的 `upstream` flake input 被 `116` 消费。
- `116` 的基础 `nixpkgs`、`home-manager`、`sops-nix`、`disko`、`impermanence` 和 downstream 服务配置由本仓库自己的 flake lock 管理。
- `yazelix-next` 是 `116` 上 `ysun` 的实验性私有工具，不属于 upstream 通用配置，也不作为 `maint-*` 日常入口。

`upstream` input 由 Renovate 每 4 小时检查一次并提交 PR。这个自动化只移动
`upstream`，不更新 downstream-owned inputs，也不更新私有 `yazelix-next`。GitHub
Actions 会用临时 `yazelix-next` stub 跑 `116` cache gate，避免 CI 需要读取 Lucca
私有仓库；gate 比较 PR 和 `main`，只拦新增的未批准本地构建。真正的构建和切换仍由
运维用户在目标机器上执行 `maint-switch`。

更新 upstream 时只更新对应 flake input：

```nu
nix flake update upstream
git diff flake.lock
git add flake.lock
git commit -m "chore: update upstream dotfiles"
maint-switch --no-pull
```

本仓库的 `scripts/maint/policy.json` 显式转发 upstream 的维护门控策略，供
`maint-switch --repo /home/ysun/github.com/sctmes/dotfiles` 在新系统激活前读取。
更新 upstream 时，如果 upstream 的 `scripts/maint/policy.json` 变了，也要同步更新
本仓库的转发文件。

如果 `maint-switch` 因轻量生成式 glue derivation 被拦住，先修 upstream policy，
再更新本仓库的 `upstream` input 和 `scripts/maint/policy.json`；不要直接绕过 gate，
也不要把 kernel、driver、Hyprland、GCC/Rust toolchain、Chromium/Electron 等重组件
加入 allowlist。

网络问题需要按路径拆分：Nix cache、GitHub release/direct fetch、npm registry 或
node-gyp、Cargo registry 和运行时代理不是同一个问题。

更新 `yazelix-next` 时也走显式手动流程：

```nu
nix flake update yazelix-next
git diff flake.lock
git add flake.lock
git commit -m "chore: update yazelix next"
maint-switch --no-pull
```

如果 dry-run 显示会触发暂时不想接受的本地构建，停止在提交前或回退对应 `flake.lock` 变更。`yazelix-next` 目前是私有仓库，执行更新的用户需要有对应 GitHub SSH 读取权限。

## 责任边界

- 运维用户负责 secret 管理、重装、系统 rebuild 和生产服务重启。
- 研究或业务用户可以提交 PR 申请依赖、服务或 token 接入变更。
- 非运维用户不要依赖手工安装的长期状态，也不要把个人 secret 放进共享 secret 文件。
- 具体用户名、权限和主机约定以对应主机文档为准。

## 主机文档

- 每台主机应在 `docs/<host>/README.md` 记录日常使用、维护、重装、存储和权限边界。
- 主机特有的磁盘、网络、服务和用户细节应留在对应主机文档，不要写成全仓库规则。
- 当前已有主机文档：[docs/116/README.md](./docs/116/README.md)。
