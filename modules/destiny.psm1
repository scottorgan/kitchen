function Export-DestinyPatrons {
    if (!(Test-Path -Path "$HomeDir\data\output\Destiny")) { New-Item -Path "$HomeDir\data\output" -Name "Destiny" -ItemType "directory" | Out-Null }
    
    $objCsvFile = @()
    
    $sqlCommand = $SqlConnection.CreateCommand()
    $sqlCommand.CommandText = "SELECT * FROM students"
    
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sqlCommand
    $data = New-Object System.Data.DataSet
    $adapter.Fill($data) | Out-Null

    $table = $data.Tables.Rows

    $additionalCsv = Import-Csv $HomeDir\data\import\additional.csv
    #Trim trailing spaces form the Cognos file
    $additionalCsv | ForEach-Object {$_.PsObject.Properties | ForEach-Object {$_.Value = $_.Value.Trim()}}


    $percentageComplete = 0
    $linePercentage = 100 / $table.count

    foreach($row in $table) {
        if ($row.dbStatus -eq 1) {
            #Add a line to the CSV file
            $percentComplete = $percentComplete + $linePercentage
            Write-Progress -Activity "Updating Destiny Patron File" -Status ("#" + $row.Student_id + " - " + $row.Last_name + ", " +$row.First_name) -PercentComplete $percentComplete
            $obj = New-Object -TypeName PSObject
            $obj | Add-Member -MemberType NoteProperty -Name "Building" -Value $row.School_id
            $obj | Add-Member -MemberType NoteProperty -Name "StudentId" -Value $row.Student_id
            $obj | Add-Member -MemberType NoteProperty -Name "LastName" -Value $row.Last_name
            $obj | Add-Member -MemberType NoteProperty -Name "FirstName" -Value $row.First_name
            $obj | Add-Member -MemberType NoteProperty -Name "Username" -Value $row.Student_email
            $obj | Add-Member -MemberType NoteProperty -Name "MiddleName" -Value $row.Middle_name
            $obj | Add-Member -MemberType NoteProperty -Name "Status" -Value "A"
            $obj | Add-Member -MemberType NoteProperty -Name "Gender" -Value $row.Gender

            $additional = $additionalCsv | Where-Object Student_id -eq $row.Student_id 
            $obj | Add-Member -MemberType NoteProperty -Name "Homeroom" -Value $additional.Homeroom

            $obj | Add-Member -MemberType NoteProperty -Name "Grade" -Value $row.Grade
            $obj | Add-Member -MemberType NoteProperty -Name "Address" -Value ""
            $obj | Add-Member -MemberType NoteProperty -Name "City" -Value ""
            $obj | Add-Member -MemberType NoteProperty -Name "State" -Value ""
            $obj | Add-Member -MemberType NoteProperty -Name "Zip" -Value ""
            $objCsvFile += $obj
            $obj = $null
        }
    }

    if (Test-Path $HomeDir\data\output\Destiny\DestinyPatronImport.csv) {Remove-Item $HomeDir\data\output\Destiny\DestinyPatronImport.csv}
    $objCsvFile | Sort-Object -Property "StudentId" | Export-Csv $HomeDir\data\output\Destiny\DestinyPatronImport.csv -NoTypeInformation

    $credentials = $UserSettings.Destiny.Split(",")
    $argumentList = "/command `"open sftp://" + $credentials[0] + ":" + $credentials[1] + "@" + $UserSettings.DestinyUrl + "`" `"synchronize remote -delete -preservetime $HomeDir\data\output\Destiny`" `"close`" `"exit`""
    Start-Process -FilePath "$HomeDir\resources\winscp.com" -ArgumentList $argumentList -Wait
}

Export-ModuleMember -Function Export-DestinyPatrons