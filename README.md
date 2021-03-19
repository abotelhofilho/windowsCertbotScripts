# windowsCertbotScripts
Scripts I developed for automating install, request and renew of ssl certificates using certbot


**certbotInstall.ps1**
  > Script for deploying certbot from SCCM.
    - It will install certbot vanilla <br>
    - Create a local service account with a randomly generated password
    - Add service account to local administrator group because it needs it for certbot renew
    - Remove the scheduled task certbot installs and creates a new one that runs twice a day.

**func_certbotRenew4iis.ps1**
  > renew and replace certs for Microsoft IIS
    - DEPENDENCY: openSSL for Windows and certbot (obviously)

**func_Get-CertbotCertificate4IIS.ps1**
  > function for requesting certificates using certbot with ACME
    - has a preReq check for IIS being installed.
    - DEPENDENCY: openSSL for Windows and certbot (obviously)
    - Will prompt for tcp port to create\replace ssl bind on if -sslport not provided
