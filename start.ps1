param(
    [parameter(Mandatory = $true)]
    [string]$server,
    [parameter(Mandatory = $true)]
    [string]$app_pool_name
)

Write-Host "Start IIS"
Write-Output "Server: $server - App Pool: $app_pool_name"

# Write-Output "Starting IIS app pool $appPoolName"
# Invoke-Command -ComputerName $server -ScriptBlock { Start-WebAppPool $appPoolName }