Import-Module $PSScriptRoot\PSNamedPipes.psm1
Import-Module $PSScriptRoot\PSHideShowConsole.psm1


<#-------------------------#
 | Text Replacement Script |
 | Author: David House     |
 | Created: 10/04/2018     |
 #-------------------------#>
   $version = '0.9.1.5'


########## Need to add version number to this script, then pass it to the other scripts when called ##########


# Get the script root path for use later
$env:scriptRootPath = $PSScriptRoot

# Ensure the shortcut with the icon has been created
& "$PSScriptRoot\InitialiseTextReplacementsShortcuts.ps1" $version
$env:PowerShellLink = "$PSScriptRoot\PowerShell.lnk"

# Hide this shell
Hide-Console -Immediate

# Store the pipes in an array for easy access
$global:pipes = @()
$global:totalClients = 0
$global:pipeTypeToID = @{} # Either 'icon' or 'script'
$global:maxPings = 2
$global:clientPings = @() # 0 if no response needed, 1 to maxPings if waiting for response
$global:pingTimer = $null
$global:pingFrequency = 2 # Seconds

### BEGIN PIPE SERVER FUNCTIONS ###
#region pipe server functions
function Get-RandomPipeName {
    # Function to get a random pipe name for a new pipe connection
    param ( $prefix = '\\.\' )
    
    # 48 - 57, 65 - 90, 97 - 122
    $newRandomName = "$prefix"
    for ($i = 0; $i -lt 64; $i++) {
        $n = Get-Random -Minimum 0 -Maximum 2
        if ($n -eq 0) {
            # 48 - 57
            # 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
            $newRandomName += [char](Get-Random -Minimum 48 -Maximum 58)
        } elseif ($n -eq 1) {
            # 65 - 90
            # A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z
            $newRandomName += [char](Get-Random -Minimum 65 -Maximum 91)
        } else { # $n -eq 2
            # 97 - 122
            # a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
            $newRandomName += [char](Get-Random -Minimum 97 -Maximum 123)
        }
    }

    $newRandomName
}

function Create-NewConnection {
    # Function to create a new pipe based on a unique pipe name and start waiting for a client to connect
    param ( $newPipeName )

    # Create a new server with the unique name provided, add to the array, and wait for a client to connect asynchronously
    $newPipe = New-NamedPipeServer -PipeName $newPipeName
    $global:pipes += ,($newPipe)
    $pipeID = $totalClients

    $global:pipes[$pipeID].WaitForConnection()
    $global:totalClients += 1

    $global:clientPings += ,(0)

    OnClientConnected $pipeID
}

function OnLobbyConnected {
    # Function triggered when a new client connects to the lobby

    # Get a unique pipe name and send this to the client
    $newPipeName = Get-RandomPipeName $global:pipePrefix
    $global:serverLobby.BeginWrite($newPipeName)

    # Close the lobby server to sever the connection
    $global:serverLobby.Close()

    # Create a new pipe with the unique name and 
    Create-NewConnection $newPipeName

    # Restart the lobby pipe and wait for a new connection once more
    $global:serverLobby = New-NamedPipeServer -PipeName $pipeLobbyName
    $global:serverLobby.BeginWaitForConnection({ OnLobbyConnected })
}

function OnClientConnected {
    # Function triggered when a new client has completed their connection to this server
    param ( $pipeID )

    # Announce the connection
    Write-Host "Client $pipeID connected at $((Get-Date).ToString('dddd dd/MM/yy - HH:mm:ss:fff'))."

    # Send the client their ID
    $global:pipes[$pipeID].BeginWrite($pipeID)

    # Start waiting for messages from the client in the background
    $global:pipes[$pipeID].BeginRead({ OnMessageReceived $args[0] })
}

function OnMessageReceived {
    # Function triggered when a client sends a message to this server
    param (
        $message
    )

    # Since we're working Async, sometimes messages can back up and combine into one
    # In this instance we are adding a 'end message' string as '<<>>'
    $messages = $message -split '<<>>'

    # Process each message
    foreach ($message in $messages) {
        if ($message -ne '') {
            # Gather the ID from the message (ID:Message)
            $messageSplit = $message -split ':'
            $pipeID = [int]$messageSplit[0]
            $message = $messageSplit[1]

            # Announce the message from the client
            Write-Host "Client $pipeID : $message"

            switch ($message) {
                'exit' {
                    Close-AllClients
                }
                'connected' {
                    $global:pipeTypeToID.Add($messageSplit[2], $pipeID)
                }
                'hide' {
                    if ($global:pipeTypeToID['icon'] -eq $pipeID) {
                        Send-Message $global:pipeTypeToID['script'] 'hide'
                    }
                }
                'show' {
                    if ($global:pipeTypeToID['icon'] -eq $pipeID) {
                        Send-Message $global:pipeTypeToID['script'] 'show'
                    }
                }
                'add' {
                    if ($global:pipeTypeToID['script'] -eq $pipeID) {
                        Send-Message $global:pipeTypeToID['icon'] 'add'
                    }
                }
                'marco' {
                    # The client in pinging us, respond
                    Send-Message $pipeID "polo"
                }
                'polo' {
                    # The client is responding to a ping
                    $global:clientPings[$pipeID] = 0
                }
                default {
                    Send-Message $pipeID "(Echo) $message"
                }
            }
        }
    }
}

function Send-Message {
    # Function to send a message to the specified client pipe
    param (
        $pipeID,
        $message
    )

    # Announce the message to send
    Write-Host "To Client $pipeID : $message"

    # Send the message through the given pipe
    $global:pipes[$pipeID].BeginWrite("$message<<>>")
}

function Ping-Client {
    # Function to test if the client is still active
    param (
        $pipeID
    )

    # Take note of the fact that we are pinging the client
    $global:clientPings[$pipeID] += 1

    # Send a ping message to the client
    try {
        Send-Message $pipeID 'marco'
        'succeeded'
    } catch {
        # Send failed, which usually means the pipe is already broken
        'failed'
    }
}

function OnClientNoResponse {
    # Function triggered when a client fails to respond to a ping
    param {
        $pipeID
    }

    if ($global:clientPings[$pipeID] -ge $global:maxPings) {
        # Client has failed to respond to max number of pings
        'close'
    } else {
        # Client has failed to respond to a ping, but still has tries left
        'continue'
    }
}

function SendAll-Message {
    # Function to send a message to all client pipes
    param (
        $message
    )
    
    # Announce the message to send
    Write-Host "To All Clients : $message"

    # Send the message through all pipes
    for ($ID = 0; $ID -lt $global:totalClients; $ID++) {
        try {
            Send-Message $ID $message
        } catch {
            # Send failed, which usually means the pipe is already broken
        }
    }
}

function Close-AllClients {
    # Function to close all clients by sending the 'exit' message and exiting the server loop
    SendAll-Message 'exit'
    $global:continue = $false
}
#endregion
###  END PIPE SERVER FUNCTIONS  ###

# Pipe name for the lobby pipe
$global:pipePrefix = "\\.\TextReplacements-"
$pipeLobbyName = $pipePrefix + 'Lobby'

# Start the lobby pipe and wait for our first new connection
$global:serverLobby = New-NamedPipeServer -PipeName $pipeLobbyName
$global:serverLobby.BeginWaitForConnection({ OnLobbyConnected })

$global:continue = $true

#$scriptBlockToAdd = [scriptblock]::Create("& '$PSScriptRoot\text_replacements.ps1' '$pipeLobbyName','$version'")
Start-Process $env:PowerShellLink -WorkingDirectory $PSScriptRoot -ArgumentList "-Command & '$PSScriptRoot\text_replacements.ps1' '$pipeLobbyName' '$version'"

# Define a unique name for the job
$jobName = "Text Replacement - Notification Icon Job"

# Start background job to handle the Notify Icon with hide/show functionality
# Pass in the initialization script block to define the functions for use
# Ensure the root path and console window handle is passed through
Start-Job -Name $jobName -ArgumentList $pipeLobbyName, $PSScriptRoot, $version -ScriptBlock {
    param (
        $pipeLobbyName,
        $scriptRootPath,
        $version
    )
    
    Import-Module $scriptRootPath\PSNamedPipes.psm1

    ### BEGIN NOTIFICATION ICON FUNCTIONS ###
    #region notification icon functions
    # Load Assemblies
    Add-Type -AssemblyName PresentationFramework, System.Drawing, System.Windows.Forms, WindowsFormsIntegration


    # Create new Objects for the form
    $global:objForm = New-Object System.Windows.Forms.Form
    $objNotifyIcon = New-Object System.Windows.Forms.NotifyIcon 
    $objContextMenu = New-Object System.Windows.Forms.ContextMenu

    function Setup-ContextMenu {
        # Function that sets up the context menu from scratch
        $objContextMenu.MenuItems.Clear()

        # Ensure index is incrementing per item
        $i = 0

        # Create a Show Menu Item
        $objContextMenu | Build-ContextMenu -Index $i -Text "Show" -Action { Send-Message 'show' }
        $i += 1

        # Create a Hide Menu Item
        $objContextMenu | Build-ContextMenu -Index $i -Text "Hide" -Action { Send-Message 'hide' }
        $i += 1

        # Create the Add Text Replacements content Menu Item
        $Action = {
            Start-Process $env:PowerShellLink -WorkingDirectory "$scriptRootPath" -ArgumentList "-Command & '$scriptRootPath\text_replacements_new_replacements.ps1' '$version'"
        }
        $objContextMenu | Build-ContextMenu -Index $i -Text "Add Text Replacements" -Action $Action
        $i += 1

        # Create an Exit Menu Item
        $objContextMenu | Build-ContextMenu -Index $i -Text "Exit" -Action { Send-Message 'exit' }
        $i += 1
    }

    function new-scriptblock([string]$textofscriptblock) {
        # Function that converts string to ScriptBlock
        $executioncontext.InvokeCommand.NewScriptBlock($textofscriptblock)
    }

    Function Build-ContextMenu {
        # Function That Creates a ContexMenuItem and adds it to the Contex Menu
        param (
            $index = 0,
            $Text,
            $Action
        )
        begin {
            $MyMenuItem = New-Object System.Windows.Forms.MenuItem
        } process {
            # Assign the Contex Menu Object from the pipeline to the ContexMenu var
            $ContextMenu = $_
        } end {
            # Create the Menu Item
            $MyMenuItem.Index = $index
            $MyMenuItem.Text = $Text
            $MyMenuItem.add_Click($Action)
            [void]$ContextMenu.MenuItems.Add($MyMenuItem)
        }
    }
    #endregion
    ###  END NOTIFICATION ICON FUNCTIONS  ###

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
                Write-Host "Server : $message"

                # If there is more than one part to the message, split by ':' (Format = 'command:arg1:arg2' etc)
                $messageSplit = $message.Split(':')

                switch ($messageSplit[0]) {
                    'exit' {
                        $global:connected = $false
                        $global:objForm.Close()
                    }
                    'add' {
                        Start-Process $env:PowerShellLink -WorkingDirectory "$scriptRootPath" -ArgumentList "-Command & '$scriptRootPath\text_replacements_new_replacements.ps1' '$version'"
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
            Send-Message "connected:icon"
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

    # Wait until connected before setting up the form
    while (-not $global:connected) {
        Start-Sleep -Milliseconds 10
    }

    # Self explanatory
    Setup-ContextMenu

    # Assign an Icon and Text to the Notify Icon object
    $objNotifyIcon.Icon = "$scriptRootPath\TextReplacements.ico"
    $objNotifyIcon.Text = "Text Replacements"

    # Assign the Context Menu
    $objNotifyIcon.ContextMenu = $objContextMenu

    # Ensure the Notify Icon is visible, but the form is not
    $objNotifyIcon.Visible = $true
    $global:objForm.WindowState = "minimized"
    $global:objForm.ShowInTaskbar = $false

    # Ensure the Notify Icon disappears when the form closes
    $global:objForm.add_Closing({
        #<#
        if ($global:connected) {
            # If we have not disconnected yet, tell the server to exit all clients
            Send-Message 'exit'

            # Wait for this to echo back to us before closing
            while ($global:connected) {
                Start-Sleep -Milliseconds 10
            }
        }
        #>
        
        # Cleanup
        $global:clientPipe.close()
        $global:activeTester.Dispose()
        $objNotifyIcon.Visible = $false
        $objNotifyIcon.Dispose()
    })

    #<# Not really needed as this does not fix the issue where you need to choose 'Exit' twice to complete the exit###############################
    # Create a timer that checks if the text replacement console window has been closed
    $global:activeTester = New-Object System.Windows.Forms.Timer
    $global:activeTester.Interval = 10
    $global:activeTester.Add_Tick({
        # Running in order to allow async activities to run through the pipe
        $global:clientPipe.GetPipeName() | Out-Null
    })
    $global:activeTester.Enabled = $true
    #>

    # Start the form
    $global:objForm.ShowDialog()

    # When you reach this point, the form has closed
}

$global:pingTimer = (Get-Date).AddSeconds($global:pingFrequency)

# Main loop
While ($global:continue) {
    Start-Sleep -Milliseconds 10

    # Every pingFrequency check if any previous pings have failed, then send a ping to all clients
    if ((Get-Date).Subtract($global:pingTimer) -ge 0) {
        $global:pingTimer = (Get-Date).AddSeconds($global:pingFrequency)

        # Loop through all clients
        for ($ID = 0;$ID -lt $global:clientPings.Length; $ID++) {
            if ($global:clientPings[$ID] -gt 0) {
                if ((OnClientNoResponse $ID) -eq 'close') {
                    # The client has not responded to too many pings, close everything
                    Close-AllClients
                    break
                }
            }

            if ((Ping-Client $ID) -eq 'failed') {
                # The ping failed, which means the client has already disconnected, close everything
                Write-Host "Ping to Client $ID failed."
                Close-AllClients
                break
            }
        }
    }
}

# Wait for the icon job to close before continuing
# This will occur after it receives the exit command
while ((Get-Job -Name $jobName).State -eq "Running") {
    Start-Sleep -Milliseconds 10
}

# Cleanup all pipes
$global:serverLobby.Close()
foreach ($pipe in $global:pipes) {
    $pipe.Close()
}

Write-Host 'Done!'
Start-Sleep 2