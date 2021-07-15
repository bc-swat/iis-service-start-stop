param(
    [parameter(Mandatory = $true)]
    [string]$server,
    [parameter(Mandatory = $true)]
    [string]$app_pool_name,
    [parameter(Mandatory = $true)]
    [string]$user_id,
    [parameter(Mandatory = $true)]
    [SecureString]$password
)

Write-Host "Start IIS"
Write-Output "Server: $server - App Pool: $app_pool_name"

$credential = [PSCredential]::new($user_id, $password)

Write-Output "Starting IIS app pool $appPoolName"
Invoke-Command -ComputerName $server `
    -Credential $credential `
    -ScriptBlock { `
        Import-Module WebAdministration; `
        Start-Sleep -s 10; `
        Start-WebAppPool -Name $app_pool_name `
}