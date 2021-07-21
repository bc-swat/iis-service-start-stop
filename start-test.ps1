# 10.207.164.190 `

Set-Location "C:\actions-runner\_work\_actions\im-open\iis-service-action\v0"

$secure_password = ConvertTo-SecureString -String "M=giiIDy0EPFI+l0" -AsPlainText -Force

.\start.ps1 -server gar-d-wn000008.extendhealth.com -app_pool_name "action-test-pool" -user_id "vmss_admin" -password $secure_password
