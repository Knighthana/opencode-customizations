# Changelog

## Unreleased — 2026-11-18

### net-proxy

- 新增 `desktop/shared/plugins/net-proxy`：输入框上方的代理开关，切换服务进程的
  `HTTP(S)_PROXY`，没有守护进程、端口或开机启动项。
- 服务端插件与 GUI 插件通过 RPC 通信；GUI 只负责显示和切换，环境变量、状态文件与
  上游探测都在服务进程内完成。
- 切换为 `proxy` 前探测上游，不可达时按直连运行；运行中不复检。
- 多个 location 共享一份插件实例（引用计数），状态变化通过 RPC 事件推送，无轮询。
- 提供 `install.ps1`、`verify.ps1`（含 `-Deep` 结构检查）和命令行开关
  `net-proxy.ps1`。

- 仓库重定义为 `opencode-customizations`：用于收集可分享、可复用的 OpenCode /
  OpenCode Desktop 自定义，而不是只服务单个插件。
- 按作用对象分目录：`desktop/shared`、`desktop/windows|macos|linux`、
  `cli-tui`、`mobile`、`web`；规则见 `docs/targets.md`。
- `enter-newline` 移动到 `desktop/shared/plugins/enter-newline/`，插件 id 保持
  `enter-newline`。
- 安装/自检/测试跟随条目：`install.ps1`、`verify.ps1`、`tests/` 都在条目目录内。
- 新增 `desktop/README.md`、各目标目录的 `README.md`（占位分类说明）。
- 新增 `docs/compatibility.md`（兼容性判定方式、升级流程）和
  `docs/desktop-internals.md`（app.asar、GUI 插件加载、composer DOM、
  设置存储等调查笔记）。

### 文档

- 移除 README 中与仓库范围无关的说明，并把 changelog 里的“可交付”
  统一为“可复用”。
- 新增 `tools/check-public.ps1`：扫描私有语境引用、本机绝对路径和疑似凭据，
  在 `docs/targets.md` 增加写作规则和提交前检查项。

### 兼容性

- 安装/自检/测试脚本同时支持 Windows PowerShell 5.1（Windows 自带）和
  PowerShell 7+。新增 `_compat.ps1`，集中处理宿主差异：
  `ConvertFrom-Json -AsHashtable`、`[Text.Encoding]::Latin1`、无 BOM 的
  UTF-8 读写。
- `tests/test.ps1` 显式按 UTF-8 读取插件和 harness，修复 PowerShell 5.1 下
  误报 `pending` 的问题。
- `verify.ps1` 打印 Desktop / CLI 版本，仅用于诊断；兼容性由结构检查
  （GUI 插件端点 + 4 个 `app.asar` 标记）决定，不维护版本白名单。
- 服务端插件列表检查增加重试，避免 Desktop 刚重启时误报。
- 在 OpenCode Desktop 2.3.2（opencode CLI 2.3.2）上复核通过：`verify -Deep`
  全绿、22 项行为测试通过、真实渲染层集成探针确认 `Enter` 只换行、
  `Ctrl+Enter` 只提交一次。
- `docs/desktop-internals.md` 补充 2.3.2 的变化：输入框 `keydown` 改为经过
  `controller.onKeyDown` 状态机，但 DOM 标记与 `insertLineBreak` 处理未变。

## enter-newline 1.0.0 — 2026-11-18

- 首个可用版本。
- `Enter` 插入换行，`Ctrl/Cmd+Enter` 发送，`Shift+Enter` 保持换行。
- 保留补全列表、历史记录、斜杠命令、输入法组词和 `Alt+Enter` 的原有行为。
- 提供 `install.ps1`（合并全局配置、备份、卸载）和 `verify.ps1`
  （安装状态与 `-Deep` 兼容性自检）。
- 提供无头 Chromium 行为测试。
- 在 OpenCode Desktop 2.3.0（opencode CLI 2.3.0）上验证通过。
