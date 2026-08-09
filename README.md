<!-- markdownlint-disable MD033 MD036 MD032 -->
# Codex /pet 用量伴随层

> 极简 Windows 悬浮层：鼠标移到 Codex Desktop 的 `/pet` 宠物身上时，弹出一个小卡片，实时显示你的剩余用量。

一个**从零编写、不修改 Codex** 的伴随工具。它只读本机的 Codex 状态文件来定位宠物、用你本机的 Codex 登录态查询用量，不发任何数据到第三方。

<p align="center">
  <img src="assets/preview-green.png" width="122" alt="高用量（绿色）" title="≥60% 绿"/>
  <img src="assets/preview-amber.png" width="122" alt="中用量（琥珀色）" title="30–59% 琥珀"/>
  <img src="assets/preview-red.png" width="122" alt="低用量（红色）" title="<30% 红"/>
  <img src="assets/preview-en.png" width="122" alt="英文界面" title="English / Weekly"/>
</p>

<p align="center"><b>简体中文</b> · <a href="README.en.md">English</a></p>

## ✨ 功能

- **悬浮跟随**：鼠标移到宠物身上即显示，移开后 10 秒自动隐藏；拖动宠物时悬浮层实时跟随（Win32 窗口跟踪）。
- **极简小卡**：光环 + 环内剩余百分比 + 下次更新倒计时，只显示必需信息。
- **分级变色**：进度环按剩余用量变色——≥60% 绿、30–59% 琥珀、<30% 红。
- **7 天窗口**：显示 `secondary_window` 的剩余用量。
- **中英切换**：`Ctrl+Alt+Shift+L` 一键切换中文 / English（`7天窗口` ⇄ `Weekly`），选择会记住。
- **多级兜底**：live 接口 → 本地日志 → 显示不可用，接口抖动不影响使用。
- **开机自启**（可选）：写入当前用户登录启动项 + Startup 快捷方式。

## 📦 前置条件

