function Update-Database {
    # Initialize possible variables
    $basePasswords = $null
    $basePasswordSymbols = "*", "-", "$", "#"
    $nameOverrides = Get-NameOverrides
        
    # populate array of existing students ids
    $studentDatabase = Get-StudentArray
    $studentCsv = @()
    
    # import students.csv and process CSV related variables
    $csvFile = Import-Csv -path "$HomeDir\data\import\students.csv"
    #Trim trailing spaces form the Cognos file
    $csvFile | ForEach-Object {$_.PsObject.Properties | ForEach-Object {$_.Value = $_.Value.Trim()}}
    $fieldNames = $csvFile[0].psobject.Properties.Name
    $percentComplete = 0
    $linePercentage = 100 / $csvFile.Length
      
    # Setup the database transaction
    $sqlCommand = $SqlConnection.CreateCommand()
    $sqlCommand.CommandText = "begin transaction"
    $sqlCommand.ExecuteNonQuery() | Out-Null
    
    # Process each CSV line  
    ForEach ($line in $csvFile) {
        $lineFields = New-Object Collections.Generic.List[String] # Empty list for each new line
        $updateFields = New-Object Collections.Generic.List[String] # Empty list for each new line
        $studentCsv = $studentCsv + $line.Student_id.trim()

        # Really hackish way of removing the time from a date string... TODO: Work on a less embarrassing way of doing this.
        $line.DOB = $line.DOB.Substring(0, $line.DOB.Length-9)

        # Convert Second Year Seniors (Grade: SS) to 12th Grade
        if ($line.Grade -eq "SS")  {$line.Grade = "12" }

        ForEach ($fieldName in $fieldNames) {
            if ($line.$fieldName) {
                $sqlCommand.Parameters.AddWithValue("@"+$fieldName, $line.$fieldName.trim()) | Out-Null
                $lineFields.Add($fieldName)
                if (!$UserSettings.LockedFields.Contains($line.$fieldName)) { $updateFields.Add($fieldName) }
                
            } Else {
                if (!$UserSettings.LockedFields.Contains($line.$fieldName) -or !$UserSettings.ProtectedFields.Contains($line.$fieldName)) { $updateFields.Add($fieldName) }
            }
        }
        
        # Populate username and email address fields if not provided by the import file
        if ([string]::IsNullOrWhiteSpace($line.username)) {
            $username = Format-Username $line.First_name $line.Last_name
            $sqlCommand.Parameters.AddWithValue("@username", $username) | Out-Null
            $lineFields.Add("username")
            $updateFields.Add("username")
        }
        if ([string]::IsNullOrWhiteSpace($line.student_email)) {
            if (![string]::IsNullOrWhiteSpace($UserSettings.StudentEmailSuffix)) {
                $emailAddress = $sqlCommand.parameters["@username"].Value + $UserSettings.StudentEmailSuffix
                $sqlCommand.Parameters.AddWithValue("@student_email", $emailAddress) | Out-Null
                $lineFields.Add("student_email")
                $updateFields.Add("student_email")
            }
        }
        
        # Populate mandatory database fields not included in CSV
        $sqlCommand.Parameters.AddWithValue("@dbStatus", 1) | Out-Null # Mark student as active/currently enrolled
        $lineFields.Add("dbStatus")
        $updateFields.Add("dbStatus")

        # Populate Password field for new students only
        if ($studentDatabase -eq $null -or !$studentDatabase.Contains($line.Student_id)) {
            # If password is not provided by import file, create one
            if ([string]::IsNullOrWhiteSpace($line.password)) {
                $newPassword = New-Password
                $sqlCommand.Parameters.AddWithValue("@password", $newPassword) | Out-Null
                $lineFields.Add("password")
            }
        }
        
        # Generate both Field and Value strings for the SQL statement from the current CSV line
        $fields = ($lineFields -join ",")
        $values = $NULL
        ForEach ($name in $lineFields) {
            $values = $values + "@" + $name + ","
        }
        $values = $values.Substring(0,($values.Length-1))
        
        # Generate UPDATE string for the SQL statement
        $updateString = $NULL
        ForEach ($updateField in $updateFields) {
            $updateString = $updateString + $updateField + "=" + "excluded." + $updateField + ","
        }
        $updateString = $updateString.Substring(0,($updateString.Length-1))


        # Build the actual SQL statement
        $sqlCommand.CommandText = "INSERT INTO students (" + $fields + ") VALUES (" + $values + ") ON CONFLICT(Student_id) DO UPDATE SET " + $updateString + ";"

        # From CSV to DB
        Try {
            $percentComplete = $percentComplete + $linePercentage
            Write-Progress -Activity "Updating Database" -Status ("#" + $line.Student_id + " - " + $line.Last_name + ", " +$line.First_name) -PercentComplete $percentComplete
            $sqlCommand.ExecuteNonQuery() | Out-Null
        } Catch {
            Write-Warning ("Could not add invalid record to database - " + $line.Student_id + ": " + $line.Last_name + ", " + $line.First_name)
        }
    }

    # Search for and deactivate any dropped students
    foreach ($studentId in $studentDatabase) {
        if ($studentCsv -NotContains $studentId.trim()) {
            $sqlCommand.CommandText = "UPDATE students SET dbStatus=0 WHERE Student_id=" + $studentId + ";"
            Try {
                $sqlCommand.ExecuteNonQuery() | Out-Null
            } Catch {
                Write-Warning ("Could not deactivate student with ID #" + $studentId + " in Kitchen Database")
            }
        }
    }
        
    # Complete the transaction and clean up
    $sqlCommand.CommandText = "commit transaction"
    $sqlCommand.ExecuteNonQuery() | Out-Null
    $sqlCommand.Dispose()

}

