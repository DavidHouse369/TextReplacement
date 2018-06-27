<# : Rename the file extension to .ps1 for purely powershell script, or .cmd for batch file starting
@echo off & setlocal

rem # re-launch self with PowerShell interpreter
powershell -noprofile "iex (${%~f0} | out-string)"

goto :EOF
: end batch / begin PowerShell chimera #>
mode con: cols=82 lines=25
clear


<#----------------------------------#
 | Text Replacement Script (Part 1) |
 | Author: David House              |
 | Created: 10/04/2018              |
 | Updated: 22/06/2018              |
 #----------------------------------#>
   $version = '0.6.2'


$exitKeys = ,'32' # Space Bar
$undo = '8' #Backspace

# import GetAsyncKeyState() and MapVirtualKey()
$signatures = @'
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int MapVirtualKey(uint uCode, int uMapType);
'@

$API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

# import System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms

### Check if specific keys are currently pressed ###
function __KeyPressCheck($iStart, $iFinish, $iHexKey = -1) {
	$iVal = @()
	if ($iHexKey -ne -1) {
		$iHex = $API::GetAsyncKeyState("0x" + $iHexKey) -band 32768
		if ($iHex) { $iVal += $API::MapVirtualKey("0x" + $iHex, 2).ToString() }
	} else {
		for ($iKey = $iStart; $iKey -lt $iFinish; $iKey++) {
			$iHex = $API::GetAsyncKeyState("0x" + [Convert]::ToString($iKey, 16)) -band 32768
			if ($iHex) { $iVal += $API::MapVirtualKey("0x" + [Convert]::ToString($iKey, 16), 2).ToString() }
		}
	}
	return $iVal
}

### Returns all keys currently pressed ###
function anyKeyPressed() {
	return __KeyPressCheck 8 221 -1
}

### Check if a specific key is currently pressed ###
function keyPressed($key) {
    return __KeyPressCheck 1 1 $key
}

### Replace the key just typed with the respective replacement ###
function replaceText($textKey, $textReplacement) {
	$count = $textKey.length + 2
	[System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE " + $count + "}")
	$prevClip = [System.Windows.Forms.Clipboard]::GetText()
    Start-Sleep -Milliseconds 10
	[System.Windows.Forms.Clipboard]::SetText($textReplacement)
    Start-Sleep -Milliseconds 25
	[System.Windows.Forms.SendKeys]::SendWait("^v")
    Start-Sleep -Milliseconds 50
    if (($prevClip -ne $null) -and ($prevClip -ne "")) {
        [System.Windows.Forms.Clipboard]::SetText($prevClip)
    } else {
        [System.Windows.Forms.Clipboard]::SetText("")
    }
	
}

### Load all keys and their replacements for use ##
function loadReplacements($display) {
    $global:textReplacements = Import-Clixml $filepath

    # Calculate how much screen space the cmd window needs to take up
	$lineCount = 40
	$longestLineSize = 0

    $customTabSize = 16
	if ($display) {
		Write-Host "Text Replacements - Created by David House.
Version: $version

Current text replacements:"
        $headerStr = "Key:" + (" " * ($customTabSize - 4)) + "Replacement:`n====" + (" " * ($customTabSize - 4)) + "============"
        Write-Host $headerStr
	}

    $keys = $global:textReplacements.Keys | sort

    foreach ($key in $keys) {
        $value = $global:textReplacements.Item($key)
        $tabSize = $customTabSize - $key.length - 1
        $displayStr = "/" + $key + (" " * $tabSize)
        if ($value.Contains("`n")) {
            $lines = $value.Split("`n")
            $lineCount += $lines.length
            foreach ($line in $lines) {
                $displayStr += $line
                if ($line -ne $lines[-1]) {
                    $displayStr += "`n" + (" " * $customTabSize)
                }
                if ($line.length -gt $longestLineSize) {
                    $longestLineSize = $line.length
                }
            }
        } else {
            $displayStr += $value
            $lineCount++
            if ($value.length -gt $longestLineSize) {
                $longestLineSize = $value.length
            }
        }
        if ($key -ne $global:textReplacements.Keys[-1]) {
            $displayStr += "`n"
            $lineCount++
        }
        Write-Host $displayStr
    }
	
	if ($display) {
		Write-Host "

Look for 'TextReplacements.exe' in System Tray for Options"
	}
	
	$longestLineSize += $customTabSize
	
	# Minimum bounds 82x25
	if ($longestLineSize -lt 82) { $longestLineSize = 82 }
	if ($lineCount -lt 25) { $lineCount = 25 }
	
	# Maximum Width 160
	if ($longestLineSize -gt 160) { $longestLineSize = 160 }
	
	$newSize = $longestLineSize, $lineCount
	return $newSize
}

### Returns the time the file was last modified ###
function getCurrModifiedDate() {
	$fileInfo = Get-Item $filepath
	return $fileInfo.LastWriteTime
}

### Compares the time last modified to the value $start ###
function hasFileBeenModified($start) {
    checkForXML
    $end = getCurrModifiedDate
    $diff = New-TimeSpan -Start $start -End $end
    if ($diff -gt 0) {
        return $true
    } else {
        return $false
    }
}

