# Desktop / shared

在 Windows、macOS、Linux 上行为一致的 OpenCode Desktop 定制。

一个条目自包含：

```
shared/plugins/<id>/
├─ README.md                功能、平台支持、限制
├─ install.*                安装/卸载（PowerShell、shell 或说明）
├─ verify.*                 安装与兼容性自检
├─ tests/                   可自动化的行为测试
└─ ...                      插件/配置本体
```

平台差异用条目 README 里的表格说明，例如“插件 JS 全平台、安装/自检脚本目前只在
Windows 验证”。如果某个平台需要完全不同的代码或安装方式，再放
[`../windows`](../windows/README.md)、[`../macos`](../macos/README.md) 或
[`../linux`](../linux/README.md)。

当前条目：

| 条目 | 说明 |
| --- | --- |
| [`plugins/enter-newline`](plugins/enter-newline/README.md) | `Enter` 换行、`Ctrl+Enter` 发送、`Shift+Enter` 换行 |
