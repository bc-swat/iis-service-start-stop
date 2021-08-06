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

if ($display_action.StartsWith('App Pool') -and @('start', 'stop', 'restart') | where { $_ -eq $verb }) {
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
elseif ('app-pool-create' -eq $action) {
    $script = {
        # create app pool if it doesn't exist
        if (Get-IISAppPool -Name $Using:app_pool_name) {
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
}
elseif ('app-pool-status' -eq $action) {
    $script = {
        $app_pool = Get-IISAppPool -Name $Using:app_pool_name
        Write-Output "::set-output name=app-pool-status::$app_pool"
    }
}
elseif ('site-create' -eq $action) {
    if (!$web_site_name -or !$web_site_path -or !$web_site_host_header) {
        "Create web site requires site name, host header and path"
        exit 1
    }

    $script = {
        # create app pool if it doesn't exist
        if (Get-IISAppPool -Name $Using:app_pool_name) {
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
        if (Get-IISSite -Name $Using:web_site_name) {
            Write-Output "The site $Using:web_site_name already exists"
        }
        else {
            Write-Host "Creating IIS site $Using:web_site_name"
            New-WebSite -Name $Using:web_site_name `
                -HostHeader $Using:web_site_host_header `
                -Ssl -Port 443 `
                -PhysicalPath $Using:web_site_path `
                -ApplicationPool $Using:app_pool_name
        }
    }
}

$Env:OUTPUT_APP_POOL_STATUS = Invoke-Command -ComputerName $server `
    -Credential $credential `
    -UseSSL `
    -SessionOption $so `
    -ScriptBlock $script

Write-Output "IIS $display_action_past_tense."
