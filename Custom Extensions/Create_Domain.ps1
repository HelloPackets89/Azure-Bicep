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

