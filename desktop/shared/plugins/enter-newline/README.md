# enter-newline

OpenCode Desktop GUI 插件：把输入框改成

| 按键                        | 行为                                       |
| --------------------------- | ------------------------------------------ |
| `Enter`                     | 插入换行（原：发送）                       |
| `Shift+Enter`               | 插入换行（不变）                           |
| `Ctrl+Enter` / `Cmd+Enter`  | 发送 / 排队（原：交替投递 steer/queue）    |
| `Alt+Enter`                 | 保持原有的“优先排队”                       |
| 补全列表打开时的 `Enter`    | 仍然选中列表项                             |
| 中文输入法组词时的 `Enter`  | 仍然确认候选词                             |

这是 [`opencode-customizations`](../../../../README.md) 仓库里的一个插件，位于
**Desktop / shared**（Windows、macOS、Linux 共用同一套插件逻辑），插件 id 为
`enter-newline`（由目录名决定）。安装/自检脚本目前只在 Windows 上验证。

## 安装

在仓库根目录执行：

```powershell
pwsh -File .\desktop\shared\plugins\enter-newline\install.ps1
```

脚本会把插件的绝对路径合并进全局配置：

`%USERPROFILE%\.config\opencode\opencode.json`

已有的 `plugins` 条目会保留，原文件会备份为 `opencode.json.bak`。

然后：

1. 在 Desktop 窗口按 `Ctrl+R`，或重启 OpenCode Desktop；
2. 在输入框验证：`Enter` 换行、`Ctrl+Enter` 发送、`Shift+Enter` 换行。

卸载：

```powershell
pwsh -File .\desktop\shared\plugins\enter-newline\install.ps1 -Uninstall
```

## 自检

```powershell
pwsh -File .\desktop\shared\plugins\enter-newline\verify.ps1 -Deep
```

检查内容：

- Desktop / CLI 版本；
- 全局配置是否指向本目录；
- 后台服务是否列出 `enter-newline`；
- `/api/plugin/gui?id=enter-newline` 返回的 bundle 是否与本地文件一致；
- `app.asar` 里插件依赖的 DOM 标记是否仍然存在。

全部 `PASS` 说明当前 Desktop 版本仍兼容。`FAIL` 的处理见
[`docs/compatibility.md`](../../../../docs/compatibility.md)。

## 行为测试

```powershell
pwsh -File .\desktop\shared\plugins\enter-newline\tests\test.ps1
```

用无头 Chrome/Edge 加载插件，验证命令注册、Enter 换行、Ctrl+Enter 提交、
补全弹层放行、焦点边界、输入法组词等行为。不需要 Node/npm。

## 为什么不能用普通配置

Desktop 把“Enter 发送”写死在渲染层输入框的 `onKeyDown` 里：

- `Enter` → `preventDefault()` + `submit()`；
- `Shift+Enter` → 浏览器默认换行；
- `Mod+Enter` → 交替投递（steer/queue）。

`opencode.json` 的 `keybinds` 只能改“命令”的快捷键，而“提交输入框”不是命令，
所以没有对应配置项。

GUI 插件命令在 `document` 的捕获阶段监听按键，并支持：

- `editable: true`：允许在文本框/可编辑区域里触发；
- `scope`：只在指定选择器内触发；
- `run()` 返回 `false`：把按键放行给输入框。

插件用 `enter` 和 `mod+enter` 两个隐藏命令接管按键，再用
`document.execCommand("insertLineBreak")` / 表单 `requestSubmit()` 完成原来的
编辑和发送语义。

## 实现细节

### Enter → 换行

- 只匹配**纯 Enter**（`bind: "enter"`，不匹配 Shift/Ctrl/Alt）；
- 只在焦点位于 `[data-component="composer"]` 且焦点元素在
  `[data-component="composer-editor"]` 内时处理；
- 补全/历史/斜杠命令弹层打开时（存在 `[data-suggestion-id]`）返回 `false`；
- 中文输入法组词期间（`compositionstart` 之后、`compositionend` 之前，或
  `event.isComposing` / `keyCode === 229`）返回 `false`；
- 用 `document.execCommand("insertLineBreak")` 插入换行，与 App 自己对
  `insertParagraph` 的处理一致；失败时回退到 Range + `<br>` 并派发 `input`
  事件。

### Ctrl/Cmd+Enter → 发送

- `bind: "mod+enter"`（Windows/Linux 是 Ctrl，macOS 是 Cmd）；
- 同样避开补全弹层与输入法；
- 调用输入框所在 `<form>` 的 `requestSubmit()`，触发 App 原有的
  `onSubmit` → `controller.submit()`，因此排队、编辑队列、空输入等语义与
  原来的纯 Enter 一致；
- 按住不放产生的重复按键会被忽略。

### 其他按键

- `Shift+Enter` 不匹配任何命令，保持浏览器默认换行；
- `Alt+Enter` 不匹配 `enter`（要求 `alt=false`），仍走 App 的“优先排队”；
- 在输入框之外，`scope` 不匹配，插件完全不干预。

## 目录

```
desktop/shared/plugins/enter-newline/
├─ gui-experimental.cjs   插件本体（CommonJS，无构建步骤）
├─ install.ps1            安装/卸载
├─ verify.ps1             安装状态与兼容性自检
├─ README.md
└─ tests/
   ├─ harness.html
   └─ test.ps1
```

`enter-newline` 目录名就是插件 id。Desktop 按“本地目录 + 根目录下的
`gui-experimental.cjs`”加载，不需要 `package.json` 或构建产物。

## 持久化与升级

插件不在 Desktop 安装目录里，Desktop 的覆盖安装 / 自动更新不会删除它；
全局配置和插件目录都在用户空间。

但它依赖两个非永久契约：

1. GUI 插件 API（`@opencode/plugin/gui`，目前 experimental）；
2. 输入框内部 DOM 标记：`data-component="composer"`、
   `data-component="composer-editor"`、`data-suggestion-id`。

升级 Desktop 后跑一次 `verify.ps1 -Deep` 即可确认。App 内部结构变化时，
插件会安全退回默认 Enter 发送行为，不会让 Desktop 无法启动。

## 已知限制

- GUI 插件 API 是 experimental，未来版本可能改动；
- 依赖输入框内部 DOM 标记，不是公开 API；
- 运行中的回合里，App 自带的 “Steer/Queue ⌘⏎” 提示文字仍可能出现；实际
  `Ctrl+Enter` 执行普通发送；
- 目前只在 OpenCode Desktop `2.3.0` 上做了完整验证（见
  [`docs/compatibility.md`](../../../../docs/compatibility.md)）。
