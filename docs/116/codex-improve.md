# Improve 使用说明

`improve` 是由 upstream 全局 Codex 配置提供的代码库审查和实施工作流。它适用于所有继承该配置的机器和用户；本文放在 `116` 文档目录，是为了给这台服务器的开发用户提供使用入口，并不表示 Improve 只面向某台主机或某个仓库。

## 适用场景

当你希望先弄清问题和方案，再让 Codex 修改代码时使用 Improve。它把工作分成 advisor 审查与规划、隔离 executor 实现、主会话实现审查、按风险触发的独立复核，以及必要时交给用户或外部系统完成的实际验收。调用 `$improve` 不会改变当前 Codex 会话使用的模型或 reasoning effort。

进入目标仓库并启动 Codex：

```nu
cd ~/github.com/<组织>/<仓库>
codex
```

大多数代码库审查从下面的命令开始：

```text
$improve standard 检查这个仓库，重点关注正确性、测试和长期维护成本。
```

## 常用命令

| 对话写法 | 用途 |
| --- | --- |
| `$improve quick 检查这个仓库` | 快速查看高风险区域，适合先了解项目现状。 |
| `$improve standard 检查这个仓库` | 审查主要模块和常见工程问题；大多数情况从这里开始。 |
| `$improve deep 检查整个仓库` | 更完整的全仓库审查，耗时和 token 消耗更高。 |
| `$improve security` | 只关注安全问题；也可以换成 `tests`、`perf` 等方向。 |
| `$improve branch` | 只审查当前分支相对默认分支引入的变化。 |
| `$improve plan <需求>` | 不做全仓库审查，只为一个明确需求写实施计划。 |
| `$improve review-plan <计划文件>` | 重新核实并补全已有计划，直到得到 `READY` 或 `BLOCKED`。 |
| `$improve execute <计划文件>` | 在独立 worktree 中执行计划，并把结果交回当前会话验收。 |
| `$improve reconcile` | 检查已有计划哪些已完成、受阻或需要更新。 |

计划文件的位置遵循目标仓库自己的约定。仓库没有明确约定时，计划默认只在本地保存；Improve 不会自行修改 `.gitignore`，也不会擅自发布计划。

## 计划怎样达到执行标准

advisor 不会把第一版草稿直接交给 executor。`plan` 和 `review-plan` 会在内部依次检查覆盖范围、零上下文可执行性、逻辑和 elegance，直到得到以下结果之一：

- `READY`：计划完整、自洽，并能在记录的代码基线上执行。
- `BLOCKED`：缺少会改变实现方向的用户决策、必要权限、外部前提或证据；advisor 会说明具体缺什么。

能通过只读调查解决的计划缺陷由 advisor 自行修正，不需要用户重复要求“再检查一次”。

计划使用 Semantic anchors（语义锚点）保存用户决定、仓库事实、advisor 推导、待验证假设和明确放弃的方案。它还会分别列出：

- executor 可以修改的完整路径范围；
- 只能读取、用于确认事实或基线漂移的 evidence/drift paths；
- 目标行为、约束、依赖、验证、回滚、停止条件和验收标准；
- Engineering contract（仓库已有的 build、test、lint、CI、policy、classifier、兼容性、发布和部署等工程约束）及其影响。

每项检查还会被明确分为三类：

- implementation gate：Codex 可以通过测试、构建、浏览器、截图、日志、指标或模拟器验证的检查，必须在实现获批前完成；
- deferred acceptance：当前环境确实无法完成的实体机、人工判断或外部系统验收；
- observation：合并后的长期观察项，除非计划写明失败阈值和状态变化，否则不阻塞当前改动。

这些内容必须足以让没有历史对话的新 executor 执行。发生上下文压缩、会话恢复或中断后，计划和仓库证据才是任务语义来源，聊天摘要只用于定位。

如果实现需要改变仓库既有的 CI、测试政策、门控规则、发布策略或兼容边界，advisor 必须解释影响并以 `BLOCKED` 等待批准，不能把这类变化作为附带修改自动纳入范围。

## 隔离执行

`$improve execute <计划文件>` 会从当前 Git `HEAD` 创建独立 branch 和 worktree。worktree 是同一个 Git 仓库的独立工作目录，executor 只能在其中修改计划允许的路径。

主目录中尚未提交的修改不会自动进入 worktree，因此执行前应确认 executor 需要的基础改动已经提交。executor 会运行计划规定的检查并留下未提交 diff，但不会自行提交、合并、推送或创建 PR。worktree 保存在 `$XDG_STATE_HOME/codex-improve/worktrees`，未设置该变量时使用 `~/.local/state/codex-improve/worktrees`；会话中断或机器重启后仍可从输出的路径继续。

## 外部实践与独立复核

外部生态惯例确实会影响结构选择时，advisor 先核实官方文档、标准、ADR、RFC、迁移指南、release notes 或开发团队的明确解释。只有一手社区证据仍可能改变判断时，才会让一个只读 scout 围绕一个明确问题检索维护者讨论、故障报告、公开基准或生产经验。scout 不做最终裁决，关键结论仍由当前会话核实。

executor 完成后，当前会话先检查完整 diff、验证结果和 Engineering contract。独立 reviewer 按风险触发，而不是每个小改动都机械运行：

