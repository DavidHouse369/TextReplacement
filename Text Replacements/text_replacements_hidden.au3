#NoTrayIcon
#include <AutoItConstants.au3>
#include <MsgBoxConstants.au3>
;~ #include <StringConstants.au3>
#include <TrayConstants.au3> ; Required for the $TRAY_ICONSTATE_SHOW constant.

Opt("TrayMenuMode", 3)

Local $idShow = TrayCreateItem("Show")
Local $idHide = TrayCreateItem("Hide")
Local $idAddTextReplacements = TrayCreateItem("Add Text Replacements")
Local $idExit = TrayCreateItem("Exit")
TraySetState($TRAY_ICONSTATE_SHOW)

$sFilePath = @ScriptDir & "\text_replacements.xml"
$bFileExists = FileExists($sFilePath)

Local $ihWnd
If Not $bFileExists Then
   AddNewTextReplacements(True)
Else
   RunMainScript(True)
EndIf

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
;~ 		 ExitScript(False)
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
   Run('powershell.exe ".\text_replacements.ps1"', @ScriptDir, @SW_MINIMIZE)

   WinWait("Windows PowerShell")
   $ihWnd = WinGetHandle("Windows PowerShell")
   HideScript(False)
   If $showMsg Then TrayTip("Text Replacement Script Running", "Text Replacement script is now running in the background. Select this icon for options.", 10, 1)
EndFunc

Func AddNewTextReplacements($showMsg)
   If $showMsg Then ShowMsg("Adding")
   RunWait('powershell.exe ".\text_replacements_new_replacements.ps1"')
;~    RunWait("text_replacements_new_replacements.ps1")
;~    RunMainScript($showMsg)
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
   WinMove($ihWnd, "", 0, 0)
   If $showMsg Then ShowMsg("Showing")
EndFunc

Func ExitScript($showMsg)
   ShowScript(False)
   If $showMsg Then ShowMsg("Closing")
   WinClose($ihWnd)
EndFunc