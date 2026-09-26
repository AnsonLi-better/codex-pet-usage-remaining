param([string]$OutputDir = (Join-Path $PSScriptRoot "assets"))

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function New-Preview {
  param([ValidateSet("zh", "en")][string]$Language, [bool]$Tooltip)

  $isEnglish = $Language -eq "en"
  $status = if ($isEnglish) { "Running" } else { "运行中" }
  $fiveHour = if ($isEnglish) { "5-hour remaining" } else { "5 小时剩余" }
  $weekly = if ($isEnglish) { "7-day remaining" } else { "7 天剩余" }
  $reset = if ($isEnglish) { "reset" } else { "重置" }
  $activity = if ($isEnglish) { "Token activity" } else { "Token 活动" }
  $today = if ($isEnglish) { "Today" } else { "今日" }
  $last7 = if ($isEnglish) { "Last 7d" } else { "近 7 天" }
  $estimate = if ($isEnglish) { "Local estimate" } else { "本机估算" }
  $overlay = if ($isEnglish) { "Overlay" } else { "悬浮窗" }
  $startup = if ($isEnglish) { "Start with Windows" } else { "开机自动启动" }
  $languageLabel = if ($isEnglish) { "Language" } else { "界面语言" }
  $languageChoice = if ($isEnglish) { "English ›" } else { "中文 ›" }
  $log = if ($isEnglish) { "View log" } else { "查看日志" }
  $exit = if ($isEnglish) { "Exit" } else { "退出程序" }
  $source = if ($isEnglish) { "Account data" } else { "账户数据" }

  $tooltipMarkup = ""
  if ($Tooltip) {
    $tooltipMarkup = @"
  <rect x="54" y="378" width="168" height="77" fill="#1A2025" stroke="#303A40" stroke-width="1"/>
  <text x="67" y="401" class="tip">09/19 (UTC)</text>
  <text x="67" y="424" class="tip">7,795,717 Token</text>
  <text x="67" y="445" class="tip">$source</text>
"@
  }

  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="438" height="650" viewBox="0 0 438 650" role="img" aria-label="Codex Usage Remaining 1.4.0 $Language tray panel preview">
  <style>
    text { font-family: 'Segoe UI', 'Microsoft YaHei UI', 'Microsoft YaHei', sans-serif; fill: #F5F2E8; }
    .title { font-size: 23px; font-weight: 700; }
    .status { font-size: 14px; fill: #43E6A8; }
    .label { font-size: 13px; fill: #98A4AC; }
    .active { font-size: 13px; fill: #43E6A8; }
    .percent { font-size: 32px; font-weight: 700; }
    .reset { font-size: 12px; fill: #78858E; }
    .section { font-size: 20px; font-weight: 700; }
    .metric { font-size: 28px; font-weight: 700; }
    .row { font-size: 16px; }
    .date { font-size: 11px; fill: #78858E; }
    .tip { font-size: 15px; fill: #FFFFFF; }
  </style>
  <rect x="1" y="1" width="436" height="648" rx="22" fill="#080A0C" stroke="#D7DFE3"/>
  <text x="24" y="46" class="title">Codex Usage Remaining</text>
  <circle cx="27" cy="65" r="4" fill="#43E6A8"/>
  <text x="36" y="70" class="status">$status</text>
  <circle cx="388" cy="52" r="25" fill="#43E6A8"/>
  <circle cx="388" cy="52" r="21" fill="#080A0C"/>
  <text x="371" y="59" font-size="23" font-weight="700" fill="#FFFFFF">&gt;_</text>

  <rect x="24" y="89" width="390" height="101" rx="14" fill="#11161B"/>
  <line x1="219" y1="101" x2="219" y2="177" stroke="#31383D"/>
  <text x="43" y="115" class="active">$fiveHour</text>
  <text x="232" y="115" class="label">$weekly</text>
  <text x="43" y="149" class="percent">82%</text>
  <text x="232" y="149" class="percent">94%</text>
  <rect x="43" y="156" width="158" height="6" rx="3" fill="#30363A"/>
  <rect x="43" y="156" width="130" height="6" rx="3" fill="#43E6A8"/>
  <rect x="232" y="156" width="158" height="6" rx="3" fill="#30363A"/>
  <rect x="232" y="156" width="149" height="6" rx="3" fill="#43E6A8"/>
  <text x="43" y="180" class="reset">20:22 $reset</text>
  <text x="232" y="180" class="reset">09/27 19:44 $reset</text>

  <text x="24" y="229" class="section">$activity</text>
  <text x="24" y="276" class="label">$today</text>
  <text x="92" y="279" class="metric">~7M</text>
  <line x1="219" y1="252" x2="219" y2="309" stroke="#30363A"/>
  <text x="258" y="276" class="label">$last7</text>
  <text x="344" y="279" class="metric">7.6M</text>
  <text x="24" y="305" class="reset">$estimate</text>

  <rect x="40" y="352" width="7" height="20" rx="3" fill="#43E6A8"/>
  <rect x="95" y="317" width="7" height="55" rx="3" fill="#43E6A8"/>
  <rect x="150" y="362" width="7" height="10" rx="3" fill="#1B4C3E"/>
  <rect x="205" y="362" width="7" height="10" rx="3" fill="#1B4C3E"/>
  <rect x="260" y="362" width="7" height="10" rx="3" fill="#1B4C3E"/>
  <rect x="315" y="362" width="7" height="10" rx="3" fill="#1B4C3E"/>
  <rect x="370" y="357" width="7" height="15" rx="3" fill="#43E6A8"/>
  <text x="27" y="389" class="date">09/19</text><text x="82" y="389" class="date">09/20</text>
  <text x="137" y="389" class="date">09/21</text><text x="192" y="389" class="date">09/22</text>
  <text x="247" y="389" class="date">09/23</text><text x="302" y="389" class="date">09/24</text>
  <text x="357" y="389" class="date">09/25</text>

  <text x="28" y="423" class="row">$overlay</text>
  <rect x="364" y="405" width="46" height="26" rx="13" fill="#43E6A8"/><circle cx="399" cy="418" r="9" fill="#F5F2E8"/>
  <text x="28" y="462" class="row">$startup</text>
  <rect x="364" y="444" width="46" height="26" rx="13" fill="#43E6A8"/><circle cx="399" cy="457" r="9" fill="#F5F2E8"/>
  <text x="28" y="501" class="row">$languageLabel</text>
  <text x="356" y="501" class="label">$languageChoice</text>
  <line x1="24" y1="516" x2="414" y2="516" stroke="#242A2E"/>
  <text x="28" y="541" class="row">$log</text><text x="405" y="541" class="label">›</text>
  <text x="28" y="580" class="row" style="fill:#FF675F">$exit</text>
  <text x="383" y="607" class="date">v1.4.0</text>
$tooltipMarkup
</svg>
"@
  $name = if ($Tooltip) { "tray-token-tooltip-v1.4-$Language.svg" } else { "tray-control-panel-v1.4-$Language.svg" }
  $path = Join-Path $OutputDir $name
  [System.IO.File]::WriteAllText($path, $svg, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output $path
}

function New-FiveHourOverlayPreview {
  param([ValidateSet("zh", "en")][string]$Language)
  $label = if ($Language -eq "en") { "5 hours" } else { "5 小时" }
  $reset = if ($Language -eq "en") { "in 4h 12m" } else { "下次 4小时后" }
  $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="112" height="136" viewBox="0 0 112 136" role="img" aria-label="5-hour floating quota card preview">
  <rect x="1" y="1" width="110" height="134" rx="14" fill="#141C24" stroke="#3D454D"/>
  <text x="56" y="20" text-anchor="middle" font-family="Segoe UI, Microsoft YaHei UI, sans-serif" font-size="10" fill="#A6B4BD">$label</text>
  <circle cx="56" cy="64" r="32" fill="none" stroke="#3D454D" stroke-width="7"/>
  <circle cx="56" cy="64" r="32" fill="none" stroke="#43E6A8" stroke-width="7" stroke-linecap="round" stroke-dasharray="165 201" transform="rotate(-90 56 64)"/>
  <text x="56" y="72" text-anchor="middle" font-family="Segoe UI, Microsoft YaHei UI, sans-serif" font-size="22" font-weight="700" fill="#FFFFFF">82%</text>
  <text x="56" y="122" text-anchor="middle" font-family="Segoe UI, Microsoft YaHei UI, sans-serif" font-size="10" fill="#A6B4BD">$reset</text>
</svg>
"@
  $path = Join-Path $OutputDir "overlay-five-hour-v1.4-$Language.svg"
  [System.IO.File]::WriteAllText($path, $svg, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output $path
}

foreach ($language in @("zh", "en")) {
  New-Preview -Language $language -Tooltip $false
  New-Preview -Language $language -Tooltip $true
  New-FiveHourOverlayPreview -Language $language
}
