Param(
    [parameter(Mandatory = $true)]
    [string]$server,
    [parameter(Mandatory = $false)]
    [string]$web_site_name,
    [parameter(Mandatory = $false)]
    [string]$web_site_path,
    [parameter(Mandatory = $true)]
    [string]$app_pool_name,
    [parameter(Mandatory = $true)]
    [string]$user_id,
    [parameter(Mandatory = $true)]
    [SecureString]$password,
    [parameter(Mandatory = $true)]
    [ValidateSet('start', 'stop', 'restart', 'create-site', 'create-app-pool')]
    [string]$action,
    [parameter(Mandatory = $true)]
    [string]$cert_path
)

switch ($action) {
    "start" {
        $display_action = 'Start'
        $display_action_past_tense = 'started'
        break
    }
    "stop" {
        $display_action = 'Stop'
        $display_action_past_tense = 'stopped'
        break
    }
    "restart" {
        $display_action = 'Restart'
        $display_action_past_tense = 'restarted'
        break
    }
    "create-site" {
        $display_action = 'Create Site'
        $display_action_past_tense = 'site created'
        break
    }
    "create-app-pool" {
        $display_action = 'Create App Pool'
        $display_action_past_tense = 'app pool created'
        break
    }
}


Write-Output "$display_action IIS"
Write-Output "Server: $server - App Pool: $app_pool_name"

$credential = [PSCredential]::new($user_id, $password)
$so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

Write-Output "Importing remote server cert..."
Import-Certificate -Filepath $cert_path -CertStoreLocation "Cert:\LocalMachine\Root"

$app_pool_path = "IIS:\AppPools\$Using:app_pool_name"
$site_path = "IIS:\Sites\$Using:web_site_name"

if (@('start', 'stop', 'restart') | where { $_ -eq $action }) {
    $script = {
        # Relies on WebAdministration Module being installed on the remote server
        # This should be pre-installed on Windows 2012 R2 and later
        # https://docs.microsoft.com/en-us/powershell/module/?term=webadministration

        if ($Using:action -eq "stop" -or $Using:action -eq "restart") {
            Stop-WebAppPool -Name $Using:app_pool_name
        }

        if ($Using:action -eq "start" -or $Using:action -eq "restart") {
            Start-Sleep 10
            Start-WebAppPool -Name $Using:app_pool_name
        }
    }
}
elseif ('create-app-pool' -eq $action) {
    # create app pool if it doesn't exist
    if (Test-Path -Path $app_pool_path) {
        Write-Output "The App Pool $Using:app_pool_name already exists"
    }
    else {
        Write-Output "Creating app pool $Using:app_pool_name"
        $app_pool = New-WebAppPool -Name $Using:app_pool_name
        $app_pool.autoStart = $true
        $app_pool.managedPipelineMode = "Integrated"
        $app_pool | Set-Item
        Write-Output "App pool $Using:app_pool_name has been created"
    }
}
elseif ('create-site' -eq $action) {
    if (!$web_site_name -or !$web_site_path) {
        "Create web site requires site name and path"
        exit 1
    }

    $script = {
        # create app pool if it doesn't exist
        if (Test-Path -Path $app_pool_path) {
            Write-Output "The App Pool $Using:app_pool_name already exists"
        }
        else {
            Write-Output "Creating app pool $Using:app_pool_name"
            $app_pool = New-WebAppPool -Name $Using:app_pool_name
            $app_pool.autoStart = $true
            $app_pool.managedPipelineMode = "Integrated"
            $app_pool | Set-Item
            Write-Output "App pool $Using:app_pool_name has been created"
        }

        # create the folder if it doesn't exist
        if (Test-path $Using:web_site_path) {
            Write-Output "The folder $Using:web_site_path already exists"
        }
        else {
            New-Item -ItemType Directory -Path $Using:web_site_path -Force
            Write-Output "Created folder $Using:web_site_path"
        }

        # create the site if it doesn't exist
        if (!(Test-Path -Path $site_path)) {
            Create-WebSite -Name $Using:web_site_name `
                -PhysicalPath $Using:web_site_path `
                -ApplicationPool $Using:app_pool_name
        }
    }
}

Invoke-Command -ComputerName $server `
    -Credential $credential `
    -UseSSL `
    -SessionOption $so `
    -ScriptBlock $script

Write-Output "IIS app pool $app_pool_name $display_action_past_tense."
