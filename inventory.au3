#include <File.au3>
#include <SQLite.au3>
#include <SQLite.dll.au3>
#include <Date.au3>
#include "CompInfo.au3"

; CompInfo Credit https://www.autoitscript.com/forum/applications/core/interface/file/attachment.php?id=12096

; author: korayy
; date:   200312
; desc:   inventory script
; version: 0.1

#Region ;**** Directives ****
#AutoIt3Wrapper_Res_ProductName=Envanterci
#AutoIt3Wrapper_Res_Description=Basit bir envanter programi
#AutoIt3Wrapper_Res_Fileversion=0.1.0.1
#AutoIt3Wrapper_Res_Fileversion_AutoIncrement=p
#AutoIt3Wrapper_Res_ProductVersion=0.1
#AutoIt3Wrapper_Res_LegalCopyright=ARYASOFT
#AutoIt3Wrapper_OutFile="dist\inventory.exe"
#EndRegion ;**** Directives ****


Global Const $DEBUG = True
Global Const $DEBUG_LOGFILE = @ScriptDir & "\inventory_" & @MON & @MDAY & @YEAR & "_" & @HOUR & @MIN & @SEC & ".txt"
Global Const $DBFILE_PATH = @WorkingDir & "\inventory.db"


;~ debug helper function
Func _DebugPrint($sMsgString)
	ConsoleWrite($sMsgString & @CRLF)
	If $DEBUG Then
		_FileWriteLog($DEBUG_LOGFILE, $sMsgString)
	EndIf
EndFunc   ;==>_DebugPrint

; yyyy-mm-dd hh:mm:ss formatinda veya epoch formatinda guncel tarih zaman doner
Func _GetDatetime($bTimestamp = False)
	$timestamp = _DateDiff('s', "1970/01/01 00:00:00", _NowCalc())
	$timedate = StringReplace(_NowCalc(), "/", "-")
	If $bTimestamp Then
		Return $timestamp
	EndIf
	Return $timedate
EndFunc   ;==>_GetDatetime

;~ sqlite veri tabani init
Func _DBInit()
	Local $hDB;
	_SQLite_Startup()
	_DebugPrint("_SQLite_LibVersion=" & _SQLite_LibVersion() & @CRLF)
	If @error Then Exit MsgBox(16, "SQLite Hata", "SQLite.dll yuklenemedi!")
	If FileExists($DBFILE_PATH) Then
		_DebugPrint($DBFILE_PATH & " aciliyor..." & @CRLF)
		$hDB = _SQLite_Open($DBFILE_PATH)
		If @error Then Exit MsgBox(16, "SQLite Hata", "Veri tabanı açılamadı!")
	Else
		$hDB = _SQLite_Open($DBFILE_PATH)
		If @error Then Exit MsgBox(16, "SQLite Hata", "Veri tabanı açılamadı!")
		; Yeni tablo olustur Processor
		_SQLite_Exec(-1, "CREATE TABLE Processor ( " & _
							"id	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, " & _
							"speed	INTEGER NOT NULL, " & _
							"arch	INTEGER, " & _
							"status	TEXT, " & _
							"family	INTEGER, " & _
							"manufacturer	TEXT, " & _
							"processor_id	TEXT UNIQUE );")
		; Yeni tablo olustur Memory
		_SQLite_Exec(-1, "CREATE TABLE Memory ( " & _
							"id	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, " & _
							"label	TEXT UNIQUE, " & _
							"capacity	INTEGER, " & _
							"speed	INTEGER);")
		; Yeni tablo olustur Software
		_SQLite_Exec(-1, "CREATE TABLE Software ( " & _
							"id	INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, " & _
							"name	TEXT UNIQUE, " & _
							"publisher	TEXT, " & _
							"version	TEXT, " & _
							"install_date	TEXT, " & _
							"is_deleted	INTEGER DEFAULT 0 );")
	EndIf
	Return $hDB
EndFunc


