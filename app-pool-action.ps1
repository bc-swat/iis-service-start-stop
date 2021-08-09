function app_pool_start_stop_restart {
    Param(
        [string]$app_pool_name,
        [string]$action
    )
    return {
        # Relies on WebAdministration Module being installed on the remote server
        # This should be pre-installed on Windows 2012 R2 and later
        # https://docs.microsoft.com/en-us/powershell/module/?term=webadministration

        if ($Using:action -eq 'stop' -or $Using:action -eq 'restart') {
            Stop-WebAppPool -Name $Using:app_pool_name
        }

        if ($Using:action -eq 'start' -or $Using:action -eq 'restart') {
            Start-Sleep 10
            Start-WebAppPool -Name $Using:app_pool_name
        }
    }
}

function app_pool_create {
    Param(
        [string]$app_pool_name
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
    }
}

function app_pool_status {
    param(
        [string]$app_pool_name
    )
    return {
        $app_pool = Get-IISAppPool -Name $Using:app_pool_name
        return "$($app_pool.Name): $($app_pool.State)"
    }
}


function app_pool_action {
    Param(
        [string]$app_pool_name,
        [string]$action
    )
    {
        switch -exact ($action) {
            'start' {}
            'stop' {}
            'restart' {
                return app_pool_start_stop_restart -app_pool_name $app_pool_name -action $action
            }
            'create' {
                return app_pool_create -app_pool_name $app_pool_name
            }
            'status' {
                return app_pool_status -app_pool_name $app_pool_name
            }
        }
    }
}