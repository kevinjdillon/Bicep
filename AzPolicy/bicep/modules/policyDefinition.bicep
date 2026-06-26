// Policy Definition Module
targetScope = 'managementGroup'

@description('Name of the policy definition')
param policyName string

@description('Display name of the policy definition')
param displayName string

@description('Description of the policy definition')
param policyDescription string

@description('Policy category')
param category string = 'Custom'

@description('Policy mode')
param mode string = 'Indexed'

@description('Policy rule object')
param policyRule object

@description('Policy parameters object')
param policyParameters object

@description('Policy metadata object')
param metadata object = {}

@description('Policy version')
param version string = '1.0.0'

// Policy Definition
resource policyDef 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: policyName
  properties: {
    displayName: displayName
    policyType: 'Custom'
    mode: mode
    description: policyDescription
    metadata: union(metadata, {
      category: category
      version: version
    })
    parameters: policyParameters
    policyRule: policyRule
  }
}

@description('Policy Definition ID')
output policyDefinitionId string = policyDef.id

@description('Policy Definition Name')
output policyDefinitionName string = policyDef.name