- 行为重要或存在歧义时，correctness reviewer 检查正确性、安全、回归、测试以及计划是否落实。
- 引入抽象、模块、公开接口、依赖、兼容层、跨所有者边界、复杂生命周期、并发或安全逻辑时，elegance reviewer 检查复用、抽象必要性、模块边界、locality、speculative flexibility 和可删除代码。

reviewer 接收一份不依赖聊天记录的完整 evidence dossier（证据包），并输出结构化 verdict。当前主会话只运行一次 Ponytail 复杂度检查，并把原始建议及采纳或拒绝理由放入证据包；elegance reviewer 复核这些证据，不会再次调用 Ponytail。Ponytail 建议只是待验证假设，不能为了减少代码而破坏正确性、用户决定、仓库规则或必要测试。

review 有分阶段收敛规则和最终运行保护，但具体 token 与时间阈值仍在观察，不是稳定的用户承诺。reviewer 不会自动重试；无法形成可靠结论时返回 `INCONCLUSIVE`，需要用户批准后才能重试或改变计划。事件日志、结构化结果和诊断文件保存在 `$XDG_STATE_HOME/codex-improve/reviews`，未设置该变量时使用 `~/.local/state/codex-improve/reviews`。

## 实现审查与实际验收

Improve 分开记录三件事，避免把“代码已经正确实现”和“用户已经在真实环境确认”混成同一个结论：

- Implementation review：实现仍待审查、已经批准、需要修改或被阻断；
- Checkpoint：当前改动还没有恢复点、已有可恢复目标，或已经集成；
- External acceptance：不需要外部验收、等待验收、已经通过或已经失败。

独立 reviewer 只判断实现和 agent 可获得的证据。需要观察实体机 UI、操作真实硬件或等待外部系统时，尚未执行的验收不会让一个正确实现被判为 `BLOCK`。主会话会先完成所有 implementation gates，再准备一个精确 checkpoint，例如持久 worktree 与 diff、commit、branch、PR 或 deployment ID。涉及 commit、push、部署或合并时，仍会先按仓库规则请求批准。

只有实现已批准、checkpoint 可以恢复，而且验收已经可以针对该目标执行时，计划才进入 `ACCEPTANCE PENDING`。此时可以退出终端、切换机器或稍后再回复；下一次对话会从计划和 checkpoint 恢复，而不是依赖聊天记忆。验收失败若证明实现有缺陷，任务回到实现阶段；如果只是代理、网络或其他无关环境故障，则保留待验收状态并记录证据。

## 完整流程

```text
你与当前 Codex 会话讨论目标
  -> advisor 只读审查并给出候选问题
  -> 你确认要处理的方向
  -> advisor 将计划收敛为 READY 或 BLOCKED
  -> executor 在独立 worktree 中修改和验证
  -> 当前会话核对完整 diff 与 Engineering contract
  -> 按风险触发 correctness / elegance 独立复核
  -> 当前会话验证 reviewer 结论并给出实现审查结果
  -> 若无需外部验收，你决定是否集成
  -> 若需要实体机、人工或外部验收，先准备可恢复 checkpoint
  -> 你针对该 checkpoint 验收并反馈，记录结果并在集成后进入 DONE
```

## 预定义 agents

这里的 agent 是预先设置好的 Codex profile。每个 profile 固定模型、reasoning effort、读写权限和是否允许继续派生 agent。普通用户不需要手动选择，Improve 会根据工作阶段和风险自动调用。

| Agent / profile | 模型与 effort | 权限 | 负责什么 |
| --- | --- | --- | --- |
| 当前 Codex 会话（advisor） | 沿用当前会话设置 | 审查和规划阶段不修改源代码；只写计划 artifact（通常是 Markdown 计划文件） | 理解仓库、筛选问题、与用户确认方向、收敛计划，并在执行后负责实现审查与外部验收交接。 |
| `improve-scout` | `gpt-5.6-luna` + `high` | 只读 | 在大型审查中分区寻找候选问题；必要时围绕明确的外部实践问题收集一手社区证据。它只提供线索，不修改代码或作最终裁决。 |
| `improve-executor` | `gpt-5.6-sol` + `medium` | 仅可写独立 worktree | 默认执行器；按照 `READY` 计划修改代码、运行检查并留下未提交 diff。 |
| `improve-executor-deep` | `gpt-5.6-sol` + `xhigh` | 仅可写独立 worktree | 处理技术不确定性高、跨模块或需要更深入推理的计划；更慢且 token 消耗更高，不作为默认选择。 |
| `improve-reviewer` | `gpt-5.6-sol` + `high` | 只读 | 独立检查 correctness、安全、回归、测试以及计划和 Engineering contract 是否落实。 |
| `improve-elegance-reviewer` | `gpt-5.6-sol` + `high` | 只读 | 独立检查实现是否引入不必要复杂度、抽象、兼容层或 speculative flexibility。 |

## 内部 helpers

Improve 会在内部使用两个命令：

- `codex-improve-exec` 创建持久 branch/worktree，并启动普通或 deep executor。
- `codex-improve-review` 用对应的只读 profile 运行 correctness 或 elegance review，保存结构化结果和诊断信息。

普通用户通常不需要直接调用它们，只需在 Codex 对话中使用 `$improve ...`。
