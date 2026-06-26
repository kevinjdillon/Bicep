# Defender Onboarding Bicep Deployment

This Bicep deployment creates a comprehensive Azure Policy solution for automated Defender onboarding to Windows VMs using Custom Script Extensions and User-Assigned Managed Identities.

## Architecture Overview

### Components Deployed

1. **User-Assigned Managed Identity (UAMI)**
   - Deployed to a specified resource group and subscription
   - Used by VMs to authenticate and access the Defender onboarding script
   - Client ID is passed to policy parameters

2. **Policy Definition: UAMI Assignment**
   - Custom policy that assigns the UAMI to Windows virtual machines
   - Based on preview built-in policy functionality
   - Deployed at management group scope

3. **Policy Definition: CSE Deployment**
   - Custom policy that deploys Custom Script Extension to Windows VMs
   - Executes PowerShell script for Defender onboarding
   - Deployed at management group scope

4. **Policy Initiative (Set)**
   - Combines both policies into a single initiative
   - Provides unified parameter management
   - Deployed at management group scope

### Deployment Scopes

```
Management Group (Policies & Initiative)
    └── Subscription (UAMI Wrapper)
            └── Resource Group (UAMI Resource)
```

## Directory Structure

```
bicep/
├── main.bicep                              # Main orchestrator
├── modules/
│   ├── uami.bicep                          # UAMI subscription-scoped module
│   ├── uami-rg.bicep                       # UAMI resource group-scoped module
│   ├── policyDefinition.bicep              # Reusable policy definition module
│   └── policyInitiative.bicep              # Policy initiative module
├── policies/
│   ├── uami-defender-onboaring.json        # UAMI assignment policy JSON
│   ├── cse-defender-onboarding.json        # CSE deployment policy JSON
│   └── defender-onboarding-initiative.json # Initiative JSON (reference)
├── parameters/
│   └── main.parameters.json                # Parameter file template
└── README.md                                # This file
```

## Prerequisites

1. **Azure CLI** with Bicep CLI installed
   ```bash
   az bicep install
   az bicep upgrade
   ```

2. **Permissions Required**
   - Management Group Contributor (or custom role with policy write permissions)
   - Subscription Contributor (for UAMI deployment)
   - Resource Group Contributor (if creating new RG for UAMI)

3. **Azure Context**
   - Logged in to Azure CLI: `az login`
   - Correct subscription selected: `az account set --subscription <subscription-id>`

## Deployment Steps

### 1. Update Parameters

Edit `parameters/main.parameters.json` and replace placeholder values:

```json
{
  "managementGroupId": {
    "value": "mg-contoso"  // Your management group ID
  },
  "subscriptionId": {
    "value": "00000000-0000-0000-0000-000000000000"  // Target subscription
  },
  "uamiResourceGroupName": {
    "value": "rg-defender-onboarding"  // Resource group name
  },
  "uamiLocation": {
    "value": "westus2"  // Azure region
  }
}
```

### 2. Validate Deployment

Before deploying, validate the Bicep template:

```bash
az deployment mg validate \
  --management-group-id "mg-contoso" \
  --location "westus2" \
  --template-file main.bicep \
  --parameters parameters/main.parameters.json
```

### 3. Deploy to Management Group

Deploy the complete solution:

```bash
az deployment mg create \
  --management-group-id "mg-contoso" \
  --location "westus2" \
  --template-file main.bicep \
  --parameters parameters/main.parameters.json \
  --name "defender-onboarding-deployment"
```

**Note:** Replace `mg-contoso` with your actual management group ID.

### 4. Monitor Deployment

Monitor the deployment progress:

```bash
az deployment mg show \
  --management-group-id "mg-contoso" \
  --name "defender-onboarding-deployment"
```

## What Gets Deployed

### 1. User-Assigned Managed Identity
- **Name:** `uami-w-operations-defender-cse` (default)
- **Location:** Specified in parameters
- **Resource Group:** Created if doesn't exist

### 2. Custom Policy Definitions
- **UAMI Assignment Policy:** Assigns managed identity to VMs
- **CSE Deployment Policy:** Deploys Custom Script Extension

### 3. Policy Initiative
- **Name:** `initiative-defender-onboarding` (default)
- **Contains:** Both policy definitions
- **Parameters:** Unified parameter set for both policies

## Post-Deployment Steps

### 1. Assign the Policy Initiative

After deployment, assign the initiative to the desired scope:

```bash
az policy assignment create \
  --name "assign-defender-onboarding" \
  --display-name "Defender Onboarding for Windows VMs" \
  --policy-set-definition <initiative-id-from-output> \
  --scope /subscriptions/<subscription-id> \
  --location "westus2" \
  --identity-scope /subscriptions/<subscription-id> \
  --role "Virtual Machine Contributor" \
  --params '{
    "User-Assigned Managed Identity Resource ID": {
      "value": "<uami-resource-id-from-output>"
    },
    "User Assigned Managed Identity Client ID": {
      "value": "<uami-client-id-from-output>"
    },
    "Script URI": {
      "value": "https://<your-storage>.blob.core.windows.net/scripts/Defender-Onboarding.ps1"
    }
  }'
```

### 2. Grant UAMI Permissions

Grant the UAMI necessary permissions to access the script storage:

```bash
# Get the UAMI principal ID from deployment outputs
UAMI_PRINCIPAL_ID="<from-deployment-output>"

# Assign Storage Blob Data Reader role to the storage account
az role assignment create \
  --assignee $UAMI_PRINCIPAL_ID \
  --role "Storage Blob Data Reader" \
  --scope /subscriptions/<subscription-id>/resourceGroups/<storage-rg>/providers/Microsoft.Storage/storageAccounts/<storage-account>
```

