// This script quickly deploys an Azure Machine Learning Workspace
// This is used to quickly spin up a space for lab/development work
// This is  WIP and not yet functional

param location string = 'australiaeast'

//Assigns a semi-random number to the deployment.
// utcnow is used in-lieu of a random number generator. May cause issues. 
param WSName string =  ('mlws${baseTime}')
param baseTime string = utcNow('mmss')

resource StorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  location:location
  name: '${WSName}storage'
  kind:'StorageV2'
  sku:{
    name:'Standard_LRS'
  }
  properties:{
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: true
    encryption:{
      keySource:'Microsoft.Storage'
      services:{
        blob:{
          enabled:true
        }
        file:{
          enabled:true
        }
      }
    }
  }
}

resource Keyvault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${WSName}KeyVault'
  location:location
  properties:{
    accessPolicies:[]
    tenantId: subscription().tenantId
    sku:{
      family:'A'
      name:'standard'
    }
  }
}

resource Insights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${WSName}Insights'
  location:location
  properties:{
    Application_Type:'web'
    Flow_Type: 'Redfield'
    Request_Source: 'IbizaMachineLearningExtension'
  }
}

resource MLworkspace 'Microsoft.MachineLearningServices/workspaces@2023-04-01' ={
name: WSName
location: location
identity:{
  type:'SystemAssigned'
  }
properties:{
  applicationInsights: Insights.id
  storageAccount: StorageAccount.id
  keyVault: Keyvault.id
}
}
