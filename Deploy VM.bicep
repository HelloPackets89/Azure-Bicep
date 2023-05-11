// Parameters

param autoshutdowntime string = '2000'
param location string = 'australiaeast'
param vmsize string = 'Standard_B1s'

@description('The email address of who created this. I do know how to force an email address so you must enter one')
param contact string = 'test@domain.com'

//Assigns a rotating number to the deployment
param baseTime string = utcNow('mmss')
param vmName string =  ('test${baseTime}')

//hard coded variable
var timezone = 'W. Australia Standard Time'

param adminUser string = 'bee_admin'
@description('What password you should enter, minimum lenghth 10')
@minLength(10)
@secure()
param adminPassword string 

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

//Subnet Resource
var subnetname = '${virtualNetwork.name}/default'
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  name: subnetname
    properties:{
    addressPrefix: '10.0.1.0/24'
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
        name: 'brandon'
        properties:{
          subnet:{
            id: subnet.id
          }
          privateIPAllocationMethod:'Dynamic'
          publicIPAddress:{
            id: pip.id

          }
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

//Set VM Autoshut down. Apparently "shutdown-computevm-<VMNAME>" is mandatory???
resource autoshutdown 'Microsoft.DevTestLab/schedules@2018-09-15' ={
  name: 'shutdown-computevm-${vmName}'
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
