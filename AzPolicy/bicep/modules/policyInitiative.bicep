// Policy Initiative (Policy Set Definition) Module
targetScope = 'managementGroup'

@description('Name of the policy initiative')
param initiativeName string

@description('Display name of the policy initiative')
param displayName string

@description('Description of the policy initiative')
param initiativeDescription string

@description('Policy category')
param category string = 'Custom'

@description('Initiative parameters object')
param initiativeParameters object

@description('Array of policy definitions to include in the initiative')
param policyDefinitions array

@description('Policy metadata object')
param metadata object = {}

@description('Policy version')
param version string = '1.0.0'

// Policy Initiative (Set Definition)
resource policySetDef 'Microsoft.Authorization/policySetDefinitions@2021-06-01' = {
  name: initiativeName
  properties: {
    displayName: displayName
    policyType: 'Custom'
    description: initiativeDescription
    metadata: union(metadata, {
      category: category
      version: version
    })
    parameters: initiativeParameters
    policyDefinitions: policyDefinitions
  }
}

@description('Policy Initiative ID')
output policySetDefinitionId string = policySetDef.id

@description('Policy Initiative Name')
output policySetDefinitionName string = policySetDef.name
