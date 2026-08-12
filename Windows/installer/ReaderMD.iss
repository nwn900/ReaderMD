#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#define AppName "ReaderMD"
#define AppExeName "ReaderMD.exe"

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

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "..\..\artifacts\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\artifacts\prereqs\MicrosoftEdgeWebview2Setup.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\ReaderMD"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\ReaderMD"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

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
