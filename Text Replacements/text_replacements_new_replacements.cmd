<# : Rename the file extension to .ps1 for purely powershell script, or .cmd for batch file starting
@echo off & setlocal

rem # re-launch self with PowerShell interpreter
powershell -noprofile "iex (${%~f0} | out-string)"

goto :EOF
: end batch / begin PowerShell chimera #>
mode con: cols=82 lines=25
clear


<#----------------------------------#
 | Text Replacement Script (Part 2) |
 | Author: David House              |
 | Created: 10/04/2018              |
 | Updated: 22/06/2018              |
 #----------------------------------#>



$startCharacter = '/'
$validKeyCharacters = [char[]]'abcdefghijklmnopqrstuvwxyz0123456789'
$filepath = ".\text_replacements.xml"
$xmlContent = @{}

if (Test-Path $filepath) {
    $xmlContent = Import-Clixml $filepath
}

$continue = $true

Write-Host "Text Replacements - Created by David House.

Valid characters for use in keys:"
Write-Host $validKeyCharacters -NoNewline -Separator ','
Write-Host "

NOTE: Enter a key with an empty replacement to remove that key.
"


While ($continue) {
    Write-Host -NoNewline "Enter a key to use: /"
    $key = Read-Host
    $newKeyValid = $true
    foreach ($char in [char[]]$key) {
        if (-not ($validKeyCharacters.Contains($char))) {
            $newKeyValid = $false
        }
    }
    While (-not ($newKeyValid)) {
        Write-Host "Invalid key. Ensure only characters listed above are used in keys."
        Write-Host -NoNewline "Enter a key to use: /"
        $key = Read-Host
        $newKeyValid = $true
        foreach ($char in [char[]]$key) {
            if (-not ($validKeyCharacters.Contains($char))) {
                $newKeyValid = $false
            }
        }
    }

    Write-Host "Enter the text to replace it with:"
    $input = Read-Host
    $newText = ""
    $count = 0
    While ($input -ne "") {
	    if ($newText -ne "") { $newText += "`n" }
	    $newText += $input
	    $input = Read-Host
        if ($input -eq "") {
            $input = Read-Host
            if (($input -ne "") -and ($newText -ne "")) { $newText += "`n" }
        }
    }

    if ($newText -eq "") {
        $xmlContent.Remove($key)
    } else {
        $xmlContent.Item($key) = $newText
    }

    if ((Read-Host "Would you like to create another replacement? [y/n]").ToLower() -ne "y") {
        $continue = $false
    }
}

$xmlContent | Export-Clixml $filepath