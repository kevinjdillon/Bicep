// User-Assigned Managed Identity Module
targetScope = 'subscription'

@description('Name of the User-Assigned Managed Identity')
param uamiName string

@description('Resource Group name where UAMI will be created')
param resourceGroupName string

@description('Location for the UAMI resource')
param location string

@description('Tags to apply to the UAMI')
param tags object = {}

// Create Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Deploy UAMI to Resource Group
module uamiDeployment 'uami-rg.bicep' = {
  name: 'deploy-${uamiName}'
  scope: rg
  params: {
    uamiName: uamiName
    location: location
    tags: tags
  }
}

@description('Client ID of the User-Assigned Managed Identity')
output clientId string = uamiDeployment.outputs.clientId

@description('Resource ID of the User-Assigned Managed Identity')
output resourceId string = uamiDeployment.outputs.resourceId

@description('Principal ID of the User-Assigned Managed Identity')
output principalId string = uamiDeployment.outputs.principalId

@description('Name of the User-Assigned Managed Identity')
output name string = uamiDeployment.outputs.name
