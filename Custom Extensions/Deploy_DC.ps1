<#
The goal of this script is to Create a new forest, promote the server to domain controller
and then create a domain admin account called 'dadmin'
It does this by performing the following:
1. It downloads two .ps1's from this github - Create_domain.ps1 and Create_dadmin.ps1
Create_Domain will create the forest and domain controller
Create_dadmin will create the domain admin account.
2. It then creates a scheduled task to run the Create_dadmin account on startup
3. It will then run create_domain
4. A restart will occur and upon relogin, create_dadmin will run. 
#>

#Create the location if it doesn't already exist
$scriptDir = "C:\HelloPackets89"
if (!(Test-Path $scriptDir)) {
    New-Item -ItemType Directory -Path $scriptDir | Out-Null
}
$scriptPath1 = Join-Path -Path $scriptDir -ChildPath "Create_domain.ps1"
$scriptPath2 = Join-Path -Path $scriptDir -ChildPath "Create_dadmin.ps1"

#Download the files from Github and store them in C:/HelloPackets89/
$scriptUrl1 = "https://github.com/HelloPackets89/Azure-Bicep/blob/main/Custom%20Extensions/Create_Domain.ps1"
$scriptUrl2 = "https://github.com/HelloPackets89/Azure-Bicep/blob/main/Custom%20Extensions/Create_dadmin.ps1"

# Specify the path where the .ps1 file will be saved
$scriptPath = "C:\Temp\script.ps1"

# Download the .ps1 file
Invoke-WebRequest -Uri $scriptUrl1 -OutFile $scriptPath1
Invoke-WebRequest -Uri $scriptUrl2 -OutFile $scriptPath2

# Execute the .ps1 file
& $scriptPath1


#Create the scheduled task to run Create_Dadmin


