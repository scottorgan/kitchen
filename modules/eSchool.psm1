function Export-eSchoolUpdates {
    if (!(Test-Path -Path "$HomeDir\data\output\eSchool")) { New-Item -Path "$HomeDir\data\output" -Name "eSchool" -ItemType "directory" | Out-Null }
    
    $objCsvFile = @()
    $string = ""
    
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
            Write-Progress -Activity "Updating eSchool Updates File" -Status ("#" + $row.Student_id + " - " + $row.Last_name + ", " +$row.First_name) -PercentComplete $percentComplete
            $obj = New-Object -TypeName PSObject
            
            $additional = $additionalCsv | Where-Object Student_id -eq $row.Student_id 
            $obj | Add-Member -MemberType NoteProperty -Name "Contact_id" -Value $additional.Contact_id
            

            $obj | Add-Member -MemberType NoteProperty -Name "Email" -Value $row.Student_email
            $objCsvFile += $obj
            $string += "$($obj.'Contact_id'),$($obj.'Email')`r`n"
            $obj = $null
        }
    }

    if (Test-Path $HomeDir\data\output\eSchool\eSchoolUpdates.csv) {Remove-Item $HomeDir\data\output\eSchool\eSchoolUpdates.csv}
    #$objCsvFile | Sort-Object -Property "Contact_id" | ConvertTo-Csv -NoTypeInformation | % {$_ -replace '"',''} | Out-File $HomeDir\data\output\eSchool\eSchoolUpdates.csv
    Out-File -Encoding ascii -InputObject $string -FilePath $HomeDir\data\output\eSchool\eSchoolUpdates.csv -Force -NoNewline

}

function Export-DvaStudents {
    if (!(Test-Path -Path "$HomeDir\data\output\eSchool")) { New-Item -Path "$HomeDir\data\output" -Name "eSchool" -ItemType "directory" | Out-Null }
    
    $objXlsFile = @()
    
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
            Write-Progress -Activity "Updating DVA Student List" -Status ("#" + $row.Student_id + " - " + $row.Last_name + ", " +$row.First_name) -PercentComplete $percentComplete
            
            $additional = $additionalCsv | Where-Object Student_id -eq $row.Student_id 

            if ($additional.Instructional_type -eq 2) {
                $obj = New-Object -TypeName PSObject
                $obj | Add-Member -MemberType NoteProperty -Name "Last Name" -Value $row.Last_name
                $obj | Add-Member -MemberType NoteProperty -Name "First Name" -Value $row.First_name
                $obj | Add-Member -MemberType NoteProperty -Name "Grade" -Value $row.Grade
                $obj | Add-Member -MemberType NoteProperty -Name "Email Address" -Value $row.Student_email
                $objXlsFile += $obj
                $obj = $null

            }
        }
    }

    if (Test-Path $UserSettings.DvaList) {Remove-Item $UserSettings.DvaList}
    $objXlsFile | Sort-Object -Property "Last Name", "First Name" | Export-Excel $UserSettings.DvaList -BoldTopRow -FreezeTopRow -AutoSize

}

Export-ModuleMember -Function Export-DvaStudents,Export-eSchoolUpdates