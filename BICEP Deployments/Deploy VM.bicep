// This BICEP script deploys a standalone VM


// Parameters
@minLength(10)
@secure()
param adminPassword string 

param adminUser string = 'beeadmin'
param autoshutdowntime string = '2000'
param location string = 'australiaeast'
param vmsize string = 'Standard_B2s'

@description('For shutdown notifications')
param contact string = 'test@domain.com'

//Assigns a semi-random number to the deployment.
// utcnow is used in-lieu of a random number generator. May cause issues. 
param baseTime string = utcNow('mmss')
param vmName string =  ('test${baseTime}')

//select Australian timezone
@allowed([
  'AUS Central Standard Time'
  'AUS Eastern Standard Time'
  'Cen. Australia Standard Time'
  'E. Australia Standard Time'
  'Tasmania Standard Time'
  'W. Australia Standard Time'
])
param timezone string = 'W. Australia Standard Time'



//Virtual Network
@description('defines the network')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: '${vmName}vnet_1'
  location: location
  properties: {
    addressSpace:{
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }  
  } 
}

//Default Subnet
var subnetname = '${virtualNetwork.name}/default'
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  name: subnetname
    properties:{
    addressPrefix: '10.0.1.0/24'
  }
}

//VM Nic
var nicname = '${vmName}nic'
resource vmnic 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: nicname
  location: location
  dependsOn: [
    virtualNetwork
  ]
  properties:{
    ipConfigurations:[
      {
        name: 'interface1'
        properties:{
          subnet:{
            id: subnet.id
          }
          privateIPAllocationMethod:'Dynamic'
        }
      }
    ]
  }
}

//Actual Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' ={
  location: location
  name: vmName
  properties:{
    hardwareProfile:{
      vmSize:vmsize
      
    }
    networkProfile:{
      networkInterfaces:[
        {
          id: vmnic.id

        }
      ]
    }
    osProfile:{
      adminPassword:adminPassword
      adminUsername:adminUser
      computerName:vmName
      windowsConfiguration:{
        timeZone: timezone
      }

    }
    storageProfile:{
      imageReference:{
        publisher:'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
      osDisk:{
        createOption:'FromImage'
        name:'${vmName}OSdisk'
        diskSizeGB: 128
        managedDisk:{
          storageAccountType:'Standard_LRS'
        }
      }
    }
    diagnosticsProfile:{
      bootDiagnostics:{
        enabled:false
      }
    }
    scheduledEventsProfile:{
      osImageNotificationProfile:{
        enable:true
        
      }
      terminateNotificationProfile:{
        enable:true
      }
    }
  }
  
}

//Set VM Autoshut down. "shutdown-computevm-<VMNAME>" is a reuqired name.
resource autoshutdown 'Microsoft.DevTestLab/schedules@2018-09-15' ={
  name: 'shutdown-computevm-${vm.name}'
  location: location
  properties:{
    status: 'Enabled'
    notificationSettings:{
      emailRecipient: contact 
      status:'Enabled'
      timeInMinutes: 15
      notificationLocale: 'en'
    }
    dailyRecurrence:{
      time: autoshutdowntime
    }
    timeZoneId:timezone
    taskType: 'ComputeVmShutdownTask'
    targetResourceId: vm.id

  }
}
