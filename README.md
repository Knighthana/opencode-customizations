# OpenCode Desktop: Enter = 换行，Ctrl+Enter = 发送

一个用户空间的 OpenCode Desktop GUI 插件，把输入框改成：

| 按键                        | 行为                                       |
| --------------------------- | ------------------------------------------ |
| `Enter`                     | 插入换行（原：发送）                       |
| `Shift+Enter`               | 插入换行（不变）                           |
| `Ctrl+Enter` / `Cmd+Enter`  | 发送 / 排队（原：交替投递 steer/queue）    |
| `Alt+Enter`                 | 保持原有的“优先排队”                       |
| 补全列表打开时的 `Enter`    | 仍然选中列表项                             |
| 中文输入法组词时的 `Enter`  | 仍然确认候选词                             |

## 能否应对 OpenCode Desktop 更新？

**能，正常情况下可以。** 原因：

- 它**不修改** Desktop 安装目录里的 `app.asar`，也不是二进制补丁；
- 插件目录和全局配置 `%USERPROFILE%\.config\opencode\opencode.json` 都在用户空间，
  Desktop 的覆盖安装 / 自动更新不会删除它们；
- Desktop 每次启动都会从配置里读取这个本地插件，并由它自己的后台服务加载
  `gui-experimental.cjs`。

但需要明确边界：它依赖两个“非永久契约”：

1. **GUI 插件 API**（`@opencode/plugin/gui`，目前标记为 experimental）；
2. **输入框的内部 DOM 标记**：`[data-component="composer"]`、
   `[data-component="composer-editor"]`、`[data-suggestion-id]`。

Desktop 大版本更新后，这两者有可能改名或改行为。为了能在更新后第一时间发现
问题，本仓库提供：

```powershell
pwsh -File .\scripts\verify.ps1 -Deep
```

它会检查：

- Desktop 与 CLI 是否可访问，版本号是多少；
- 全局配置是否仍指向本仓库的插件；
- 后台服务是否列出了 `enter-newline`；
- `/api/plugin/gui?id=enter-newline` 返回的 bundle 是否和本地文件一致；
- `app.asar` 里插件依赖的 DOM 标记和 `insertLineBreak` 是否仍然存在。

全部 `PASS` 就说明当前版本仍兼容；出现 `FAIL` 时按输出的提示处理。

另外，插件在 Desktop 里是“可选装饰”：即使未来加载失败，也只是恢复
Enter 发送的默认行为，不会让 Desktop 无法启动。你可以在
`Settings > Extensions > Plugins` 里看到它的加载状态。

## 快速开始

要求：Windows、PowerShell 7（`pwsh`）、已安装 OpenCode Desktop。

```powershell
# 1. 安装到全局配置（会备份原 opencode.json）
pwsh -File .\scripts\install.ps1

# 2. 让 Desktop 重新加载
#    先在窗口里按 Ctrl+R；没变化就重启 OpenCode Desktop

# 3. 自检
pwsh -File .\scripts\verify.ps1 -Deep
```

验证效果：

1. 在输入框输入 `第一行`，按 `Enter` → 光标到第二行，消息没有发出；
2. 按 `Ctrl+Enter` → 消息发出；
3. `Shift+Enter` → 仍然换行。

也可以用 CLI 直接确认：

```powershell
& "$env:LOCALAPPDATA\Programs\ai.opencode.desktop\resources\opencode-cli.exe" plugin list
& "$env:LOCALAPPDATA\Programs\ai.opencode.desktop\resources\opencode-cli.exe" api get "/api/plugin/gui?id=enter-newline"
```

## 目录结构

```
enter-newline-plugin/
├─ enter-newline/
│  └─ gui-experimental.cjs     插件本体（无构建步骤，CommonJS）
├─ scripts/
│  ├─ install.ps1              安装 / 卸载（合并全局 opencode.json）
│  └─ verify.ps1               安装状态 + 兼容性自检（-Deep 检查 app.asar）
├─ tests/
│  ├─ harness.html             浏览器内的行为测试页
│  └─ test.ps1                 用无头 Chrome/Edge 跑测试
├─ README.md
├─ CHANGELOG.md
└─ LICENSE
```

`enter-newline` 目录名就是插件 id；全局配置指向这个目录，Desktop 按
“本地目录 + 根目录下的 `gui-experimental.cjs`”加载，不需要 `package.json`
或构建产物。

## 为什么不能用普通配置实现

OpenCode Desktop 把“Enter 发送”写死在渲染层输入框的 `onKeyDown` 里：

- `Enter` → `preventDefault()` + `submit()`；
- `Shift+Enter` → 浏览器默认换行；
- `Mod+Enter` → 交替投递（steer/queue）。

`opencode.json` 的 `keybinds` 只能改“命令”的快捷键，而“提交输入框”不是命令，
所以没有对应的配置项。

