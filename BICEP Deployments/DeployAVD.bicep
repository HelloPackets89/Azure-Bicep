//Brandon's first AVD BICEP Script. Created by referencing the portal creation wizard, MS Learn, VS Code Hints and Trial n Error.
param vmsize string = 'Standard_B2s'
param location string = 'australiaeast'
param useruri string = 'https://bklabkv.vault.azure.net/secrets/vmpassword/3f8ff853ccfb4aec811a39dbf54121c9'
param passworduri string = 'https://bklabkv.vault.azure.net/secrets/vmuser/0d460fb32e0943f3b4357eb812973417'
//Assigns a semi-random number to the deployment.
// utcnow is used in-lieu of a random number generator. May cause issues. 
param baseTime string = utcNow('mmss')
param vmName string =  ('test${baseTime}')

//hostpool
resource hostpool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: '${vmName}_HP'
  location: location
    
    properties: {
      validationEnvironment: false
      preferredAppGroupType: 'Desktop'
      hostPoolType: 'Pooled'
      loadBalancerType: 'BreadthFirst'
      maxSessionLimit: 3
      managementType : 'automated'
  }
}


//Desktop Application group. Depends on the hostpool
resource DesktopAppGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: '${vmName}DAG'
  location: location
  properties:{
    applicationGroupType: 'Desktop'
    hostPoolArmPath: hostpool.id
  }
}

//Virtual Machines
resource SessionHosts 'Microsoft.DesktopVirtualization/hostPools/sessionHostConfigurations@2023-11-01-preview' ={
  name: 'default'
    properties:{
      diskInfo: {
        type: 'StandardSSD_LRS'
      }
      domainInfo: {
        joinType: 'AzureActiveDirectory'
      }
      imageInfo: {
        type: 'Marketplace'
        marketplaceInfo:{
          sku: 'win10-21h2-avd'
          exactVersion: '19044.3570.231001'
          offer: 'Windows-10'
          publisher: 'MicrosoftWindowsDesktop'
        }
      }
      networkInfo: {
        subnetId: subnetid
      }
      vmAdminCredentials: {
        passwordKeyVaultSecretUri: useruri
        usernameKeyVaultSecretUri: passworduri
      }
      vmNamePrefix: '${vmName}SH'
      vmSizeId: vmsize
    }
  parent:hostpool
}

//workspace - linked template? Depends on DAG
resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: '${vmName}_Workspace'
  location:location
  
}
