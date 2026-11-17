# Targets

这个仓库按“定制作用的客户端”分目录，而不是按实现语言或文件类型分。

## 目录

| 目录 | 作用对象 | 说明 |
| --- | --- | --- |
| `desktop/shared/` | OpenCode Desktop，全平台 | Windows / macOS / Linux 行为一致的定制 |
| `desktop/windows/` | OpenCode Desktop，Windows | 依赖 Windows 路径/API/安装方式 |
| `desktop/macos/` | OpenCode Desktop，macOS | 依赖 macOS 路径/API/安装方式 |
| `desktop/linux/` | OpenCode Desktop，Linux | 依赖 Linux 路径/API/安装方式 |
| `cli-tui/` | CLI / TUI | `cli.json`、TUI 主题/键位/插件 |
| `mobile/` | Mobile / 窄屏客户端 | 独立验证，不假设 Desktop DOM/快捷键 |
| `web/` | OpenCode Web UI | 浏览器标签页，`ctx.app.platform === "web"` |
| `docs/` | 全仓库 | 兼容矩阵、调查笔记、本文件 |
| `shared/`（按需创建） | 多客户端共用 | 例如服务端插件、跨端脚本；创建时写 README 说明 |

## 判断规则

1. **先看作用对象，不看代码位置。**  
   一个 GUI 插件即使有 server 部分，只要用户是在 Desktop 里使用，就放 `desktop/`；
   纯 TUI 插件放 `cli-tui/`。
2. **Desktop 优先放 `shared/`。**  
   只有当路径、安装方式、系统 API 或行为确实只属于某个 OS 时才分到
   `desktop/windows|macos|linux/`。
3. **同一功能不要按 OS 复制三份。**  
   平台差异写进条目 README 的支持表；确需不同实现时再拆。
4. **Mobile 和 Web 不继承 Desktop 的假设。**  
   即使渲染层相同，也要单独验证输入方式、安装路径和可用 API。
5. **条目自包含。**  
   `install`、`verify`、`tests`、`README` 都放在条目目录里，不在仓库根目录建平行树。

## 条目形状

```
<target>[/<os>]/plugins/<id>/
├─ README.md
├─ install.*
├─ verify.*
├─ tests/
└─ <payload>
```

目录名 `<id>` 对 GUI 插件来说就是插件 id。

## 新增条目 checklist

- [ ] 选对 target 目录（Desktop 先考虑 `shared`）。
- [ ] 条目 README 写明：作用、平台支持、安装、卸载、限制。
- [ ] `install` 只合并必要配置，并备份原文件。
- [ ] `verify` 至少检查：文件存在、配置指向、服务端/客户端能加载。
- [ ] 能自动测试的行为放进 `tests/`。
- [ ] 在目标目录的 README 和根 README 的表格里登记。
- [ ] 在 `docs/compatibility.md` 记录验证过的版本。
