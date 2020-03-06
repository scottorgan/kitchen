function Update-Database {
    # import students.csv and process CSV related variables
    $csvFile = Import-Csv -path "$HomeDir\import\students.csv"
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

        ForEach ($fieldName in $fieldNames) {
            if ($line.$fieldName) {
                $sqlCommand.Parameters.AddWithValue("@"+$fieldName, $line.$fieldName) | Out-Null
                $lineFields.Add($fieldName)
                if (!$UserSettings.LockedFields.Contains($line.$fieldName)) { $updateFields.Add($fieldName) }
                
            } Else {
                if (!$UserSettings.LockedFields.Contains($line.$fieldName) -or !$UserSettings.ProtectedFields.Contains($line.$fieldName)) { $updateFields.Add($fieldName) }
            }
        }
        
        # Populate mandatory database fields not included in CSV
        $sqlCommand.Parameters.AddWithValue("@dbStatus", 1) | Out-Null # Mark student as active/currently enrolled
        $lineFields.Add("dbStatus")

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

    # Complete the transaction and clean up
    $sqlCommand.CommandText = "commit transaction"
    $sqlCommand.ExecuteNonQuery() | Out-Null
    $sqlCommand.Dispose()

}

function Initialize-Database {
    if ((Read-Host "WARN: Database was not found. Create a new one? (Y/N)") -eq "Y") {
        $SqlConnection.ConnectionString = "Data Source=$HomeDir\data\master.db3"
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

Export-ModuleMember -Function Update-Database, Initialize-Database, Test-DataTable