GUI 插件命令在 `document` 的**捕获阶段**监听按键，并且支持：

- `editable: true`：允许在文本框/可编辑区域里触发；
- `scope`：只在指定选择器内触发；
- `run()` 返回 `false`：把按键放行给输入框。

因此插件可以先用 `enter` 和 `mod+enter` 两个隐藏命令接管按键，再用
`document.execCommand("insertLineBreak")` / 表单 `requestSubmit()` 完成原来的
编辑和发送语义。

## 实现细节

### Enter → 换行

- 命令只匹配**纯 Enter**（`bind: "enter"`，不匹配 Shift/Ctrl/Alt）；
- 只在焦点位于 `[data-component="composer"]` 且焦点元素在
  `[data-component="composer-editor"]` 内时处理；
- 补全/历史/斜杠命令弹层打开时（存在 `[data-suggestion-id]`）返回 `false`，
  Enter 继续用于选中列表项；
- 中文输入法组词期间（`compositionstart` 之后、`compositionend` 之前，或
  `event.isComposing` / `keyCode === 229`）返回 `false`，Enter 继续确认候选词；
- 用 `document.execCommand("insertLineBreak")` 插入换行，与 App 自己对
  `insertParagraph` 的处理完全一致；失败时回退到 Range + `<br>` 并派发
  `input` 事件。

### Ctrl/Cmd+Enter → 发送

- 命令为 `bind: "mod+enter"`（Windows/Linux 是 Ctrl，macOS 是 Cmd）；
- 同样避开补全弹层与输入法；
- 调用输入框所在 `<form>` 的 `requestSubmit()`，触发 App 原有的
  `onSubmit` → `controller.submit()`，因此排队、编辑队列、空输入等语义都与
  原来的纯 Enter 完全一致；
- 按住不放产生的重复按键会被忽略，避免重复提交。

### 其他按键

- `Shift+Enter` 不匹配任何命令，保持浏览器默认换行；
- `Alt+Enter` 不匹配 `enter`（要求 `alt=false`），仍走 App 的“优先排队”；
- 在输入框之外，`scope` 不匹配，插件完全不干预。

## 更新 OpenCode Desktop 之后

1. 先正常使用；如果按键行为仍然正确，无需操作。
2. 想确认兼容性：

   ```powershell
   pwsh -File .\scripts\verify.ps1 -Deep
   ```

3. 如果 `Config points at this plugin` 或 `Server lists enter-newline` 失败：
   - 检查插件目录是否被移动；重新运行 `scripts\install.ps1`。
4. 如果 `-Deep` 的 DOM 标记检查失败：
   - 说明 Desktop 改动了输入框内部结构，需要按新结构更新
     `enter-newline/gui-experimental.cjs` 中的选择器，再跑
     `tests\test.ps1` 和 `verify.ps1 -Deep`。
5. 如果插件完全不再加载：
   - 查看 `Settings > Extensions > Plugins` 是否把 `enter-newline` 标为未加载；
   - 对照最新文档：<https://opencode.ai/docs/build/plugins/gui/>。

## 测试

```powershell
pwsh -File .\tests\test.ps1
```

测试会在无头 Chrome/Edge 中加载插件，用模拟的 composer DOM 验证：

- 两个命令的 id、快捷键、`editable`、`scope`；
- Enter 插入换行且不提交；
- Ctrl+Enter 恰好提交一次；
- 补全弹层打开时两者都放行；
- 焦点不在编辑器时 Enter 放行；
- 输入法组词期间 Enter 放行，组词结束后恢复。

不需要 Node、npm 或任何构建工具。

## 卸载

```powershell
pwsh -File .\scripts\install.ps1 -Uninstall
```

然后重启 OpenCode Desktop（或 `Ctrl+R`）。

## 迁移 / 重装

- 移动了仓库目录：重新运行 `scripts\install.ps1`，它会移除指向旧路径的条目
  并写入新路径。
- 重装了系统或 Desktop：插件文件在本仓库里，重新运行安装脚本即可。
- 安装脚本会保留 `opencode.json` 里其他 `plugins` 条目，并在写入前备份为
  `opencode.json.bak`。
- 如果全局配置是 `opencode.jsonc`（带注释），脚本不会冒险改写，而是打印需要
  手工加入的路径。

## 已知限制

- GUI 插件 API 是 experimental，未来版本可能改动。
- 插件依赖输入框的内部 DOM 标记，不是公开 API。
- 运行中的回合里，App 自带的 “Steer/Queue ⌘⏎” 提示文字仍可能出现；实际
  `Ctrl+Enter` 现在执行普通发送。按钮本身仍可点击。
- 目前只在 OpenCode Desktop `2.3.0` 上做了完整验证。

## License

MIT，见 [LICENSE](LICENSE)。
