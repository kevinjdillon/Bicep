# Quick Start Guide

This guide provides a streamlined deployment process for the Defender Onboarding Bicep solution.

## 📋 Prerequisites Checklist

- [ ] Azure CLI installed and updated
- [ ] Logged into Azure: `az login`
- [ ] Access to a Management Group
- [ ] Contributor access to target subscription
- [ ] Management Group Contributor role

## 🚀 Deploy in 3 Steps

### Step 1: Update Parameters (2 minutes)

Edit `bicep/parameters/main.parameters.json`:

```json
{
  "managementGroupId": { "value": "YOUR_MG_ID" },
  "subscriptionId": { "value": "YOUR_SUB_ID" },
  "uamiResourceGroupName": { "value": "rg-defender-onboarding" },
  "uamiLocation": { "value": "westus2" }
}
```

### Step 2: Validate (1 minute)

```bash
cd bicep
az deployment mg validate \
  --management-group-id "YOUR_MG_ID" \
  --location "westus2" \
  --template-file main.bicep \
  --parameters parameters/main.parameters.json
```

### Step 3: Deploy (5-10 minutes)

```bash
az deployment mg create \
  --management-group-id "YOUR_MG_ID" \
  --location "westus2" \
  --template-file main.bicep \
  --parameters parameters/main.parameters.json \
  --name "defender-onboarding-$(date +%Y%m%d-%H%M%S)"
```

## 📊 Verify Deployment

After deployment completes, verify the resources:

```bash
# View deployment outputs
az deployment mg show \
  --management-group-id "YOUR_MG_ID" \
  --name "defender-onboarding-TIMESTAMP" \
  --query properties.outputs

# List policy definitions at management group
az policy definition list \
  --management-group "YOUR_MG_ID" \
  --query "[?policyType=='Custom'].{Name:name, DisplayName:displayName}"

# List policy initiatives
az policy set-definition list \
  --management-group "YOUR_MG_ID" \
  --query "[?policyType=='Custom'].{Name:name, DisplayName:displayName}"

# Verify UAMI
az identity show \
  --name "uami-w-operations-defender-cse" \
  --resource-group "rg-defender-onboarding"
```

## 🔧 What Was Deployed

| Resource Type | Name | Scope | Purpose |
|--------------|------|-------|---------|
| User-Assigned Managed Identity | `uami-w-operations-defender-cse` | Subscription/RG | VM authentication for script access |
| Policy Definition | `policy-assign-uami-defender-onboarding` | Management Group | Assign UAMI to VMs |
| Policy Definition | `policy-cse-defender-onboarding` | Management Group | Deploy CSE to VMs |
| Policy Initiative | `initiative-defender-onboarding` | Management Group | Combined policy set |

## 📝 Next Steps

1. **Assign the Policy Initiative** to your desired scope
2. **Configure the assignment parameters** (UAMI Client ID, Script URI)
3. **Grant UAMI permissions** to access blob storage
4. **Grant Policy Assignment Managed Identity permissions** to UAMI resource - 'Managed Identity Operator'
4. **Test on a pilot VM** before broad deployment

See [README.md](README.md) for detailed post-deployment steps.

## 🆘 Troubleshooting Quick Tips

**Problem:** Permission denied during deployment
- **Solution:** Verify you have Management Group Contributor role

**Problem:** Module not found error
- **Solution:** Ensure you're running commands from the `bicep/` directory

**Problem:** Invalid JSON in policy files
- **Solution:** Validate JSON files at `bicep/policies/` directory

**Problem:** Deployment timeout
- **Solution:** Add `--no-wait` flag to run asynchronously

## 🧹 Quick Cleanup

Remove everything in reverse order:

```bash
# 1. Delete policy assignment (if created)
az policy assignment delete --name "your-assignment-name"

# 2. Delete initiative
az policy set-definition delete \
  --management-group "YOUR_MG_ID" \
  --name "initiative-defender-onboarding"

# 3. Delete policies
az policy definition delete \
  --management-group "YOUR_MG_ID" \
  --name "policy-assign-uami-defender-onboarding"

az policy definition delete \
  --management-group "YOUR_MG_ID" \
  --name "policy-cse-defender-onboarding"

# 4. Delete UAMI and resource group
az group delete \
  --name "rg-defender-onboarding" \
  --yes --no-wait
```

## 📚 Additional Resources

- Full documentation: [README.md](README.md)
- Azure Policy documentation: https://learn.microsoft.com/azure/governance/policy/
- Bicep documentation: https://learn.microsoft.com/azure/azure-resource-manager/bicep/