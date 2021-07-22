Param(
    [parameter(Mandatory = $true)]
    [string]$server,
    [parameter(Mandatory = $true)]
    [string]$app_pool_name,
    [parameter(Mandatory = $true)]
    [string]$user_id,
    [parameter(Mandatory = $true)]
    [SecureString]$password,
    [parameter(Mandatory = $true)]
    [string]$action,
    [parameter(Mandatory = $true)]
    [string]$cert_path
)

$display_action = "Restart"
if ($action -eq "start") {
    $display_action = "Start"
}
elseif ($action -eq "stop") {
    $display_action = "Stop"
}
$display_action_past_tense = "restarted"
if ($action -eq "start") {
    $display_action_past_tense = "started"
}
elseif ($action -eq "stop") {
    $display_action_past_tense = "stopped"
}

Write-Host "$display_action IIS"
Write-Output "Server: $server - App Pool: $app_pool_name"

$credential = [PSCredential]::new($user_id, $password)
$so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

Write-Information "Importing remote server cert..."
Import-Certificate -Filepath $cert_path -CertStoreLocation "cert:\CurrentUser\Root"

$script = {
    if (-not (Get-InstalledModule -Name "WebAdministration" -ErrorAction SilentlyContinue)) {
        Write-Output "WebAdministration module not detected. Installing..."
        Install-Module -Name WebAdministration -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
        Write-Output "Finished Installing WebAdministration module."
    }

    if ($Using:action -eq "stop" -or $Using:action -eq "restart") {
        Stop-WebAppPool -Name $Using:app_pool_name
    }

    if ($Using:action -eq "start" -or $Using:action -eq "restart") {
        Start-Sleep 10
        Start-WebAppPool -Name $Using:app_pool_name
    }
}

Invoke-Command -ComputerName $server `
    -Credential $credential `
    -UseSSL `
    -SessionOption $so `
    -ScriptBlock $script

Write-Output "IIS app pool $app_pool_name $display_action_past_tense."
