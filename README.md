# windowsCertbotScripts
Scripts I developed for automating install, request and renew of ssl certificates using certbot for Microsoft IIS web server


**certbotInstall.ps1**
  > Script for deploying certbot from SCCM.<br>
    - It will install certbot vanilla <br>
    - Create a local service account with a randomly generated password<br>
    - Add service account to local administrator group because it needs it for certbot renew<br>
    - Removes scheduled tasks installed by certbot, creates new scheduled task that run twice daily(12AM/12PM).

**func_certbotRenew4iis.ps1**
  > Renew and replace certs for Microsoft IIS<br>
    - DEPENDENCY: openSSL for Windows and certbot (obviously) <br>

**func_Get-CertbotCertificate4IIS.ps1**
  > Function for requesting certificates using certbot with ACME<br>
    - has a preReq check for IIS being installed.<br>
    - DEPENDENCY: openSSL for Windows and certbot (obviously) <br>
    - Will prompt for tcp port to create\replace ssl bind on if -sslport not provided<br>
