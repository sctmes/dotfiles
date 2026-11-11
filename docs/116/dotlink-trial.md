# 116 dotlink 接入（现为 unrestricted）

固定版本 v0.14.3，commit `84cd9b7cbda48e327e15781c771e162fb8820ae7`。
本次配置位于独立 worktree，基于已核实的 remote main `475a41285afbbc76945e19e743a39eaa603ce5f6`。用户已创建并通过隐藏终端输入导入 runtime key，SOPS 加密与解密格式检查通过。已创建用户批准的隧道并完成系统切换，服务 enabled/running，日志确认 `Connected — ready`。

## 首轮权限范围（历史）

以现有 `ysun` 运行，但保留 Bubblewrap；只允许 `/home/ysun/dotlink-workspace` 读写、shell 和联网。不提供全根目录、SSH agent、Docker/Nix daemon socket、GPU/KVM、其他用户目录或 `--unrestricted`。这不等同于将 ysun 的 sudo 权限交给远程客户端。后续真实项目可以逐个增加目录或特定功能。

## 凭据与接入

1. 确认 OpenAI Platform organization 与使用该隧道的 ChatGPT workspace。
2. 在 https://platform.openai.com/settings/organization/tunnels 创建或选定专用 116 隧道。CLI 创建路径需要一次性 Tunnels Manage Admin key，以及 workspace ID 或 organization ID；无需让服务长期持有 Admin key。
3. 创建仅有 Tunnels Read + Use 的 runtime API key。通过安全输入或操作者本机秘密录入流程，将其加密写入现有 `secrets/hosts/116.yaml` 的 `dotlink-runtime-api-key`。不要在聊天、命令参数、日志、Nix 配置或 Git 明文中填写密钥。
4. 在模块填入非秘密 tunnel ID。sops-nix 解密到 `/run/secrets`，systemd `LoadCredential` 提供私有副本。服务只持有 runtime key。
5. 审查权限范围、具体 workspace、声明式改动后启用，再按仓库既有 PR/review/运维部署流程执行。已设为 `enable = true` 并部署；当前 unrestricted 状态见文末。
6. 验证服务身份、凭据保护、ChatGPT 端工具调用、断线恢复，再安排服务重启与主机重启验证。首轮 scoped 阶段已验证服务启动与重启；后续 ChatGPT MCP App 注册与端到端读取结果见文末，整机重启仍未验证。

## 持久化与测试

`/home` 已核实为 Btrfs 持久卷；sops 解密钥位于现有 `/persist/var/lib/sops-nix/key.txt`。不把密钥内容写入 Nix store；无需为持久化另设可变明文秘密文件。

已运行真实 stdio MCP 临时目录测试：16 个工具、文本和二进制编辑、路径/符号链接拒绝、bwrap shell、并发编辑、后台作业输出重放/ACK/取消。网络测试显式指定现有可信 CA bundle 后通过 GitHub HTTPS 与 OpenAI 根地址 TLS；OpenAI 根地址返回 421，不代表隧道已认证。Bubblewrap 会清理父进程环境；单设服务 SSL_CERT_FILE 不足以修复沙箱 curl。模块为 curl/git 提供设置可信 CA 路径的包装器，并为 dotlink 主进程设置证书环境；curl 包装器已在真实沙箱验证。

已执行完整构建、维护 gate、dry-activate、系统切换和服务重启。未执行全机重启。

## 安全导入助手

`scripts/enroll-dotlink-key.py` 拒绝非 TTY，使用隐藏输入，将 JSON 字符串只经 stdin 交给 `sops set --value-stdin`，不打印密钥、不写明文文件、不启用服务。已验证语法、非 TTY 拒绝和非秘密 SOPS fixture 往返；现有文件所有者保持不变。

在生成 runtime key 之前准备好交互终端。在仓库根目录使用锁定输入提供 Python：`nix shell --inputs-from . nixpkgs#python3 --command python3 ./scripts/enroll-dotlink-key.py`，不要依赖可能被 GC 清除的固定 store 路径。输入完成后仅加密配置变化；正式部署仍需后续审查和验证。

