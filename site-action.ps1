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
        $web_site_cert_store = 'cert:\LocalMachine\My'
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
        Set-Content -Path $cert_file_path -Value $Using:web_site_cert_data -Encoding Byte

        # Always import the cert, because there's a lot of work to do thumbprint comparisons
        # in powershell of an un-imported pfx file
        $imported_cert = Import-PfxCertificate `
            -CertStoreLocation $web_site_cert_store `
            -FilePath $cert_file_path `
            -Password $Using:web_site_cert_password

        # create the site if it doesn't exist
        $iis_site = Get-IISSite -Name $Using:web_site_name
        if ($iis_site) {
            Write-Output "The site $Using:web_site_name already exists"
        }
        else {
            Write-Output "Creating IIS site $Using:web_site_name"
            $iis_site = New-WebSite -Name $Using:web_site_name `
                -HostHeader $Using:web_site_host_header `
                -Port 80 `
                -PhysicalPath $Using:web_site_path `
                -ApplicationPool $Using:app_pool_name

            $cert_parts = $web_site_cert_store.Split('\')
            $location = $cert_parts[$cert_parts.Length - 1]

            $binding = Set-WebBinding -Name $Using:web_site_name `
                -BindingInformation "443" -PropertyName "Port" -Value "443"
            $binding.AddSslCertificate($imported_cert.GetCertHashString(), $location)
        }
    }
}