### Check the xml file exists, if not call the new text replacements script ###
function checkForXML() {
    if (-not (Test-Path $filepath)) {
        Write-Host -NoNewline "No text replacements found - Starting text replacement addition script."
        Start-Sleep -Milliseconds 500
        Write-Host -NoNewline "."
        Start-Sleep -Milliseconds 500
        Write-Host -NoNewline "."
        Start-Sleep -Milliseconds 500
        Write-Host -NoNewline "."
        Start-Sleep -Milliseconds 500
        mode con: cols=82 lines=25
        if (Test-Path $createReplacementsFilepath) {
	        Invoke-Expression $createReplacementsFilepath
        } else {
	        Start-Process -Wait $createReplacementsFilepathCMD
        }
    }
}

### The file has been modified, load it again ###
function reloadTextReplacements() {
    checkForXML
	$size = loadReplacements $false
	$cols = $size[0]
	$lines = $size[1]
	# mode con: cols=82 lines=25 # Default
	# mode con: cols=200 lines=83 # Maximum
	$linesCount = 83
	if ($lines -lt 83) { $linesCount = $lines }
	$colsCount = 83
	if ($cols -lt 200) { $colsCount = $cols }
	
	mode con: cols=$colsCount lines=$linesCount
    $host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($cols,$lines)
	clear
	$size = loadReplacements $true
}

### Check to see if the buffer matches a key, and if so trigger the replacement ###
function checkKeyBuffer($buffer) {
    $bufferComparable = -join $buffer | foreach {$_.ToLower()}
    foreach ($key in $global:textReplacements.Keys) {
        if ($bufferComparable -eq $key) {
            replaceText $key $global:textReplacements.Item($key)
            break
        }
    }
}



$global:textReplacements = @{}

$filepath = ".\text_replacements.xml"
$createReplacementsFilepath = ".\text_replacements_new_replacements.ps1"
$createReplacementsFilepathCMD = ".\text_replacements_new_replacements.cmd"
checkForXML
reloadTextReplacements

$currModifiedDate = getCurrModifiedDate

$continue = $true

$intervalTime = 5000 # 5 seconds
$stopwatch = new-object System.Diagnostics.Stopwatch
$targetTime = $intervalTime
$stopwatch.Start()

$keyBuffer = @()
$keysDown = @()
$currKey = ''

Start-Sleep -Milliseconds 10

while ($continue) {
	if ($stopwatch.ElapsedMilliseconds -ge $targetTime) {
        # Check every 5 seconds to see if the file has been modified
		if (hasFileBeenModified $currModifiedDate) {
			Write-Host "
Text Replacements have been modified; reloading Text Replacments..."
			start-sleep -milliseconds 1000
			reloadTextReplacements
			$currModifiedDate = getCurrModifiedDate
		}
		$stopwatch.Restart()
	}
    
    # Get currently pressed keys
    $newKeysDown = anyKeyPressed
    if ($newKeysDown.length -gt 0) {
        foreach ($newkeyDown in $newKeysDown) {
            if (-not ($keysDown.Contains($newkeyDown))) {
                # Ignore any pressed keys that haven't been released since being processed
                $keysDown += $newkeyDown
                if ($newkeyDown -eq $undo) {
                    # If backspace is pressed, remove the last key from the buffer
                    if ($keyBuffer.length -gt 1) { $keyBuffer = $keyBuffer[0..($keyBuffer.length - 2)] }
                    else { $keyBuffer = @() }
                } elseif ($exitKeys.contains($newkeyDown)) {
                    # If space is pressed, check if a key has been entered
                    checkKeyBuffer $keyBuffer[1..($keyBuffer.length - 1)]
                    $keyBuffer = @()
                } elseif (([int]$newKeyDown -ge 33) -and ([int]$newkeyDown -le 126)) {
                    if ([char][int]$newKeyDown -eq '/') {
                        # If '/' is pressed, start the buffer reading
                        $keybuffer = @()
                        $keyBuffer += [char][int]$newKeyDown
                    } elseif ($keyBuffer.Length -gt 0) {
                        # Add each key to the buffer
                        $keyBuffer += [char][int]$newKeyDown
                    }
                }
            }
        }

        # Loop through currently pressed keys and check if they have been released
        for ($i = $keysDown.length - 1; $i -ge 0; $i--) {
            if (-not ($newKeysDown.Contains($keysDown[$i]))) {
                # If the key has been released, remove it from current processing array
                if ($i -eq 0) {
                    # remove first item
                    $keysDown = $keysDown[1..($keysDown.length - 1)]
                } elseif ($i -lt $keysDown.Length - 1) {
                    # remove middle items
                    $keysDown = $keysDown[0..($i - 1)] + $keysDown[($i + 1)..($keysDown.length - 1)]
                } else {
                    # remove last item
                    $keysDown = $keysDown[0..($keysDown.length - 2)]
                }
            }
        }
    } else {
        # There are currently no keys pressed
        if ($keysDown.length -gt 0) {
            $keysDown = @()
        }
    }

    # Sleep to avoid locking up the system
	start-sleep -milliseconds 10
}

$Host.UI.RawUI.FlushInputBuffer()