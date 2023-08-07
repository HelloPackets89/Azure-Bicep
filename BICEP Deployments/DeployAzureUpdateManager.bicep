// This BICEP script deploys a standalone VM with a public IP and static hostname
// This will then create an Automation account with accompanying LAW to test AUM
// Current WIP and is not functional




// Parameters
param location string = 'australiaeast'
param lawname string = 'BrandonLAW'
param automationAccountName string = 'BrandonAutomation'

@minLength(10)
@secure()
param adminPassword string 
//The static DNS Name of your VM, choose something unique to you
param PIPDNSName string = 'thisonebelongstobrandon'

param adminUser string = 'beeadmin'
param vmsize string = 'Standard_B2s'
//For shutdown notifications
param contact string = 'test@domain.com'
param autoshutdowntime string = '2000'

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
resource pip 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: '${vmName}pip'
  sku:{
    name:'Basic'
  }
  location: location
  properties:{
    publicIPAllocationMethod:'Dynamic'
    dnsSettings:{
      domainNameLabel: PIPDNSName
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


resource law 'Microsoft.OperationalInsights/workspaces@2020-03-01-preview' = {
  name: lawname
  location: location
  properties: {
    sku:{
      name:'PerGB2018'
    }
  }
}

resource automationAccount 'Microsoft.Automation/automationAccounts@2020-01-13-preview' = {
  name: automationAccountName
  location: location
  properties: {
    sku: {
      name: 'basic'
    }
  }

}

var linkname = '${law.name}/Automation'
resource law_link 'Microsoft.OperationalInsights/workspaces/linkedServices@2020-08-01' = {
  //parent: law
  name: linkname
    properties: {
    resourceId: automationAccount.id
  }
}


//all the below properties are required. Removing any of the below will result in deployment errors. 
resource updateManagement 'Microsoft.Automation/automationAccounts/softwareUpdateConfigurations@2019-06-01' ={
  parent: automationAccount
  name: 'default'
    dependsOn:[
      law
      law_link
      vm
      automationAccount
  ]
  properties:{
    updateConfiguration: {
      operatingSystem: 'Windows'
      windows:{
        excludedKbNumbers: []
        includedKbNumbers: []
        rebootSetting: 'IfRequired'
        includedUpdateClassifications: 'Critical, Security'
      } 
      azureVirtualMachines:[
        vm.id
      ]
      duration: 'PT3H'
    }
    scheduleInfo: {
      frequency: 'Week'
      startTime:'2023-07-27T18:00:00+08:00'
      expiryTime:'2033-07-27T18:00:00+08:00'
      timeZone: timezone
      isEnabled: true 
      interval: 1
      advancedSchedule: {
        weekDays: [
          'Wednesday'
          'Thursday'
        ]
      }    
    }

  }
}
