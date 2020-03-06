# Bootstrap
$ErrorActionPreference = "Inquire"
$HomeDir = $PSScriptRoot  # used in external modules

# Load Dependencies
$modules = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath '\modules\*') -Include "*.psm1" -Exclude "_*"
ForEach($file in $modules) {
    Import-Module $file
}

# Set up the enviroment
$UserSettings = Get-Settings

# Verify and connect the SQLite database
Unblock-File  -Path .\resources\System.Data.SQLite.dll # Only required one time per machine, but here for ease of initial setup.
Add-Type -Path .\resources\System.Data.SQLite.dll
$SqlConnection = New-Object -TypeName System.Data.SQLite.SQLiteConnection

If (Test-Path .\data\master.db3) {
    $SqlConnection.ConnectionString = "Data Source=$HomeDir\data\master.db3"
    $SqlConnection.Open()
    Test-DataTable
}
Else {
    Initialize-Database
}


# This is where the magic happens!
Update-Database


# Clean Up, Clean Up
$SqlConnection.Close()
Write-Host "Exited Normally"