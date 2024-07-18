/* 
This script deploys multiple VM using the integer index method. It deploys a mix of windows
and Linux VMs. The index notes that once there are more than 4 windows VMs deployed, it'll 
start deploying ubuntu VMs. The supporting resources have also had to be deployed via integers. 
Setting the number for each resource individually is unlikely to be best way to do it
there is space for refinement in this script due to this. 

This BICEP script deploys a standalone VM with a public IP
This deployment spins up faster and is cheaper than using a Bastion accessible lab
Access to the VM in this deployment is via RDP , 3389 has been opened in the NSG.
This script sets the PIP DNS Name to the name of the host. 
Will assign a random name to VMs if vmName isn't defined during deployment
*/

// Parameters

@minLength(10)
@secure()
param adminPassword string 
param adminUser string = 'beeadmin'
param vmsize string = 'Standard_B1ms'
//For shutdown notifications
param contact string = 'test@domain.com'
param autoshutdowntime string = '2000'
param location string = resourceGroup().location
param workspaceid string
@secure()
param workspacekey string

//Assigns a semi-random number to the deployment.
// utcnow is used in-lieu of a random number generator. May cause issues. 
//param baseTime string = utcNow('mmss')
//param vmName string =  ('test${baseTime}')
param vmName string =  'brandotesto'

//select Australian timezone
@allowed([
  'AUS Central Standard Time'
  'AUS Eastern Standard Time'
  'Cen. Australia Standard Time'
  'E. Australia Standard Time'
  'W. Australia Standard Time'
  'Tasmania Standard Time'
])
param timezone string = 'W. Australia Standard Time'

//Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' ={
  name: '${vmName}NSG'
  location:location
  properties:{
    securityRules:[
      {
        name:'RDP'
        properties:{
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          destinationAddressPrefix: '*'
          sourceAddressPrefix: '*'

        }
      }
    ]
  }
}

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

//VM PIP
resource pip 'Microsoft.Network/publicIPAddresses@2022-11-01' = [for i in range(1, 8): {
  name: '${vmName}${i}pip'
  sku:{
    name:'Basic'
  }
  location: location
  properties:{
    publicIPAllocationMethod:'Dynamic'
    dnsSettings:{
      domainNameLabel: '${vmName}${i}'
    }
       
  }
}]

//VM Nic
resource vmnic 'Microsoft.Network/networkInterfaces@2022-11-01' = [for i in range(1, 8): {
  name: '${vmName}${i}nic'
  location: location
  dependsOn: [
    virtualNetwork
  ]
  properties:{
    networkSecurityGroup: {
      id: nsg.id
    }
    ipConfigurations:[
      {
        name: 'interface1'
        properties:{
          subnet:{
            id: subnet.id
          }
          privateIPAllocationMethod:'Dynamic'
          publicIPAddress:{
            id: pip[i-1].id
          } 
        } 
      }
    ]
  }
}]



//Actual Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(1, 8): {
  name: '${vmName}${i}'
  location: location
  properties:{
    hardwareProfile:{
      vmSize:vmsize
    }
    networkProfile:{
      networkInterfaces:[
        {
          id: vmnic[i-1].id
        }
      ]
    }
    osProfile:{
      adminPassword:adminPassword
      adminUsername:adminUser
      computerName:'${vmName}${i}'
      windowsConfiguration: i <= 4 ? {
        timeZone: timezone
      } : null
      linuxConfiguration: i > 4 ? {
        disablePasswordAuthentication: false
      } : null
    }
    storageProfile:{
      imageReference:{
        publisher: i <= 4 ? 'MicrosoftWindowsServer' : 'Canonical'
        offer: i <= 4 ? 'WindowsServer' : 'UbuntuServer'
        sku: i <= 4 ? '2022-Datacenter' : '18.04-LTS'
        version: 'latest'
      }
      osDisk:{
        createOption:'FromImage'
        name:'${vmName}${i}OSdisk'
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
}]

//Set VM Autoshut down. "shutdown-computevm-<VMNAME>" is a required name.
resource autoshutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = [for i in range(1, 8): {
  name: 'shutdown-computevm-${vm[i-1].name}'
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
    targetResourceId: vm[i-1].id
  }
}]


// MMA Extension for all VMs.
// Name changes based on vm number. <2 = MMAExtension 3-4 = Microsoft Monitoring Agent. >4 = OMSAgent
resource mmaExtensions 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, 8): {
  name: i < 2 ? '${vm[i].name}/MMAExtension' : (i < 4 ? '${vm[i].name}/MicrosoftMonitoringAgent' : '${vm[i].name}/OmsAgentForLinux')
  location: location
  properties: {
    autoUpgradeMinorVersion: false
    enableAutomaticUpgrade: false
    forceUpdateTag: '1.0'
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: i < 4 ? 'MicrosoftMonitoringAgent' : 'OmsAgentForLinux'
    typeHandlerVersion: i < 4 ? '1.0' : '1.12'
    settings: {
      workspaceId: workspaceid
    }
    protectedSettings: {
      workspaceKey: workspacekey
    }
  }
}]
