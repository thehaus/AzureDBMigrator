Connect-AzAccount

$PathVariables=$env:Path
if (-not $PathVariables.Contains( "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin"))
{
  #write-host "SQLPackage.exe path is not found, Update the environment variable"
  $env:Path = $env:Path + ";C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin;" 
}

$BackupDirectory="C:\Azure Transition\dbbacpacs\"
$dirName  = [io.path]::GetDirectoryName($BackupDirectory)
$ext = "bacpac"

$storageAccount = New-AzStorageContext -StorageAccountName "saname" -StorageAccountKey "skey"
$ctx = $storageAccount.Context

$DBMapServerName="dbserver"
$DBMapUserName = "dbuser"
$DBMapPassword = "dbpass"
$DBMapQuery = "SELECT DBConnection FROM DBMap WHERE RootDB ="

foreach ($DatabaseName in Get-Content .\DBList.dat)
{
    $filename = $DatabaseName
	
	$TargetFilePath  = "$dirName\$filename.$ext"
	
	#get connection string from DBMap
	$SourceConnString = (Invoke-Sqlcmd -Query "$DBMapQuery '$DatabaseName'" -ServerInstance $DBMapServerName -Username $DBMapUserName -Password $DBMapPassword -Database "NetServiceMaster").DBConnection
		
	sqlpackage.exe /a:Export /scs:$SourceConnString /tf:$TargetFilePath /of:true 2> "C:\Azure Transition\$DatabaseName.log"
	
	if ([System.IO.File]::Exists($TargetFilePath))
	{
		$NewDBMapConnString = "Initial Catalog=$DatabaseName;Data Source=azuredb;User Id=dbuser;PASSWORD=dbpass;"
	
		#Copy bacpac file to blob
		set-AzStorageblobcontent -Force -File "C:\Azure Transition\dbbacpacs\$DatabaseName.bacpac" `
		-Container 'test-01' `
		-Blob "$DatabaseName.bacpac" `
		-Context $ctx 		
		
		#Restore DB from bacpac file
		$SecureString = ConvertTo-SecureString "dbpass" -AsPlainText -Force
		$importRequest = New-AzSqlDatabaseImport -RazureurceGroupName "rgname" -ServerName "sname" -DatabaseName $DatabaseName -StorageKeyType "StorageAccessKey" -StorageKey "skey" -StorageUri "blobfilelocation" -AdministratorLogin "user" -AdministratorLoginPassword $SecureString -Edition Basic -ServiceObjectiveName Basic -DatabaseMaxSizeBytes 5000000

		#Wait here until we're done with the import	
		$importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
		[Console]::Write("Importing")
		while ($importStatus.Status -eq "InProgress")
		{    
			$importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
			[Console]::Write(".")
			Start-Sleep -s 10
		}

		#Alert user to status		
		$importStatus  
		
		#update dbmap entry on both local and azure servers to point to azure server
		$DropConstraintString = "IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[chk_read_only]') AND parent_object_id = OBJECT_ID(N'[dbo].[DBMap]')) ALTER TABLE [dbo].[DBMap] DROP CONSTRAINT [chk_read_only]"
		Invoke-Sqlcmd -Query $DropConstraintString -ServerInstance $DBMapServerName -Username $DBMapUserName -Password $DBMapPassword -Database "database"
		
		$ModifyConnString = "UPDATE DBMap SET DBConnection = '$NewDBMapConnString', IsMigratedToAzure = 1 WHERE RootDB = '$DatabaseName'"
		Invoke-Sqlcmd -Query $ModifyConnString -ServerInstance $DBMapServerName -Username $DBMapUserName -Password $DBMapPassword -Database "database"
		
		$CreateConstraintString = "ALTER TABLE [dbo].[DBMap]  WITH NOCHECK ADD  CONSTRAINT [chk_read_only] CHECK  (((1)=(0))) ALTER TABLE [dbo].[DBMap] CHECK CONSTRAINT [chk_read_only]"
		Invoke-Sqlcmd -Query $CreateConstraintString -ServerInstance $DBMapServerName -Username $DBMapUserName -Password $DBMapPassword -Database "database"
		
		$DropConstraintString = "IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[chk_read_only]') AND parent_object_id = OBJECT_ID(N'[dbo].[DBMap]')) ALTER TABLE [dbo].[DBMap] DROP CONSTRAINT [chk_read_only]"
		Invoke-Sqlcmd -Query $DropConstraintString -ServerInstance "azuredb" -Username "user" -Password "password" -Database "database"
		
		$ModifyConnString = "UPDATE DBMap SET DBConnection = '$NewDBMapConnString', IsMigratedToAzure = 1 WHERE RootDB = '$DatabaseName'"
		Invoke-Sqlcmd -Query $ModifyConnString -ServerInstance "azuredb" -Username "user" -Password "password" -Database "database"
		
		$CreateConstraintString = "ALTER TABLE [dbo].[DBMap]  WITH NOCHECK ADD  CONSTRAINT [chk_read_only] CHECK  (((1)=(0))) ALTER TABLE [dbo].[DBMap] CHECK CONSTRAINT [chk_read_only]"
		Invoke-Sqlcmd -Query $CreateConstraintString -ServerInstance "azuredb" -Username "user" -Password "password" -Database "database"
		
		#remove bacpac file from blob
		Remove-AzStorageBlob -Context $ctx -Container "test-01" -Blob "$filename.$ext"
	}
	else
	{
		write-host "Error exporting database $DatabaseName. See log file for details."
	}
}
