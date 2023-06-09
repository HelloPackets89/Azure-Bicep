// This BICEP script deploys a VM inside an NSG with Bastion access. 


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


//Network Security Group
//All entries are required for Bastion. 
resource nsg 'Microsoft.Network/networkSecurityGroups@2022-11-01' ={
  name: '${vmName}NSG'
  location: location
  properties:{
    securityRules:[
      {
        name: 'AllowHttpsInbound'
        properties:{
          priority: 120
          sourcePortRange: '*'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        } 
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties:{
          priority: 130
          sourcePortRange: '*'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access:'Allow'
          direction:'Inbound'
        }
      }
      {
        name:'AllowAzureLoadBalancerInbound'
        properties:{
          priority: 140
          sourcePortRange: '*'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunication'
        properties:{
          priority: 150
          sourcePortRange:'*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutbound'
        properties:{
          priority: 100
          sourcePortRange:'*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties:{
          priority: 110
          sourcePortRange:'*'
          destinationPortRange: '443'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCommunication'
        properties:{
          priority: 120
          sourcePortRange:'*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowHttpOutbound'
        properties:{
          priority: 130
          sourcePortRange: '*'
          destinationPortRange: '80'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          direction: 'Outbound'
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
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

//Bastion Subnet. This has been set to depend on the default subnet to avoid a conflicted parallel deployment.
//MUST be called "AzureBastionSubnet" with a minimum /26 subnet.
var bastionsn = '${virtualNetwork.name}/AzureBastionSubnet'
resource bastionsubnet 'Microsoft.Network/virtualNetworks/subnets@2022-11-01' = {
  name: bastionsn
  dependsOn: [
    subnet
  ]
    properties:{
    addressPrefix: '10.0.100.0/24'
    networkSecurityGroup:{
      id:nsg.id
    }
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

//Set VM Autoshut down. "shutdown-computevm-<VMNAME>" is a required name.
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

//Bastion Public IP. Must be Static / Standard.
resource pip 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${vmName}bastionpip'
  location: location
  properties:{
    publicIPAllocationMethod: 'Static'
  }
  sku:{
    name:'standard'
  }
}

//Deploy Bastion. This part takes almost exactly 5 minutes. 

resource bastion 'Microsoft.Network/bastionHosts@2022-11-01' = {
  name: '${virtualNetwork.name}Bastion'
  location: location
  sku: {
    name:'Basic'
  }
  properties: {
    disableCopyPaste:false
        ipConfigurations: [
       {
        name: 'bastionipconfig' 
        properties: {
          publicIPAddress: {
            id: pip.id
          }
          subnet: {
            id: bastionsubnet.id
          }
         }
       }
    ]
  }
}
