# Krita for Windows on ARM64 -- NSIS installer script
#
# Self-contained installer for the native AArch64 (ARM64) build of Krita.
# Unlike the upstream Krita installer, this does NOT bundle the x64
# KritaShellExtension COM DLLs (they cannot load natively on ARM64). It
# installs a proper Windows program: Program Files install, Start Menu and
# optional desktop shortcuts, .kra/.ora file associations, and a full
# Add/Remove Programs entry with a working uninstaller.
#
# Required defines (pass with /D on the makensis command line):
#   KRITA_PACKAGE_ROOT  - path to the extracted self-contained package tree
#   KRITA_VERSION       - 4-part numeric version, e.g. 5.3.2.1
#   KRITA_VERSION_DISPLAY - human-readable version string
#   KRITA_OUTFILE       - output setup .exe path

!ifndef KRITA_PACKAGE_ROOT
	!error "KRITA_PACKAGE_ROOT must be defined and point to the package tree."
!endif

!define /ifndef KRITA_VERSION "0.0.0.0"
!define /ifndef KRITA_VERSION_DISPLAY "test-version"
!define /ifndef KRITA_OUTFILE "krita-arm64-setup.exe"

!define KRITA_PUBLISHER "Krita Foundation"
!define KRITA_PRODUCTNAME "Krita (ARM64)"
!define KRITA_UNINSTALL_REGKEY "Krita_arm64"

Unicode true
ManifestDPIAware false

VIProductVersion "${KRITA_VERSION}"
VIAddVersionKey "CompanyName" "${KRITA_PUBLISHER}"
VIAddVersionKey "FileDescription" "${KRITA_PRODUCTNAME} ${KRITA_VERSION_DISPLAY} Setup"
VIAddVersionKey "FileVersion" "${KRITA_VERSION}"
VIAddVersionKey "LegalCopyright" "${KRITA_PUBLISHER}"
VIAddVersionKey "ProductName" "${KRITA_PRODUCTNAME} ${KRITA_VERSION_DISPLAY} Setup"
VIAddVersionKey "ProductVersion" "${KRITA_VERSION}"

BrandingText "${KRITA_PRODUCTNAME} ${KRITA_VERSION_DISPLAY}"
Name "${KRITA_PRODUCTNAME} ${KRITA_VERSION_DISPLAY}"
OutFile "${KRITA_OUTFILE}"
InstallDir "$PROGRAMFILES64\Krita (ARM64)"
InstallDirRegKey HKLM "Software\Krita ARM64" "InstallLocation"
XPstyle on
SetCompressor /SOLID lzma

ShowInstDetails show
ShowUninstDetails show

Var KritaStartMenuFolder
Var CreateDesktopIcon
Var hwndChkDesktopIcon

!include MUI2.nsh
!include LogicLib.nsh
!include x64.nsh
!include WinVer.nsh
!include FileFunc.nsh

!define MUI_ICON "krita.ico"
!define MUI_UNICON "krita.ico"
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_FINISHPAGE_RUN "$INSTDIR\bin\krita.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Krita"

# Installer pages
!insertmacro MUI_PAGE_WELCOME
!define MUI_LICENSEPAGE_CHECKBOX
!insertmacro MUI_PAGE_LICENSE "license_gpl-3.0.rtf"
!insertmacro MUI_PAGE_DIRECTORY

!define MUI_STARTMENUPAGE_DEFAULTFOLDER "Krita"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT HKLM
!define MUI_STARTMENUPAGE_REGISTRY_KEY "Software\Krita ARM64"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "StartMenuFolder"
!insertmacro MUI_PAGE_STARTMENU Krita $KritaStartMenuFolder

Page Custom func_DesktopIconPage_Init func_DesktopIconPage_Leave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

# Uninstaller pages
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

Section "Krita (ARM64)" SEC_main
	SectionIn RO
	SetOutPath "$INSTDIR"

	# Program icons used by shortcuts / file associations / Add-Remove
	File "krita.ico"
	File "kritafile.ico"

	# The self-contained package tree
	File /r "${KRITA_PACKAGE_ROOT}\bin"
	File /r "${KRITA_PACKAGE_ROOT}\lib"
	File /r "${KRITA_PACKAGE_ROOT}\share"
	File /r "${KRITA_PACKAGE_ROOT}\python"
	File /nonfatal /r "${KRITA_PACKAGE_ROOT}\etc"
SectionEnd

Section "-Associations"
	# .kra - Krita native document
	WriteRegStr HKLM "Software\Classes\.kra" "" "Krita.Document"
	WriteRegStr HKLM "Software\Classes\Krita.Document" "" "Krita Document"
	WriteRegStr HKLM "Software\Classes\Krita.Document\DefaultIcon" "" "$INSTDIR\kritafile.ico,0"
	WriteRegStr HKLM "Software\Classes\Krita.Document\shell\open\command" "" '"$INSTDIR\bin\krita.exe" "%1"'

	# .ora - OpenRaster (shared format; register an open verb without stealing default)
	WriteRegStr HKLM "Software\Classes\.ora\OpenWithProgids" "Krita.OpenRaster" ""
	WriteRegStr HKLM "Software\Classes\Krita.OpenRaster" "" "OpenRaster Image"
	WriteRegStr HKLM "Software\Classes\Krita.OpenRaster\DefaultIcon" "" "$INSTDIR\kritafile.ico,0"
	WriteRegStr HKLM "Software\Classes\Krita.OpenRaster\shell\open\command" "" '"$INSTDIR\bin\krita.exe" "%1"'

	# Refresh the shell so new icons/associations show up immediately
	System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, i 0, i 0)'
