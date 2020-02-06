$storageAccount = New-AzStorageContext -StorageAccountName "accountname" -StorageAccountKey "storage key"

$ctx = $storageAccount.Context

set-AzStorageblobcontent -File "C:\Azure Transition\dbbacpacs\dbname.bacpac" `
  -Container 'test-01' `
  -Blob "dbname.bacpac" `
  -Context $ctx 