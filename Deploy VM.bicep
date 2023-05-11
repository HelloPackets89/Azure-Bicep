// Parameters
param vmName string
param adminUser string
param autoshutdowntimezone string
param autoshutdowntime string

@description('The email address of who created this. I do know how to force an email address so you must enter one')
param contact string




@description('What password you should enter, minimum lenghth 10')
@minLength(10)
@secure()
param adminPassword string 

// Hard coded variables
var location = 'australiaeast'
var vmsize = 'Standard_B1s'


//Virtual Network
var subnetname = '${vmName}subnet'
@description('defines the network')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: '${vmName}vnet'
  location: location
  properties: {
    addressSpace:{
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets:[
      {
        name: subnetname
        properties:{
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  } 
}

//Public IP address
resource pip 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${vmName}pip'
  location: location
  sku:{
    name:'Basic'
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
        properties:{
          subnet:{
            name: subnetname
          }
          privateIPAllocationMethod:'Dynamic'
          publicIPAddress:{
            id:pip.id

          }
        }
      }
    ]
  }
}

//Actual Virtual Machine
var timezone = 'W. Australia Standard Time'
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
        diskSizeGB: 32
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

//Set VM Autoshut down
resource autoshutdown 'Microsoft.DevTestLab/labs/schedules@2018-09-15' ={
  name: '${vmName}_shutdown'
  properties:{
    dailyRecurrence:{
      time: '2000'
    }
    timeZoneId:timezone
    notificationSettings:{
      emailRecipient: contact 
      status:'Enabled'
      timeInMinutes: 15
    }
    taskType: 'ComputeVMShutdownTask'
    targetResourceId: vm.id

  }
}
