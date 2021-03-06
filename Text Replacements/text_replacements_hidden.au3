#NoTrayIcon
#include <Misc.au3>
#include <WinAPIGdi.au3>
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
#include <TrayConstants.au3> ; Required for the $TRAY_ICONSTATE_SHOW constant.

If _Singleton("TextReplacements", 1) == 0 Then
   MsgBox(64, "Warning", "Only once instance of TextReplacements can be running at once." & @CRLF & "(This window will close automatically after two seconds)", 2)
   Exit
EndIf

; Default tray menu items will not be shown and no tick marks.
Opt("TrayMenuMode", 3)

; Set Title Match Mode to match exactly
Opt("WinTitleMatchMode", 3)

$aData = _WinAPI_GetMonitorInfo(1)

Local $idShow = TrayCreateItem("Show")
Local $idHide = TrayCreateItem("Hide")
Local $idAddTextReplacements = TrayCreateItem("Add Text Replacements")
Local $idExit = TrayCreateItem("Exit")
TraySetState($TRAY_ICONSTATE_SHOW)
TraySetToolTip("Text Replacements")

$sFilePath = @ScriptDir & "\text_replacements.xml"
$bFileExists = FileExists($sFilePath)

$sScriptPowerShellPath = '\text_replacements.ps1'
$sScriptCMDPath = @ScriptDir & '\text_replacements.cmd'
$sAddScriptPowerShellPath = '".\text_replacements_new_replacements.ps1"'
$sAddScriptCMDPath = @ScriptDir & '\text_replacements_new_replacements.cmd'

$bUsePowerShell = FileExists(@ScriptDir & $sScriptPowerShellPath)
If $bUsePowerShell Then
   $sScriptPowerShellPath = '".' & $sScriptPowerShellPath & '"'
EndIf

Local $ihWnd
If Not $bFileExists Then
   AddNewTextReplacements(True)
EndIf

RunMainScript(True)

While 1
   If Not WinExists($ihWnd) Then
	  ShowMsg("Closed")
	  ExitLoop
   EndIf
   If BitAND(WinGetState($ihWnd), $WIN_STATE_VISIBLE) Then
	  If BitAND(WinGetState($ihWnd), $WIN_STATE_MINIMIZED) Then
		 Sleep(300)
		 HideScript(False)
	  EndIf
   EndIf
   Switch TrayGetMsg()
	  Case $idHide
		 HideScript(False)
	  Case $idShow
		 ShowScript(False)
	  Case $idAddTextReplacements
		 ShowScript(False)
		 AddNewTextReplacements(False)
	  Case $idExit
		 ExitScript(False)
		 ExitLoop
   EndSwitch
WEnd

Func ShowMsg($type)
   If $type == "Adding" Then
	  MsgBox(64, $type & "...", "Running script to add new text replacements." & @CRLF & "(This window will close automatically after two seconds)", 2)
   ElseIf $type == "Closed" Then
	  MsgBox(64, "Closing" & "...", "Text Replacement script has closed." & @CRLF & "(This window will close automatically after two seconds)", 2)
   Else
	  MsgBox(64, $type & "...", $type & " Text Replacement script." & @CRLF & "(This window will close automatically after two seconds)", 2)
   EndIf
EndFunc

Func RunMainScript($showMsg)
   If $bUsePowerShell Then
	  Run('powershell.exe ' & $sScriptPowerShellPath, @ScriptDir, @SW_MINIMIZE)
   Else
	  Run($sScriptCMDPath, @ScriptDir, @SW_MINIMIZE)
   EndIf

   WinWait("Windows PowerShell")
   $ihWnd = WinGetHandle("Windows PowerShell")
   HideScript(False)
   If $showMsg Then TrayTip("Text Replacement Script Running", "Text Replacement script is now running in the background. Select this icon for options.", 10, 1)
EndFunc

Func AddNewTextReplacements($showMsg)
   If $showMsg Then ShowMsg("Adding")
   If $bUsePowerShell Then
	  RunWait('powershell.exe ' & $sAddScriptPowerShellPath)
   Else
	  RunWait($sAddScriptCMDPath)
   EndIf
EndFunc

Func HideScript($showMsg)
   If $showMsg Then ShowMsg("Hiding")
   If not BitAND(WinGetState($ihWnd, ""), $WIN_STATE_MINIMIZED) Then
	  WinSetState($ihWnd, "", @SW_MINIMIZE)
   EndIf
   WinSetState($ihWnd, "", @SW_HIDE)
EndFunc

Func ShowScript($showMsg)
   WinSetState($ihWnd, "", @SW_SHOW)
   WinSetState($ihWnd, "", @SW_RESTORE)
   WinMove($ihWnd, "", 0, 0, DllStructGetData($aData[1], 3), DllStructGetData($aData[1], 4))
   If $showMsg Then ShowMsg("Showing")
EndFunc

Func ExitScript($showMsg)
   ShowScript(False)
   If $showMsg Then ShowMsg("Closing")
   WinClose($ihWnd)
EndFunc