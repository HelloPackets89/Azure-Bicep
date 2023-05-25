<#

This script will seek your available subscriptions, then your resource groups. 

It will then display the resources within those groups and provide you the option of deleting everything. 

It will run until everything is gone. Depending on the contents of your RG, it might get stuck.  

This script is only intended for cleaning up personal environments. 

Do not run this inside any Corporate Directory. 

Please be extremely careful with this script, as it will permanently delete all resources in the selected resource group.

#>


#Enter your corporate domain. This is a fail safe for accidental logins. 
$safedomain = '*domain.com'

#########################################################################
# This block logs you into Az and allows you to select your subscription#
#########################################################################
# Connect to your Azure account
$account = Connect-AzAccount

# Check the account domain
if ($account.Context.Account.Id -like $safedomain) {
    throw "This script is intended for personal labs only, aborting..."
}

# Get all subscriptions and query the user
$subscriptions = Get-AzSubscription
write-host 'Select your subscription ' -ForegroundColor Cyan
for ($i=0; $i -lt $subscriptions.Count; $i++) {
    Write-Host "$($i + 1). $($subscriptions[$i].Name)"
}
$userInput = Read-Host

# Validate user input and set the selected subscription as the current subscription
if ($userInput -match '^\d+$' -and $userInput -gt 0 -and $userInput -le $subscriptions.Count) {
    $selectedSubscription = $subscriptions[$userInput - 1]
    Write-Host "You selected subscription: $($selectedSubscription.Name)"
    Set-AzContext -Subscription $selectedSubscription
} else {
    Write-Host "Invalid input. Please enter a number between 1 and $($subscriptions.Count)."
}

###################################################################################
# This block retrieves your Resource Groups and queries which one you want to view#
###################################################################################
$resourceGroups = Get-AzResourceGroup
for ($i=0; $i -lt $resourceGroups.Count; $i++) {
    Write-Host "$($i + 1). $($resourceGroups[$i].ResourceGroupName)"
}
$userInput = Read-Host

# Validate user input and display the resources in the selected resource group
if ($userInput -match '^\d+$' -and $userInput -gt 0 -and $userInput -le $resourceGroups.Count) {
    $selectedResourceGroup = $resourceGroups[$userInput - 1].ResourceGroupName
    Write-Host "You selected resource group: $selectedResourceGroup"
    Write-Host "Contents:"
    Get-AzResource -ResourceGroupName $selectedResourceGroup | select ResourceName, ResourceType | Format-Table


###############################################
# This block performs the first workspace wipe#
###############################################
# Ask the user if they want to delete everything in this resource group
Write-host 'Do you want to delete everything in this resource group? (y/n)' -ForegroundColor Cyan
$deleteConfirmation = Read-Host
if ($deleteConfirmation -eq 'y') {
    # Ask for additional confirmation
    write-host 'Are you sure? This will delete everything. (y/n)' -ForegroundColor Red
    $finalConfirmation = Read-Host
    if ($finalConfirmation -eq 'y') {
        do {
            Write-Host "Deleting detected resources..." -ForegroundColor Red
            $executionTime = Measure-Command -Expression {
                try {
                    Get-AzResource -ResourceGroupName $selectedResourceGroup | Remove-AzResource -Force -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Host "Error occurred, attempting again" -ForegroundColor Red
                }
            }
            Write-Host "Operation completed in $($executionTime.TotalSeconds) seconds."
            Write-Host "Checking Remaining Contents in $selectedResourceGroup..." -ForegroundColor Yellow
            sleep 5
            try {
                $remainingResources = Get-AzResource -ResourceGroupName $selectedResourceGroup -ErrorAction SilentlyContinue
                $remainingResources | select ResourceName, ResourceType | Format-Table
            }
            catch {
                Write-Host "Error occurred when checking remaining resources, attempting again" -ForegroundColor Red
            }
        } while ($remainingResources)
    }
}
    }
 else {
    Write-Host "Invalid input. Please enter a number between 1 and $($resourceGroups.Count)."
}
