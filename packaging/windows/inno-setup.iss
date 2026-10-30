#ifndef AppVersion
#define AppVersion "0.1.9"
#endif

[Setup]
AppId={{D41F59B1-7A39-4C5C-9A82-3A61E37B3D2F}
AppName=ChessPasant
AppVersion={#AppVersion}
AppPublisher=ChessPasant Team
AppPublisherURL=https://github.com/Yogesh-Kumar-Mallik-dev/ChessPasant
AppSupportURL=https://github.com/Yogesh-Kumar-Mallik-dev/ChessPasant/issues
AppUpdatesURL=https://github.com/Yogesh-Kumar-Mallik-dev/ChessPasant/releases
DefaultDirName={autopf}\ChessPasant
DisableProgramGroupPage=yes
OutputDir=..\..\dist\windows
OutputBaseFilename=ChessPasant_{#AppVersion}_x64_Setup
SetupIconFile=..\..\apps\app\windows\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\chesspasant.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\apps\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\ChessPasant"; Filename: "{app}\chesspasant.exe"; IconFilename: "{app}\chesspasant.exe"
Name: "{autodesktop}\ChessPasant"; Filename: "{app}\chesspasant.exe"; Tasks: desktopicon; IconFilename: "{app}\chesspasant.exe"

[Run]
Filename: "{app}\chesspasant.exe"; Description: "{cm:LaunchProgram,ChessPasant}"; Flags: nowait postinstall skipifsilent
