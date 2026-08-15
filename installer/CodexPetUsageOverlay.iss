#define MyAppName "Codex Usage Remaining"
#define MyAppVersion "1.1.0"
#define MyAppPublisher "AnsonLi-better"
#define MyAppURL "https://github.com/AnsonLi-better/codex-pet-usage-remaining"
#define MyAppScript "CodexPetUsageOverlay.ps1"

[Setup]
AppId={{8D5E00C6-4DB8-44D8-98EE-0CA63420A530}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\CodexUsageRemaining
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=CodexUsageRemaining-Setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\assets\app-icon.ico
UninstallDisplayName={#MyAppName}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\CodexPetUsageOverlay.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Start.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Stop.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Status.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.en.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\assets\app-icon.ico"; DestDir: "{app}\assets"; Flags: ignoreversion
Source: "..\assets\app-icon.png"; DestDir: "{app}\assets"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\{#MyAppScript}"" -Command Start"; WorkingDir: "{app}"; IconFilename: "{app}\assets\app-icon.ico"; Comment: "Start {#MyAppName}"
Name: "{group}\Stop {#MyAppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\{#MyAppScript}"" -Command Stop"; WorkingDir: "{app}"
Name: "{group}\View log"; Filename: "notepad.exe"; Parameters: """{localappdata}\CodexPetUsageOverlay\overlay.log"""
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{userstartup}\{#MyAppName}"; Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\{#MyAppScript}"" -Command Start"; WorkingDir: "{app}"; IconFilename: "{app}\assets\app-icon.ico"; Comment: "Start {#MyAppName}"

[Run]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\{#MyAppScript}"" -Command Start"; Flags: runhidden nowait postinstall skipifsilent; Description: "Start {#MyAppName}"

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\{#MyAppScript}"" -Command Stop"; Flags: runhidden waituntilterminated; RunOnceId: "StopOverlay"
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\{#MyAppScript}"" -Command UninstallTask"; Flags: runhidden waituntilterminated; RunOnceId: "RemoveStartupTask"

[InstallDelete]
Type: files; Name: "{userstartup}\Codex Pet Usage Overlay.lnk"
Type: files; Name: "{userstartup}\Codex Usage Remaining.lnk"
Type: filesandordirs; Name: "{localappdata}\Programs\CodexPetUsageOverlay"

[Code]
procedure DeleteScheduledTask(const TaskName: String);
var
  ResultCode: Integer;
begin
  { schtasks returns a non-zero code when the task does not exist; that is safe to ignore. }
  Exec(ExpandConstant('{sys}\schtasks.exe'),
    '/Delete /TN "' + TaskName + '" /F',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

procedure StopOverlayScript(const ScriptPath: String);
var
  ResultCode: Integer;
begin
  if FileExists(ScriptPath) then
    Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      '-NoProfile -ExecutionPolicy Bypass -File "' + ScriptPath + '" -Command Stop',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  InstalledScript: String;
  LegacyScript: String;
begin
  Result := '';
  { Old releases used a scheduled task while current releases use one Startup shortcut. }
  DeleteScheduledTask('Codex Pet Usage Overlay');
  DeleteScheduledTask('Codex Usage Remaining');

  InstalledScript := ExpandConstant('{app}\{#MyAppScript}');
  LegacyScript := ExpandConstant('{localappdata}\Programs\CodexPetUsageOverlay\CodexPetUsageOverlay.ps1');
  StopOverlayScript(InstalledScript);
  if CompareText(InstalledScript, LegacyScript) <> 0 then
    StopOverlayScript(LegacyScript);
end;

function InitializeSetup(): Boolean;
begin
  if not FileExists(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe')) then
  begin
    MsgBox('Windows PowerShell 5.1 is required but was not found.', mbError, MB_OK);
    Result := False;
  end
  else
    Result := True;
end;