; Hardware tablosuna kayıt ekler ve sql exec sonucu durumunu doner
Func _DB_InsertProcessor($cpu_speed, $arch, $status, $family, $manufacturer, $processor_id)
	Local $d = _SQLite_Exec(-1, "INSERT INTO main.Processor(speed, arch, status, family, manufacturer, processor_id) " & _
							"VALUES (" & $cpu_speed & "," & _SQLite_FastEscape($arch) & "," & _SQLite_FastEscape($status) & "," & _
							_SQLite_FastEscape($family) & "," & _SQLite_FastEscape($manufacturer) & "," & _SQLite_FastEscape($processor_id) & ");")
	Return $d
EndFunc

Func _DB_InsertMemory($label, $capacity, $speed)
	Local $d = _SQLite_Exec(-1, "INSERT INTO main.Memory(label, capacity, speed) " & _
							"VALUES (" & _SQLite_FastEscape($label) & "," & $capacity & "," & $speed & ");")
	Return $d
EndFunc

Func _DB_InsertSoftware($name, $publisher, $version, $install_date)
	Local $d = _SQLite_Exec(-1, "INSERT INTO main.Software(name, publisher, version, install_date) " & _
							"VALUES (" & _SQLite_FastEscape($name) & "," & _SQLite_FastEscape($publisher) & "," & _
							_SQLite_FastEscape($version) & "," & _SQLite_FastEscape($install_date) & ");")
	Return $d
EndFunc

Func InventoryProcessor()
	Dim $Processors

	_ComputerGetProcessors($Processors)
	If @error Then
		$error = @error
		$extended = @extended
		Switch $extended
			Case 1
				_DebugPrint($ERR_NO_INFO)
			Case 2
				_DebugPrint($ERR_NOT_OBJ)
		EndSwitch
	EndIf
	_DebugPrint("Inserting processor")
	For $i = 1 To $Processors[0][0] Step 1
		Local $d = _DB_InsertProcessor( $Processors[$i][23], $Processors[$i][2], $Processors[$i][33], _
										$Processors[$i][16], $Processors[$i][22], $Processors[$i][28])
		If $d <> $SQLITE_OK  And $d <> $SQLITE_CONSTRAINT Then
			_DebugPrint("SQL Insert Hatasi: _DB_InsertProcessor SQLITE hata kodu: " & $d)
			Return
		EndIf
	Next
	Return $d
EndFunc

Func InventoryMemory()
	Dim $Memory
	_ComputerGetMemory($Memory)
	If @error Then
		$error = @error
		$extended = @extended
		Switch $extended
			Case 1
				_DebugPrint($ERR_NO_INFO)
			Case 2
				_DebugPrint($ERR_NOT_OBJ)
		EndSwitch
	EndIf

	_DebugPrint("Inserting memory")

	For $i = 1 To $Memory[0][0] Step 1
		Local $d = _DB_InsertMemory($Memory[$i][1], $Memory[$i][2], $Memory[$i][22])
		If $d <> $SQLITE_OK  And $d <> $SQLITE_CONSTRAINT Then
			_DebugPrint("SQL Insert Hatasi: _DB_InsertMemory SQLITE hata kodu: " & $d)
			Return
		EndIf
	Next

	Return $d
EndFunc

Func InventorySoftware()
	Dim $Software
	_ComputerGetSoftware($Software)

	If @error Then
		$error = @error
		$extended = @extended
		Switch $extended
			Case 1
				_DebugPrint("Array contains no data.")
		EndSwitch
	EndIf

	_DebugPrint("Inserting software")

	For $i = 1 To $Software[0][0] Step 1
		If $Software[$i][0] = "" Then
			ContinueLoop
		EndIf
		Local $d = _DB_InsertSoftware($Software[$i][0], $Software[$i][2], $Software[$i][1], $Software[$i][3])
		If $d <> $SQLITE_OK  And $d <> $SQLITE_CONSTRAINT Then
			_DebugPrint("SQL Insert Hatasi: _DB_InsertMemory SQLITE hata kodu: " & $d)
			Return
		EndIf
	Next
	Return $d
EndFunc


;~  ana program
Func _Main()
	_DBInit()
    InventoryProcessor()
	InventoryMemory()
	InventorySoftware()
EndFunc

_Main()