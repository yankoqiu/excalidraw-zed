# Excalidraw Zed Preview — 工程目标与实现文档

> 本文是 `excalidraw-zed` 子工程的说明文档。该子工程与现有的
> `excalidraw-tui`（`exv`）并列，放在 `D:\Project\iamyanko\excalidraw-zed`。

## 1. 背景与结论

用户希望：在 Zed 中打开 `.excalidraw` 文件后，像 Markdown 预览那样，右上角有一个"眼睛"按钮，点一下就在编辑原文和预览之间切换。

调查结论（已核实，截止 2026-11）：

- Zed 的 Markdown 预览按钮是 **Zed 核心**（Rust crate `markdown_preview`）写死的功能，**不是扩展 API 提供的通用能力**。
- 第三方扩展运行在 WASM 沙盒中，`zed_extension_api` 的 `Extension` trait 只有语言、LSP、主题、图标、snippet、调试器、MCP、slash command 等方法，**没有注册自定义面板、webview、视图或编辑器标题栏按钮的接口**。
- Zed 官方 issue #21197 "Excalidraw integration" 已被关闭为 **not planned**，维护者明确表示需要先有扩展 webview API；总需求 #21208 "Webview via Extensions" 至今仍是 open，481 赞，无实现时间表。
- 唯一一个第三方 Excalidraw 预览扩展 (`arindampradhan/excalidraw-zed-extension`) 最终也是**启动独立的原生窗口**，而非在 Zed 内部绘制面板。
- Zed 语言扩展定义语言时 `grammar` 是必填的，写一个"只有图标"的极简扩展反而要引入 tree-sitter 编译，得不偿失。因此本工程**不编写 Zed 插件**。

**因此，用户接受的最终方案是**：用 Zed 的 task + 快捷键触发渲染，把生成的 PNG 作为**图片标签页**在 Zed 中打开。"切换原文/预览"就是切换标签页。命令面板中的 task 条目充当"眼睛按钮"的等价物。

## 2. 工程目标

### 目标（Goals）

1. 在 Zed 中打开 `.excalidraw` 文件（看到 JSON 原文）。
2. 按一个快捷键（或命令面板输入名字），一键把当前文件渲染成 PNG 并在 Zed 中作为标签页打开。
3. 改完 JSON 后再触发一次，PNG 被重新渲染覆盖，预览随之更新。
4. 利用 Zed 原生标签页切换（`Ctrl+Tab` / 点击标签）在原文和预览之间来回切。
5. `.excalidraw` 文件获得 JSON 语法高亮（通过用户设置 `file_types`，不写插件）。

### 非目标（Non-goals）

- 不在 Zed 内部绘制 Excalidraw 画布/面板（API 不允许）。
- 不做可编辑的绘图（本工程只读预览）。
- 不修改 Zed 源码、不自编译 Zed。
- 不编译 tree-sitter 语法、不发布 Zed 扩展市场插件。

### 反目标（Anti-goals，做了反而算失败）

- 引入一个会常驻后台的进程或服务——本工程只做一次性渲染。
- 把生成的 PNG 提交进 git 仓库（应被 `.gitignore` 忽略）。

## 3. 最终用户体验（操作脚本）

1. 在 Zed 中打开 `foo.excalidraw`，看到 JSON 原文。
2. 按 **`Ctrl+Shift+V`**（与 Zed Markdown 预览同键位）。
   - 命令面板方式：`Ctrl+Shift+P` → 输入 `excalidraw` → 回车 `"Excalidraw: Preview"`。
3. Zed 渲染 PNG 并跳转到该图片标签页，看到绘图。
4. 按 `Ctrl+Tab` 切回 JSON 原文继续编辑。
5. 再按 `Ctrl+Shift+V`，预览刷新到最新内容。

## 4. 架构与数据流

```
用户在 Zed 中按 Ctrl+Shift+V
  -> Zed task "Excalidraw: Preview"
     (powershell -NoProfile -ExecutionPolicy Bypass
      -File <工程目录>/preview.ps1 -File "$ZED_FILE")
  -> preview.ps1
     1. 计算输出路径：<同名>.png（与源文件同目录）
     2. 调用 exv <源文件> -f png -o <输出路径>
     3. 检查退出码；成功则 zed.exe -e <输出路径>
  -> exv（现有 excalidraw-tui 的二进制，已安装到 PATH）
     读取 .excalidraw JSON -> 内置 Node renderer -> SVG -> resvg -> PNG
  -> Zed（已有窗口，-e 复用）打开 PNG -> 图片标签页 -> 用户看到绘图
```

## 5. 文件结构

