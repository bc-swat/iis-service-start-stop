function site_create {
    Param(
        [string]$website_name,
        [string]$app_pool_name,
        [string]$website_path,
        [string]$website_host_header,
        [string]$website_cert_path,
        [SecureString]$website_cert_password,
        [string]$website_cert_friendly_name,
        [Byte[]]$website_cert_data
    )

    return {
        $website_cert_store = 'cert:\LocalMachine\My'
        $cert_file_parts = $($Using:website_cert_path).Replace('/', '\').Split('\')
        $cert_file_name = $cert_file_parts[$cert_file_parts.Length - 1]
        $cert_file_path = (Join-Path -Path $Using:website_path -ChildPath $cert_file_name)

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
        if (Test-path $Using:website_path) {
            Write-Output "The folder $Using:website_path already exists"
        }
        else {
            New-Item -ItemType Directory -Path $Using:website_path -Force
            Write-Output "Created folder $Using:website_path"
        }

        #write out the cert
        Set-Content -Path $cert_file_path -Value $Using:website_cert_data -Encoding Byte
        $imported_cert = Get-ChildItem -Path $website_cert_store | where { $_.FriendlyName -eq $Using:website_cert_friendly_name }
        if (!$imported_cert) {
            $imported_cert = Import-PfxCertificate `
                -CertStoreLocation $website_cert_store `
                -FilePath $cert_file_path `
                -Password $Using:website_cert_password
        }

        # create the site if it doesn't exist
        $iis_site = Get-IISSite -Name $Using:website_name
        if ($iis_site) {
            Write-Output "The site $Using:website_name already exists"
        }
        else {
            Write-Output "Creating IIS site $Using:website_name"
            New-WebSite -Name $Using:website_name `
                -HostHeader $Using:website_host_header `
                -Port 80 `
                -PhysicalPath $Using:website_path `
                -ApplicationPool $Using:app_pool_name

            New-WebBinding -Name $Using:website_name `
                -IPAddress "*" -Port 443 `
                -HostHeader $Using:website_host_header `
                -Protocol "https"

            $ssl_binding = Get-WebBinding -Name $Using:website_name | where { $_.Protocol -eq 'https' }

            $cert_parts = $website_cert_store.Split('\')
            $location = $cert_parts[$cert_parts.Length - 1]

            $ssl_binding.AddSslCertificate($imported_cert.Thumbprint, $location)
        }
    }
}