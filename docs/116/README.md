# 116 服务器说明

`116` 是一台 headless GPU 服务器，由本仓库通过 NixOS 管理。

## headless 开发环境

所有 headless dev 用户都继承 upstream 的 headless 开发工具集，包括 `gh`、Codex、Nushell、Helix、Yazi、ripgrep，以及下列 Codex 全局能力：

| 名称 | 类型 | 触发条件 | 功能 |
| --- | --- | --- | --- |
| [全局 `AGENTS.md`](https://github.com/bioinformatist/dotfiles/blob/main/home/programs/codex/default.nix) | 全局指令 | Codex 启动后自动读取生成的 `~/.codex/AGENTS.md`。 | 补充跨仓库工作偏好：采用最小但完整的改动、让建议和术语解释具备充分上下文、遵循 Git/Nix 约定，并执行 Context7 fallback 与 per-user secret routing 等通用 capability routing。 |
| [GitHub MCP](https://github.com/github/github-mcp-server) | MCP | Codex 注册 `github` MCP；处理 GitHub repo、issue、PR、review、CI 相关任务时调用。 | 通过用户自己的 GitHub token 访问 GitHub context、issues、pull requests、repos、users 和 orgs。token 配置见下方“GitHub 认证”。 |
| [GitHub curated plugin](https://github.com/openai/plugins/tree/main/plugins/github) | Skill plugin | Codex 启用 `github@openai-curated`；处理 GitHub issue、PR、review、CI 或发布本地改动时可能触发。 | 在 GitHub MCP 之上提供更高层工作流 skills，例如处理 PR review comments、修复 GitHub Actions CI、梳理 repo/issue/PR 上下文和发布本地修改。 |
| [Context7 MCP](https://github.com/upstash/context7) | MCP | Codex 注册匿名 `context7` MCP；涉及库、框架、SDK、API、CLI 或云服务当前文档时使用。 | 默认先用匿名 Context7 拉取较新的项目文档；登记了个人 API key 的用户还会得到 `context7_auth` fallback，匿名额度不可用时再使用自己的认证额度。 |
| [`improve`](https://github.com/shadcn/improve/tree/03369ee6d7cafbfcecc4346539b05b3dc0a603bb/skills/improve) | Skill + executor | 想系统检查一个代码库、找出值得修复的问题、制定计划并逐项实施时，在 Codex 对话中使用 `$improve`。 | 先只读审查并把选中的问题写成计划，再让独立 executor 在隔离目录中改代码，最后由当前 Codex 会话复核。适合“不知道该从哪里开始优化”或“希望先审查、确认方案，再动代码”的场景。 |
| [Playwright CLI skill](https://github.com/microsoft/playwright-cli/tree/v0.1.14/skills/playwright-cli) | Skill | 浏览器自动化、页面预览、截图、交互验证或 Playwright 相关任务；也可显式要求 `$playwright-cli`。 | 用 Playwright 驱动浏览器，验证 headless web UI、页面状态、截图和交互行为。 |
| [stop-slop](https://github.com/hardikpandya/stop-slop/tree/8da1f030185bdfe8471220585162991eaeb970e9) | Skill | 英文 PR、issue、release notes、README/docs、公评文本等 publishable prose 的最终润色；也可显式要求 `$stop-slop`。 | 在不改技术事实、命令、日志、标识符和有用不确定性的前提下，去掉公式化 AI 文风。 |
| [Ponytail Review](https://github.com/DietrichGebert/ponytail/tree/v4.8.3/skills/ponytail-review) | Skill | 用户明确要求 over-engineering review、simplify review、what can we delete，或显式 `$ponytail-review`。 | 只审复杂度：指出可删除的 speculative abstraction、重复造轮子、无用依赖和死弹性。 |
| [Ponytail Audit](https://github.com/DietrichGebert/ponytail/tree/v4.8.3/skills/ponytail-audit) | Skill | 用户明确要求全仓库 over-engineering audit、find bloat、what can I delete，或显式 `$ponytail-audit`。 | 对整个 repo 做复杂度审计，输出按优先级排序的删除、简化和 stdlib/native 替代建议。 |
| [Ponytail Debt](https://github.com/DietrichGebert/ponytail/tree/v4.8.3/skills/ponytail-debt) | Skill | 用户明确要求 ponytail debt、列出 `ponytail:` 注释，或显式 `$ponytail-debt`。 | 汇总代码中有意留下的 `ponytail:` 延后事项，避免临时取舍失去上下文。 |
| [Diagnosing Bugs](https://github.com/mattpocock/skills/tree/v1.0.1/skills/engineering/diagnosing-bugs) | Skill | 遇到具体 bug、回归、flaky failure 或原因不明的性能问题；也可显式要求 `$diagnosing-bugs`。 | 用紧反馈循环建立复现、区分事实和假设、逐步缩小根因，不把普通实现任务误当调试流程。 |
| [TDD](https://github.com/mattpocock/skills/tree/v1.0.1/skills/engineering/tdd) | Skill | 用户要求 test-first、先写回归测试再修 bug，或显式要求 `$tdd`。 | 通过 red-green-refactor 和面向行为的测试推进改动，优先经公开接口验证行为。 |
| [Codebase Design](https://github.com/mattpocock/skills/tree/v1.0.1/skills/engineering/codebase-design) | Skill | 设计或调整模块边界、接口深度、seam、adapter、可测试性时；也可显式要求 `$codebase-design`。 | 提供深模块、接口、seam、locality 等架构词汇，用于评估模块边界是否值得调整。 |
| [Grilling](https://github.com/mattpocock/skills/tree/v1.0.1/skills/productivity/grilling) | Skill | 用户明确要求 grill、interrogate、stress-test plan，或显式要求 `$grilling`。 | 在实现前逐问 stress-test 计划或设计，帮助暴露隐含假设和弱论证。 |

### 扩展自己的 Codex 能力

普通用户没有 root 权限也可以扩展自己的 Codex 能力。OpenAI 官方文档对 [AGENTS.md](https://developers.openai.com/codex/guides/agents-md)、[skills](https://developers.openai.com/codex/skills)、[MCP](https://developers.openai.com/codex/mcp) 和 [`config.toml`](https://developers.openai.com/codex/config-basic) 有更完整说明；在 `116` 上要区分个人配置和全员共享配置：

- 项目级指令：在自己的项目仓库放置 `AGENTS.md`。Codex 进入该项目时会读取它，适合记录项目约定、测试命令、代码风格和部署边界。
- 个人 skill：把 skill 放到 `~/.agents/skills/<skill-name>/SKILL.md`，或在 Codex 中使用系统自带的 `$skill-installer` 从 GitHub 安装。之后可通过 `$skill-name` 显式触发；description 写得足够明确时，Codex 也可能按任务自动触发。
- 个人 MCP：用 `codex mcp` 添加，或在 `~/.codex/config.toml` 里新增自己的 `[mcp_servers.<name>]`。命令可以指向用户 home、项目目录或用户可执行的 Nix profile。不要覆盖系统管理的 `github`、`context7` 和 `github@openai-curated` 配置；下一次 Home Manager activation 会继续维护这些 managed keys。
- 全员共享能力：如果某个 skill、MCP 或全局指令应该给所有 headless dev 用户使用，应提交 PR 修改 upstream/downstream 声明式配置，再由运维用户 rebuild。

### 用 Improve 审查和改进代码库

`improve` 适合把一次范围较大的代码改进拆成“审查、确认、计划、执行、复核”几个阶段。它不会在发现问题后立刻改代码：当前 Codex 会话先作为 advisor（顾问）阅读仓库、解释问题和影响，等用户选定要处理的事项后才写计划。

第一次使用时，先进入目标仓库并启动 Codex：

```nu
cd ~/github.com/<组织>/<仓库>
codex
```

然后直接在 Codex 对话中输入，例如：

```text
$improve standard 检查这个仓库，重点关注正确性、测试和长期维护成本。
```

常用方式：

| 对话写法 | 用途 |
| --- | --- |
| `$improve quick 检查这个仓库` | 快速查看高风险区域，适合先了解项目现状。 |
| `$improve standard 检查这个仓库` | 审查主要模块和常见工程问题；大多数情况从这里开始。 |
| `$improve deep 检查整个仓库` | 更完整的全仓库审查，耗时和 token 消耗更高。 |
| `$improve security` | 只关注安全问题。也可以换成 `tests`、`perf` 等具体方向。 |
| `$improve branch` | 只审查当前分支相对默认分支引入的变化。 |
| `$improve plan <需求>` | 不做全仓库审查，只为一个明确需求写实施计划。 |
| `$improve review-plan plans/NNN-name.md` | 检查并补全已有计划。 |
| `$improve execute plans/NNN-name.md` | 在独立工作目录中执行计划，并把结果交回当前会话复核。 |
| `$improve reconcile` | 检查已有计划哪些已完成、受阻或需要更新。 |

一次完整流程通常是：

```text
你与当前 Codex 会话讨论目标
  -> advisor 只读审查并给出候选问题
  -> 你选择要处理的问题
  -> advisor 在 plans/ 中写出实施计划
  -> executor 在独立 worktree 中修改和验证
  -> 当前 Codex 会话检查完整 diff 和验证结果
  -> 你决定接受、要求修改或放弃
```

worktree 是同一个 Git 仓库的独立工作目录。executor 在这里工作，不会直接改动你启动 Codex 时所在的目录。它从当前 Git 提交（`HEAD`）开始，因此主目录中尚未提交的修改不会自动带入；执行计划前应先确认需要的基础改动已经提交。executor 也不会自行提交、合并、推送或创建 PR；只有当前 Codex 会话复核完成并得到你的批准后，才会继续处理结果。

#### 预定义的 Improve agents

这里的 agent 实际上是预先设置好的 Codex profile：每个 profile 固定了模型、reasoning effort、读写权限和是否允许继续派生 agent。普通用户不需要手动选择，大多数情况下由 `$improve` 工作流自动调用。

| Agent / profile | 模型与 effort | 权限 | 负责什么 |
| --- | --- | --- | --- |
| 当前 Codex 会话（advisor） | 沿用当前会话设置 | 审查阶段只读；只写 `plans/` | 理解仓库、筛选问题、与用户确认方向、写计划，并在执行后做最终验收。调用 `$improve` 不会更改当前会话的模型或 effort。 |
| `improve-scout` | `gpt-5.6-luna` + `high` | 只读 | 在较大的审查中分区查看代码并返回候选问题。它只提供线索，advisor 还会重新核实，不会直接写计划或改代码。 |
| `improve-executor` | `gpt-5.6-sol` + `medium` | 仅可写独立 worktree | 默认执行器。按照已确认的计划修改代码、运行测试并留下未提交 diff，适合边界清楚的大多数任务。 |
| `improve-executor-deep` | `gpt-5.6-sol` + `xhigh` | 仅可写独立 worktree | 用于技术不确定性高、跨模块或需要更深入推理的计划。它更慢、token 消耗更高，不作为默认选择。 |
| `improve-reviewer` | `gpt-5.6-sol` + `high` | 只读 | 对重要或存在争议的 executor 结果做独立复核，重点检查计划是否真正完成、diff 是否越界、测试是否有意义。 |

`codex-improve-exec` 是工作流内部使用的 helper：它负责创建临时 branch/worktree，并启动普通或 deep executor。普通用户通常只需要在对话中使用 `$improve execute <计划文件>`，不必直接运行这个 helper。

本机安装的是针对 Codex 调整后的版本；表格中的链接指向原始 `shadcn/improve` skill。共享 skill、profiles 和 helper 均由 Nix/Home Manager 管理，不要在 `116` 上手工复制或修改生成文件。

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

### Yazelix Next

`116` 只为 `ysun` 安装实验中的 Yazelix Next，入口命令是 `yzn`。上游通用 dotfiles 不安装 Yazelix；等 `yzn` 更稳定后，再决定是否提升为所有机器的声明式配置。

更新 `yzn` 时只更新 `yazelix-next` flake input；具体流程见 [CONTRIBUTING.md](../../CONTRIBUTING.md)。`yazelix-next` 目前是私有仓库，执行更新的用户需要有对应 GitHub SSH 读取权限。

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
