# 贡献说明

本仓库管理共享基础设施。所有改动都按运维变更处理，不按个人 dotfiles
小改动处理。

## 依赖和服务变更

如果需要在 `116` 上新增系统依赖或服务变更：

1. 向本仓库提交 PR。
2. 说明用户需求，以及具体要改的包、服务或配置。
3. 等待 `ysun` review。
4. 通过后由 `ysun` 执行 rebuild、服务重启或重装。

不要在机器上手工安装长期依赖并假设它们会在 rebuild 后保留。

日常维护、rebuild 和重装说明见 [docs/116/README.md](./docs/116/README.md)。

## 安装和 rebuild 责任

- 当前模型中只有 `ysun` 是运维用户。
- `ysun` 负责：
  - secret 管理
  - `nixos-anywhere` 重装
  - 系统 rebuild
  - 生产服务重启
- `zky` 和 `wangrongfeng` 是可信研究用户，有 Docker 权限，没有 sudo。

## 116 主机约定

- 系统 SSD 是声明式管理的，可以被完整重建。
- `/data1` 是保留的慢速备份盘，不是 Docker 或模型服务运行目录。
- 重装时系统 SSD 上的旧 `/home` 不保证保留。
- 声明式用户会在重装后重建，但个人数据仍需要单独备份或迁移。
