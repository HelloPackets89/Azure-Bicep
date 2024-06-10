param email string
param company string
param APIname string
param AppInsightsname string
param AppInsightsID string


resource APIManagement 'Microsoft.ApiManagement/service@2022-09-01-preview' = {
  name: APIname
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


resource logger 'Microsoft.ApiManagement/service/loggers@2022-08-01' ={
  name: '${APIManagement.name}/${AppInsightsname}'
  properties:{
    loggerType: 'applicationInsights'
    resourceId: AppInsightsID
    credentials:{
      instrumentationKey: reference(AppInsightsID, '2015-05-01').InstrumentationKey
    }
  }
}

//Note Child resources need to include their parents in their name. 
//ARM checks for this by ensuring child resources have an extra 'segment' 
//In the below example I'm using logger.name because that contains both the grandparent and parent segments. 
resource diagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: '${logger.name}/default1'
  properties: {
    loggerId: '${APIManagement.id}/loggers/${logger.name}'
    alwaysLog: 'allErrors'
    sampling: {
      percentage: 100
      samplingType: 'fixed'
    }
  }
}
