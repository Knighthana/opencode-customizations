# Changelog

## 1.0.0 — 2026-11-18

- 首个可交付版本。
- `Enter` 插入换行，`Ctrl/Cmd+Enter` 发送，`Shift+Enter` 保持换行。
- 保留补全列表、历史记录、斜杠命令、输入法组词和 `Alt+Enter` 的原有行为。
- 提供 `install.ps1`（合并全局配置、备份、卸载）和 `verify.ps1`
  （安装状态与 `-Deep` 兼容性自检）。
- 提供无头 Chromium 行为测试 `tests/test.ps1`。
- 在 OpenCode Desktop 2.3.0（opencode CLI 2.3.0）上验证通过。
