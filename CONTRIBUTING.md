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
- public Yazelix Nova `main` 是 `116` 上仅供 `ysun` 使用的 downstream 实验。Home Manager 安装适合 SSH/headless 环境的 `yazelix-no-mars`，入口是 `yzx enter`；它不属于 upstream 通用配置，也不会提供给 `zky` 或 `wangrongfeng`。

`upstream` input 由 Renovate 每 4 小时检查一次。`yazelix` 每天在 UTC
16:00–19:59（Asia/Shanghai 次日 00:00–03:59）的 eligibility window 内检查。
只有这两个 input 可以自动更新；Yazelix PR 通过现有 maintenance gate 后可以
automerge。gate 会对 public Yazelix 做真实求值；只有迁移 PR 的 legacy base
仍声明 `yazelix-next` 时才使用最小临时 stub。其他 downstream-owned inputs
继续禁用自动更新。

Renovate automerge 只合并 lock PR，绝不会 build、rebuild 或部署 `116`。真正的构建
和切换仍由运维用户从已审查的干净 `main` 在目标机器上执行 `maint-switch`。

更新 upstream 时只更新对应 flake input：

```nu
nix flake update upstream
git diff flake.lock
git add flake.lock
git commit -m "chore: update upstream dotfiles"
maint-switch --no-pull
```

本仓库的 `scripts/maint/policy-overrides.json` 只声明公司专属的维护门控规则。
`maint-switch --repo /home/ysun/github.com/sctmes/dotfiles` 在新系统激活前读取 flake
输出的 `lib.maintenancePolicy`；该有效策略由锁定的 upstream 共享基线和本仓库的窄
overlay 合成，不需要复制 upstream 的完整 policy。

如果 `maint-switch` 因共享的轻量生成式 glue derivation 被拦住，先修 upstream
policy，再更新本仓库的 `upstream` input；公司专属 derivation 才加入
`scripts/maint/policy-overrides.json`。不要直接绕过 gate，也不要把 kernel、driver、
Hyprland、GCC/Rust toolchain、Chromium/Electron 等重组件加入 allowlist。

网络问题需要按路径拆分：Nix cache、GitHub release/direct fetch、npm registry 或
node-gyp、Cargo registry 和运行时代理不是同一个问题。

首次从 Yazelix Next 迁移时，普通用户不能让 Nix daemon 信任临时指定的 Cachix。
合并并检查干净 `main` 后，由 root 先显式 bootstrap 目标 closure：

```nu
sudo nix build --no-link --print-out-paths --option extra-substituters https://yazelix.cachix.org --option extra-trusted-public-keys 'yazelix.cachix.org-1:ZgxIjQvaP0VTWL8Racx27mpUNzDJ97xC2y7QWYjmGNM=' .#nixosConfigurations.116.config.system.build.toplevel
maint-switch --no-pull
```

后续 Yazelix 更新以 Renovate PR、maintenance gate 和对应 `flake.lock` 变更为审查及
回退边界；需要回退时恢复上一份已审查的 lock/main 状态，再由运维用户构建和切换。
不要绕过 gate，也不要把自动合并理解为自动部署。

## 责任边界

- 运维用户负责 secret 管理、重装、系统 rebuild 和生产服务重启。
- 研究或业务用户可以提交 PR 申请依赖、服务或 token 接入变更。
- 非运维用户不要依赖手工安装的长期状态，也不要把个人 secret 放进共享 secret 文件。
- 具体用户名、权限和主机约定以对应主机文档为准。

## 主机文档

- 每台主机应在 `docs/<host>/README.md` 记录日常使用、维护、重装、存储和权限边界。
- 主机特有的磁盘、网络、服务和用户细节应留在对应主机文档，不要写成全仓库规则。
- 当前已有主机文档：[docs/116/README.md](./docs/116/README.md)。
