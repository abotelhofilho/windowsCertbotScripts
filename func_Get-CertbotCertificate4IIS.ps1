<## 
        -sslBindingPort, if a port is included it won't prompt for TCP port for the SSL bind, if no port is included you'll be prompted for ssl binding port.
        -CertificateName, certificate friendly name
        -CertificateDomains, certificate DNS names.  If multiple names use a comma to separate.
        -email, email address for the certification notification registration
        -server, if no server is specified it uses lets encrypt by default.  It can be use with alternative ACME servers like InCommmon or Sectigo
        -eab_kid, please supply your eab-kID from your ACME server
        -eab_hmac_key, please supply your eab-hmac-key from your ACME server
        -certbotWorkingDir, default certbot working directory path is "C:\certbot\"
        -pfxDir,  default directory path for the PFX certs "C:\Certbot\pfx\"
        -opensslInstallDir, default openSSL install directory "C:\Program Files\OpenSSL-Win64\bin\"
        -certbotInstallDir = default certbot install directory "C:\Program Files (x86)\Certbot\bin\"
##>
function Get-CertbotCertificate4IIS {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)] $sslBindingPort,
        [Parameter(Mandatory = $true)] $CertificateName,
        [Parameter(Mandatory = $true)] [String[]] $CertificateDomains,
        [Parameter(Mandatory = $true)] $email,
        [Parameter(Mandatory = $true)] $server,
        [Parameter(Mandatory = $true)] $eab_kid,
        [Parameter(Mandatory = $true)] $eab_hmac_key,
        [Parameter(Mandatory = $false)] $certbotWorkingDir = "C:\certbot\", # default
        [Parameter(Mandatory = $false)] $pfxDir = "C:\Certbot\pfx\", #default
        [Parameter(Mandatory = $false)] $opensslInstallDir = "C:\Program Files\OpenSSL-Win64\bin\", #default
        [Parameter(Mandatory = $false)] $certbotInstallDir = "C:\Program Files (x86)\Certbot\bin\" #default
    )
    ## get today's date
    $today = Get-date
    ## log file name
    $logname = $pfxDir + $Today.tostring("MM-dd-yyyy") + '_Renew-iiscertificate' + '.log'

    $certbotWorkingDirCheck = Test-Path -Path $certbotWorkingDir
    $opensslInstallDirCheck = Test-Path -Path $opensslInstallDir
    $certbotInstallDirCheck = Test-Path -Path $certbotInstallDir

    $webserver = (Get-WindowsFeature web-server).installstate
    if ($webserver -eq 'installed') { $iischeck = $true } else { $iischeck = $false }
    
    if (($certbotWorkingDirCheck -and $opensslInstallDirCheck -and $certbotInstallDirCheck -and $iischeck) -eq $true) { 
        $preReqCheck = $true
        Write-Host "Passed preReq Check" -ForeGround Green
        ## add OpenSSL path to system environment path variable
        $ENV:PATH = "$ENV:PATH" + ";" + $opensslInstallDir + ";" + $certbotInstallDir + ";"
        ## Import webAdmin powershell module
        Import-Module WebAdministration
    }
    else { 
        if ($certbotWorkingDirCheck -eq $false) { $certbotWorkingDirCheck = "Failed" } else { $certbotWorkingDirCheck = "Passed" } 
        if ($opensslInstallDirCheck -eq $false) { $opensslInstallDirCheck = "Failed" } else { $opensslInstallDirCheck = "Passed" }
        if ($certbotInstallDirCheck -eq $false) { $certbotInstallDirCheck = "Failed" } else { $certbotInstallDirCheck = "Passed" }
        if ($iischeck -eq $false) { $iischeck = "Failed" } else { $iischeck = "Passed" }

        Write-Host "ERROR: Please check the log file $logname" -ForegroundColor Red -BackgroundColor Black
        
        "ERROR: Certbot or OpenSSL or IIS are not installed, or not installed in default directories.
        `nReview preReqCheck logged below.  
        `nPlease check that Certbot and OpenSSL and IIS are installed and re-run with the correct the paths in the appropriate parameters if they are not installed in the default directories.
        `nPreReqChecks below:
        Certbot Install Directory Check = $certbotInstallDirCheck
        Certbot Working Directory Check = $certbotWorkingDirCheck
        OpenSSL Install Directory Check = $opensslInstallDirCheck
        Is IIS Installed Check = $iischeck " | Out-File -FilePath $logname
        Get-Content $logname
    }

    ## check if preReq check passed
    if ($preReqCheck -match $true) {
        ## certificate files
        $certificatefile = "C:\Certbot\live\$CertificateName\cert.pem"
        $certificatekey = "C:\Certbot\live\$CertificateName\privkey.pem"
        $certificatepfxdir = "$pfxdir$CertificateName\"
        $certificatepfx = "$certificatepfxdir$CertificateName.pfx"
        #$certificateoldpfx = "$certificatepfxdir$CertificateName.pfx.old"
        $certificatechain = "C:\Certbot\live\$CertificateName\chain.pem"

        New-Item -Path $certificatepfxdir -ItemType Directory -Force | Out-Null 

        $CertificateDomains = $CertificateDomains -join ','
			
        ## request cert
        certbot certonly --webroot --non-interactive --agree-tos --email $email --server $server --eab-kid $eab_kid --eab-hmac-key $eab_hmac_key --domain $CertificateDomains --cert-name $CertificateName

        ## convert certificate PEM file to PFX
        openssl.exe pkcs12 -name $CertificateName -export -in $certificatefile -inkey $certificatekey -out $certificatepfx -certfile $certificatechain -passout pass:
        ## Import new cert into windows OS certificate vault
        $newCert = Import-PfxCertificate -FilePath $certificatepfx -CertStoreLocation Cert:\LocalMachine\My

        if ($sslBindingPort -match '\d') {
            $sslPort = $sslBindingPort
            $bindingInfo = "IIS:\SSLBindings\*!$sslPort"
            ## Change certificate on SSL Binding
            $newCert | Set-Item -Path $bindingInfo 
        }
        else {
            do {
                try {
                    $sslPort = $null ; [Int]$sslPort = Read-Host -Prompt 'Enter TCP port for certificate binding'
                }
                catch { 
                    Write-Host "You've entered an invalid TCP port." -ForegroundColor RED 
                }
                ## Set SSL Binding path variable
                $bindingInfo = "IIS:\SSLBindings\*!$sslPort"
                ## Change certificate on SSL Binding
                $newCert | Set-Item -Path $bindingInfo 
            }
            until (($sslPort -is [Int]) -eq $true)
        } 
        ## clean up
        $pfxlogs = Get-ChildItem -Path $certificatepfxdir*.log | Sort-Object LastWriteTime -Descending
        if (($pfxlogs).count -gt 3) { $pfxlogs | Select-Object -Skip 3 | Remove-Item -Force }
    }
}

## get current script fullname (path+filename)
$scriptname = $myinvocation.mycommand.source

#$32bitcheck = [intptr]::size
## Print on screen that if current shell is 64 bit
#if ($32bitcheck -eq '8') { Write-host "This is a 64 bit shell" -foregroundColor Magenta }
## Check if powershell is running as 32 bit shell and relaunch as a 64bit shell
if (($pshome -like "*syswow64*") -and ((Get-WmiObject Win32_OperatingSystem).OSArchitecture -like "64*")) {

    write-warning "Restarting script under 64 bit powershell"
     
    ## relaunch this script under 64 bit shell
    & (join-path ($pshome -replace "syswow64", "sysnative")\powershell.exe) -file $scriptname ; exit
}