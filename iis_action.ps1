Param(
    [parameter(Mandatory = $true)]
    [ValidateSet( 'app-pool-start', 'app-pool-stop', 'app-pool-restart', `
            'app-pool-create', 'app-pool-status', `
            'website-create')]
    [string]$action,
    [parameter(Mandatory = $true)]
    [string]$server,
    [parameter(Mandatory = $false)]
    [string]$website_name,
    [parameter(Mandatory = $false)]
    [string]$website_host_header,
    [parameter(Mandatory = $false)]
    [string]$website_path,
    [parameter(Mandatory = $false)]
    [string]$website_cert_path,
    [parameter(Mandatory = $false)]
    [SecureString]$website_cert_password,
    [parameter(Mandatory = $false)]
    [string]$website_cert_friendly_name,
    [parameter(Mandatory = $true)]
    [string]$app_pool_name,
    [parameter(Mandatory = $true)]
    [string]$user_id,
    [parameter(Mandatory = $true)]
    [SecureString]$password,
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
        $action_prefix = 'website\-(?<verb>.+)'
        $display_action = 'Website'
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
Import-Certificate -Filepath $cert_path -CertStoreLocation 'Cert:\LocalMachine\Root'

if ($action -like 'app-pool-*') {
    $script = app_pool_action $app_pool_name, $verb
}
elseif ($action -eq 'website-create') {
    if (!$website_name -or !$website_path -or !$website_host_header -or !$website_cert_path -or !$website_cert_password -or !$website_cert_friendly_name) {
        "Create website requires site name, host header, website cert, website cert password, website cert friendly name, and directory path"
        exit 1
    }

    # Get the key data
    [Byte[]]$website_cert_data = Get-Content -Path $website_cert_path -Encoding Byte

    $script = site_create `
        -website_name $website_name `
        -app_pool_name $app_pool_name `
        -website_path $website_path `
        -website_host_header $website_host_header `
        -website_cert_path $website_cert_path `
        -website_cert_password $website_cert_password `
        -website_cert_friendly_name $website_cert_friendly_name `
        -website_cert_data $website_cert_data
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
