function site_create {
    Param(
        [string]$web_site_name,
        [string]$app_pool_name,
        [string]$web_site_path,
        [string]$web_site_host_header
    )

    return {
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