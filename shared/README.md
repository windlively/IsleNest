# Shared

这里存放与具体平台无关、未来可供 macOS / Windows 复用的内容：

- `spec/`：跨端产品契约，例如配置 schema、状态命名、数据迁移约定。
- `design/`：品牌资产与视觉 token（颜色、间距、动效时长、图标源文件）。

平台实现分别位于 `apps/macos/` 与预留的 `apps/windows/`。平台专属的窗口、权限、快捷键实现不放入本目录。
