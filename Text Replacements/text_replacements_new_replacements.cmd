<# : batch portion (begins PowerShell multiline comment block)
@echo off & setlocal

set /P "=Text Replacements - Created by David House."<NUL

rem # re-launch self with PowerShell interpreter
powershell -noprofile "iex (${%~f0} | out-string)"

echo Closing

goto :EOF
: end batch / begin PowerShell chimera #>

$hexKeys = @{}
$hexKeys.Add("BF", "/")
$hexKeys.Add("30", "0")
$hexKeys.Add("31", "1")
$hexKeys.Add("32", "2")
$hexKeys.Add("33", "3")
$hexKeys.Add("34", "4")
$hexKeys.Add("35", "5")
$hexKeys.Add("36", "6")
$hexKeys.Add("37", "7")
$hexKeys.Add("38", "8")
$hexKeys.Add("39", "9")
$hexKeys.Add("41", "A")
$hexKeys.Add("42", "B")
$hexKeys.Add("43", "C")
$hexKeys.Add("44", "D")
$hexKeys.Add("45", "E")
$hexKeys.Add("46", "F")
$hexKeys.Add("47", "G")
$hexKeys.Add("48", "H")
$hexKeys.Add("49", "I")
$hexKeys.Add("4A", "J")
$hexKeys.Add("4B", "K")
$hexKeys.Add("4C", "L")
$hexKeys.Add("4D", "M")
$hexKeys.Add("4E", "N")
$hexKeys.Add("4F", "O")
$hexKeys.Add("50", "P")
$hexKeys.Add("51", "Q")
$hexKeys.Add("52", "R")
$hexKeys.Add("53", "S")
$hexKeys.Add("54", "T")
$hexKeys.Add("55", "U")
$hexKeys.Add("56", "V")
$hexKeys.Add("57", "W")
$hexKeys.Add("58", "X")
$hexKeys.Add("59", "Y")
$hexKeys.Add("5A", "Z")
$hexKeys.Add("60", "0")
$hexKeys.Add("61", "1")
$hexKeys.Add("62", "2")
$hexKeys.Add("63", "3")
$hexKeys.Add("64", "4")
$hexKeys.Add("65", "5")
$hexKeys.Add("66", "6")
$hexKeys.Add("67", "7")
$hexKeys.Add("68", "8")
$hexKeys.Add("69", "9")
$hexKeys.Add("6F", "/")

$textReplacements = @()
$filepath = ".\text_replacements.txt"

function getNewTextReplacement() {
	$newKey = Read-Host -Prompt "Enter a key to replace"
	$newKeyValid = $true
	for ($i = 0; $i -lt $newKey.length; $i++) {
		$char = $newKey.substring($i, 1).Toupper()
		if (-not ($hexKeys.ContainsValue($char))) {
			$newKeyValid = $false
			break
		}
	}
	while (-not $newKeyValid) {
		$newKeyValid = $true
		Write-Host 'Key must only use the character listed above'
		$newKey = Read-Host -Prompt "Enter a key to replace"
		$newKeyValid = $true
		for ($i = 0; $i -lt $newKey.length; $i++) {
			$char = $newKey.substring($i, 1).Toupper()
			if (-not ($hexKeys.ContainsValue($char))) {
				$newKeyValid = $false
				break
			}
		}
	}
	
	$newText = Read-Host -Prompt "Enter the text to replace it with"
	$textReplacements += ,($newKey, -1, $newText)
	$newKey + "," + $newText >> $filepath
	return 1
}

Write-Host ''
Write-Host '[Add New Text Replacements]'
if (-not (Test-Path $filepath)) {
	"Text Replacements Format per line = key,textToReplaceWith" >> $filepath
} else {
	$fileContents = Get-Content -Path $filepath
	$tab = [char]9
	for ($i = 1; $i -lt $fileContents.Count; $i++) {
		$newTextReplacement = $fileContents[$i].Split(",")
		$textReplacements += ,($newTextReplacement[0], -1, $newTextReplacement[1])
	}
}

$keysString = ""
foreach($hexKey in $hexKeys.GetEnumerator() | Sort Name) {
	if (-not ($keysString -Match $hexKey.Value)) {
		$keysString += $hexKey.Value + ","
	}
}
$keysString = $keysString.substring(0, $keysString.length - 1)
Write-Host ''
Write-Host 'When choosing a key, it can only contain the following characters:'
Write-Host $keysString
Write-Host '(NOTE: letters are NOT case-sensitive)'
Write-Host ''
Write-Host 'In order to add a new line in the replacement text, use "\n"'
Write-Host ''

if (getNewTextReplacement) {}
while ((Read-Host -Prompt "Add new text replacement? [Y/N]").ToUpper() -eq "Y") {
	if (getNewTextReplacement) {}
}

$Host.UI.RawUI.FlushInputBuffer()