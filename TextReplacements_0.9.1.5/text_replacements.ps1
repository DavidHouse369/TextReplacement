param (
    $pipeLobbyName,
    $version
)

Import-Module $PSScriptRoot\PSNamedPipes.psm1
Import-Module $PSScriptRoot\PSHideShowConsole.psm1


mode con: cols=82 lines=25
clear

Hide-Console

$exitKeys = ,'32' # Space Bar
$undo = '8' #Backspace
$keysToCheck = @()
$keysToCheck += 48..57 # 0,1,2,3,4,5,6,7,8,9
$keysToCheck += 65..90 # a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z
$keysToCheck += 96..107 # 0,1,2,3,4,5,6,7,8,9,*,+
$keysToCheck += 109..111 # -,.,/
$keysToCheck += 186..192 # ;,=,,,-,.,/,`
$keysToCheck += 219..222 # [,\,],'
$keysToCheck += $exitKeys
$keysToCheck += $undo

# import System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms

### BEGIN TEXT REPLACEMENT FUNCTIONS ###
#region text replacement functions
### Replace the key just typed with the respective replacement ###
function replaceText($textKey, $textReplacement) {
	$count = $textKey.length + 2
	[System.Windows.Forms.SendKeys]::SendWait("{BACKSPACE " + $count + "}")
	$prevClip = Get-Clipboard
	Set-Clipboard $textReplacement
	[System.Windows.Forms.SendKeys]::SendWait("^v")
    Start-Sleep -Milliseconds 50
    Set-Clipboard $prevClip
	
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

Current text replacements:`n"
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

Look for 'Text Replacements' in System Tray for Options"
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

### Check the xml file exists, if not call the new text replacements script ###
function checkForXML() {
    Test-Path $filepath
}

### The file has been modified, load it again ###
function reloadTextReplacements() {
    if (checkForXML) {
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

        $true
    } else {
	    mode con: cols=82 lines=25 # Default
        clear
        Show-Console -moveToTopLeft
        Write-Host "Text Replacements - Created by David House.
Version: $version

No text replacements present. Text replacements must be added in order to be used.
"
        $false
    }
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
#endregion
###  END TEXT REPLACEMENT FUNCTIONS  ###

### BEGIN PIPE CLIENT FUNCTIONS ###
#region pipe client functions
function OnMessageReceived {
    # Function triggered when a message is received from the server
    param ( $message )

    # Since we're working Async, sometimes messages can back up and combine into one
    # In this instance we are adding a 'end message' string as '<<>>'
    $messages = $message -split '<<>>'

    # Process each message
    foreach ($message in $messages) {
        if ($message -ne '') {
            # Announce the message
            #Write-Host "Server : $message"

            # If there is more than one part to the message, split by ':' (Format = 'command:arg1:arg2' etc)
            $messageSplit = $message.Split(':')

            switch ($messageSplit[0]) {
                'exit' {
                    $global:continue = $false
                }
                'hide' {
                    $global:isHidden = $true
                    Hide-Console
                }
                'show' {
                    Show-Console -moveToTopLeft
                    $global:isHidden = $false
                }
                'marco' {
                    # The server in pinging us, respond
                    Send-Message "polo"
                }
            }
        }
    }
}

function OnPipeNameReceived {
    # Function triggered when a unique pipe name has been received from the server
    param ( $pipeName )
    Write-Host $pipeName

    # Close off the current connection to the lobby
    $global:clientPipe.Close()

    # Restart the pipe with the new name and connect
    $global:clientPipe = New-NamedPipeClient -PipeName $pipeName
    $global:clientPipe.Connect(60000)

    # Start listening first for the pipe ID, then for any further messages
    $global:clientPipe.BeginRead({
        OnPipeIDReceived $args[0]
        $global:clientPipe.BeginRead({ OnMessageReceived $args[0] })
        Send-Message "connected:script"
        $global:connected = $true
    })
}

function OnPipeIDReceived {
    # Function triggered when a unique pipe name has been received from the server
    param ( $newPipeID )
    Write-Host "Pipe ID: $newPipeID"
    
    # Leave a gap for Write-Progress to fill
    Write-Host "-`n-`n-`n-"

    $global:pipeID = $newPipeID
}

function Send-Message {
    # Function to send a message to the server
    param ( $message )

    # Add the ID to the message so the server know who's talking
    $message = $global:pipeID + ':' + $message

    # Send this to the server
    $global:clientPipe.BeginWrite("$message<<>>")
}
#endregion
###  END PIPE CLIENT FUNCTIONS  ###


# The ID of this pipe as defined by the server once connected
$global:pipeID = -1

$global:connected = $false

# Create the PipeClient object and connect
$global:clientPipe = New-NamedPipeClient -PipeName $pipeLobbyName
$global:clientPipe.Connect(60000)
$global:clientPipe.BeginRead({ OnPipeNameReceived $args[0] })

# Wait until connected before setting up text replacements
while (-not $global:connected) {
    Start-Sleep -Milliseconds 10
}

# Begin setup for text replacments
$global:textReplacements = @{}

$filepath = ".\text_replacements.xml"
$createReplacementsFilepath = ".\text_replacements_new_replacements.ps1"
#checkForXML # Not needed as the below function calls this anyway
if (-not (reloadTextReplacements)) {
    Send-Message 'add'
    while (-not (reloadTextReplacements)) {
        Start-Sleep 1
    }
}

$jobName = 'KeyListener'

