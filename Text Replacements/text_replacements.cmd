<# : batch portion (begins PowerShell multiline comment block)
@echo off & setlocal

rem # re-launch self with PowerShell interpreter
powershell -noprofile "iex (${%~f0} | out-string)"

echo Closing

goto :EOF
: end batch / begin PowerShell chimera #>

$exitKeys = ,'32' # Space Bar
$undo = '8' #Backspace

# import GetAsyncKeyState()
$signatures = @'
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int MapVirtualKey(uint uCode, int uMapType);
'@

$API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

# import System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms


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

function anyKeyPressed() {
	return __KeyPressCheck 8 221 -1
}

function keyPressed($key) {
    return __KeyPressCheck 1 1 $key
}

function replaceText($textKey, $textReplacement) {
	$count = $textKey.length + 1
	[System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE " + $count + "}")
	start-sleep -milliseconds 10
	# $textReplacement = $textReplacement.Replace("\n", "`n")
	$prevClip = [System.Windows.Forms.Clipboard]::GetText()
	start-sleep -milliseconds 10
	[System.Windows.Forms.Clipboard]::SetText($textReplacement)
	start-sleep -milliseconds 50
	[System.Windows.Forms.SendKeys]::SendWait("^v")
	start-sleep -milliseconds 50
	[System.Windows.Forms.Clipboard]::SetText($prevClip)
}

function loadReplacements($display) {
	if ($display) {
		Write-Host 'Text Replacements - Created by David House.'
		Write-Host ''
		Write-Host 'Current text replacements:'
	}
	$fileContents = Get-Content -Path $filepath
	$lineCount = 9
	$longestLineSize = 0
	$global:textReplacements = @()
	for ($i = 1; $i -lt $fileContents.Count; $i++) {
		$lineCount++
		$newTextReplacement = $fileContents[$i].Split(",")
		$newTextReplacement[1] = $newTextReplacement[1].Replace("\n", "`n")
		$replacementToDisplay = $newTextReplacement[1].Replace("`n", "`n" + "              ")
		$textToDisplay = 'Key:          ' + $newTextReplacement[0] + "`n" + 'Replacement:  ' + $replacementToDisplay
		if ($display) { Write-Host $textToDisplay }
		if ($i -lt $fileContents.Count - 1) {
			if ($display) { Write-Host '' }
			$lineCount++
		}
		$global:textReplacements += ,($newTextReplacement[0], -1, $newTextReplacement[1])
		if ($newTextReplacement[1].Contains("`n")) {
			$temp = $newTextReplacement[1].Split("`n")
			foreach ($line in $temp.GetEnumerator()) {
				$lineCount++
				if ($line.length -gt $longestLineSize) {
					$longestLineSize = $line.length
				}
			}
		} else {
			$lineCount++
			if ($newTextReplacement[1].length -gt $longestLineSize) {
				$longestLineSize = $newTextReplacement[1].length
			}
		}
	}
	
	if ($display) {
		Write-Host ''
		Write-Host ''
		Write-Host 'Look for "TextReplacements.exe" in System Tray for Options'
	}
	
	$longestLineSize += 14
	
	# Minimum bounds 82x25
	if ($longestLineSize -lt 82) { $longestLineSize = 82 }
	if ($lineCount -lt 25) { $lineCount = 25 }
	
	# Maximum Width 160
	if ($longestLineSize -gt 160) { $longestLineSize = 160 }
	
	$newSize = $longestLineSize, $lineCount
	return $newSize
}

function getCurrModifiedDate() {
	$fileInfo = Get-Item $filepath
	return $fileInfo.LastWriteTime
}

function hasFileBeenModified($start) {
    $end = getCurrModifiedDate
    $diff = New-TimeSpan -Start $start -End $end
    if ($diff -gt 0) {
        return $true
    } else {
        return $false
    }
}

function reloadTextReplacements() {
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

function checkKeyBuffer($buffer) {
    $bufferComparable = -join $buffer | foreach {$_.ToLower()}
    foreach ($replacement in $global:textReplacements) {
        if ($bufferComparable -eq $replacement[0]) { # TODO: figure out a way to compare two arrays to ensure they are the same
            replaceText $replacement[0] $replacement[2]
            break
        }
    }
}

$global:textReplacements = @()

$filepath = ".\text_replacements.txt"
$batchFilepath = ".\text_replacements_new_replacements.cmd"
if (-not (Test-Path $filepath)) {
	start $batchFilepath -Wait
}

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
		if (hasFileBeenModified $currModifiedDate) {
			Write-Host ''
			Write-Host 'Text Replacements have been modified; reloading Text Replacments...'
			start-sleep -milliseconds 1000
			$currModifiedDate = getCurrModifiedDate
			reloadTextReplacements
		}
		$stopwatch.Restart()
	}

    $changeOccurred = $false
    $newKeysDown = anyKeyPressed
    if ($newKeysDown.length -gt 0) {
        foreach ($newkeyDown in $newKeysDown) {
            if (-not ($keysDown.Contains($newkeyDown))) {
                $keysDown += $newkeyDown
                if ($newkeyDown -eq $undo) {
                    if ($keyBuffer.length -gt 1) { $keyBuffer = $keyBuffer[0..($keyBuffer.length - 2)] }
                    else { $keyBuffer = @() }
                } elseif ($exitKeys.contains($newkeyDown)) {
                    checkKeyBuffer $keyBuffer
                    $keyBuffer = @()
                } elseif (([int]$newKeyDown -ge 33) -and ([int]$newkeyDown -le 126)) {
                    if ([char][int]$newKeyDown -eq '/') {
                        $keybuffer = @()
                        $keyBuffer += [char][int]$newKeyDown
                        $changeOccurred = $true
                    } elseif ($keyBuffer.Length -gt 0) {
                        $keyBuffer += [char][int]$newKeyDown
                        $changeOccurred = $true
                    }
                }
            }
        }
        for ($i = $keysDown.length - 1; $i -ge 0; $i--) {
            if (-not ($newKeysDown.Contains($keysDown[$i]))) {
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
                $changeOccurred = $true
            }
        }
        
        if ($changeOccurred) {
            #Write-Host 'Change' $keysDown -NoNewline -Separator ','
            #Write-Host ''
        }
    } else {
        if ($keysDown.length -gt 0) {
            $keysDown = @()
            #Write-Host 'Empty'
        }
    }
    #Write-Host 'Outside' $keysDown -NoNewline -Separator ','
    #Write-Host ''
    #Write-Host $keyBuffer
	start-sleep -milliseconds 10
}

$Host.UI.RawUI.FlushInputBuffer()