SectionEnd

Section "-Shortcuts"
	!insertmacro MUI_STARTMENU_WRITE_BEGIN Krita
		CreateDirectory "$SMPROGRAMS\$KritaStartMenuFolder"
		CreateShortcut "$SMPROGRAMS\$KritaStartMenuFolder\Krita.lnk" "$INSTDIR\bin\krita.exe" "" "$INSTDIR\krita.ico" 0
		CreateShortcut "$SMPROGRAMS\$KritaStartMenuFolder\Uninstall Krita.lnk" "$INSTDIR\uninstall.exe"
	!insertmacro MUI_STARTMENU_WRITE_END
	${If} $CreateDesktopIcon == 1
		CreateShortcut "$DESKTOP\Krita.lnk" "$INSTDIR\bin\krita.exe" "" "$INSTDIR\krita.ico" 0
	${EndIf}
SectionEnd

Section "-RegistryAndUninstaller"
	# Where we are installed (used by InstallDirRegKey + start menu page)
	WriteRegStr HKLM "Software\Krita ARM64" "InstallLocation" "$INSTDIR"
	WriteRegStr HKLM "Software\Krita ARM64" "Version" "${KRITA_VERSION}"

	# Add/Remove Programs entry
	!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${KRITA_UNINSTALL_REGKEY}"
	WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${KRITA_PRODUCTNAME} ${KRITA_VERSION_DISPLAY}"
	WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${KRITA_VERSION}"
	WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\krita.ico,0"
	WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "${KRITA_PUBLISHER}"
	WriteRegStr HKLM "${UNINST_KEY}" "URLInfoAbout" "https://krita.org/"
	WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
	WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
	WriteRegStr HKLM "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
	WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
	WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1

	# Report install size to Add/Remove Programs
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
	IntFmt $0 "0x%08X" $0
	WriteRegDWORD HKLM "${UNINST_KEY}" "EstimatedSize" "$0"

	WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------

Section "un.Krita"
	RMDir /r "$INSTDIR\bin"
	RMDir /r "$INSTDIR\lib"
	RMDir /r "$INSTDIR\share"
	RMDir /r "$INSTDIR\python"
	RMDir /r "$INSTDIR\etc"
	Delete "$INSTDIR\krita.ico"
	Delete "$INSTDIR\kritafile.ico"
	Delete "$INSTDIR\uninstall.exe"
	RMDir "$INSTDIR"

	# Shortcuts
	Delete "$DESKTOP\Krita.lnk"
	!insertmacro MUI_STARTMENU_GETFOLDER Krita $KritaStartMenuFolder
	Delete "$SMPROGRAMS\$KritaStartMenuFolder\Krita.lnk"
	Delete "$SMPROGRAMS\$KritaStartMenuFolder\Uninstall Krita.lnk"
	RMDir "$SMPROGRAMS\$KritaStartMenuFolder"

	# File associations
	DeleteRegKey HKLM "Software\Classes\Krita.Document"
	DeleteRegKey HKLM "Software\Classes\Krita.OpenRaster"
	DeleteRegValue HKLM "Software\Classes\.kra" ""
	DeleteRegValue HKLM "Software\Classes\.ora\OpenWithProgids" "Krita.OpenRaster"

	# Registry
	DeleteRegKey HKLM "Software\Krita ARM64"
	DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\${KRITA_UNINSTALL_REGKEY}"

	System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, i 0, i 0)'
SectionEnd

# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

Function .onInit
	SetShellVarContext all
	${IfNot} ${RunningX64}
		MessageBox MB_OK|MB_ICONSTOP "This is the ARM64 build of Krita and requires a 64-bit (ARM64) edition of Windows."
		Abort
	${EndIf}
	${IfNot} ${AtLeastWin10}
		MessageBox MB_OK|MB_ICONSTOP "Krita for Windows on ARM requires Windows 10 or later."
		Abort
	${EndIf}
	SetRegView 64
	StrCpy $CreateDesktopIcon 1
FunctionEnd

Function un.onInit
	SetShellVarContext all
	SetRegView 64
FunctionEnd

Function func_DesktopIconPage_Init
	!insertmacro MUI_HEADER_TEXT "Choose shortcuts" "Choose how Krita is made available."
	nsDialogs::Create 1018
	Pop $0
	${If} $0 == error
		Abort
	${EndIf}
	${NSD_CreateCheckbox} 0u 10u 100% 12u "Create a &desktop shortcut"
	Pop $hwndChkDesktopIcon
	${If} $CreateDesktopIcon == 1
		${NSD_Check} $hwndChkDesktopIcon
	${EndIf}
	nsDialogs::Show
FunctionEnd

Function func_DesktopIconPage_Leave
	${NSD_GetState} $hwndChkDesktopIcon $CreateDesktopIcon
FunctionEnd