Start-Job -Name $jobName -ArgumentList @($keysToCheck),@($exitKeys) -ScriptBlock {
    param (
        [int[]]$keysToCheck,
        [string[]]$exitKeys
    )

    [System.Threading.Thread]::CurrentThread.Priority = 'Highest'

    # import GetAsyncKeyState() and MapVirtualKey()
    $signatures = @'
        [DllImport("user32.dll")]
        public static extern short GetAsyncKeyState(int vKey);
        [DllImport("user32.dll", CharSet=CharSet.Auto)]
        public static extern int MapVirtualKey(uint uCode, int uMapType);
'@

    $API = Add-Type -MemberDefinition $signatures -Name 'Win32' -Namespace API -PassThru

    ### Check if specific keys are currently pressed ###
    function __KeyPressCheck($iStart = 1, $iFinish = 1, $iHexKey = -1, $aKeyCodes = @()) {
	    $iVal = @()
        if ($iHexKey -ne -1) {
		    $iHex = $API::GetAsyncKeyState("0x" + $iHexKey) -band 32768
		    if ($iHex) { $iVal += $API::MapVirtualKey("0x" + $iHex, 2).ToString() }
	    } else {
            if ($aKeyCodes.Length -eq 0) {
                $aKeyCodes = $iStart..$iFinish
            }

            foreach ($iKey in $aKeyCodes) {
			    $iHex = $API::GetAsyncKeyState("0x" + [Convert]::ToString($iKey, 16)) -band 32768
			    if ($iHex) { $iVal += $API::MapVirtualKey("0x" + [Convert]::ToString($iKey, 16), 2).ToString() }
		    }
	    }
	    return $iVal
    }

    ### Returns all keys currently pressed ###
    function anyKeyPressed($aKeyCodes = @()) {
	    __KeyPressCheck 8 221 -1 $aKeyCodes
    }

    ### Check if a specific key is currently pressed ###
    function keyPressed($key) {
        __KeyPressCheck 1 1 $key
    }
    
    $newKeysDown = @()
    $keysDown = @()
    $keyBuffer = @()

    while ($true) {
        $keysPressed = anyKeyPressed | Where {$_ -ne $null}
        #$keysPressed

        if ($keysPressed.Length -gt 0) {
            $newKeysDown = @()
            $keysDown | foreach {
                if ($keysPressed.Contains($_)) {
                    $newKeysDown += ,$_
                }
            }
            $keysDown = $newKeysDown

            $keyBuffer = @()
            $keysPressed | foreach {
                if (-not $keysDown.Contains($_)) {
                    $keysDown += ,$_
                    $keyBuffer += ,$_
                }
            }
        } else {
            $keysDown = @()
            $keyBuffer = @()
        }

        # Return the buffer
        $keyBuffer
    }
} | Out-Null

function Watch-File {
    param (
        [string]$FilePath,
        [scriptblock]$Callback
    )

    $FilePathSplit = $FilePath.Split('/\')
    $dirPath = $FilePathSplit[0..($FilePathSplit.Length - 2)] -join '\'
    $filename = $FilePathSplit[-1]

    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = $dirPath
    $watcher.Filter = $filename
    $watcher.NotifyFilter = 'LastWrite'

    $lastModified = $null

    Register-ObjectEvent -InputObject $watcher -EventName 'Changed' -Action $Callback
}

$filepath = "$PSScriptRoot\FileWatcherTest.txt"

$action = {
    # Compare LastWriteTime to avoid duplicate events.
    $lastWrite = (Get-Item $FilePath).LastWriteTime.ToString("hh:mm:ss.ff")
    if ($lastWrite -ne $lastModified) {
        $lastModified = $lastWrite
        Write-Host "`nText Replacements have been modified; reloading Text Replacments..."
		Sleep -milliseconds 1000
		reloadTextReplacements | Out-Null
    }
}

$eventChanged = Watch-File -FilePath $filepath -Callback $action

$startTimeForMinimisedCheck = Get-Date
$intervalForMinimisedCheck = 10
$global:isHidden = $false
$global:isShowing = $false

$keys = @()
$keyBuffer = @()

$global:continue = $true

while ($global:continue) {
    # Reduce CPU load
    Start-Sleep -Milliseconds 10

    if ((-not $global:isHidden) -and (Get-ConsoleMinimized)) {
        $global:isHidden = $true
        Hide-Console -delay 300
    }

    $keys = Receive-Job -Name $jobName | Where {$_ -ne $null}

    if ($keys.Length -gt 0) {
        $keys | foreach {
            if ([char][int]$_ -eq '/') {
                # If '/' is pressed, start the buffer reading
                $keyBuffer = @()
                $keyBuffer += ,[char][int]$_
            } elseif ($_ -eq $undo) {
                # If backspace is pressed, remove the last key from the buffer
                if ($keyBuffer.length -gt 1) {
                    $keyBuffer = $keyBuffer[0..($keyBuffer.length - 2)]
                } else {
                    $keyBuffer = @()
                }
            } elseif ($exitKeys.Contains($_)) {
                # Exit key pressed, replace text and start again
                # If space is pressed, check if a key has been entered
                checkKeyBuffer $keyBuffer[1..($keyBuffer.length - 1)]
                $keyBuffer = @()
            } elseif ($keyBuffer.Length -gt 0) {
                # Add each other key to the buffer if the buffer is already started
                $keyBuffer += ,[char][int]$_
            }
        }
    }

    # Display the current buffer if there is anything in it for clarity
    if ($keyBuffer.Length -gt 0) {
        Write-Progress -Activity "Reading keys to the buffer" -Status "$keyBuffer".Replace(' ', '')
    } else {
        Write-Progress -Activity ' ' -Completed
    }
}

# Cleanup
$global:clientPipe.Close()
Unregister-Event -SubscriptionId $eventChanged.Id
$Host.UI.RawUI.FlushInputBuffer()