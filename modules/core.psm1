function Get-Settings {

    Get-Content $HomeDir\settings.ini | ForEach-Object -begin {$hashTable=@{}} -process {
            $line = [regex]::Split($_,"=");
            if (($line[0].CompareTo("") -ne 0) -and ($line[0].StartsWith("[") -ne $True)) {
                $hashTable.Add($line[0], $line[1])
            }
    }
    return $hashTable
}
Export-ModuleMember -Function Get-Settings