新建目录 `D:\Project\iamyanko\excalidraw-zed\`：

| 文件 | 职责 |
| --- | --- |
| `preview.ps1` | 接收源文件路径；调用 `exv` 渲染 PNG；调用 Zed CLI 打开 PNG |
| `README.md` | 安装/配置步骤、使用方法、故障排查 |
| `config/tasks.json` | Zed task 定义（需合并到用户 `tasks.json`） |
| `config/keymap.json` | 快捷键绑定（需合并到用户 `keymap.json`） |
| `config/settings.snippet.json` | `file_types` 片段（需合并到用户 `settings.json`） |
| `.gitignore` | 忽略 `*.png`（生成的预览图不入库） |

注意：Zed 的扩展 manifest **不允许插件自带 task/keymap/settings**，所以这三份配置必须由用户手动合并到自己的 Zed 用户配置中；README 会把路径和步骤写清楚。这是该方案的唯一一次性手动成本。

## 6. 关键技术事实（已核实）

- `exv` 导出命令可用：`exv <file> -f png -o <out>`（实测成功，49 个元素，输出约 345 KB PNG）。
- `exv` 依赖 Node.js（本机 v22.23.4，满足要求）；renderer 已打包在已安装的 `exv` 中，无需工程内再装依赖。
- Zed CLI 路径：`C:\Users\yanko\AppData\Local\Programs\Zed\bin\Zed.exe`；`-e/--existing` 表示在现有 Zed 窗口打开。
- Zed task 变量：`$ZED_FILE`（当前文件绝对路径）。
- Zed task 快捷键绑定写法：

```json
{
  "context": "Workspace",
  "bindings": {
    "ctrl-shift-v": ["task::Spawn", { "task_name": "Excalidraw: Preview" }]
  }
}
```

- Zed 文件类型关联写法：

```json
"file_types": { "JSON": ["excalidraw"] }
```

## 7. 实现任务清单

### Task 1: `preview.ps1` 渲染脚本

**文件：** 创建 `excalidraw-zed/preview.ps1`

**要求：**

- 参数：`param([Parameter(Mandatory=$true)][string]$File)`
- 校验 `$File` 存在且扩展名为 `.excalidraw`，否则写 stderr 并以非零码退出。
- 输出路径：`[IO.Path]::ChangeExtension($File, ".png")`。
- 调用 `exv $File -f png -o $png`；检查 `$LASTEXITCODE`：非 0 则 stderr 报错、退出非零、不打开 Zed；为 0 则调用 `Zed.exe -e $png` 打开图片标签页。
- Zed 路径优先使用 PATH 中的 `Zed.exe`，找不到时用已知绝对路径回退 (`$env:LOCALAPPDATA\Programs\Zed\bin\Zed.exe`)。

**验收：** `powershell -NoProfile -File preview.ps1 -File <任意已有.excalidraw绝对路径>`，预期同目录生成同名 `.png`，Zed 在现有窗口打开该 PNG 标签页。

### Task 2: 配置片段

**文件：** 创建 `config/tasks.json`、`config/keymap.json`、`config/settings.snippet.json`。内容按第 6 节给出的确切 JSON 片段填写，task label 统一为 `"Excalidraw: Preview"`，快捷键 `ctrl-shift-v`。

### Task 3: `.gitignore`

**文件：** 创建 `excalidraw-zed/.gitignore`，含 `*.png`。

### Task 4: `README.md`

**文件：** 创建 `excalidraw-zed/README.md`，包含：方案说明（为什么是标签页而非面板，简述官方 API 限制）、前置条件（`exv` 在 PATH、已装 Zed、Node.js）、一次性配置（把三份配置片段合并到 `%APPDATA%\Zed\` 下对应文件，给出 Windows 路径）、使用方法（第 3 节操作脚本）、故障排查（`exv` 找不到、Zed 找不到、渲染报错、PNG 没刷新）。

## 8. 验证清单

- [ ] 在 Zed 中打开一个 `.excalidraw`，JSON 高亮生效（file_types 生效）。
- [ ] 按 `Ctrl+Shift+V`，命令面板/快捷键触发 task。
- [ ] PNG 在源文件同目录生成，并在 Zed 中作为标签页打开。
- [ ] `Ctrl+Tab` 能切回 JSON 原文。
- [ ] 修改 JSON 后再按快捷键，PNG 时间戳更新、内容刷新。
- [ ] `preview.ps1` 对不存在的文件、错误扩展名给出明确报错且退出码非零。
- [ ] 生成的 PNG 未被 git 跟踪。

## 9. 未来可能（不在本次范围）

- 如果 Zed 官方在未来开放了 webview/面板 API（#21208），可以做一个真正带"眼睛"按钮的扩展，复用 `exv` 或 Excalidraw 官方 npm 包渲染。届时本工程可以作为临时过渡方案退役。
- 如需在别的编辑器（VS Code）使用同样能力，可复用 `exv` 的 PNG 导出，但那是另一个工程。
