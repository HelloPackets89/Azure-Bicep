param location string = resourceGroup().location
param name string
param repoUrl string
param branch string = 'main'
param SPSecret string 
param tenantID string
param SPID string

resource storageaccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: '${name}storage'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
var StorageAccountPrimaryAccessKey = storageaccount.listKeys().keys[0].value

resource appinsights 'Microsoft.Insights/components@2020-02-02' ={
  name: '${name}appinsights'
  location: location
  kind: 'web'
  properties:{
    Application_Type: 'web'
    publicNetworkAccessForIngestion:'Enabled'
    publicNetworkAccessForQuery:'Enabled'
  }
}
var AppInsightsPrimaryAccessKey = appinsights.properties.InstrumentationKey

resource hostingplan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${name}hp'
  location: location
  kind: 'linux'
  properties: {
    reserved:true
  }
  sku:{
    name: 'Y1' //Consumption plan
  }
}

resource ResumeFunctionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${name}functionapp'
  location: location
  kind: 'functionapp'
  identity:{
    type:'SystemAssigned'
  }
  properties:{
    httpsOnly:true
    serverFarmId:hostingplan.id
    siteConfig:{
      alwaysOn:false
      linuxFxVersion: 'python|3.10'
      cors:{
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
      appSettings:[
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: AppInsightsPrimaryAccessKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${AppInsightsPrimaryAccessKey}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${StorageAccountPrimaryAccessKey}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(storageaccount.name)
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageaccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${StorageAccountPrimaryAccessKey}'
        }
      ]
    }
  }
}


//This resource assumes a service principal is already created inside your Entra tenant and that its corresponding secrets are configured in your github. 

resource githubactions 'Microsoft.Web/sites/sourcecontrols@2020-12-01' = {
  parent: ResumeFunctionApp
  name: 'web'
  properties: {
    repoUrl: repoUrl
    branch: branch
    isManualIntegration: false
    deploymentRollbackEnabled: false
    isMercurial: false
    isGitHubAction: true
    gitHubActionConfiguration: {
      generateWorkflowFile: true
      workflowSettings: {
        appType: 'functionapp'
        authType: 'serviceprincipal'
        publishType: 'code'
        os: 'linux'
        runtimeStack: 'python'
        workflowApiVersion: '2022-10-01'
        slotName: 'production'
        variables: {
          runtimeVersion: '3.11'
          clientId: SPID
          tenantId: tenantID
          clientSecret: SPSecret
        }
      }
    }
  }
}
