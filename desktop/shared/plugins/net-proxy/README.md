# net-proxy

让 OpenCode Desktop 的模型请求、WebFetch、WebSearch 走代理，并在输入框上方提供一个
可随时切换的胶囊开关。

不修改用户级或系统级环境变量，也没有常驻守护进程、监听端口或开机启动项。

## 支持的客户端

| 客户端 | 支持 | 说明 |
| --- | --- | --- |
| OpenCode Desktop | 是 | 服务端插件 + GUI 插件 |
| CLI / TUI | 默认不启用 | 插件只在 `OPENCODE_CLIENT=desktop` 时生效；可用 `desktopOnly: false` 放开 |
| OpenCode Web UI | 否 | 不在浏览器里管理进程环境 |

安装、自检脚本目前只在 Windows 上验证过；插件代码本身不依赖平台。

## 为什么不需要守护进程

WebFetch、WebSearch 和模型请求都发在同一个 OpenCode 服务进程里，而 Bun 的 `fetch` 每次
请求都会重新读取 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`。插件就运行在这个进程里：

- `setup` 时按状态文件写入或清除这些变量；
- 之后监听状态文件（1 秒轮询），变化时重新应用；
- 插件卸载时恢复启动时看到的值。

因此切换不需要重启应用，也不需要中间人证书；HTTPS 仍然是端到端 TLS。

## 文件

| 文件 | 作用 |
| --- | --- |
| `index.ts` | 服务端插件：应用/恢复环境变量、探测上游、注册 RPC |
| `rpc.ts` | 服务端与 GUI 之间的 RPC 契约 |
| `gui-experimental.cjs` | GUI 插件：输入框上方的胶囊与 `/proxy` 命令 |
| `net-proxy.ps1` / `net-proxy.cmd` | 命令行开关：只写状态文件 |
| `install.ps1` | 合并全局配置、备份、卸载 |
| `verify.ps1` | 安装状态与 `-Deep` 兼容性自检 |
| `_compat.ps1` | PowerShell 5.1 / 7+ 兼容层 |

状态文件：`%USERPROFILE%\.config\opencode\net-proxy.json`
（或 `$XDG_CONFIG_HOME/opencode/net-proxy.json`）

```json
{ "mode": "auto", "upstream": "http://127.0.0.1:7897" }
```

## 安装

```powershell
powershell -File .\desktop\shared\plugins\net-proxy\install.ps1
# 或：pwsh -File .\desktop\shared\plugins\net-proxy\install.ps1
```

脚本把本目录的绝对路径并入 `~/.config/opencode/opencode.json` 的 `plugins`，保留已有条目，
首次修改备份为 `opencode.json.bak`。然后在 Desktop 窗口按 `Ctrl+R`，或重启应用。

卸载：

```powershell
powershell -File .\desktop\shared\plugins\net-proxy\install.ps1 -Uninstall
```

## 使用

输入框上方那一行会出现胶囊：

| 胶囊显示 | 含义 |
| --- | --- |
| `代理: 自动` | 不管理，保留服务进程继承的环境 |
| `代理: 开` | 已强制走上游（绿色） |
| `代理: 关` | 已强制直连 |
| `代理: 中断·直连` | 想走代理但上游不可达，已按直连运行（红色） |

点开胶囊选择「走代理 / 直连 / 不干预」。命令面板、`Ctrl/Cmd+Shift+P`、`/proxy on|off|auto`
也可以切换。

不用 GUI 时，命令行同样可以改：

```powershell
.\desktop\shared\plugins\net-proxy\net-proxy.cmd on
.\desktop\shared\plugins\net-proxy\net-proxy.cmd off
.\desktop\shared\plugins\net-proxy\net-proxy.cmd auto
.\desktop\shared\plugins\net-proxy\net-proxy.cmd upstream http://127.0.0.1:7897
.\desktop\shared\plugins\net-proxy\net-proxy.cmd status
```

改完约 1 秒内对新请求生效；桌面端没开时改也行，下次启动直接按文件应用。

## 三种模式

| mode | 行为 |
| --- | --- |
| `auto`（默认） | 不管理，保留服务进程继承的 `HTTP(S)_PROXY` |
| `proxy` | 写入 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`（含小写）为 `upstream` |
| `direct` | 删除上述变量（直连） |

- `NO_PROXY` 不修改；Desktop 拉起的服务本身已包含回环排除。
- 只在加载插件的服务进程内生效；默认仅 `OPENCODE_CLIENT=desktop`。
- 多个 location 加载插件时共享一份实例，最后一个卸载时才恢复环境。

## 上游不可达时

切换到 `proxy`（或启动时已是 `proxy`）会先对上游做一次 1.5 秒 TCP 探测：

- 连不上就不写代理变量，按直连运行，胶囊显示 `代理: 中断·直连`；
- 运行中不再自动复检；代理中途挂掉后由用户点「直连」。

探测只判断端口可达，不校验认证或节点质量。

## 自检

```powershell
powershell -File .\desktop\shared\plugins\net-proxy\verify.ps1 -Deep
# 或：pwsh -File .\desktop\shared\plugins\net-proxy\verify.ps1 -Deep
```

检查内容：

- Desktop / CLI 版本（仅诊断）；
- 插件文件是否齐全；
- 全局配置是否指向本目录；
- 后台服务是否列出 `net-proxy`；
- `/api/plugin/gui?id=net-proxy` 返回的 bundle 是否与本地文件一致；
- 状态文件能否解析、mode 是否合法；
- `-Deep` 额外检查 `app.asar` 里的 `ComposerPill`、`@opencode/plugin/rpc`、
  `/api/plugin/gui` 标记是否仍在。

全部 `PASS` 说明当前 Desktop 版本仍兼容。这个条目没有自动化行为测试：胶囊需要运行中的
Desktop 窗口，`verify.ps1` 覆盖加载、配置、RPC 端点和 bundle 一致性。

## 限制

- GUI 插件与 RPC 是 experimental API，Desktop 升级后可能需要小幅调整；失效表现为胶囊消失
  或插件加载失败，不会静默改变网络走向。
- OpenCode 2.4.x 的 RPC 校验只接受 Effect Schema；服务端 `rpc.ts` 用 `Schema.Struct`，
  GUI 侧只声明同 id 的 JSON Schema 契约，校验在服务端完成。
- 代理开关作用于服务进程的 `fetch`。实测进程内 `fetch` 立即生效；模型请求走同一套环境，
  但使用 WebSocket transport 的 provider 可能不读取 HTTP 代理变量。
- 切换只影响新请求，正在流式输出的响应不会迁移。
- `auto` 不等于直连，只是“不管理”；进程里原本继承的代理变量会继续生效。
- 状态文件属于全局配置，多个 profile 共用；它只是开关，不含凭据。
