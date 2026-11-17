# Desktop

OpenCode Desktop（Electron 客户端）的定制。

- `shared/`：Windows / macOS / Linux 都适用的 Desktop 定制；
- `windows/`：只在 Windows 上生效或安装的 Desktop 定制；
- `macos/`：只在 macOS 上生效或安装的 Desktop 定制；
- `linux/`：只在 Linux 上生效或安装的 Desktop 定制。

优先放 `shared/`；只有确实依赖某个系统的路径、API 或安装方式时才分 OS。

当前条目：

| 条目 | 平台 | 说明 |
| --- | --- | --- |
| [`shared/plugins/enter-newline`](shared/plugins/enter-newline/README.md) | Desktop 全平台（安装/自检脚本目前在 Windows 上验证） | `Enter` 换行、`Ctrl+Enter` 发送、`Shift+Enter` 换行 |

平台细节和判断规则见 [`../docs/targets.md`](../docs/targets.md)。
