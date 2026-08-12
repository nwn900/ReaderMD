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
Name: "associate"; Description: "Open Markdown files with ReaderMD"; GroupDescription: "File associations:"
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

Root: HKCU; Subkey: "Software\Classes\Applications\{#AppExeName}\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{#AppExeName}"" ""%1"""; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".md"; ValueData: ""; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".markdown"; ValueData: ""; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".mdown"; ValueData: ""; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\Applications\{#AppExeName}\SupportedTypes"; ValueType: string; ValueName: ".mkd"; ValueData: ""; Tasks: associate

Root: HKCU; Subkey: "Software\Classes\.md"; ValueType: string; ValueName: ""; ValueData: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\.markdown"; ValueType: string; ValueName: ""; ValueData: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\.mdown"; ValueType: string; ValueName: ""; ValueData: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\.mkd"; ValueType: string; ValueName: ""; ValueData: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Classes\.md\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.markdown\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.mdown\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Classes\.mkd\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue

Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.md\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.markdown\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.mdown\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.mkd\OpenWithProgids"; ValueType: none; ValueName: "{#AppProgId}"; Flags: uninsdeletevalue; Tasks: associate

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
procedure SHChangeNotify(wEventId: LongWord; uFlags: LongWord; dwItem1: LongWord; dwItem2: LongWord);
  external 'SHChangeNotify@shell32.dll stdcall';

const
  SHCNE_ASSOCCHANGED = $08000000;
  SHCNF_IDLIST = $0000;

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

procedure ForceMarkdownAssociation(Extension: String);
var
  UserChoiceKey: String;
  OpenWithListKey: String;
  OpenWithProgidsKey: String;
  ResultCode: Integer;
  ExecSucceeded: Boolean;
begin
  UserChoiceKey := 'Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\' + Extension + '\UserChoice';
  OpenWithListKey := 'Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\' + Extension + '\OpenWithList';
  OpenWithProgidsKey := 'Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\' + Extension + '\OpenWithProgids';

  if RegKeyExists(HKCU, UserChoiceKey) then
  begin
    if not RegDeleteKeyIncludingSubkeys(HKCU, UserChoiceKey) then
    begin
      Log('Direct UserChoice reset failed for ' + Extension + '; trying reg.exe.');
      Exec(
        ExpandConstant('{sys}\reg.exe'),
        'delete "HKCU\' + UserChoiceKey + '" /f',
        '',
        SW_HIDE,
        ewWaitUntilTerminated,
        ResultCode);
    end;
  end;

  if RegKeyExists(HKCU, OpenWithListKey) then
    RegDeleteKeyIncludingSubkeys(HKCU, OpenWithListKey);

  RegWriteStringValue(HKCU, 'Software\Classes\' + Extension, '', '{#AppProgId}');

  ExecSucceeded := Exec(
    ExpandConstant('{sys}\reg.exe'),
    'add "HKCU\' + OpenWithProgidsKey + '" /v "{#AppProgId}" /t REG_NONE /d "" /f',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode);
  if (not ExecSucceeded) or (ResultCode <> 0) then
  begin
    Log('REG_NONE Explorer OpenWithProgids write failed for ' + Extension + '; falling back to a string marker.');
    RegWriteStringValue(HKCU, OpenWithProgidsKey, '{#AppProgId}', '');
  end;

  Log('Reasserted ReaderMD association and Explorer Open With entry for ' + Extension + '.');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and WizardIsTaskSelected('associate') then
  begin
    ForceMarkdownAssociation('.md');
    ForceMarkdownAssociation('.markdown');
    ForceMarkdownAssociation('.mdown');
    ForceMarkdownAssociation('.mkd');
    SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, 0, 0);
    Log('Broadcast shell association refresh after ReaderMD Markdown association reset.');
  end;
end;
