function Export-ActiveDirectory {
    $objCsvFile = @()
    
    $sqlCommand = $SqlConnection.CreateCommand()
    $sqlCommand.CommandText = "SELECT * FROM students"
    
    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sqlCommand
    $data = New-Object System.Data.DataSet
    $adapter.Fill($data) | Out-Null

    $table = $data.Tables.Rows

    $percentageComplete = 0
    $linePercentage = 100 / $table.count

    foreach($row in $table) {
        $percentComplete = $percentComplete + $linePercentage
        Write-Progress -Activity "Updating Active Directory" -Status ("#" + $row.Student_id + " - " + $row.Last_name + ", " +$row.First_name) -PercentComplete $percentComplete

        # If student is currently active in eSchool
        if ($row.dbStatus -eq 1) {

            $currentID = $row.Student_id

            # If the student already exists in Active Directory
            If ($adUser = Get-ADUser -SearchBase "OU=students,OU=user accounts,dc=mountainburg,dc=local" -Filter "EmployeeNumber -eq '$currentID'" -Properties "Description","EmailAddress","EmployeeNumber") {
                # If AD account is disabled, enable it
                if ($adUser.Enabled -eq $False) {Get-ADUser -SearchBase "OU=students,OU=user accounts,dc=mountainburg,dc=local" -Filter "EmployeeNumber -eq '$currentID'" | Enable-ADAccount}
                # If the student's name has changed, update AD
                if ($adUser.UserPrincipalName -ne $row.Student_Email) {
                    Write-Host("Changing Username from " + $adUser.UserPrincipalName + " to " + $row.Student_Email)
                    $newName = $row.First_name + " " + $row.Last_Name
                    Get-ADUser -SearchBase "OU=students,OU=user accounts,dc=mountainburg,dc=local" -Filter "EmployeeNumber -eq '$currentID'" | Rename-ADObject -NewName $newName 
                    Get-ADUser -SearchBase "OU=students,OU=user accounts,dc=mountainburg,dc=local" -Filter "EmployeeNumber -eq '$currentID'" | Set-ADUser `
                        -GivenName $row.First_name `
                        -Surname $row.Last_name `
                        -SamAccountName $row.Username `
                        -UserPrincipalName $row.Student_Email `
                        -EmailAddress $row.Student_Email
                }
                
                
                # add updated student to Mail Merge CSV for password slips to be printed later
                #$obj = New-Object -TypeName PSObject
                #$obj | Add-Member -MemberType NoteProperty -Name "lastName" -Value $row.Last_name
                #$obj | Add-Member -MemberType NoteProperty -Name "firstName" -Value $row.First_name
                #$obj | Add-Member -MemberType NoteProperty -Name "Grade" -Value $row.Grade
                #$obj | Add-Member -MemberType NoteProperty -Name "username" -Value $row.Username
                #$obj | Add-Member -MemberType NoteProperty -Name "password" -Value $row.Password
                #$objCsvFile += $obj
                #$obj = $null
            } Else {
                # Add the student to Active Directory
                Write-Host("Adding " + $row.Student_id + " " + $row.Username + " to Active Directory")
                
                #Determine the proper OU based on building number
                switch($row.School_id) {
                    12 {$ouPath = "OU=elementary,OU=students,OU=user accounts,DC=mountainburg,DC=local"; $mailGroup = $null; break}
                    13 {$ouPath = "OU=high school,OU=students,OU=user accounts,DC=mountainburg,DC=local"; $mailGroup = "Mail - High School Students"; break}
                    22 {$ouPath = "OU=middle school,OU=students,OU=user accounts,DC=mountainburg,DC=local"; $mailGroup = "Mail - Middle School Students"; break}
                    702{$ouPath = "OU=middle school,OU=students,OU=user accounts,DC=mountainburg,DC=local"; $mailGroup = "Mail - Middle School Students"; break}
                    default {$ouPath = $null; $mailGroup = $null; break}
                }
                
                New-ADUser `
                    -Name ($row.First_name + " " + $row.Last_Name) `
                    -Path $ouPath `
                    -GivenName $row.First_name `
                    -Surname $row.Last_name `
                    -SamAccountName $row.Username `
                    -UserPrincipalName $row.Student_Email `
                    -EmailAddress $row.Student_Email `
                    -EmployeeNumber $row.Student_id `
                    -AccountPassword (ConvertTo-SecureString -AsPlainText $row.Password -Force) `
                    -Description ("Grade " + $row.Grade + " Class of " + $row.Graduation_year) `
                    -CannotChangePassword $True `
                    -PasswordNeverExpires $True `
                    -Division (Convert-Hash($row.Password)) `
                    -PassThru | Enable-ADAccount
                                       
                    
                # Add student to proper Groups
                Add-ADGroupMember -Identity "students" -Members $row.Username
                if ($mailGroup -ne $null) {Add-ADGroupMember -Identity $mailGroup -Members $row.Username}

                # Add student to Mail Merge CSV for password slips to be printed later
                if ($row.School_id -ne 12) {
                    $obj = New-Object -TypeName PSObject
                    $obj | Add-Member -MemberType NoteProperty -Name "lastName" -Value $row.Last_name
                    $obj | Add-Member -MemberType NoteProperty -Name "firstName" -Value $row.First_name
                    $obj | Add-Member -MemberType NoteProperty -Name "Grade" -Value $row.Grade
                    $obj | Add-Member -MemberType NoteProperty -Name "username" -Value $row.Username
                    $obj | Add-Member -MemberType NoteProperty -Name "password" -Value $row.Password
                    $objCsvFile += $obj
                    $obj = $null
                }
            }        
        } Else {
            # Student is not in this import file... Deactivate them.
            Write-Host("Disabling " + $row.Student_id + " " + $row.Username + " in Active Directory")
            Disable-ADAccount -Identity $row.Username 

        }    
    }

    # Export the Mail Merge file
    if (Test-Path $HomeDir\data\output\mailMerge.csv) {Remove-Item $HomeDir\data\output\mailMerge.csv}
    if ($objCsvFile.Count -gt 0) {$objCsvFile | Sort Grade,Last_name,First_name | Export-Csv $HomeDir\data\output\mailMerge.csv -NoTypeInformation}
}

function Convert-Hash([String] $password) {
    $hashObject = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create("SHA1").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($password)) | %{[Void]$hashObject.Append($_.ToString("x2"))}
    return $hashObject.ToString()
}

Export-ModuleMember -Function Export-ActiveDirectory