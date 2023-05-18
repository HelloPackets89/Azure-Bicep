
#User input required
$RG = ""
$password = ""

#Default parameters
$Templatefile = "DeployVMDynamicRDP.bicep"
$Location = "australiaeast"
$adminuser = "beeadmin"
$vmsize = "Standard_B2s"
$contact = "test@domain.com"
$autoshutdowntime = "2000"



# Deploy Bicep template
# add the parameter "vmName" if you want to define resource names. Otherwise the name will be randomised. 
az login
az deployment group create --resource-group $RG --template-file $Templatefile `
    --parameters `
        adminPassword=$password `
        adminUser=$adminuser `
        vmsize=$vmsize `
        contact=$contact `
        autoshutdowntime=$autoshutdowntime `
        location=$Location