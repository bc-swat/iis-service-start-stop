Param(
    [parameter(Mandatory = $true)]
    [ValidateSet( 'start', 'stop', 'restart')]
    [string]$action,
    [parameter(Mandatory = $true)]
    [string]$server,
    [parameter(Mandatory = $true)]
    [string]$user_id,
    [parameter(Mandatory = $true)]
    [SecureString]$password,
    [parameter(Mandatory = $false)]
    [string]$cert_path
)

$display_action = 'IIS'
$title_verb = (Get-Culture).TextInfo.ToTitleCase($action)

$display_action += " $title_verb"
$past_tense = "ed"
switch ($action) {
    "start" {}
    "restart" { break; }
    "stop" { $past_tense = "ped"; break; }
}
$display_action_past_tense = "$display_action$past_tense"

Write-Output $display_action

$credential = [PSCredential]::new($user_id, $password)
$so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

if ($cert_path.Length -gt 0) {
    Write-Output "Importing remote server cert..."
    Import-Certificate -Filepath $cert_path -CertStoreLocation 'Cert:\LocalMachine\Root'
}

$script = {
    # Relies on WebAdministration Module being installed on the remote server
    # This should be pre-installed on Windows 2012 R2 and later
    # https://docs.microsoft.com/en-us/powershell/module/?term=webadministration

    switch ($Using:action) {
        'stop' {
            IISReset /STOP
            break
        }
        'start' {
            IISReset /START
            break
        }
        'restart' {
            IISReset /RESTART
            break
        }
    }
}

Invoke-Command -ComputerName $server `
    -Credential $credential `
    -UseSSL `
    -SessionOption $so `
    -ScriptBlock $script

Write-Output "$display_action_past_tense."