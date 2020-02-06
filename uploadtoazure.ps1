Connect-AzAccount

$SecureString = ConvertTo-SecureString "password" -AsPlainText -Force
New-AzSqlDatabaseImport -ResourceGroupName "rgname" -ServerName "servername" -DatabaseName "dbname" -StorageKeyType "StorageAccessKey" -StorageKey "storage key" -StorageUri "blobstorelocation" -AdministratorLogin "admin" -AdministratorLoginPassword $SecureString -Edition Basic -ServiceObjectiveName Basic -DatabaseMaxSizeBytes 5000000

$exportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink 'azuresubscriptionlink'
[Console]::Write("Importing")
while ($exportStatus.Status -eq "InProgress")
{
    Start-Sleep -s 10
    $exportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink 'azuresubscriptionlink'
    [Console]::Write(".")
}
[Console]::WriteLine("")
$exportStatus