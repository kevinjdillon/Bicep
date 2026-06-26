// User-Assigned Managed Identity - Resource Group Scoped
targetScope = 'resourceGroup'

@description('Name of the User-Assigned Managed Identity')
param uamiName string

@description('Location for the UAMI resource')
param location string

@description('Tags to apply to the UAMI')
param tags object = {}

// User-Assigned Managed Identity
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
  tags: tags
}

@description('Client ID of the User-Assigned Managed Identity')
output clientId string = uami.properties.clientId

@description('Resource ID of the User-Assigned Managed Identity')
output resourceId string = uami.id

@description('Principal ID of the User-Assigned Managed Identity')
output principalId string = uami.properties.principalId

@description('Name of the User-Assigned Managed Identity')
output name string = uami.name
