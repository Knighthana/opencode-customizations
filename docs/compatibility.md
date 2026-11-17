# Compatibility

## Verified

| 自定义 | 目标 | OpenCode Desktop | opencode CLI | 平台 | 验证日期 | 结果 |
| --- | --- | --- | --- | --- | --- | --- |
| `enter-newline` 1.0.0 | Desktop / shared | 2.3.0 | 2.3.0 | Windows | 2026-11-18 | 通过 |

验证方式：

```powershell
pwsh -File .\desktop\shared\plugins\enter-newline\verify.ps1 -Deep
pwsh -File .\desktop\shared\plugins\enter-newline\tests\test.ps1
```

`verify.ps1 -Deep` 会检查插件依赖的 `app.asar` 内部标记：

- `composer-editor`
- `data-component="composer"`
- `data-suggestion-id`
- `insertLineBreak`

## Desktop 升级后的流程

1. 先正常使用一次；如果按键行为正确，通常不需要动作。
2. 跑对应插件的 `verify.ps1 -Deep`。
3. 按结果处理：

| 失败项 | 含义 | 处理 |
| --- | --- | --- |
| `Config points at this plugin` | 全局配置没指向当前路径 | 重新运行 `install.ps1` |
| `Server lists <id>` | 后台服务没加载插件 | 检查插件目录/文件是否存在；看 Desktop 日志 |
| `Server serves the current GUI bundle` | 服务端 bundle 和本地文件不一致 | `Ctrl+R` 或重启 Desktop；确认文件已保存 |
| `App still has ...` | Desktop 改了内部 DOM 标记 | 更新插件里的选择器，再跑测试 |
| 插件完全不在 `Settings > Extensions > Plugins` | GUI API 或加载方式变化 | 对照最新 GUI 插件文档 |

4. 改完插件后重新跑：

```powershell
pwsh -File .\desktop\shared\plugins\enter-newline\tests\test.ps1
pwsh -File .\desktop\shared\plugins\enter-newline\verify.ps1 -Deep
```

## 兼容性策略

- 插件只依赖少量、可检查的内部标记，并在 `run()` 里做防御性判断：
  条件不满足就返回 `false`，把按键交还给 App；
- 加载失败时 App 只失去这个插件的贡献，不会启动失败；
- 每次 Desktop 升级后，在 `docs/compatibility.md` 追加一行验证结果；
- 如果 GUI 插件 API 发生破坏性变化，优先按官方文档迁移，而不是继续依赖旧接口。

## 已知的接口/内部依赖

| 依赖 | 类型 | 风险 |
| --- | --- | --- |
| `@opencode/plugin/gui` `./gui-experimental` | experimental API | 中 |
| `Command.bind` / `editable` / `scope` / `run` 返回 `false` | 插件 API | 中 |
| `data-component="composer"` | App 内部 DOM | 中 |
| `data-component="composer-editor"` | App 内部 DOM | 中 |
| `data-suggestion-id` | App 内部 DOM | 中 |
| `document.execCommand("insertLineBreak")` | 浏览器 API（deprecated 但 Chromium 仍支持） | 低 |
| 表单 `requestSubmit()` | 标准 Web API | 低 |
