param dbname string = 'bee-resume-db'
param location string = resourceGroup().location
param primaryRegion string = 'australiaeast'

resource cosmodb 'Microsoft.DocumentDB/databaseAccounts@2024-02-15-preview' = {
  name: dbname
  location: location
  properties: {
    databaseAccountOfferType:'Standard' 
        locations: [
    {
      failoverPriority: 0
      locationName: primaryRegion
      isZoneRedundant: false
    }
      ]
    backupPolicy:{
      type: 'Continuous'
      continuousModeProperties:{
        tier:'Continuous7Days'
      }
    }
    isVirtualNetworkFilterEnabled:false
    minimalTlsVersion:'Tls12'
    enableMultipleWriteLocations:false
    enableFreeTier: true
        capacity:{
      totalThroughputLimit: 1000
    }
  }
}
