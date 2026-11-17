# Changelog

## Unreleased — 2026-11-18

- 仓库重定义为 `opencode-customizations`：用于收集可分享、可交付的 OpenCode /
  OpenCode Desktop 自定义，而不是只服务单个插件。
- `enter-newline` 移动到 `plugins/enter-newline/`，插件 id 保持
  `enter-newline`。
- 安装/自检脚本跟着插件走：`plugins/enter-newline/install.ps1`、
  `plugins/enter-newline/verify.ps1`。
- 测试移动到 `tests/enter-newline/`。
- 新增 `docs/compatibility.md`（Desktop 版本矩阵、升级流程）和
  `docs/desktop-internals.md`（app.asar、GUI 插件加载、composer DOM、
  设置存储等调查笔记）。

## enter-newline 1.0.0 — 2026-11-18

- 首个可交付版本。
- `Enter` 插入换行，`Ctrl/Cmd+Enter` 发送，`Shift+Enter` 保持换行。
- 保留补全列表、历史记录、斜杠命令、输入法组词和 `Alt+Enter` 的原有行为。
- 提供 `install.ps1`（合并全局配置、备份、卸载）和 `verify.ps1`
  （安装状态与 `-Deep` 兼容性自检）。
- 提供无头 Chromium 行为测试。
- 在 OpenCode Desktop 2.3.0（opencode CLI 2.3.0）上验证通过。
