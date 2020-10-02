function Export-PasswordList {
    $objXlsFile = @()

    $sqlCommand = $SqlConnection.CreateCommand()
    $sqlCommand.CommandText = "SELECT * FROM students"
    
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sqlCommand
    $data = New-Object System.Data.DataSet
    $adapter.Fill($data) | Out-Null

    $table = $data.Tables.Rows

    $percentageComplete = 0
    $linePercentage = 100 / $table.count

    foreach($row in $table) {
        if ($row.dbStatus -eq 1) {
            #Add a line to the CSV file
            $percentComplete = $percentComplete + $linePercentage
            Write-Progress -Activity "Exporting Master Password List" -Status ("#" + $row.Student_id + " - " + $row.Last_name + ", " +$row.First_name) -PercentComplete $percentComplete
            $obj = New-Object -TypeName PSObject
            $obj | Add-Member -MemberType NoteProperty -Name "Last Name" -Value $row.Last_name
            $obj | Add-Member -MemberType NoteProperty -Name "First Name" -Value $row.First_name
            $obj | Add-Member -MemberType NoteProperty -Name "Grade" -Value $row.Grade
            $obj | Add-Member -MemberType NoteProperty -Name "Username" -Value $row.Student_email
            $obj | Add-Member -MemberType NoteProperty -Name "Password" -Value $row.Password
            $objXlsFile += $obj
            $obj = $null
        }
    }

    if (Test-Path $UserSettings.AccountList) {Remove-Item $UserSettings.AccountList}
    $objXlsFile | Sort-Object -Property "Last Name", "First Name" | Export-Excel $UserSettings.AccountList -BoldTopRow -FreezeTopRow -AutoSize
}

function Get-Settings {

    Get-Content $HomeDir\data\settings.ini | ForEach-Object -begin {$hashTable=@{}} -process {
            $line = [regex]::Split($_,"=");
            if (($line[0].CompareTo("") -ne 0) -and ($line[0].StartsWith("[") -ne $True)) {
                $hashTable.Add($line[0], $line[1])
            }
    }
    return $hashTable
}

function Export-PasswordSlips {
    if (Test-Path $HomeDir\data\output\mailMerge.csv) {
        $word = New-Object -ComObject "Word.application"
        $word.visible = 1
        $doc = $word.Documents.Open("$HomeDir\data\passwordForm.docx")
        $doc.MailMerge.Execute()
        ($word.documents | ?{$_.Name -match "Letters1"}).PrintOut()
        # pause long enough for Word to get the merged forms into the print queue
        Start-Sleep -Seconds 5
        $quitFormat = [Enum]::Parse([Microsoft.Office.Interop.Word.WdSaveOptions],"wdDoNotSaveChanges")
        $word.Quit([ref]$quitFormat)
    }
}

Export-ModuleMember -Function Export-PasswordList,Get-Settings,Export-PasswordSlips