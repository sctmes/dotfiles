# 116 服务器说明

`116` 是一台 headless GPU 服务器，由本仓库通过 NixOS 管理。

## headless 开发环境

`116` 通过本仓库锁定的 `upstream` flake input 继承 headless 开发工具集，包括 `gh`、Codex、Nushell、Helix、Yazi 和 ripgrep。下表记录当前 upstream 管理的共享 Codex 能力及其触发边界；Codex release 自带且不由 dotfiles 管理的 system Skills 也单独列出，避免混淆两种来源。

upstream 合并、下游更新 `flake.lock` 和 `116` 完成 rebuild 是三个不同阶段。三步全部完成后，新能力才会出现在服务器上的新 Codex 会话中；不能只根据 upstream PR 已合并就判断已经部署。

| 名称 | 类型 | 触发条件 | 功能 |
| --- | --- | --- | --- |
| [全局 `AGENTS.md`](https://github.com/bioinformatist/dotfiles/blob/main/home/programs/codex/default.nix) | 全局指令 | Codex 启动后自动读取生成的 `~/.codex/AGENTS.md`。 | 补充跨仓库工作偏好：采用最小但完整的改动、让建议和术语解释具备充分上下文、遵循 Git/Nix 约定，并执行 Context7 fallback 与 per-user secret routing 等通用 capability routing。 |
| [OpenAI system Skills](https://developers.openai.com/codex/skills) | Codex 内置 Skills | 随当前 Codex release 提供；任务匹配 description 或用户用 `$skill-name` 显式要求时加载。 | 提供 `$skill-creator`、`$skill-installer` 等通用能力。具体清单不由 dotfiles 固定，应在当前会话用 `/skills` 查看。 |
| [GitHub MCP](https://github.com/github/github-mcp-server) | MCP | Codex 注册 `github` MCP；处理 GitHub repo、issue、PR、review、CI 相关任务时调用。 | 通过用户自己的 GitHub token 访问 GitHub context、issues、pull requests、repos、users 和 orgs。token 配置见下方“GitHub 认证”。 |
| [GitHub curated plugin](https://github.com/openai/plugins/tree/main/plugins/github) | Skill plugin | Codex 启用 `github@openai-curated`；处理 GitHub issue、PR、review、CI 或发布本地改动时可能触发。 | 在 GitHub MCP 之上提供更高层工作流 skills，例如处理 PR review comments、修复 GitHub Actions CI、梳理 repo/issue/PR 上下文和发布本地修改。 |
| [Context7 MCP](https://github.com/upstash/context7) | MCP | Codex 注册匿名 `context7` MCP；涉及库、框架、SDK、API、CLI 或云服务当前文档时使用。 | 默认先用匿名 Context7 拉取较新的项目文档；登记了个人 API key 的用户还会得到 `context7_auth` fallback，匿名额度不可用时再使用自己的认证额度。 |
| [`improve`](https://github.com/shadcn/improve/tree/03369ee6d7cafbfcecc4346539b05b3dc0a603bb/skills/improve) | Skill + executors/reviewers | 想系统检查代码库、收敛实施计划并隔离执行时，在 Codex 对话中使用 `$improve`。 | advisor 把计划收敛为 `READY` 或 `BLOCKED`，声明执行环境和 Spark/standard/deep lane；runner 在独立 worktree 预检并执行，之后按风险触发 correctness 或 elegance 复核。完整用法见 [Improve 使用说明](codex-improve.md)。 |
| [Playwright CLI skill](https://github.com/microsoft/playwright-cli/tree/v0.1.17/skills/playwright-cli) | Skill | 浏览器自动化、页面预览、截图、交互验证或 Playwright 相关任务；也可显式要求 `$playwright-cli`。 | 使用 Playwright CLI 做 headless-first 的页面检查和自动化，默认采用 snapshot/screenshot；只有用户明确要求且存在图形会话时才使用交互 annotation。 |
| [stop-slop](https://github.com/hardikpandya/stop-slop/tree/8da1f030185bdfe8471220585162991eaeb970e9) | Skill | 英文 PR、issue、release notes、README/docs、公开评论等 publishable prose 的最终润色；也可显式要求 `$stop-slop`。 | 在不改技术事实、命令、日志、标识符和有用不确定性的前提下，去掉公式化 AI 文风。 |
| [Ponytail Review](https://github.com/DietrichGebert/ponytail/tree/v4.8.3/skills/ponytail-review) | Skill | 用户明确要求 over-engineering review、simplify review、what can we delete，或显式 `$ponytail-review`。 | 只审复杂度：指出可删除的 speculative abstraction、重复造轮子、无用依赖和死弹性。 |
| [Ponytail Audit](https://github.com/DietrichGebert/ponytail/tree/v4.8.3/skills/ponytail-audit) | Skill | 用户明确要求全仓库 over-engineering audit、find bloat、what can I delete，或显式 `$ponytail-audit`。 | 对整个 repo 做复杂度审计，输出按优先级排序的删除、简化和 stdlib/native 替代建议。 |
| [Ponytail Debt](https://github.com/DietrichGebert/ponytail/tree/v4.8.3/skills/ponytail-debt) | Skill | 用户明确要求 ponytail debt、列出 `ponytail:` 注释，或显式 `$ponytail-debt`。 | 汇总代码中有意留下的 `ponytail:` 延后事项，避免临时取舍失去上下文。 |
| [Diagnosing Bugs](https://github.com/mattpocock/skills/tree/2ab958093e83e0ec752e6c1c5932da465bf23e0c/skills/engineering/diagnosing-bugs) | Skill | 遇到具体 bug、回归、flaky failure 或原因不明的性能问题；也可显式要求 `$diagnosing-bugs`。 | 用紧反馈循环建立复现、区分事实和假设、逐步缩小根因，不把普通实现任务误当调试流程。 |
| [TDD](https://github.com/mattpocock/skills/tree/2ab958093e83e0ec752e6c1c5932da465bf23e0c/skills/engineering/tdd) | Skill | 用户要求 test-first、先写回归测试再修 bug，或显式要求 `$tdd`。 | 从已接受计划、规格或仓库证据确定测试 seam；只有 seam 仍有材料性歧义时才询问用户，并在测试保持 green 时重构。 |
| [Codebase Design](https://github.com/mattpocock/skills/tree/2ab958093e83e0ec752e6c1c5932da465bf23e0c/skills/engineering/codebase-design) | Skill | 设计或调整模块边界、接口深度、seam、adapter、可测试性时；也可显式要求 `$codebase-design`。 | 提供深模块、接口、seam、locality 等架构词汇，用于评估模块边界是否值得调整。不会自动派生多个 agent。 |
| [Grilling](https://github.com/mattpocock/skills/tree/2ab958093e83e0ec752e6c1c5932da465bf23e0c/skills/productivity/grilling) | Skill | 仅在用户明确要求 grill、interrogate、interview、stress-test 某个计划、决定或想法时触发；也可显式要求 `$grilling`。 | 一次提出一个问题，在行动前暴露隐含假设、弱论证和缺失决策。 |
| [Handoff](https://github.com/mattpocock/skills/tree/2ab958093e83e0ec752e6c1c5932da465bf23e0c/skills/productivity/handoff) | Skill | 仅在用户明确要求为另一个会话准备 handoff，或显式要求 `$handoff` 时触发。 | 在 `$TMPDIR` 或 `/tmp` 写一份唯一命名、已脱敏的 Markdown 交接文件，引用现有计划、commit 和日志，不复制整份 artifact，也不会自动启动新会话。 |
| [Domain Modeling](https://github.com/mattpocock/skills/tree/2ab958093e83e0ec752e6c1c5932da465bf23e0c/skills/engineering/domain-modeling) | Skill | 正在修改 glossary、ubiquitous language 或记录 ADR 级决定时触发；仅读取 `CONTEXT.md` 不会触发。也可显式要求 `$domain-modeling`。 | 收敛领域术语、概念关系和持久架构决定，减少同一概念在代码和文档中的语义漂移。 |
| [Resolving Merge Conflicts](https://github.com/mattpocock/skills/tree/2ab958093e83e0ec752e6c1c5932da465bf23e0c/skills/engineering/resolving-merge-conflicts) | Skill | Git 已处于 merge/rebase 且存在未解决 conflict hunk 时触发；也可显式要求 `$resolving-merge-conflicts`。 | 根据 commit、PR、issue、计划和周边代码恢复双方意图，只处理现有冲突并验证结果；不会自行 continue/abort、commit、push、reset、discard 或 clean。 |

Skill 是可复用工作流，不会扩大当前任务的授权范围。即使某个 Skill 可以修改文件或调用外部工具，commit、push、merge、部署、重建和破坏性 Git 操作仍遵循当前请求及仓库规则。MCP 则提供实时数据或受控动作，并继续受各用户自己的认证和服务端权限约束。

rebuild 后启动一个新的 Codex 会话，再用以下命令核对实际安装状态：

```nu
ls -l ~/.agents/skills | select name target
codex mcp list
codex-improve-exec --help
```

在 Codex TUI 中使用 `/skills` 查看当前会话识别到的 system、user 和 repo Skills，使用 `/plugins` 查看已安装并启用的 plugins。Skill 更新后若当前会话没有识别到，应重新启动 Codex。

### 扩展自己的 Codex 能力

普通用户没有 root 权限也可以扩展自己的 Codex 能力。OpenAI 官方文档对 [AGENTS.md](https://developers.openai.com/codex/guides/agents-md)、[skills](https://developers.openai.com/codex/skills)、[MCP](https://developers.openai.com/codex/mcp) 和 [`config.toml`](https://developers.openai.com/codex/config-basic) 有更完整说明；在 `116` 上要区分个人配置和全员共享配置：

- 项目级指令：在自己的项目仓库放置 `AGENTS.md`。Codex 进入该项目时会读取它，适合记录项目约定、测试命令、代码风格和部署边界。
- 项目或个人 Skill：项目专用 Skill 放到仓库的 `.agents/skills/<skill-name>/SKILL.md`；跨仓库自用的 Skill 放到 `~/.agents/skills/<skill-name>/SKILL.md`，也可以用系统自带的 `$skill-installer` 从 GitHub 安装。之后可通过 `$skill-name` 显式触发；description 与任务匹配时，Codex 也可能隐式触发。避免与全局 Skill 使用相同的 `name`，同名 Skill 不会自动合并。
- 项目 MCP：在受信任仓库的 `.codex/config.toml` 中增加 `[mcp_servers.<name>]`，把只服务该项目的命令和 endpoint 留在项目范围。Codex 不会为 untrusted project 加载这层配置。
- 个人 MCP 试验：`codex mcp` 和 `~/.codex/config.toml` 可以用于临时验证，但 `116` 的用户配置由 Home Manager 生成，下一次 activation 可能覆盖手工改动。需要跨仓库长期保留的个人 MCP，应提交 per-user 声明式配置；不要覆盖系统管理的 `github`、`context7`、`context7_auth` 和 `github@openai-curated`。
- 全员共享能力：如果某个 skill、MCP 或全局指令应该给所有 headless dev 用户使用，应提交 PR 修改 upstream/downstream 声明式配置，再由运维用户 rebuild。

### 用 Improve 审查和改进代码库

`improve` 由 upstream 全局配置提供，并不只面向 `116`。它适合先审查和确认方向，再把完整计划交给隔离 executor 实现；普通用户不需要直接运行内部 helper。

进入目标仓库并启动 Codex：

```nu
cd ~/github.com/<组织>/<仓库>
codex
```

然后直接在 Codex 对话中输入，例如：

```text
$improve standard 检查这个仓库，重点关注正确性、测试和长期维护成本。
```

也可以直接为明确需求写计划：

```text
$improve plan <需求>
```

完整命令、计划的 `READY` / `BLOCKED` 语义、worktree 边界、预定义 agents 和独立复核规则见 [Improve 使用说明](codex-improve.md)。

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

`116` 只为 `ysun` 安装 public Yazelix Nova `main` 的 `yazelix-no-mars`，这是适合 SSH/headless 环境的版本，入口命令是 `yzx enter`。`zky` 和 `wangrongfeng` 不会获得 Yazelix 或通用 Zellij；上游通用 dotfiles 也不安装 Yazelix。

Renovate 每天检查 `yazelix` input，maintenance gate 通过后可以自动合并 PR，但不会 build、rebuild 或部署 `116`。首次迁移需要 root 用 Yazelix Cachix bootstrap 目标 closure；后续更新、回退和运维应用边界见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

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
4. 应用仓库声明的系统配置，再显式重跑 Mihomo bootstrap unit：

   ```nu
   nu --login -c 'maint-switch --no-pull --repo /home/ysun/github.com/sctmes/dotfiles'
   sudo systemctl restart mihomo-config-bootstrap.service
   ```

   `mihomo-config-bootstrap` 是 `RemainAfterExit` 的 oneshot。导入运行配置后，即使目标 generation 没有变化，也要显式重跑该 unit 才能保证执行归一化。
5. 确认归一化结果：`Proxy` 只包含 `WestWorld Auto`；`WestWorld Auto` 每 1800 秒测试一次 `WestWorld` provider 中严格匹配日本的节点，使用 `tolerance: 0` 和 `lazy: false`；`YToo Backup` 代理组已移除；`YToo` provider 保留定义，但不参与路由。
6. 验证配置并重启 Mihomo：

   ```nu
   docker exec mihomo /mihomo -t -d /root/.config/mihomo -f /root/.config/mihomo/config.yaml
   sudo systemctl restart mihomo-compose.service
   ```

   不得使用 `PUT /configs?force=true`。重启会短暂删除并重新创建 `Meta` TUN 接口。
7. 恢复模型文件到 `/var/lib/ai-serving/models`。
8. 检查核心服务：

   ```nu
   systemctl status mihomo-compose.service
   systemctl status cloudflare-ddns-compose.service
   systemctl status caddy.service
   systemctl status label-studio-compose.service
   ```

9. 如需回退 Mihomo 路由策略，按以下顺序操作：

   1. 恢复此前已审核的仓库源码/检查点。
   2. 从该版本运行 `nu --login -c 'maint-switch --no-pull --repo /home/ysun/github.com/sctmes/dotfiles'`。
   3. 将 `/persist/mihomo/config.yaml.before-westworld-japan-policy` 恢复到 `/persist/mihomo/config.yaml`，并保留原 owner、group 和 mode。
   4. 运行 `docker exec mihomo /mihomo -t -d /root/.config/mihomo -f /root/.config/mihomo/config.yaml` 验证配置。
   5. 运行 `sudo systemctl restart mihomo-compose.service`。
   6. 如果固定备份不存在，应先回退仓库源码，再恢复此前已知可用的运行时配置，并按相同顺序验证和重启。

10. 在 `https://label.bigdick.live:2053` 登录 Label Studio 并轮换初始密码。

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
