function site_create {
    Param(
        [string]$web_site_name,
        [string]$app_pool_name,
        [string]$web_site_path,
        [string]$web_site_host_header,
        [string]$web_site_cert_path,
        [SecureString]$web_site_cert_password,
        [Byte[]]$web_site_cert_data
    )

    return {
        $cert_file_parts = $($Using:web_site_cert_path).Replace('/', '\').Split('\')
        $cert_file_name = $cert_file_parts[$cert_file_parts.Length - 1]
        $cert_file_path = (Join-Path -Path $Using:web_site_path -ChildPath $cert_file_name)

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

        #write out the cert
        $cert_store_path = 'Cert:\LocalMachine\Root'
        Set-Content -Path $cert_file_path -Value $Using:web_site_cert_data -Encoding Byte

        $importing_cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $importing_cert.Import($cert_file_path, $Using:web_site_cert_password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
        $imported_cert = Get-ChildItem $cert_store_path | where { $_.Subject -eq $importing_cert.Subject }
        $import_cert = $true

        if ($imported_cert -and $imported_cert.Thumbprint -eq $importing_cert.Thumbprint) {
            $import_cert = $false
        }

        if ($import_cert) {
            Import-PfxCertificate `
                -CertStoreLocation $cert_store_path `
                -FilePath $cert_file_path `
                -Password $web_site_cert_password
        }

        # create the site if it doesn't exist
        $iis_site = Get-IISSite -Name $Using:web_site_name
        if ($iis_site) {
            Write-Output "The site $Using:web_site_name already exists"
        }
        else {
            Write-Output "Creating IIS site $Using:web_site_name"
            $iis_site = New-WebSite -Name $Using:web_site_name `
                -HostHeader $Using:web_site_host_header `
                -Ssl -Port 443 `
                -SslFlags 0 `
                -PhysicalPath $Using:web_site_path `
                -ApplicationPool $Using:app_pool_name
        }

        $binding = Get-WebBinding -Name $Using:web_site_name -Protocol "https"
        if (!$binding) {
            Set-WebBinding `
                -Name $Using:web_site_name `
                -BindingInformation '443' `
                -HostHeader $Using:web_site_host_header `
                -Confirm $false `
                -Port 443
        }
    }
}