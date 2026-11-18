# Compatibility

## 兼容性怎么判定

这个仓库不维护“支持版本白名单”。`enter-newline` 真正依赖的是少量可检查的
结构，而不是某个版本号：

| 依赖 | 类型 | 风险 | 检查方式 |
| --- | --- | --- | --- |
| `@opencode/plugin/gui` `./gui-experimental` | experimental API | 中 | `opencode-cli api get "/api/plugin/gui?id=enter-newline"` 有返回 |
| `Command.bind` / `editable` / `scope` / `run()` 返回 `false` | 插件 API | 中 | 行为测试（`tests/test.ps1`） |
| `data-component="composer"` | App 内部 DOM | 中 | `verify.ps1 -Deep` 扫描 `app.asar` |
| `data-component="composer-editor"` | App 内部 DOM | 中 | 同上 |
| `data-suggestion-id` | App 内部 DOM | 中 | 同上 |
| `document.execCommand("insertLineBreak")` | 浏览器 API（deprecated，Chromium 仍支持） | 低 | 同上 |
| 表单 `requestSubmit()` | 标准 Web API | 低 | 行为测试 |

`verify.ps1 -Deep` 全绿即表示当前 Desktop 兼容。**版本号与兼容性判断无关**，
所以 Desktop 更新后不需要回来改版本表，只需要（想确认时）跑一次自检。

`verify.ps1` 会打印 `Desktop <版本> / CLI <版本>`，仅用于诊断和回溯。

## 验证记录（历史样本，不要求逐版本补充）

| 日期 | Desktop | CLI | 平台 | 验证内容 | 结果 |
| --- | --- | --- | --- | --- | --- |
| 2026-11-18 | 2.3.0 | 2.3.0 | Windows | install + `verify -Deep` + 行为测试 | 通过 |
| 2026-11-18 | 2.3.2 | 2.3.2 | Windows | install + `verify -Deep` + 22 项行为测试 + 渲染层集成探针 | 通过 |

2.3.0 → 2.3.2 的变化（插件无需修改的原因）：

- composer 的 `keydown` 入口改成先走 `controller.onKeyDown` 状态机，纯 Enter
  的发送分支在 `app.asar` 里的偏移和函数形状都变了；
- 但插件依赖的四个标记没变，`onBeforeInput` 把 `insertParagraph` 换成
  `insertLineBreak` 的处理也没变；
- 所以插件保持原样，只需重新跑一次自检。

## Desktop 升级后的流程

1. 先正常使用一次；如果按键行为正确，通常不需要动作。
2. 想确认就跑（5.1 和 7+ 都可以）：

   ```powershell
   powershell -File .\desktop\shared\plugins\enter-newline\verify.ps1 -Deep
   powershell -File .\desktop\shared\plugins\enter-newline\tests\test.ps1
   ```

3. 按结果处理：

| 失败项 | 含义 | 处理 |
| --- | --- | --- |
| `Config points at this plugin` | 全局配置没指向当前路径 | 重新运行 `install.ps1` |
| `Server lists enter-newline` | 后台服务没加载插件 | 等待/重启 Desktop；检查插件目录和全局配置 |
| `Server serves the current GUI bundle` | 服务端 bundle 和本地文件不一致 | `Ctrl+R` 或重启 Desktop；确认文件已保存 |
| `App still has ...` | Desktop 改了内部 DOM 标记 | 更新插件里的选择器，再跑 `tests/test.ps1` |
| 插件完全不在 `Settings > Extensions > Plugins` | GUI API 或加载方式变化 | 对照最新 GUI 插件文档 |

4. 改完插件后重新跑测试和自检。

## 兼容性策略

- 插件只依赖少量、可检查的内部标记，并在 `run()` 里做防御性判断：
  条件不满足就返回 `false`，把按键交还给 App；
- 加载失败时 App 只失去这个插件的贡献，不会启动失败；
- 版本号只作为诊断信息，不作为放行条件；
- 如果 GUI 插件 API 发生破坏性变化，优先按官方文档迁移，而不是继续依赖旧接口。
