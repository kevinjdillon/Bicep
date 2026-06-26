// Main Orchestrator for Defender Onboarding Policy Deployment
targetScope = 'managementGroup'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Management Group ID where policies will be deployed')
param managementGroupId string

@description('Subscription ID where UAMI will be deployed')
param subscriptionId string

@description('Resource Group name where UAMI will be created')
param uamiResourceGroupName string

@description('Location for the UAMI resource')
param uamiLocation string

@description('Name of the User-Assigned Managed Identity')
param uamiName string = 'uami-w-operations-defender-cse'

@description('Tags to apply to resources')
param tags object = {
  Environment: 'Production'
  ManagedBy: 'Bicep'
  Purpose: 'DefenderOnboarding'
}

@description('Name for the UAMI Assignment Policy Definition')
param uamiPolicyName string = 'policy-assign-uami-defender-onboarding'

@description('Name for the CSE Deployment Policy Definition')
param csePolicyName string = 'policy-cse-defender-onboarding'

@description('Name for the Policy Initiative')
param initiativeName string = 'initiative-defender-onboarding'

// ============================================================================
// VARIABLES
// ============================================================================

// Load policy JSON files
var uamiPolicyJson = loadJsonContent('policies/uami-defender-onboaring.json')
var csePolicyJson = loadJsonContent('policies/cse-defender-onboarding.json')
var initiativeJson = loadJsonContent('policies/defender-onboarding-initiative.json')

// ============================================================================
// MODULE: User-Assigned Managed Identity
// ============================================================================

module uami 'modules/uami.bicep' = {
  name: 'deploy-uami-${uamiName}'
  scope: subscription(subscriptionId)
  params: {
    uamiName: uamiName
    resourceGroupName: uamiResourceGroupName
    location: uamiLocation
    tags: tags
  }
}

// ============================================================================
// MODULE: UAMI Assignment Policy Definition
// ============================================================================

module uamiPolicy 'modules/policyDefinition.bicep' = {
  name: 'deploy-${uamiPolicyName}'
  scope: managementGroup(managementGroupId)
  params: {
    policyName: uamiPolicyName
    displayName: uamiPolicyJson.properties.displayName
    policyDescription: uamiPolicyJson.properties.description
    category: uamiPolicyJson.properties.metadata.category
    mode: uamiPolicyJson.properties.mode
    policyRule: uamiPolicyJson.properties.policyRule
    policyParameters: uamiPolicyJson.properties.parameters
    metadata: {
      version: uamiPolicyJson.properties.version
      preview: true
    }
    version: uamiPolicyJson.properties.version
  }
  dependsOn: [
    uami
  ]
}

// ============================================================================
// MODULE: CSE Deployment Policy Definition
// ============================================================================

module csePolicy 'modules/policyDefinition.bicep' = {
  name: 'deploy-${csePolicyName}'
  scope: managementGroup(managementGroupId)
  params: {
    policyName: csePolicyName
    displayName: csePolicyJson.properties.displayName
    policyDescription: csePolicyJson.properties.description
    category: csePolicyJson.properties.metadata.category
    mode: csePolicyJson.properties.mode
    policyRule: csePolicyJson.properties.policyRule
    policyParameters: csePolicyJson.properties.parameters
    metadata: {
      version: csePolicyJson.properties.version
    }
    version: csePolicyJson.properties.version
  }
  dependsOn: [
    uami
  ]
}

// ============================================================================
// MODULE: Policy Initiative (Policy Set)
// ============================================================================

module initiative 'modules/policyInitiative.bicep' = {
  name: 'deploy-${initiativeName}'
  scope: managementGroup(managementGroupId)
  params: {
    initiativeName: initiativeName
    displayName: initiativeJson.properties.displayName
    initiativeDescription: initiativeJson.properties.description
    category: initiativeJson.properties.metadata.category
    version: initiativeJson.properties.version
    metadata: initiativeJson.properties.metadata
    initiativeParameters: initiativeJson.properties.parameters
    policyDefinitions: [
      {
        policyDefinitionReferenceId: 'AssignUAMI'
        policyDefinitionId: uamiPolicy.outputs.policyDefinitionId
        parameters: initiativeJson.properties.policyDefinitions[0].parameters
      }
      {
        policyDefinitionReferenceId: 'DeployCSE'
        policyDefinitionId: csePolicy.outputs.policyDefinitionId
        parameters: initiativeJson.properties.policyDefinitions[1].parameters
      }
    ]
  }
  dependsOn: [
    uamiPolicy
    csePolicy
  ]
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Client ID of the deployed User-Assigned Managed Identity')
output uamiClientId string = uami.outputs.clientId

@description('Resource ID of the deployed User-Assigned Managed Identity')
output uamiResourceId string = uami.outputs.resourceId

@description('Principal ID of the deployed User-Assigned Managed Identity')
output uamiPrincipalId string = uami.outputs.principalId

@description('Name of the deployed User-Assigned Managed Identity')
output uamiName string = uami.outputs.name

@description('Policy Definition ID for UAMI Assignment Policy')
output uamiPolicyDefinitionId string = uamiPolicy.outputs.policyDefinitionId

@description('Policy Definition ID for CSE Deployment Policy')
output csePolicyDefinitionId string = csePolicy.outputs.policyDefinitionId

@description('Policy Initiative (Set) Definition ID')
output initiativeId string = initiative.outputs.policySetDefinitionId

@description('Deployment Summary')
output deploymentSummary object = {
  uami: {
    name: uami.outputs.name
    clientId: uami.outputs.clientId
    resourceId: uami.outputs.resourceId
  }
  policies: {
    uamiPolicy: uamiPolicy.outputs.policyDefinitionId
    csePolicy: csePolicy.outputs.policyDefinitionId
  }
  initiative: {
    id: initiative.outputs.policySetDefinitionId
    name: initiative.outputs.policySetDefinitionName
  }
}