## 基线核对

116 的普通工作目录停在 detached `57f9224`，不是当前 main。当前 main 已包含 PR #70 的 `SCTMES Trial` 代理及加密密码；该节点在本次只读检查时正被 Proxy 组选中。准备 worktree 已对齐 remote main，不再额外复制或重复声明 trial secret。既有加密文件与 live 源一致，不属于本次清理范围。

## 部署结果（2026-11-10）

- Tunnel: `tunnel_6af2e2f4e8f0819194441ebbe4862fd1`，名称 `dotlink-116-scoped`。
- 仅使用用户批准的 Personal Platform organization 和唯一可选 ChatGPT workspace；UUID 到 Personal 名称的对应是基于账号/唯一选项的推断，用户已明确确认。
- 上游 NixOS module 的 `settings` 将配置放在 Nix store，会触发 shell sandbox 的 protected-path 冲突。当前模块改为在 systemd `ExecStartPre` 将声明式非秘密 profile 复制到 `/run/dotlink/config.jsonc`，目录 0700、文件 0600。当时没有关闭 sandbox；2026-11-11 经用户确认后启用 unrestricted，见文末。
- Key 仍由 SOPS 解密，再经 systemd `LoadCredential` 注入；不在 Nix store 明文、环境变量值或命令参数中保存。
- 系统部署使用标准 `nixos-rebuild switch --sudo --no-reexec --store-path <已构建产物>`，避免 root 独立 Git cache 重复求值取源。
- 服务以 ysun 运行，固定工作目录 `/home/ysun/dotlink-workspace`；boot system profile 已指向部署 generation。
- 服务 restart 成功，首个30秒长轮询后显示 `Connected — ready`。Mihomo 容器未重启，保持原代理选择。
- 首轮实现位于准备 worktree；后续使用未包含本模块的 main 重建会移除服务，需完成源码审查/合入。

## unrestricted 变更（2026-11-11）

用户在明确获知关闭 Bubblewrap、开放全机读写与 shell、以及现有 ysun NOPASSWD sudo 带来的持久 root-equivalent 权限后，确认启用并注册私有 ChatGPT connector。

- `hosts/116/dotlink.nix` 声明式追加 `--unrestricted`，并将 `/run/wrappers`、ysun profile 与 system profile 加入服务 PATH；以 ysun 运行。原 scoped profile 作为未带该参数时的默认值保留，运行时由 CLI 明确覆盖。
- 未创建新凭据或开放新监听端口；仍使用既有 OpenAI Secure MCP Tunnel、SOPS 和 systemd LoadCredential。
- maintenance gate（workflow_dispatch 比较模式）、完整 toplevel 构建和 dry-activate 均通过；dry-activate 仅需重启 dotlink，已通过标准 nixos-rebuild switch 部署。
- 服务日志确认 `Access unrestricted read+write`、`Sandbox disabled` 和 `Connected — ready`。enabled 状态及 boot system profile 已核实；未执行整机重启。
- 独立 stdio MCP 测试返回 16 个工具；bash 在 `/home/ysun` 成功执行 hostname、id、`sudo -n id -u`（返回 0）及 `/data1` 目录存在检查，结果 `sandboxed=false`。测试没有读取秘密文件。
- Mihomo 容器 StartedAt 在部署前后均为 `2026-10-29T05:45:46.444499719Z`，未被重启或修改。
- 私有 ChatGPT plugin `dotlink 116 (unrestricted)` 已注册并连接，UI 确认 connected，发现全部 16 个工具（9 write / 7 read）。Plugin ID: `plugin_asdk_app_6af3ba46da388191a1caf72d6ea4a6f5`。父会话已通过新 connector 成功读取 `/home/ysun/dotlink-workspace/dotlink-e2e-gz9uqey2/read-check.txt`，确认端到端读取；ChatGPT 端到端 shell 命令待独立核实，本地 stdio 测试不等同于该验证。
- 改动保存在本地功能分支；尚未 push/合入 main。之后从未包含此改动的 main rebuild 会移除此服务，发布 PR 和合并需另行确认。
