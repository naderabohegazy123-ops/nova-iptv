#define MyAppName "NOVA IPTV"
#define MyAppVersion "0.2.0"
#define MyAppPublisher "NOVA IPTV"
#define MyAppExeName "nova_iptv_windows.exe"

[Setup]
AppId={{A61BCE57-3D20-4A12-8C77-6A5E5B9A2026}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\NOVA IPTV
DefaultGroupName={#MyAppName}
OutputDir=Output
OutputBaseFilename=NOVA-IPTV-Setup
ArchitecturesInstallIn64BitMode=x64
ArchitecturesAllowed=x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\NOVA IPTV"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\NOVA IPTV"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch NOVA IPTV"; Flags: postinstall nowait skipifsilent
