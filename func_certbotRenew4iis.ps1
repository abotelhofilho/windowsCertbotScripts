<## place this script in the \renewal-hooks\post directory
this script is triggered after certbot renews a cert 

This will take the newly certificate and install it in IIS SSL binding depending on certificate name and binding port

Most of the default paths in the function parameters except for pfxdir which is something I use in 

##>
function certbotRenew {
    Param (
        [Parameter(Mandatory = $false)]  [String]$certbotWorkingDir = "C:\certbot\", # default
        [Parameter(Mandatory = $false)]  [String]$pfxDir = "C:\Certbot\pfx\", #default
        [Parameter(Mandatory = $false)]  [String]$opensslInstallDir = "C:\Program Files\OpenSSL-Win64\bin\", #default
        [Parameter(Mandatory = $false)]  [String]$certbotInstallDir = "C:\Program Files (x86)\Certbot\bin\" #default

    )
    ## get today's date
    $today = Get-date
    ## log file name
    $logname = $pfxDir + $Today.tostring("MM-dd-yyyy") + '_Renew-iiscertificate' + '.log'

    $certbotWorkingDirCheck = Test-Path -Path $certbotWorkingDir
    $opensslInstallDirCheck = Test-Path -Path $opensslInstallDir
    $certbotInstallDirCheck = Test-Path -Path $certbotInstallDir
    $certbotENVCheck = $env:path -match 'certbot'

    if (($certbotWorkingDirCheck -and $opensslInstallDirCheck -and $certbotInstallDirCheck -and $certbotENVCheck) -eq $true) {
        $preReqCheck = $true 
        Write-Host "Passed preReq Check" -ForeGround Green
        ## add OpenSSL path to system environment path variable
        $ENV:PATH = "$ENV:PATH" + ";" + $opensslInstallDir + ";"
	}
    else { "ERROR: Certbot or OpenSSL are not installed, or not installed in default directories. `n`nPlease re-run and supply the paths in the appropriate parameters." | Out-File -FilePath $logname }

    ## check if preReq check passed
    if ($preReqCheck -match $true) {
        ## pfx directory path
        #$pfxDir = 'C:\Certbot\pfx\'
        ## get today's date
        #$today = Get-date
        ## log file name
        #$logname = $pfxDir + $Today.tostring("MM-dd-yyyy") + '_Renew-iiscertificate' + '.log'
    
        ## get web binding/s
        $wb = Get-WebBinding -Protocol https
        foreach ($b in $wb) {
            ## parse for ssl port from iis ssl binding
            $sslPort = $b.bindingInformation -split ":" -match "\d"
            ## get current certificate name being used by the iis ssl binding
            $CertificateName = (Get-ChildItem -Path cert:localmachine\my | Select-Object -Property * | Where-Object { $_.Thumbprint -eq $b.certificateHash }).FriendlyName
            ## certificate files
            $certificatefile = "C:\Certbot\live\$CertificateName\cert.pem"
            $certificatekey = "C:\Certbot\live\$CertificateName\privkey.pem"
            $certificatepfxdir = "$pfxdir$CertificateName\"
            $certificatepfx = "$certificatepfxdir$CertificateName.pfx"
            #$certificateoldpfx = "$certificatepfxdir$CertificateName.pfx.old"
            $certificatechain = "C:\Certbot\live\$CertificateName\chain.pem"

            ## Remove all pfx files from the certbot pfx directory
            #Get-ChildItem -path $certificatepfx | Rename-Item -NewName $certificateoldpfx
            Get-ChildItem -path $certificatepfxdir | Remove-Item -Force

	    ## convert certificate PEM file to PFX
            openssl.exe pkcs12 -name $CertificateName -export -in $certificatefile -inkey $certificatekey -out $certificatepfx -certfile $certificatechain -passout pass:
            ## Import new cert into windows OS certificate vault
            $newCert = Import-PfxCertificate -FilePath $certificatepfx -CertStoreLocation Cert:\LocalMachine\My

            # $newCert = (Get-ChildItem -Path cert:localmachine\my | select -Property * | where {$_.FriendlyName -eq $CertificateName -and $_.Issuer -match 'InCommon'} | Sort-Object NotAfter -Descending)[0]

            ## Set SSL Binding path variable
            $bindingInfo = "IIS:\SSLBindings\*!$sslPort"
            ## Change certificate on SSL Binding
            $newCert | Set-Item -Path $bindingInfo

            ## clean up
            $pfxlogs = Get-ChildItem -Path $certificatepfxdir*.log | Sort-Object LastWriteTime -Descending
            if (($pfxlogs).count -gt 3) { $pfxlogs | Select-Object -Skip 3 | Remove-Item -Force }
            
        }
    }
}

## get current script fullname (path+filename)
$scriptname = $myinvocation.mycommand.source

$32bitcheck = [intptr]::size
## Print on screen that if current shell is 64 bit
if ($32bitcheck -eq '8') { Write-host "This is a 64 bit shell" -foregroundColor Magenta }
## Check if powershell is running as 32 bit shell and relaunch as a 64bit shell
if (($pshome -like "*syswow64*") -and ((Get-WmiObject Win32_OperatingSystem).OSArchitecture -like "64*")) {

    write-warning "Restarting script under 64 bit powershell"
     
    ## relaunch this script under 64 bit shell
    & (join-path ($pshome -replace "syswow64", "sysnative")\powershell.exe) -file $scriptname ; exit
}

certbotRenew ## call certbotRenew function

