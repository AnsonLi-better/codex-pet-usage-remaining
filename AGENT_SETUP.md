# 🤖 复制给 AI 助手：安装「Codex /pet 用量伴随层」

把下面 `--- 从这里开始复制 ---` 到 `--- 复制到这里结束 ---` 之间的内容整段复制给你的 AI 助手（**Codex CLI / Claude Code** 这类能操作你电脑的尤其合适），它会帮你完成下载、安装、启动和验证。

> 如果你的 AI 助手不能执行命令（如普通聊天 AI），把它当安装教程，让它一步步教你操作。

---

<!-- 从这里开始复制 -->

# 任务：帮我安装并启动「Codex /pet 用量伴随层」

请在用户电脑上安装并启动一个 Windows 小工具「Codex /pet 用量伴随层」。下面是完整步骤，按顺序执行。

## 这是什么

- 一个给 Codex Desktop 的 `/pet` 宠物显示的实时用量悬浮层：鼠标移到宠物身上时，弹出 112×136 的小卡片，显示**进度环（颜色分级）+ 环内剩余百分比 + 下次刷新倒计时**。
- 纯 PowerShell 5.1 + WPF 实现，绿色软件，无需安装、无第三方依赖。
- 进度环按剩余用量变色：**≥60% 绿、30–59% 琥珀、<30% 红**；界面可中英切换（`Ctrl+Alt+Shift+L`）。
- 安全：只读本机 `%USERPROFILE%\.codex\` 下的状态文件、登录态和日志，**不发任何数据到第三方**。

## 前置条件检查

1. Windows 10 或 11，PowerShell 5.1+（系统自带，无需安装）。
2. Codex Desktop 已安装并登录，能输入 `/pet` 调出宠物。
3. 可选：Python（live 用量接口故障时，用于读本地日志兜底）。

## 第一步：下载源码

```text
git clone https://github.com/AnsonLi-better/codex-pet-usage-remaining
cd codex-pet-usage-remaining
```

如果用户没有 git，改为打开仓库主页下载 ZIP，解压到任意目录后进入该目录。

## 第二步：自检

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 SelfTest
```

**必须输出 `SelfTest OK`。** 若不是，停下来排查（多为 PowerShell 版本过低或文件编码问题），不要继续后续步骤。

## 第三步：启动

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Start
```

启动后引导用户验证：

1. 打开 Codex Desktop，输入 `/pet` 让宠物出现在屏幕上。
2. 鼠标移到宠物身上 → 应出现悬浮层，显示百分比和倒计时。
3. 拖动宠物 → 悬浮层应跟随移动。
4. 按 `Ctrl+Alt+Shift+L` → 界面应在中文 / English 之间切换。

## 常用命令（给用户以后使用）

| 命令 | 作用 |
| --- | --- |
| `Start` | 启动悬浮层（后台运行，重复运行会复用实例） |
| `Stop` | 停止悬浮层 |
| `Status` | 查看运行状态、开机自启状态、最新日志 |
| `SelfTest` | 自检 |
| `InstallStartup` | 安装开机自启 |
| `UninstallStartup` | 取消开机自启 |
| `FindPet` | 诊断宠物窗口识别（列候选窗口） |

手动执行示例：

```powershell
powershell -ExecutionPolicy Bypass -File .\CodexPetUsageOverlay.ps1 Status
```

## 用户可能遇到的问题

- **没看到悬浮层**：确认 `/pet` 已打开，鼠标移到宠物身上；悬浮层只在悬停时显示约 10 秒。
- **显示 `--%` / `--`**：用量接口临时不可用，会自动降级为"不可用"，等一分钟会自动重试，不影响工具本身。
- **悬浮层不跟随宠物**：运行 `FindPet` 看输出，排查宠物窗口识别。
- **想开机自启**：运行 `InstallStartup`。

## 注意事项

- **不要修改 Codex 本体文件。**
- **不要用管理员权限运行**（本工具不需要）。
- **不要**把用户的 Codex token、用量数据发送到任何第三方。
- 如果检查/执行过程中出现错误，把完整报错信息给用户看，不要擅自绕过。

<!-- 复制到这里结束 -->
