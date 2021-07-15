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

Write-Host "Stop IIS"
Write-Output "Server: $server - App Pool: $app_pool_name"

$credential = [PSCredential]::new($user_id, $password)

Write-Output "Stopping IIS app pool $appPoolName"
Invoke-Command -ComputerName $server `
    -Credential $credential `
    -ScriptBlock { `
        Import-Module WebAdministration; `
        Stop-WebAppPool -Name $app_pool_name `
}