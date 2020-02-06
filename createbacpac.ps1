$PathVariables=$env:Path
$PathVariables
 
IF (-not $PathVariables.Contains( "C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin"))
{
  write-host "SQLPackage.exe path is not found, Update the environment variable"
  $env:Path = $env:Path + ";C:\Program Files (x86)\Microsoft SQL Server\140\DAC\bin;" 
}

$BackupDirectory="C:\Azure Transition\dbbacpacs\"
$DatabaseName="testdb"
#Source SQL Server name 
$SourceServerName="dbserver"
$UserName = "dbuser"
$Password = "dbpass"

$dirName  = [io.path]::GetDirectoryName($BackupDirectory)
#set the filename, the database should be a part of the filename
$filename = "dbfile"
#extension must be bacpac
$ext      = "bacpac"
#target filepath is a combination of the directory and filename appended with year month and day hour minutes and seconds
$TargetFilePath  = "$dirName\$filename.$ext"
#print the full path of the target file path
$TargetFilePath

sqlpackage.exe /a:Export /ssn:$SourceServerName /sdn:$DatabaseName /su:$UserName /sp:$Password /tf:$TargetFilePath
