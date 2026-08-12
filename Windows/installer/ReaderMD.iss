#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "ReaderMD"
#define AppExeName "ReaderMD.exe"
#define AppProgId "ReaderMD.Markdown"

[Setup]
AppId={{A9ED0F5C-24D2-4E5E-B0F0-89D5B7B3F751}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=ReaderMD
AppPublisherURL=https://github.com/nwn900/ReaderMD
AppSupportURL=https://github.com/nwn900/ReaderMD
AppUpdatesURL=https://github.com/nwn900/ReaderMD/releases
DefaultDirName={localappdata}\Programs\ReaderMD
DefaultGroupName=ReaderMD
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
OutputDir=..\..\artifacts\installer
OutputBaseFilename=ReaderMD-{#AppVersion}-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupLogging=yes
UninstallDisplayName=ReaderMD
UninstallDisplayIcon={app}\{#AppExeName}
LicenseFile=..\..\LICENSE
CloseApplications=yes
RestartApplications=no
ChangesAssociations=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "associate"; Description: "Open Markdown files with ReaderMD"; GroupDescription: "File associations:"; Flags: checkedonce
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\artifacts\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\artifacts\prereqs\MicrosoftEdgeWebview2Setup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\ReaderMD"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\ReaderMD"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\{#AppProgId}"; ValueType: string; ValueName: ""; ValueData: "Markdown Document"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\{#AppProgId}\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\{#AppExeName},0"
Root: HKCU; Subkey: "Software\Classes\{#AppProgId}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""

Root: HKCU; Subkey: "Software\Classes\.md"; ValueType: string; ValueName: ""; ValueData: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\.markdown"; ValueType: string; ValueName: ""; ValueData: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\.mdown"; ValueType: string; ValueName: ""; ValueData: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\.mkd"; ValueType: string; ValueName: ""; ValueData: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\.md\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.markdown\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.mdown\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.mkd\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue

Root: HKCU; Subkey: "Software\ReaderMD\Capabilities"; ValueType: string; ValueName: "ApplicationName"; ValueData: "ReaderMD"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\ReaderMD\Capabilities"; ValueType: string; ValueName: "ApplicationDescription"; ValueData: "ReaderMD Markdown reader and editor"
Root: HKCU; Subkey: "Software\ReaderMD\Capabilities\FileAssociations"; ValueType: string; ValueName: ".md"; ValueData: "{#AppProgId}"
Root: HKCU; Subkey: "Software\ReaderMD\Capabilities\FileAssociations"; ValueType: string; ValueName: ".markdown"; ValueData: "{#AppProgId}"
Root: HKCU; Subkey: "Software\ReaderMD\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mdown"; ValueData: "{#AppProgId}"
Root: HKCU; Subkey: "Software\ReaderMD\Capabilities\FileAssociations"; ValueType: string; ValueName: ".mkd"; ValueData: "{#AppProgId}"
Root: HKCU; Subkey: "Software\RegisteredApplications"; ValueType: string; ValueName: "ReaderMD"; ValueData: "Software\ReaderMD\Capabilities"; Flags: uninsdeletevalue

[Run]
Filename: "{tmp}\MicrosoftEdgeWebview2Setup.exe"; Parameters: "/silent /install"; StatusMsg: "Ensuring Microsoft Edge WebView2 Runtime is installed..."; Flags: runhidden waituntilterminated skipifdoesntexist; Check: ShouldInstallWebView2
Filename: "{app}\{#AppExeName}"; Description: "Launch ReaderMD"; Flags: nowait postinstall skipifsilent

[Code]
function ShouldInstallWebView2(): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to ParamCount do
  begin
    if CompareText(ParamStr(I), '/SKIPWEBVIEW2') = 0 then
    begin
      Result := False;
      Exit;
    end;
  end;
end;