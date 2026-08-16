<!-- markdownlint-disable MD033 MD036 MD032 -->
# Codex Usage Remaining

<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-43E6A8" alt="MIT License"/>
  <img src="https://img.shields.io/badge/platform-Windows-0078d6" alt="Windows"/>
  <img src="https://img.shields.io/badge/powershell-5.1%2B-5391FE" alt="PowerShell 5.1+"/>
  <img src="https://img.shields.io/badge/release-v1.2.0-2ea44f" alt="v1.2.0"/>
</p>

<p align="center">
  <img src="assets/app-icon-terminal-black.png" width="96" alt="Codex Usage Remaining 的黑底 >_< 终端图标"/>
</p>

> 给 Codex Desktop 的 `/pet` 宠物实时显示剩余额度，并在 Windows 系统托盘中查看 Token 活动、管理程序。

一个开源的 Windows 桌面伴随工具：鼠标移到 Codex 宠物身上，会弹出跟随宠物的小卡片，实时显示 7 天剩余额度；系统托盘里还有常驻控制面板，可查看每日 Token 趋势、暂停悬浮窗、切换中英文、管理开机自启、查看日志和退出。它**不修改 Codex**，只读取本机 Codex 状态和登录态来查询用量，不会上传任何数据。

> **[⬇️ 下载最新版 Windows 安装包](https://github.com/AnsonLi-better/codex-pet-usage-remaining/releases/latest)**

<p align="center"><b>简体中文</b> · <a href="README.en.md">English</a></p>

## 🖼️ 界面预览

<p align="center">
  <img src="assets/tray-control-panel-zh.png" width="280" alt="Codex Usage Remaining 中文托盘控制面板"/>
  &nbsp;&nbsp;
  <img src="assets/tray-control-panel-en.png" width="280" alt="Codex Usage Remaining 英文托盘控制面板"/>
</p>

<p align="center"><sub>点击通知区域的图标即可打开；支持中文和 English。</sub></p>

<p align="center">
  <img src="assets/tray-token-tooltip-zh.png" width="280" alt="中文：鼠标悬停柱状图显示 UTC 日期、Token 数值和数据来源"/>
  &nbsp;&nbsp;
  <img src="assets/tray-token-tooltip-en.png" width="280" alt="English: hovering a daily bar shows its UTC date, token count, and data source"/>
</p>

<p align="center"><sub>鼠标移到每日柱状图上，可查看 UTC 日期、完整 Token 数值和数据来源。</sub></p>

## ⬇️ 安装

推荐使用正式安装包，不需要进入项目目录或手动输入命令：

1. 打开 [Releases](https://github.com/AnsonLi-better/codex-pet-usage-remaining/releases/latest)，下载 `CodexUsageRemaining-Setup-*.exe`。
2. 双击安装。程序会安装到当前用户目录、立即启动，并默认随 Windows 登录启动，无需管理员权限。
3. 打开 Codex Desktop，输入 `/pet`，将鼠标移到宠物上；看到剩余额度卡片即表示运行成功。

安装后，Windows 通知区域会出现 `>_<` 图标。如果没有直接看到，请展开任务栏右侧的 `^` 折叠区域。

卸载时，可使用 Windows“设置 → 应用”，或开始菜单中的 **Uninstall Codex Usage Remaining**。

## 🎛️ 托盘控制面板

点击通知区域的 `>_<` 图标即可打开控制面板：

- **Token 活动**：显示今日 Token、本周最近 7 个完整 UTC 日期的柱状趋势和合计；将鼠标移到柱子上可查看日期、完整数值及数据来源。
- **悬浮窗**：使用滑轨暂停或恢复宠物旁的额度卡片。
- **开机自动启动**：控制登录 Windows 后是否自动运行。
- **界面语言**：鼠标移到这一行，选择“中文”或“EN”；选择会自动保存。
- **查看日志**：打开运行日志，便于排查用量或窗口识别问题。
- **退出程序**：完全结束当前后台实例。

退出后不需要寻找安装目录，可从开始菜单重新打开 **Codex Usage Remaining**。

## ✨ 功能

- 🖱️ **宠物悬停显示**：鼠标进入宠物区域时显示，离开后 10 秒自动隐藏。
- 🎯 **实时跟随**：拖动 `/pet` 宠物时，额度卡片跟随移动。
- 💠 **剩余额度光环**：显示 7 天窗口剩余百分比和更新时间。
- 📊 **Token 活动面板**：今日数据使用本机 Codex 会话日志增量估算；可用时通过随程序启动的私有 Codex app-server 补充官方每日数据。
- 🎨 **状态变色**：剩余 ≥60% 为绿色、30–59% 为琥珀色、<30% 为红色。
- 🎛️ **托盘管理**：无需进入文件夹，即可暂停、恢复、切换语言、管理自启和退出。
- 🌐 **中英双语**：支持控制面板选择，也保留 `Ctrl+Alt+Shift+L` 全局快捷键。
- 🔁 **多级兜底**：实时用量接口不可用时尝试读取本地日志。

<p align="center">
  <img src="assets/preview-green.png" width="122" alt="高剩余额度（绿色）" title="≥60% 绿色"/>
  <img src="assets/preview-amber.png" width="122" alt="中等剩余额度（琥珀色）" title="30–59% 琥珀色"/>
  <img src="assets/preview-red.png" width="122" alt="低剩余额度（红色）" title="<30% 红色"/>
  <img src="assets/preview-en.png" width="122" alt="英文悬浮窗" title="English / Weekly"/>
</p>

## 📦 系统要求

- Windows 10 或 Windows 11
- Windows PowerShell 5.1（系统通常自带）
- 已登录的 [Codex Desktop](https://openai.com/codex/)
- 独立 Codex CLI（可选；存在时用于读取官方每日 Token，缺少时今日本机估算仍可使用）

## 🔒 数据与隐私

程序可能读取以下本机文件：

- `%USERPROFILE%\.codex\.codex-global-state.json`：宠物状态和位置。
- `%USERPROFILE%\.codex\auth.json`：仅使用登录 token 查询用量。
- `%USERPROFILE%\.codex\logs_2.sqlite` / `logs_1.sqlite`：用量兜底数据。
- `%USERPROFILE%\.codex\sessions\**\rollout-*.jsonl`：只读取 `token_count` 事件，用于今日 Token 的本机增量估算。

token 只用于请求：

```text
https://chatgpt.com/backend-api/wham/usage
```

程序不会上传宠物图片、屏幕截图、prompt、仓库内容或日志正文。

本机估算只增量读取新增的 `token_count` 事件，不会反复扫描全部会话。私有 app-server 仅在程序需要官方每日数据且本机存在可用 Codex CLI 时启动，并会在程序退出时一同结束。

运行时状态保存在：

```text
%LOCALAPPDATA%\CodexPetUsageOverlay\overlay.pid
%LOCALAPPDATA%\CodexPetUsageOverlay\overlay.log
%LOCALAPPDATA%\CodexPetUsageOverlay\lang.txt
%LOCALAPPDATA%\CodexPetUsageOverlay\token-usage-state.json
```

内部目录仍保留旧名称 `CodexPetUsageOverlay`，用于兼容旧版本升级。

## ❓ 常见问题

1. **安装后没有看到图标？** 检查任务栏通知区域右侧的 `^`；仍没有就从开始菜单再次启动 **Codex Usage Remaining**。
2. **有托盘图标，但没有悬浮窗？** 确认 Codex Desktop 已打开 `/pet`，控制面板中的“悬浮窗”滑轨已开启，再把鼠标移到宠物上。
3. **额度显示不可用？** 通常是实时接口暂时不可用。点击托盘图标选“查看日志”；程序也会自动尝试本地日志兜底。
4. **Token 数值前为什么有 `~`？** `~` 表示该值来自本机 Codex 会话日志估算，而非官方账户汇总；只统计当前电脑能读到的会话，可能与最终统计略有差异。
5. **为什么今天没有官方数据？** 官方每日统计只覆盖已结束的 UTC 日期，今天尚未结算，所以用本机会话日志给出实时估算。UTC 日期在中国标准时间每天 08:00 切换。
6. **为什么某一天没有柱子？** 没有柱子表示该日期没有可用记录，不等同于已确认用量为 0；鼠标移到有数据的柱子上可查看完整数值和数据来源。
7. **为什么任务管理器里多了一个 Codex 进程？** 当本机有可用 Codex CLI 时，程序会启动私有 app-server 读取官方每日统计；它不监听公共端口、按需后台通信，并随程序退出。本机估算本身不需要它。
8. **如何关闭开机启动？** 点击托盘图标，在控制面板中关闭“开机自动启动”，无需进入安装目录。
9. **退出后如何重新打开？** 打开 Windows 开始菜单，搜索 **Codex Usage Remaining**。
10. **为什么开机后托盘图标出现但 Codex 还没打开？** 后台控制程序随 Windows 登录启动，以便提供托盘开关；宠物旁的悬浮窗只有在 Codex `/pet` 可用时才出现。

## 🛠️ 从源码运行（开发者 / 高级用户）

普通用户不需要本节。如果希望阅读源码、修改程序或不用安装器运行，可以下载 ZIP 或克隆仓库。

### 使用批处理文件

保持整个项目文件夹完整，然后双击：

- `Install.bat`：启动程序并安装源码版开机启动。
- `Start.bat`：启动程序。
- `Stop.bat`：停止程序。
- `Status.bat`：查看状态和最新日志。
- `Uninstall.bat`：取消源码版开机启动，不删除项目文件。

源码版开机启动会记录当前项目路径，因此启用后移动文件夹，需要重新执行 `Install.bat`。

### 让 Agent 协助

可把下面的说明链接交给能够操作本机文件和终端的 Agent：

```text
https://raw.githubusercontent.com/AnsonLi-better/codex-pet-usage-remaining/main/AGENT_SETUP.md
```

### PowerShell 命令

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 -Command Start
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 -Command Status
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 -Command SelfTest
```

| 命令 | 说明 |
| --- | --- |
| `Start` | 启动后台程序；相同路径已有实例时不会重复启动 |
| `Stop` | 停止当前实例 |
| `Status` | 显示运行、自启、Codex 状态和最新日志 |
| `SelfTest` | 检查脚本逻辑和 Win32/WPF 依赖 |
| `InstallTask` | 为源码版安装开机启动 |
| `UninstallTask` | 删除新旧开机启动入口 |
| `FindPet` | 输出宠物窗口识别诊断信息 |

常用参数：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `UsagePollSeconds` | `60` | 用量刷新间隔（秒），最小 60 |
| `PetPollMs` | `80` | 鼠标和宠物位置轮询间隔（毫秒），最小 50 |
| `HoverPaddingPx` | `24` | 宠物周围额外的悬停判定范围 |
| `Language` | `zh` | `zh` 或 `en`；不传时读取已保存选择 |
| `LanguageHotkey` | `Ctrl+Alt+Shift+L` | 全局语言切换快捷键 |
| `CodexHome` | `%USERPROFILE%\.codex` | Codex 数据目录 |

## 🧠 工作原理

- **悬停检测**：周期性读取鼠标位置，进入宠物区域后显示额度卡片。
- **窗口跟踪**：通过 Win32 枚举 Codex 窗口并识别宠物窗口，找不到时回退到 Codex 本地状态中的坐标。
- **用量获取**：使用本机 Codex 登录态查询 7 天剩余额度；增量读取会话中的 `token_count` 估算今日 Token，并在可用时通过私有 app-server 获取官方每日统计。
- **界面渲染**：使用 Windows PowerShell 5.1、WPF 和 Windows Forms 构建悬浮窗、托盘和控制面板。

## 📁 项目结构

```text
CodexPetUsageOverlay.ps1       主程序
installer/                     Inno Setup 安装器定义
Build-Installer.ps1            安装包构建脚本
Install.bat / Uninstall.bat    源码版开机启动管理
Start.bat / Stop.bat           源码版启动和停止
Status.bat                     状态诊断
assets/                        正式图标、预览图和设计探索稿
AGENT_SETUP.md                 Agent 安装说明
```

## ⚠️ 已知边界

- `wham/usage` 不是公开稳定 API，字段和可用性未来可能变化。
- 今日 Token 是当前电脑上的本地估算，不代表账户在其他设备上的完整用量。
- 官方每日统计依赖本机存在程序可访问的 Codex CLI；没有时仍可显示今日估算和 7 天剩余额度。
- 宠物窗口识别使用尺寸和位置启发式，极端情况下可能选错窗口。
- 托盘和 WPF 控制面板目前仍需要在真实 Windows 桌面环境中进行手动 UI 验证。

## 📄 许可证

[MIT](LICENSE)

---

<p align="center"><b>如果这个项目对你有帮助，欢迎 ⭐ 支持一下！</b></p>
