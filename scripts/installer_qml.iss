; Inno Setup Script para el Sistema de Liquidacion de Sueldos (C++/QML Edition)

#define MyAppName "Sistema de Liquidacion de Sueldos"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Antigravity Software"
#define MyAppExeName "liquidacion_sueldos_app.exe"

[Setup]
AppId={{D1A3F5B8-4720-4E4A-B6A9-1981F27A0923}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/max
SolidCompression=yes
OutputDir=..\dist
OutputBaseFilename=Setup_LiquidacionSueldos_QML_v1.0.0

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
