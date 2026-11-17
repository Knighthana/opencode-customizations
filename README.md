# OpenCode Customizations

可分享、可复用的 OpenCode 自定义集合。按**作用的客户端**分目录，而不是按实现语言
分；每个条目都带安装、自检和（可自动化时）行为测试，目标是升级后能快速确认
是否还兼容。

本仓库与“本机 OpenCode 改动审计”是分开的：个人机器的配置、试验和踩坑记录留在
本地私有仓库，不推到远程；这里只放整理过、可以交付的内容。

## 目标分类

| 目录 | 作用对象 | 当前条目 |
| --- | --- | --- |
| [`desktop/shared/`](desktop/shared/README.md) | OpenCode Desktop，Windows/macOS/Linux 通用 | `enter-newline` |
| [`desktop/windows/`](desktop/windows/README.md) | Desktop，Windows 专属 | 暂无 |
| [`desktop/macos/`](desktop/macos/README.md) | Desktop，macOS 专属 | 暂无 |
| [`desktop/linux/`](desktop/linux/README.md) | Desktop，Linux 专属 | 暂无 |
| [`cli-tui/`](cli-tui/README.md) | CLI / TUI | 暂无 |
| [`mobile/`](mobile/README.md) | Mobile / 窄屏客户端 | 暂无 |
| [`web/`](web/README.md) | OpenCode Web UI | 暂无 |

判断规则、目录形状和新增条目 checklist 见
[`docs/targets.md`](docs/targets.md)。

## 条目

| 条目 | 目标 | 作用 |
| --- | --- | --- |
| [`enter-newline`](desktop/shared/plugins/enter-newline/README.md) | Desktop / shared | `Enter` 换行、`Ctrl+Enter` 发送、`Shift+Enter` 换行 |

## 快速开始

```powershell
# 安装 enter-newline
pwsh -File .\desktop\shared\plugins\enter-newline\install.ps1

# 让 Desktop 重新加载：先在窗口里按 Ctrl+R；没变化就重启 Desktop

# 自检（含 Desktop app.asar 的内部标记）
pwsh -File .\desktop\shared\plugins\enter-newline\verify.ps1 -Deep

# 行为测试（无头 Chrome/Edge）
pwsh -File .\desktop\shared\plugins\enter-newline\tests\test.ps1
```

## 仓库结构

```
opencode-customizations/
├─ desktop/
│  ├─ shared/
│  │  ├─ README.md
│  │  └─ plugins/
│  │     └─ enter-newline/
│  │        ├─ gui-experimental.cjs
│  │        ├─ install.ps1
│  │        ├─ verify.ps1
│  │        ├─ README.md
│  │        └─ tests/
│  ├─ windows/README.md
│  ├─ macos/README.md
│  ├─ linux/README.md
│  └─ README.md
├─ cli-tui/README.md
├─ mobile/README.md
├─ web/README.md
├─ docs/
│  ├─ compatibility.md
│  ├─ desktop-internals.md
│  └─ targets.md
├─ CHANGELOG.md
├─ LICENSE
└─ README.md
```

## 设计约定

- 一个条目自包含：`README.md`、`install.*`、`verify.*`、`tests/`、payload 都在
  同一目录；
- Desktop 条目优先放 `desktop/shared/`；确实只属于某个 OS 的，才放
  `desktop/windows|macos|linux/`；
- 同一功能不按 OS 复制三份，平台差异写进条目 README 的支持表；
- `install` 只合并必要配置并备份原文件；
- `verify` 至少检查文件、配置、服务端/客户端加载；依赖 App 内部结构的再加
  `-Deep` 检查；
- 在目标目录 README 和根 README 的表格里登记新条目；
- 在 `docs/compatibility.md` 记录验证过的版本。

## 兼容性

当前验证环境：**OpenCode Desktop 2.3.0 / opencode CLI 2.3.0（Windows）**。

Desktop 的 GUI 插件 API（`@opencode/plugin/gui`）目前是 experimental；依赖
`app.asar` 内部 DOM 标记的插件会随 Desktop 升级而变化。升级后请跑对应条目的
`verify.ps1 -Deep`。

详见 [`docs/compatibility.md`](docs/compatibility.md) 和
[`docs/desktop-internals.md`](docs/desktop-internals.md)。

## License

MIT，见 [LICENSE](LICENSE)。
