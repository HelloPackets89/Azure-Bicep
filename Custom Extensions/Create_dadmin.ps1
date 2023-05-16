#This script is intended to be ran as a scheduled task. 
#The scheduled task is intended to be scheduled to be ran after the server has promoted itself to domain controller

Import-Module ActiveDirectory
$password = ConvertTo-SecureString -String "A1@SuperPassword" -AsPlainText -Force
New-ADUser -SamAccountName 'dadmin' -UserPassword $password -GivenName 'Domain' -Surname 'Admin' -Enabled $true
Add-ADGroupMember -Identity "Domain Admins" -Members 'dadmin'

#Unregister itself so it does not run on startup 
Unregister-ScheduledTask -TaskName 'Create_Dadmin' -Confirm:$false