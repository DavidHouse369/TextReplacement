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

$sFilePath = @ScriptDir & "\text_replacements.txt"
$bFileExists = FileExists($sFilePath)

Local $ihWnd
If Not $bFileExists Then
   AddNewTextReplacements(True)
Else
   RunMainScript(False)
EndIf

While 1
   If Not WinExists($ihWnd) Then
	  ShowMsgBox("Closed")
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
		 AddNewTextReplacements(True)
	  Case $idExit
		 ExitScript(True)
		 ExitLoop
   EndSwitch
WEnd

Func ShowMsgBox($type)
   If $type == "Adding" Then
	  MsgBox(64, $type & "...", "Running script to add new text replacements." & @CRLF & "(This window will close automatically after two seconds)", 2)
   ElseIf $type == "Closed" Then
	  MsgBox(64, "Closing" & "...", "Text Replacement script has closed." & @CRLF & "(This window will close automatically after two seconds)", 2)
   Else
	  MsgBox(64, $type & "...", $type & " Text Replacement script." & @CRLF & "(This window will close automatically after two seconds)", 2)
   EndIf
EndFunc

Func RunMainScript($showMsg)
   If $showMsg Then ShowMsgBox("Running")
   Run("text_replacements.cmd")
   WinWait("Windows PowerShell")
   WinActivate("Windows PowerShell")
   $ihWnd = WinGetHandle("Windows PowerShell")
   WinMove($ihWnd, "", 0, 0)
;~    HideScript(True)
EndFunc

Func AddNewTextReplacements($showMsg)
   If $showMsg Then ShowMsgBox("Adding")
   RunWait("text_replacements_new_replacements.cmd")
;~    RunMainScript($showMsg)
EndFunc

Func HideScript($showMsg)
   If $showMsg Then ShowMsgBox("Hiding")
   WinSetState($ihWnd, "", @SW_HIDE)
EndFunc

Func ShowScript($showMsg)
   WinSetState($ihWnd, "", @SW_SHOW)
   WinSetState($ihWnd, "", @SW_RESTORE)
   If $showMsg Then ShowMsgBox("Showing")
EndFunc

Func ExitScript($showMsg)
   ShowScript(False)
   If $showMsg Then ShowMsgBox("Closing")
   WinClose($ihWnd)
EndFunc