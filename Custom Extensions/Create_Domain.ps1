#This custom extension installs ADDS on the server, creates a new forest and promotes itself to DC
#It then creates a Domain Admin Account
#This script is only intended for deploying test environments. 

# Define the parameters for the new forest and domain controller
$domainName = "domain.local"
$safeModeAdminPassword = ConvertTo-SecureString -String "A1@SuperPassword" -AsPlainText -Force

# Install the AD DS role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# Import the AD DS deployment module
Import-Module ADDSDeployment

# Install a new forest and promote the server to a domain controller.
#WinThreshold corresponds to Server 2016 , which is the highest forest level at the time of writing.  
#Default Paths
Install-ADDSForest -DomainName $domainName `
    -DomainMode "WinThreshold" `
    -ForestMode "WinThreshold" `
    -InstallDns:$true `
    -SafeModeAdministratorPassword $safeModeAdminPassword `
    -DomainNetbiosName ( $domainName.Split(".")[0] ) `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" 

#Create a scheduled task to create a new domain admin on start up
$taskName = "CreateAdminUser"
#This defines the task that creates the domain. It then runs a command to unregister the task so a new admin account isn't made everytime the server starts up. 
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-Command {Import-Module ActiveDirectory; New-ADUser -SamAccountName 'dadmin' -UserPassword (ConvertTo-SecureString -String 'YourPassword' -AsPlainText -Force) -Name 'Domain Admin' -GivenName 'Domain' -Surname 'Admin' -Enabled $true; `
     Add-ADGroupMember -Identity 'Domain Admins' -Members 'dadmin'; `
     Unregister-ScheduledTask -TaskName `"$taskName`" -Confirm:$false}"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount

# Register the scheduled task
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskName -Description "#Create a scheduled task to create a new domain admin on start up" -Principal $principal

#Restart-Computer -Force