- Windows 10 / 11，PowerShell 5.1+（系统自带，无需安装）
- [Codex Desktop](https://openai.com/codex/)（已登录），并打开 `/pet`
- **Python**（可选）：live 接口不可用时，用于读取本地日志兜底；没有 Python 时只是少了这一层兜底

## 🚀 快速开始（新手也能 3 分钟搞定）

> **一句话版**：把下面 `AGENT_SETUP.md` 的链接丢给你的 Agent 即可自动装好；想自己动手就：下载 ZIP → 解压 → 双击 `Start.bat` → 悬停宠物。

### 方式一：让 Agent 帮你装（推荐）

已经有能操作电脑的 Agent（Codex / Claude）？把下面这个**链接**发给它，它会自己下载、自检、启动，并问你需不需要开机自启：

```text
https://raw.githubusercontent.com/AnsonLi-better/codex-pet-usage-remaining/main/AGENT_SETUP.md
```

### 方式二：手动安装

**第 1 步 · 下载**
1. 打开本仓库页面，点右上角绿色的 `Code` 按钮
2. 在下拉菜单里点 `Download ZIP`
3. 下载完成后，右键这个压缩包 → 选 `全部解压`，解压到任意位置（比如"下载"文件夹）

**第 2 步 · 启动**
1. 打开解压出来的文件夹（名字类似 `codex-pet-usage-remaining-main`）
2. **双击 `Start.bat`**
3. 如果弹出蓝色提示"Windows 已保护你的电脑"：点 `更多信息` → `仍要运行`（只是因为文件来自网上下载，脚本是安全的）

**第 3 步 · 看效果**
1. 打开 Codex Desktop，输入 `/pet` 回车 → 宠物出现在屏幕上
2. 把鼠标移到宠物身上 → 弹出深色小卡片，显示剩余百分比和刷新倒计时
3. **看到卡片 = 成功** 🎉 拖动宠物，卡片会跟着移动
4. 想用英文界面？按 `Ctrl+Alt+Shift+L` 一键切换中 / 英文（`7天窗口` ⇄ `Weekly`），选择会自动记住

> 想开机自启：双击 `InstallStartup.bat`。想关掉：双击 `Stop.bat`。

### 方式三：用命令行（熟手）

会打开 PowerShell 的，直接运行下面的命令即可；完整命令见下文"命令"一节。

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Start
```

## 🧭 命令

| 命令 | 说明 |
| --- | --- |
| `Start` | 启动悬浮层（后台运行，可复用已运行实例） |
| `Stop` | 停止悬浮层 |
| `Status` | 显示运行状态、开机自启状态、最新日志 |
| `SelfTest` | 自检：脚本解析、逻辑函数、Win32 C# 类编译 |
| `InstallStartup` | 安装当前用户开机自启 |
| `UninstallStartup` | 取消开机自启 |
| `FindPet` | 诊断宠物窗口识别（列出 Codex 进程、候选窗口、选中结果） |

双击 `.bat` 或手动执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Start
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Status
```

## ⚙️ 参数

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Start -UsagePollSeconds 60 -PetPollMs 80 -HoverPaddingPx 24
```

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `UsagePollSeconds` | `60` | 用量刷新间隔（秒），最小 60 |
| `PetPollMs` | `80` | 鼠标/宠物位置轮询间隔（毫秒），最小 50 |
| `HoverPaddingPx` | `24` | 悬停判定在宠物四周扩出的像素，避免"差一点"不显示 |
| `Language` | `zh` | 界面语言：`zh` 中文 / `en` English（不传则记住上次选择） |
| `LanguageHotkey` | `Ctrl+Alt+Shift+L` | 运行时切换语言的全局热键 |
| `CodexHome` | `%USERPROFILE%\.codex` | Codex 数据目录 |

## 🧠 工作原理

- **悬停检测**：每 `PetPollMs` 轮询鼠标位置，进入宠物区域（含 padding）即显示，持续 10 秒。
- **窗口跟踪**：用 Win32 枚举 Codex 进程窗口，按尺寸与位置启发式识别宠物窗口，缓存句柄后每 `PetPollMs` 读取实时坐标——拖动宠物时悬浮层跟着走；找不到窗口时回退到 `.codex-global-state.json` 里的坐标。
- **用量获取**：每 `UsagePollSeconds` 用本机 `auth.json` 的 access token 请求 `chatgpt.com/backend-api/wham/usage`，取 7 天窗口剩余百分比；接口失败时读本地 `logs_2.sqlite` / `logs_1.sqlite` 里的 `codex.rate_limits` 事件兜底。
- **渲染**：PowerShell 5.1 + WPF，无 XAML 纯代码构建；透明、置顶、点击穿透的窗口，不干扰操作宠物。

## 📁 目录结构

```text
CodexPetUsageOverlay.ps1    主脚本（全部逻辑）
Start.bat / Stop.bat / Status.bat
InstallStartup.bat / UninstallStartup.bat
assets/                     预览图
README.md / README.en.md    文档
LICENSE
```

## 🔒 数据与隐私

读取本机文件：

- `%USERPROFILE%\.codex\.codex-global-state.json`（宠物位置）
- `%USERPROFILE%\.codex\auth.json`（登录态，仅取 token）
- `%USERPROFILE%\.codex\logs_2.sqlite` / `logs_1.sqlite`（用量兜底）

实时用量只把 token 用于请求：

```text
https://chatgpt.com/backend-api/wham/usage
```

不会发送宠物图片、截图、prompt、仓库内容或日志正文到任何其他地方。

运行时文件（自动创建）：

```text
%LOCALAPPDATA%\CodexPetUsageOverlay\overlay.pid
%LOCALAPPDATA%\CodexPetUsageOverlay\overlay.log
%LOCALAPPDATA%\CodexPetUsageOverlay\lang.txt
```

`lang.txt` 记录界面语言（`zh` / `en`），切换后重启也会保留。

## 🔧 故障排查

- **没看到悬浮层**：确认 Codex Desktop 已打开 `/pet`，再把鼠标移到宠物身上。
- **重启后没显示**：运行 `Status.bat`，确认 `StartupEnabled: True` 且 `Running: True`。
- **显示用量不可用**：运行 `Status.bat` 看最新日志；或直接看 `%LOCALAPPDATA%\CodexPetUsageOverlay\overlay.log`。多为接口临时故障，会自动降级。
- **悬浮层不跟随宠物**：宠物显示在屏幕上时运行 `FindPet`，把输出贴出来排查窗口识别。

## ⚠️ 已知边界

- `wham/usage` 不是公开稳定的 API，字段和可用性未来可能变化。
- 本地日志兜底依赖 Codex 日志出现 `codex.rate_limits` 事件；没有事件时显示不可用。
- 开机自启使用当前用户 `HKCU\...\Run` 并保留 Startup 快捷方式；如需延迟启动或管理员权限，请改用任务计划程序。
- 宠物窗口识别是启发式的（尺寸 + 位置打分），极端情况下可能选错窗口；`FindPet` 可诊断。

## 📄 许可证

[MIT](LICENSE)

## ⚖️ 免责声明

本工具与 OpenAI / Anthropic 无关，仅供个人学习使用。请遵循 Codex 服务条款，用量数据以官方为准。
