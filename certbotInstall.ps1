#change6
## install certbot
.\certbot-beta-installer-win32.exe /S

## This is to delay the script
PING localhost -n 30 | Out-Null

##create local certbot account and set a password
Add-Type -AssemblyName 'System.Web'
$MaximumPasswordLength = 17
$MinimumPasswordLength = 16
$NumberOfAlphaNumericCharacters = 5
$length = Get-Random -Minimum $MinimumPasswordLength -Maximum $MaximumPasswordLength
$password = [System.Web.Security.Membership]::GeneratePassword($length, $NumberOfAlphaNumericCharacters)
$SecurePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
##I removed and added to ensure that the account was present and the password created above was set,
## because its going to be needed later in the script when setting the scheduled task.
Remove-LocalUser -Name certbot -ErrorAction SilentlyContinue
New-LocalUser -Name "certbot" -Password $SecurePassword -Description "local certbot service account" -PasswordNeverExpires


##Certbot working directory
$certbot_working_dir = 'C:\certbot\'
##create certbot working directory if it doesn't exist
if ((Test-Path -Path $certbot_working_dir) -eq $false ) { New-Item -Path $certbot_working_dir -ItemType Directory -Force | Out-Null }
##cerbot accounts directory
$certbot_accounts_dir = 'C:\Certbot\accounts'
##create certbot accounts directory and move the accounts files from the SCCM cache to the certbot accounts directory
if ((Test-Path -Path $certbot_accounts_dir) -eq $false ) { 
    New-Item -Path $certbot_accounts_dir -ItemType Directory -Force | Out-Null 
    Move-Item -Path .\acme.sectigo.com\ -Destination $certbot_accounts_dir
}

##Add local certbot service account to local admin.  It needs to be a local admin to run the certbot commands.
##I tried playing with giving the service account access to only the certbot working directory and install directory and it wasn't enough.
Add-LocalGroupMember -Member certbot -Group Administrators

##Remove broken scheduled task that certbot install creates
Unregister-ScheduledTask -TaskName "Certbot Renew Task" -Confirm:$false

##Create new scheduled task for certbot to run certbot renew twice aday
$taskname = "Certbot Renew Task"
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -Command "certbot renew"'
$trigger = @(
    $(New-ScheduledTaskTrigger -At 12AM -Daily),
    $(New-ScheduledTaskTrigger -At 12PM -Daily)
)
Register-ScheduledTask -TaskName $taskname -Action $action -Trigger $trigger -User "certbot" -Password "$password" -Description "Execute twice a day the 'certbot renew' command, to renew managed certificates if needed." -RunLevel Highest

