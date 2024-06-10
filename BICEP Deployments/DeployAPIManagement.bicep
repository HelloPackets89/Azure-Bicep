param email string
param company string

//Name of your API Management resource
param APIMname string
// Name of your existing FunctionApp resource
param FunctionAppName string

//Name of your existing AppInsights resource
param AppInsightsname string

//The Insights ID (long)
param AppInsightsID string

//define existing functionapp
resource FunctionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: FunctionAppName
}

resource APIManagement 'Microsoft.ApiManagement/service@2022-09-01-preview' = {
  name: APIMname
  location: resourceGroup().location
  sku: {
    capacity: 0
    name: 'Consumption'
  }
  identity:{
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: email
    publisherName: company
  }
}

resource API 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
  name: FunctionApp.name
  parent: APIManagement
  properties: {
    displayName: FunctionApp.name
    path: FunctionApp.name
    protocols:[
      'https'
    ]
    serviceUrl: 'https://${FunctionApp.name}azurewebsites.net'
    
  }
}

resource logger 'Microsoft.ApiManagement/service/loggers@2022-08-01' ={
  name: 'AppInsightsname'
  parent: APIManagement
  properties:{
    loggerType: 'applicationInsights'
    resourceId: AppInsightsID
    credentials:{
      instrumentationKey: reference(AppInsightsID, '2015-05-01').InstrumentationKey
    }
  }
}