function Initialize-Database {
    if ((Read-Host "WARN: Database was not found. Create a new one? (Y/N)") -eq "Y") {
        $SqlConnection.ConnectionString = "Data Source=$HomeDir\data\resources\master.db3"
        $SqlConnection.Open()
        $createTableQuery = "CREATE TABLE students (
            School_id TEXT NOT NULL,
            Student_id TEXT NOT NULL PRIMARY KEY,
            Student_number TEXT,
            State_id TEXT,
            Last_name TEXT NOT NULL,
            Middle_name TEXT,
            First_name TEXT NOT NULL,
            Grade TEXT,
            Gender TEXT,
            Graduation_year TEXT,
            DOB TEXT,
            Race TEXT,
            Hispanic_Latino TEXT,
            Home_language TEXT,
            Ell_status TEXT,
            Frl_status TEXT,
            IEP_status TEXT,
            Student_street TEXT,
            Student_city TEXT,
            Student_state TEXT,
            Student_zip TEXT,
            Student_email TEXT,
            Contact_relationship TEXT,
            Contact_type TEXT,
            Contact_name TEXT,
            Contact_phone INTEGER,
            Contact_phone_type TEXT,
            Contact_email TEXT,
            Contact_sis_id TEXT,
            Username TEXT,
            Password TEXT,
            Unweighted_gpa TEXT,
            Weighted_gpa  TEXT,
            dbStatus INTEGER
            );"
    
        $sqlCommand = $SqlConnection.CreateCommand()
        $sqlCommand.CommandText = $createTableQuery
        $sqlCommand.ExecuteNonQuery() | Out-Null

        $sqlCommand.Dispose()
    } Else {
        Exit     
    }
}

function Test-DataTable {
    $sqlCommand = $SqlConnection.CreateCommand()
    $sqlCommand.CommandText = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='students';"

    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sqlCommand
    $data = New-Object System.Data.DataSet
    $adapter.Fill($data) | Out-Null

    $sqlCommand.Dispose()

    if ($data.Tables.Rows.'count(*)' -ne 1) {
        Initialize-Database
    }
}

function Format-Username($first, $last) {
    $concatenatedName = $first + $last
    $concatenatedName = $concatenatedName -replace "[/\s'.-]",""
    $concatenatedName = $concatenatedName.SubString(0,[math]::min(20,$concatenatedName.length))
    return $concatenatedName
}

function Get-NameOverrides {
    $studentIds = @()
    if (Test-Path $HomeDir\NameOverrides.csv) {
        $students = Import-Csv $HomeDir\data\NameOverrides.csv
        foreach ($line in $students) {
            $studentIds += $line.student_id
        }
    }
    return $studentIds
}

function Get-StudentArray {
    $studentArray = @()
    
    $sqlCommand = $SqlConnection.CreateCommand()
    $sqlCommand.CommandText = "SELECT * FROM students"

    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sqlCommand
    $data = New-Object System.Data.DataSet
    $adapter.Fill($data) | Out-Null

    $table = $data.Tables.Rows

    foreach($row in $table) {
        $studentArray += $row.Student_id
    }

    $sqlCommand.Dispose()

    return $studentArray
}

function New-Password{
    if ($basePasswords -eq $null) {
        Try {
            $basePasswords = Get-Content $HomeDir\data\resources\basePasswordList.txt
        } Catch {
            Write-Error("Base password list does not exist.")
        }
    }

    return $basePasswords[$(Get-Random -Maximum $basePasswords.Length)]+`
    $(Get-Random -Minimum 10 -Maximum 99) + `
    $basePasswordSymbols[$(Get-Random -Maximum $basePasswordSymbols.Length)]
}

Export-ModuleMember -Function Update-Database, Initialize-Database, Test-DataTable