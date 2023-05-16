# Import the Active Directory module
Import-Module ActiveDirectory

# Define the user parameters
$password = ConvertTo-SecureString -String "A1@SuperPassword" -AsPlainText -Force
New-ADUser -SamAccountName 'dadmin' -UserPassword $password -GivenName 'Domain' -Surname 'Admin' -Enabled $true
Add-ADGroupMember -Identity "Domain Admins" -Members 'dadmin'
