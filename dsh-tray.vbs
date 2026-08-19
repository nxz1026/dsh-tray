' DSH Web tray launcher: starts assets\dsh-tray.ps1 with no console window.
' Double-click this file (it runs under wscript.exe) and no window appears.
Option Explicit

Dim shell, ps1Path, psCmd
ps1Path = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & "assets\dsh-tray.ps1"
psCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1Path & """"

Set shell = CreateObject("WScript.Shell")
shell.Run psCmd, 0, False
Set shell = Nothing
