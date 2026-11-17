# OpenCode Desktop internals（调查笔记）

这份笔记记录做 `enter-newline` 时确认过的 Desktop 结构，方便下次升级后快速定位，
而不是重新翻一遍 `app.asar`。内容对应 **OpenCode Desktop 2.3.0 / CLI 2.3.0**。

## 安装位置（Windows）

| 内容 | 路径 |
| --- | --- |
| 程序 | `%LOCALAPPDATA%\Programs\ai.opencode.desktop` |
| 渲染层/主进程代码 | `resources\app.asar` |
| 内置 CLI | `resources\opencode-cli.exe` |
| 用户数据 | `%APPDATA%\ai.opencode.desktop` |
| 日志 | `%APPDATA%\ai.opencode.desktop\logs\<timestamp>\{main,renderer}.log` |
| 全局配置 | `%USERPROFILE%\.config\opencode\opencode.json(c)` |

它是一个 Electron 应用，渲染层通过自定义协议 `oc://renderer/...` 加载。

## GUI 插件如何加载

- 全局配置里的 `plugins` 支持 npm 包名、本地目录、`file://` 路径。
- 本地目录没有 `package.json` 时：
  - 目录名就是插件 id；
  - 根目录的 `gui-experimental.cjs`（或 `.js`）就是 GUI bundle；
  - 服务端还会找 `server`/`index`、`tui` 等入口；纯 GUI 插件可以没有它们。
- bundle 是 CommonJS，由宿主用类似下面的方式求值：

  ```js
  new Function("require", "module", "exports", code)(host.require, module, module.exports)
  ```

  `require("@opencode/plugin/gui")` 由宿主提供，不需要 npm install 或构建。
- bundle 的 `module.exports`（或 `.default`）必须是 `Plugin.define({...})` 的结果，
  且至少包含 `setup` 或 `main`。
- GUI 插件没有自己的 id 字段，id 来自插件包/目录名。

相关 API：

```powershell
opencode-cli.exe plugin list
opencode-cli.exe api get "/api/plugin/gui?id=<id>"
```

`/api/plugin/gui` 返回的 `data.code` 就是当前生效的 bundle，`data.revision` 是服务端
算出的修订值（不等于文件 SHA-256，比较内容更可靠）。

## 命令快捷键与输入框

- 命令注册表在 `document` 上以 **capture** 阶段监听 `keydown`。
- 命令字段（GUI 插件）：
  - `bind`：默认快捷键；
  - `editable: true`：焦点在文本框/可编辑区域时也生效；
  - `scope`：CSS 选择器，焦点必须位于其中；
  - `run()` 同步返回 `false`：放弃该按键，事件继续传给目标。
- 输入框（composer）内部标记（2.3.0）：

  ```html
  <form data-component="composer">
    ...
    <div data-component="composer-scroll">
      <div data-component="composer-editor" role="textbox" aria-multiline="true">
        ...
      </div>
    </div>
    <button data-action="composer-submit">...</button>
  </form>
  ```

  补全/历史/斜杠命令弹层是 form 的兄弟节点，行上带 `data-suggestion-id`。

- 2.3.0 的输入框按键逻辑在 `app/src/composer/editor/editor.tsx`：
  - 纯 `Enter`：`preventDefault()` + `props.controller.submit()`
  - `Shift+Enter`：浏览器默认换行
  - `Mod+Enter`：`submit({ alternate: true })`（steer/queue 交替投递）
  - `onBeforeInput` 把 `insertParagraph` 换成
    `document.execCommand("insertLineBreak")`，这也是插件换行采用的同一手法。

## 设置存储

- `%APPDATA%\ai.opencode.desktop\opencode.settings`：窗口/onboarding/背景色等。
- 渲染层设置以 `settings.v3` 为 key 持久化（桌面端走主进程存储，不是普通
  `localStorage`）。
- 命令目录以 `command.catalog.v1` 持久化。
- `settings.keybinds` 是 `{ [commandId]: keybindString }`，用户在
  `Settings > Shortcuts` 里的自定义优先于命令默认值。
- `Settings > Extensions > Plugins` 的 GUI 开关按插件 id 记录。

## 升级后怎么查

1. 先跑仓库里的 `verify.ps1 -Deep`。
2. 需要手动确认时，在 `app.asar` 里搜 ASCII 标记：

   ```powershell
   # verify.ps1 里的 Test-AsarPattern 就是流式搜索，不会整包读入内存
   ```

   重点看：`composer-editor`、`data-component="composer"`、
   `data-suggestion-id`、`insertLineBreak`。

3. 看服务端是否还认这个插件：

   ```powershell
   opencode-cli.exe plugin list
   opencode-cli.exe api get "/api/plugin/gui?id=enter-newline"
   ```

4. 看日志：

   ```
   %APPDATA%\ai.opencode.desktop\logs\<最新时间戳>\main.log
   %APPDATA%\ai.opencode.desktop\logs\<最新时间戳>\renderer.log
   ```

5. 如果 DOM 标记变了：
   - 更新 `plugins/enter-newline/gui-experimental.cjs` 里的
     `COMPOSER` / `EDITOR` / `[data-suggestion-id]`；
   - 跑 `tests\enter-newline\test.ps1`；
   - 再跑 `verify.ps1 -Deep`。

## 调查 app.asar 的小工具

`app.asar` 是“8 字节 pickle 头 + JSON 头 + 数据区”：

- 偏移 0：`uint32`，通常为 4；
- 偏移 4：`uint32`，payload 大小；
- 偏移 8：`uint32`，头部字符串长度；
- 偏移 16：JSON 头部，列出每个文件的 `size`、`offset`、`integrity`；
- 数据区起点 = `8 + payload 大小`；
- 文件内容偏移 = 数据区起点 + 条目的 `offset`。

`verify.ps1` 不需要解析头部，只做 ASCII 流式搜索；要抽取具体文件时再按上面的
格式解析。

## 注意

- 这些是 2.3.0 的内部实现，不是稳定 API；升级后以实际安装包为准。
- 不要把个人机器的绝对路径、token、日志内容提交到本仓库。
