$file1 = "./text_replacements.ps1"
$file1CMD = "./text_replacements.cmd"
$file2 = "./text_replacements_new_replacements.ps1"
$file2CMD = "./text_replacements_new_replacements.cmd"

if (Test-Path $file1) {
    Rename-Item -Path $file1 -NewName $file1CMD
} else {
    Rename-Item -Path $file1CMD -NewName $file1
}

if (Test-Path $file2) {
    Rename-Item -Path $file2 -NewName $file2CMD
} else {
    Rename-Item -Path $file2CMD -NewName $file2
}