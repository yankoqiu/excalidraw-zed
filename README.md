# Excalidraw Zed Preview

在 Zed 中按快捷键，把当前 `.excalidraw` 文件渲染成 PNG 并作为图片标签页打开，
用标签切换实现"原文 / 预览"来回切换。

## 为什么不是"眼睛按钮"

Zed 的 Markdown 预览按钮是 Zed 核心写死的功能，第三方扩展的 WASM API 没有
注册自定义面板 / webview / 视图的接口（官方 issue #21197 已关闭为 not planned，
#21208 仍未实现）。因此退而求其次：用 task + 快捷键跳到图片标签页，功能等价，
形态不同。详见 [AGENT.md](AGENT.md)。

## 前置条件

- `exv`（excalidraw-tui）已安装且在 PATH 中：`exv --version` 应能输出版本号
- Node.js >= 22（exv 渲染器依赖）
- Zed 已安装（Windows 默认在 `%LOCALAPPDATA%\Programs\Zed\bin\Zed.exe`）

## 一次性配置

Zed 不允许扩展自带 task / keymap / settings，所以要把本仓库 `config/` 下的
三份片段合并到你的用户配置中。Windows 路径为 `%APPDATA%\Zed\`（即
`C:\Users\<你>\AppData\Roaming\Zed\`）。

### 1. `tasks.json`

把 `config/tasks.json` 的内容放到 `%APPDATA%\Zed\tasks.json`。若该文件已存在，
把其中的 task 对象追加进现有数组。

### 2. `keymap.json`

把 `config/keymap.json` 的内容放到 `%APPDATA%\Zed\keymap.json`。若该文件已存在，
把 `Workspace` 上下文里的绑定合并进去（注意 `ctrl-shift-v` 不要和已有绑定冲突；
Zed 默认的 Markdown 预览就是 `ctrl-shift-v`，在 `.excalidraw` 文件上不冲突，
其他语言文件上仍会触发 Markdown 预览）。

### 3. `settings.json`

把 `config/settings.snippet.json` 里的 `file_types` 合并进 `%APPDATA%\Zed\settings.json`
的顶层对象（若已有 `file_types`，追加 `"JSON": ["excalidraw"]`，不要覆盖其他条目）。
这让 `.excalidraw` 获得 JSON 语法高亮。

## 使用方法

1. 在 Zed 中打开 `foo.excalidraw`，看到 JSON 原文。
2. 按 `Ctrl+Shift+V`（或 `Ctrl+Shift+P` 输入 `excalidraw` 回车）。
3. Zed 渲染 PNG 并跳到该图片标签页，看到绘图。
4. 按 `Ctrl+Tab` 切回 JSON 原文编辑。
5. 改完再按 `Ctrl+Shift+V`，PNG 被覆盖刷新，预览更新。

生成的 PNG 与源文件同目录、同名，仅为预览产物，不提交进 git。

## 故障排查

- **`exv not found on PATH`**：重装 excalidraw-tui 并确保其 bin 目录在 PATH。
- **`Zed.exe not found`**：确认 Zed 安装路径，必要时把 `Zed.exe` 加入 PATH。
- **渲染报错 / PNG 不生成**：先手动跑
  `exv <文件> -f png -o <输出>` 看具体错误（常见是文件 JSON 损坏或 Node 版本过低）。
- **PNG 没刷新**：确认 Zed 关闭了对应图片标签的缓存，或直接关闭该图片标签再按快捷键。
- **快捷键没反应**：确认 `keymap.json` 里 task 名与 `tasks.json` 的 label 完全一致
  （区分大小写）。
