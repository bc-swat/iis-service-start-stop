# IIS Service Action

A GitHub action that can start, stop, or restart an On-Prem IIS servers.

## Index
- [Inputs](#inputs)
- [Pre-requisites](#pre-requisites)
- [Code of Conduct](#code-of-conduct)
- [License](#license)

### Inputs
| Parameter                  | Is Required | Description                                              |
| -------------------------- | ----------- | -------------------------------------------------------- |
| `server`                   | true        | The name of the target server                            |
| `service-account-id`       | true        | The service account name                                 |
| `service-account-password` | true        | The service account password                             |
| `app-pool-name`            | true        | IIS app pool name                                        |
| `action`                   | true        | Specify start, stop, or restart as the action to perform |
| `server-public-key`        | true        | Path to remote server public ssl key                     |

### Pre-requisites

- Allow NSG WinRm Inbound Traffic (HTTPS port 5986) from GitHub Actions Runner VNet/Subnet
- Prep the remote IIS server to accept WinRM IIS management calls.  Detailed instructions and explanations can be found in this article: [PowerShell Remoting over HTTPS with a self-signed SSL certificate]

  This is a sample script that would be run on the target IIS server:

  ```powershell
  $Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName <<ip-address|fqdn-host-name>>

  Export-Certificate -Cert $Cert -FilePath C:\temp\<<cert-name>>

  Enable-PSRemoting -SkipNetworkProfileCheck -Force

  # Check for HTTP listeners
  dir wsman:\localhost\listener

  # If HTTP Listeners exist, remove them
  Get-ChildItem WSMan:\Localhost\listener | Where -Property Keys -eq "Transport=HTTP" | Remove-Item -Recurse

  # If HTTPs Listeners don't exist, add one
  New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint –Force

  # This allows old WinRm hosts to use port 443
  Set-Item WSMan:\localhost\Service\EnableCompatibilityHttpsListener -Value true

  # Make sure an HTTPs inbound rule is allowed
  New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Name "Windows Remote Management (HTTPS-In)" -Profile Any -LocalPort 5986 -Protocol TCP

  # For security reasons, you might want to disable the firewall rule for HTTP that *Enable-PSRemoting* added:
  Disable-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)"
  ```

  - `ip-address` or `fqdn-host-name` can be used for the `DnsName` property in the certificate creation. It should be the name that the actions runner will use to call to the IIS server.
  - `cert-name` can be any name.  This file will used to secure the traffic between the actions runner and the IIS server

## Example

```yml
...

jobs:
  stop-iis:
   runs-on: [self-hosted, windows-2019]
   env:
      server: 'iis-server.extendhealth.com'
      pool-name: 'website-pool'
      cert-path: './server-cert'

   steps:
    - name: Checkout
      id: Checkout
      uses: actions/checkout@v2
    - name: IIS stop
      id: iis-stop
      uses: 'im-open/iis-service-action@v1.0.0'
      with:
        server: ${{ env.server }}
        service-account-id: ${{secrets.iis_admin_user}}
        service-account-password: ${{secrets.iis_admin_password}}
        app-pool-name: ${{ env.pool-name }}
        action: 'stop'
        server-public-key: ${{ env.cert-path }}

  ...
```


### Code of Conduct

This project has adopted the [im-open's Code of Conduct](https://github.com/im-open/.github/blob/master/CODE_OF_CONDUCT.md).

### License

Copyright &copy; 2021, Extend Health, LLC. Code released under the [MIT license](LICENSE).


<!-- Links -->
[PowerShell Remoting over HTTPS with a self-signed SSL certificate]: https://4sysops.com/archives/powershell-remoting-over-https-with-a-self-signed-ssl-certificate