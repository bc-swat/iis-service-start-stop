Param(
    [parameter(Mandatory = $true)]
    [string]$server,
    [parameter(Mandatory = $false)]
    [string]$web_site_name,
    [parameter(Mandatory = $false)]
    [string]$web_site_host_header,
    [parameter(Mandatory = $false)]
    [string]$web_site_path,
    [parameter(Mandatory = $true)]
    [string]$app_pool_name,
    [parameter(Mandatory = $true)]
    [string]$user_id,
    [parameter(Mandatory = $true)]
    [SecureString]$password,
    [parameter(Mandatory = $true)]
    [ValidateSet('app-pool-start', 'app-pool-stop', 'app-pool-restart', 'app-pool-create', 'app-pool-status', 'site-create')]
    [string]$action,
    [parameter(Mandatory = $true)]
    [string]$cert_path
)

. $PSScriptRoot\app-pool-action.ps1
. $PSScriptRoot\site-action.ps1

switch -Regex ($action) {
    "app-pool*" {
        $action_prefix = 'app\-pool\-(?<verb>.+)'
        $display_action = 'App Pool'
        break;
    }
    "site*" {
        $action_prefix = 'site\-(?<verb>.+)'
        $display_action = 'Web Site'
        break;
    }
}

$action -match $action_prefix
$verb = $Matches.verb
$title_verb = (Get-Culture).TextInfo.ToTitleCase($verb)

$display_action += " $title_verb"
$display_action_past_tense = $display_action + $(If (!$verb.EndsWith('p')) { If (!$verb.EndsWith("e")) { "e" } else {} } else { "p" }) + "d"

Write-Output "IIS $display_action"
Write-Output "Server: $server - App Pool: $app_pool_name"

$credential = [PSCredential]::new($user_id, $password)
$so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

Write-Output "Importing remote server cert..."
Import-Certificate -Filepath $cert_path -CertStoreLocation "Cert:\LocalMachine\Root"

if ($action -like 'app-pool-*') {
    $script = app_pool_action $app_pool_name, $verb
}
elseif ($action -eq 'site-create') {
    if (!$web_site_name -or !$web_site_path -or !$web_site_host_header) {
        "Create web site requires site name, host header and path"
        exit 1
    }
    $script = site_create $web_site_name, $app_pool_name, $web_site_path, $web_site_host_header
}

$result = Invoke-Command -ComputerName $server `
    -Credential $credential `
    -UseSSL `
    -SessionOption $so `
    -ScriptBlock $script

if ($result) {
    switch -exact ($action) {
        'app-pool-status' {
            Write-Output "::set-output name=app-pool-status::$result"
            break
        }

    }
}
Write-Output "IIS $display_action_past_tense."
