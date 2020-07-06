function Export-CleverStudents {
    $objCsvFile = @()
    
    $sqlCommand = $SqlConnection.CreateCommand()
    $sqlCommand.CommandText = "SELECT * FROM students"
    
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sqlCommand
    $data = New-Object System.Data.DataSet
    $adapter.Fill($data) | Out-Null

    $table = $data.Tables.Rows

    foreach($row in $table) {
        #Add a line to the CSV file
        Write-Progress -Activity "Updating Clever Student File" -Status ("#" + $row.Student_id + " - " + $row.Last_name + ", " +$row.First_name)
        $obj = New-Object -TypeName PSObject
        $obj | Add-Member -MemberType NoteProperty -Name "School_id" -Value $row.School_id
        $obj | Add-Member -MemberType NoteProperty -Name "Student_id" -Value $row.Student_id
        $obj | Add-Member -MemberType NoteProperty -Name "State_id" -Value $row.State_id
        $obj | Add-Member -MemberType NoteProperty -Name "Last_name" -Value $row.Last_name
        $obj | Add-Member -MemberType NoteProperty -Name "First_name" -Value $row.First_name
        $obj | Add-Member -MemberType NoteProperty -Name "Grade" -Value $row.Grade
        $obj | Add-Member -MemberType NoteProperty -Name "Gender" -Value $row.Gender
        $obj | Add-Member -MemberType NoteProperty -Name "DOB" -Value $row.DOB
        $obj | Add-Member -MemberType NoteProperty -Name "Race" -Value $row.Race
        $obj | Add-Member -MemberType NoteProperty -Name "Username" -Value $row.Username
        $obj | Add-Member -MemberType NoteProperty -Name "Password" -Value $row.Password
        $objCsvFile += $obj
        $obj = $null
    }

    if (Test-Path $HomeDir\Output\Clever\students.csv) {Remove-Item $HomeDir\Output\Clever\students.csv}
    $objCsvFile | Sort-Object -Property "Student_id" | Export-Csv $HomeDir\Output\Clever\students.csv -NoTypeInformation
}

Export-ModuleMember -Function Export-CleverStudents