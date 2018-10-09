param (
    $version
)

Write-Host "Text Replacements - Created by David House.
Version: $version
"

$desktopPath = "$($HOME.Replace('C:\', 'D:\'))\Desktop"
$needsChanging = $false
$needsCreating = $false

$WshShell = New-Object -comObject WScript.Shell

if (-not (Test-Path "$PSScriptRoot\TextReplacements.lnk")) {
    # If the shortcut doesn't exist yet it needs to be created
    $needsCreating = $true
    if (Test-Path "$desktopPath\TextReplacements.lnk") {
        # Check to see if the dektop link already exists
        $targetPath = $WshShell.CreateShortcut("$desktopPath\TextReplacements.lnk").TargetPath
        $arguments = $WshShell.CreateShortcut("$desktopPath\TextReplacements.lnk").Arguments

        if ($targetPath -ine (Get-Command powershell.exe).Definition -or $arguments -ine "-NoProfile -File ""$PSScriptRoot\TextReplacementsShell.ps1""") {
            # Check if the target path is not pointing to PowerShell correctly,
            # Or the arguments are not specific to this folder, we need to re-create the shortcut
            $needsChanging = $true
        }
    }
}

if (-not (Test-Path "$PSScriptRoot\PowerShell.lnk") -or $needsChanging) {
    # Only complete any action if this link does not exist or it does exist, and the desktop link exists but is wrong
    # This allows a one time prompt instead of every time the script is run, unless the desktop link breaks somehow
    Write-Host "Creating necessary links..."

    # Create a shortcut to PowerShell using the TextReplacements icon
    $shortcut1 = $WshShell.CreateShortcut("$PSScriptRoot\PowerShell.lnk")
    $shortcut1.TargetPath = (Get-Command powershell.exe).Definition
    $shortcut1.IconLocation = "$PSScriptRoot\TextReplacements.ico"
    $shortcut1.WorkingDirectory = $PSScriptRoot
    $shortcut1.Save()

    if ($needsCreating -or $needsChanging) {
        # First check if the user wants a shortcut on the desktop
        $input = Read-Host "Would you like to create a shortcut on the desktop? [y/n] (Default is 'y')"

        if ($input -ine 'n') {
            # If they do, create a shortcut to the text replacements shell script
            $shortcut2 = $WshShell.CreateShortcut("$desktopPath\TextReplacements.lnk")
            $shortcut2.TargetPath = (Get-Command powershell.exe).Definition
            $shortcut2.Arguments = "-NoProfile -File ""$PSScriptRoot\TextReplacementsShell.ps1"""
            $shortcut2.IconLocation = "$PSScriptRoot\TextReplacements.ico"
            $shortcut2.WorkingDirectory = $PSScriptRoot
            $shortcut2.Save()
        } else {
            # If they don't, create a shortcut to the text replacements shell script within this folder
            $shortcut2 = $WshShell.CreateShortcut("$PSScriptRoot\TextReplacements.lnk")
            $shortcut2.TargetPath = (Get-Command powershell.exe).Definition
            $shortcut2.Arguments = "-NoProfile -File ""$PSScriptRoot\TextReplacementsShell.ps1"""
            $shortcut2.IconLocation = "$PSScriptRoot\TextReplacements.ico"
            $shortcut2.WorkingDirectory = $PSScriptRoot
            $shortcut2.Save()
        }
    }
}