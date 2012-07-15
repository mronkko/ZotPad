'  link_zotero_windows.vbs
'  ZotPad
'
'  Created by Mikko Rönkkö on 7/11/12.
'  Copyright (c) 2012 Helsiki University of Technology. All rights reserved.


If WScript.Arguments.length =0 Then
  Set objShell = CreateObject("Shell.Application")
  'Pass a bogus argument with leading blank space, say [ uac]
  objShell.ShellExecute "wscript.exe", Chr(34) & _
  WScript.ScriptFullName & Chr(34) & " uac", "", "runas", 1
Else

' Locate profile directory. 

Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
Set env = shell.Environment("PROCESS")

If fileSystem.FileExists(env("APPDATA") & "\Zotero\Zotero\profiles.ini") Then

profileBase=env("APPDATA") & "\Zotero\Zotero"

ElseIf fileSystem.FileExists(env("APPDATA") & "\Mozilla\Firefox\profiles.ini") Then

profileBase=env("APPDATA") & "\Mozilla\Firefox"

Else

WScript.Echo "Could not locate Firefox or Zotero Standalone profile"
WScript.Quit 1

End If


' Parse the default profile

Set profilesIni = fileSystem.OpenTextFile((profileBase & "\profiles.ini"),1)

Set pathRegex = CreateObject("VBScript.RegExp")
pathRegex.Pattern = "Path=(.*)"

Do Until profilesIni.atEndOfStream
	line =  profilesIni.ReadLine
	If line = "Default=1" Then
		Exit Do
	End If

	Set matches= pathRegex.Execute(line)
	
	If matches.Count > 0 Then
		path = Replace(matches(0).SubMatches(0),"/","\")
	End if

Loop

' Parse preferences

If Not fileSystem.FileExists(profileBase & "\" & path & "\prefs.js") Then

WScript.Echo "Could not locate preferences file"
WScript.Quit 1

End If

Set prefsJs = fileSystem.OpenTextFile(profileBase & "\" & path & "\prefs.js",1)

Set dataDirRegex = CreateObject("VBScript.RegExp")
dataDirRegex.Pattern = "user_pref(""extensions.zotero.dataDir"", ""(.*)"");"

useDatadir = False

Do Until prefsJs.atEndOfStream
	line =  prefsJs.ReadLine
	If line = "user_pref(""extensions.zotero.useDataDir"", true);" Then
		useDatadir = True
	End If

	Set matches= dataDirRegex.Execute(line)
	
	If matches.Count > 0 Then
		dataDirPath = matches(0).SubMatches(0)
	End if

Loop

If Not useDataDir Then
	dataDirPath = profileBase & "\" & path &"\zotero"
End If

' Set up symlink

If fileSystem.FolderExists(dataDirPath) Then

currentDirectory = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))

WScript.Echo "Linking ZotPad App folder at "&currentDirectory& "\storage to Zotero storage directory at "& dataDirPath & "\storage"

'Set up the symbolic link
shell.Run "cmd.exe /c mklink /D " & currentDirectory & "\storage " & dataDirPath & "\storage & pause"

Else

WScript.Echo "Could not locate Zotero data directory"
WScript.Quit 1

End If


End If

