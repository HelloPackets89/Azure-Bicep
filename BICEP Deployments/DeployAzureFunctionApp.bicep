param location string = resourceGroup().location
param name string = 'beeresumequery'

resource storageaccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: '${name}storage'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
var StorageAccountPrimaryAccessKey = listKeys(storageaccount.id, storageaccount.apiVersion).keys[0].value

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
//      use32BitWorkerProcess:true //this allows me to use the FREEEEE tier
      alwaysOn:false
      linuxFxVersion: 'python|3.11'
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
/*
resource functionappstorageslot 'Microsoft.Web/sites/slots@2023-12-01' = {
  name: '${name}functionstaging'
  location: location
  identity:{
    type:'SystemAssigned'
  }
  properties:{
    enabled:true
    httpsOnly:true
  }
}

resource functionslotconfig 'Microsoft.Web/sites/config@2023-12-01' = {
  name: 'slotConfigNames'
  parent: ResumeFunctionApp
  properties:{
    appSettingNames:[
      'APP_CONFIGURATION_LABEL'
    ]
  }
}
*/
