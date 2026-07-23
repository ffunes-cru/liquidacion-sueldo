; =====================================================================
; Inno Setup Script — Sistema de Liquidación de Sueldos y Costo Laboral
; Compilador recomendado: Inno Setup 6.x (https://jrsoftware.org/isinfo.php)
; =====================================================================

#define MyAppName "Liquidación de Sueldos"
#define MyAppVersion "0.1"
#define MyAppPublisher "Sistema de Liquidación"
#define MyAppExeName "LiquidacionSueldos.exe"

[Setup]
; Identificador único de la aplicación (GUID)
AppId={{D37E6F41-8B39-4E9A-A3D2-99F5B8E6712A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

; Directorio por defecto de instalación (Instala en AppData local para permitir crear la BD sin pedir permisos de Administrador)
DefaultDirName={localappdata}\Programs\LiquidacionSueldos
DefaultGroupName={#MyAppName}

; Permite al usuario elegir si instalar sólo para su usuario o para todos
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=commandline dialog

; Archivo ejecutable de salida del instalador
OutputDir=.
OutputBaseFilename=LiquidacionSueldos_Setup_v2.0
Compression=lzma2/ultra64
SolidCompression=yes

; Estilo moderno de la interfaz del instalador
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Archivos compilados por PyInstaller (carpeta dist\LiquidacionSueldos\)
Source: "dist\LiquidacionSueldos\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Acceso directo en el Menú Inicio
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
; Acceso directo opcional en el Escritorio
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Opción para ejecutar la aplicación al finalizar la instalación
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