### 3. Grant Policy Assignment Managed Identity Access to UAMI

After creating the policy assignment (which creates its own system-assigned managed identity), grant that identity the **Managed Identity Operator** role on the UAMI resource:

```bash
# Get the policy assignment's managed identity principal ID
ASSIGNMENT_PRINCIPAL_ID=$(az policy assignment show \
  --name "assign-defender-onboarding" \
  --scope /subscriptions/<subscription-id> \
  --query identity.principalId -o tsv)

# Get the UAMI resource ID from deployment outputs
UAMI_RESOURCE_ID="<uami-resource-id-from-output>"

# Grant Managed Identity Operator role to the policy assignment's identity
az role assignment create \
  --assignee $ASSIGNMENT_PRINCIPAL_ID \
  --role "Managed Identity Operator" \
  --scope $UAMI_RESOURCE_ID
```

**PowerShell equivalent:**
```powershell
# Get the policy assignment's managed identity principal ID
$assignmentIdentity = Get-AzPolicyAssignment -Name "assign-defender-onboarding" -Scope "/subscriptions/<subscription-id>"
$assignmentPrincipalId = $assignmentIdentity.Identity.PrincipalId

# Get the UAMI resource ID from deployment outputs
$uamiResourceId = "<uami-resource-id-from-output>"

# Grant Managed Identity Operator role
New-AzRoleAssignment `
  -ObjectId $assignmentPrincipalId `
  -RoleDefinitionName "Managed Identity Operator" `
  -Scope $uamiResourceId
```

**Why this is needed:** The policy assignment creates a system-assigned managed identity that needs permission to assign the user-assigned managed identity to virtual machines. The **Managed Identity Operator** role provides this permission.

## Deployment Outputs

The deployment provides the following outputs:

```json
{
  "uamiClientId": "00000000-0000-0000-0000-000000000000",
  "uamiResourceId": "/subscriptions/.../resourceGroups/.../providers/Microsoft.ManagedIdentity/userAssignedIdentities/...",
  "uamiPrincipalId": "00000000-0000-0000-0000-000000000000",
  "uamiPolicyDefinitionId": "/providers/Microsoft.Management/managementGroups/.../providers/Microsoft.Authorization/policyDefinitions/...",
  "csePolicyDefinitionId": "/providers/Microsoft.Management/managementGroups/.../providers/Microsoft.Authorization/policyDefinitions/...",
  "initiativeId": "/providers/Microsoft.Management/managementGroups/.../providers/Microsoft.Authorization/policySetDefinitions/..."
}
```

## Key Bicep Concepts Demonstrated

### 1. Multi-Scope Deployment
- Management Group scope for policies
- Subscription scope for resource group
- Resource Group scope for UAMI

### 2. Module Composition
- Reusable modules for common patterns
- Parameter passing between modules
- Output chaining for dependencies

### 3. Loading External JSON
```bicep
var policyJson = loadJsonContent('policies/policy.json')
```

### 4. Cross-Scope Module References
```bicep
module uami 'modules/uami.bicep' = {
  scope: subscription(subscriptionId)
}

module policy 'modules/policyDefinition.bicep' = {
  scope: managementGroup(managementGroupId)
}
```

### 5. Dynamic Resource ID Construction
```bicep
policyDefinitionId: uamiPolicy.outputs.policyDefinitionId
```

## Customization

### Change UAMI Name
Modify the `uamiName` parameter in the parameter file or override during deployment:

```bash
az deployment mg create ... --parameters uamiName="my-custom-uami-name"
```

### Change Policy Names
Update the parameter file:
```json
{
  "uamiPolicyName": { "value": "custom-uami-policy" },
  "csePolicyName": { "value": "custom-cse-policy" },
  "initiativeName": { "value": "custom-initiative" }
}
```

### Add Custom Tags
Modify the `tags` parameter:
```json
{
  "tags": {
    "value": {
      "Environment": "Production",
      "CostCenter": "IT-Security",
      "Owner": "Security-Team"
    }
  }
}
```

## Troubleshooting

### Common Issues

1. **Permission Errors**
   - Ensure you have the required roles at management group and subscription levels
   - Check RBAC assignments with `az role assignment list`

2. **Policy Validation Errors**
   - Validate policy JSON files are properly formatted
   - Check that all required parameters are defined

3. **Module Not Found Errors**
   - Ensure all module files exist in the `modules/` directory
   - Check file paths are relative to `main.bicep`

4. **Deployment Timeout**
   - Management group deployments can take several minutes
   - Use `--no-wait` flag for async deployment if needed

### Debugging

Enable verbose output:
```bash
az deployment mg create ... --verbose
```

View detailed deployment operations:
```bash
az deployment mg operation list \
  --management-group-id "mg-contoso" \
  --name "defender-onboarding-deployment"
```

## Clean Up

To remove the deployment:

```bash
# Delete policy assignment first
az policy assignment delete --name "assign-defender-onboarding"

# Delete initiative
az policy set-definition delete --management-group "mg-contoso" --name "initiative-defender-onboarding"

# Delete policy definitions
az policy definition delete --management-group "mg-contoso" --name "policy-assign-uami-defender-onboarding"
az policy definition delete --management-group "mg-contoso" --name "policy-cse-defender-onboarding"

# Delete UAMI and resource group
az identity delete --ids "<uami-resource-id>"
az group delete --name "rg-defender-onboarding" --yes
```

## Support and Contribution

For issues or questions:
1. Review this documentation
2. Check Azure Policy documentation
3. Validate Bicep syntax with `az bicep build`

## License

This Bicep deployment is provided as-is for demonstration and learning purposes.