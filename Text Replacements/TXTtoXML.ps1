$filepath = '.\text_replacements.txt'
$newFilepath = '.\text_replacements.xml'

$fileContents = Get-Content -Path $filepath

$xml = @{}
$skipFirst = $true
foreach ($line in $fileContents) {
    if ($skipFirst) {
        $skipFirst = $false
        continue
    }
    $line = $line.Split(",")
    $line[0] = $line[0].Replace("/", "")
    if ($line.Length -gt 2) {
        for ($i = 2; $i -lt $line.Length; $i++) {
            $line[1] += ", " + $line[$i]
        }
    }
    $line[1] = $line[1].Replace("\n", "`n")
    $xml.Item($line[0]) = $line[1]
}

$xml | Export-Clixml $newFilepath