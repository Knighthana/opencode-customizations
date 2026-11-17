# OpenCode Customizations

可分享、可复用的 OpenCode / OpenCode Desktop 自定义集合。每个条目都带安装脚本、
自检和（可自动化时）行为测试，目标是升级 Desktop 后能快速确认是否还兼容。

本仓库与“本机 OpenCode 改动审计”是分开的：个人机器的配置、试验和踩坑记录留在
本地私有仓库，不推到远程；这里只放整理过、可以交付的内容。

## 目录

| 自定义 | 作用 | 入口 |
| --- | --- | --- |
| [`enter-newline`](plugins/enter-newline/README.md) | `Enter` 换行、`Ctrl+Enter` 发送、`Shift+Enter` 换行 | [`plugins/enter-newline`](plugins/enter-newline/) |

## 快速开始

```powershell
# 安装 enter-newline
pwsh -File .\plugins\enter-newline\install.ps1

# 让 Desktop 重新加载：先在窗口里按 Ctrl+R；没变化就重启 Desktop

# 自检（含 Desktop app.asar 的内部标记）
pwsh -File .\plugins\enter-newline\verify.ps1 -Deep

# 行为测试（无头 Chrome/Edge）
pwsh -File .\tests\enter-newline\test.ps1
```

## 仓库结构

```
opencode-customizations/
├─ plugins/
│  └─ enter-newline/
│     ├─ gui-experimental.cjs   插件本体
│     ├─ install.ps1            安装/卸载
│     ├─ verify.ps1             安装 + 兼容性自检
│     └─ README.md
├─ tests/
│  └─ enter-newline/
│     ├─ harness.html
│     └─ test.ps1
├─ docs/
│  ├─ compatibility.md          Desktop 版本兼容矩阵
│  └─ desktop-internals.md      本次调查到的 Desktop 内部结构/调试方法
├─ CHANGELOG.md
├─ LICENSE
└─ README.md
```

## 设计约定

新增一个自定义时，尽量保持同样的形状：

- `plugins/<id>/` 目录名就是 OpenCode 插件 id（GUI 插件没有单独的 id 字段）；
- 安装脚本只做“合并全局配置 + 备份 + 可卸载”，不覆盖用户其他设置；
- `verify.ps1` 至少检查：文件存在、配置指向、服务端能加载；
  依赖 App 内部结构的再加 `-Deep` 检查；
- 能自动测试的行为放进 `tests/<id>/`，不要求 Node/npm；
- 在 `docs/compatibility.md` 记录验证过的 Desktop 版本；
- 在根 `README.md` 的表格里加一行。

## 兼容性

当前验证环境：**OpenCode Desktop 2.3.0 / opencode CLI 2.3.0**。

Desktop 的 GUI 插件 API（`@opencode/plugin/gui`）目前是 experimental；依赖
`app.asar` 内部 DOM 标记的插件会随 Desktop 升级而变化。升级后请跑对应条目的
`verify.ps1 -Deep`。

详见 [`docs/compatibility.md`](docs/compatibility.md) 和
[`docs/desktop-internals.md`](docs/desktop-internals.md)。

## License

MIT，见 [LICENSE](LICENSE)。
