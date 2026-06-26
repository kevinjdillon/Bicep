<#
.SYNOPSIS
    Deploys the Defender Onboarding Policy Solution using Bicep

.DESCRIPTION
    This script deploys a User-Assigned Managed Identity, two custom policy definitions,
    and a policy initiative to a management group for automated Defender onboarding to Windows VMs.

.PARAMETER ManagementGroupId
    The management group ID where policies will be deployed (overrides parameter file)

.PARAMETER ParameterFile
    Path to the parameter file (default: .\parameters\main.parameters.json)

.PARAMETER Location
    Azure location for the deployment metadata (default: westus2)

.PARAMETER SkipValidation
    Skip template validation before deployment

.EXAMPLE
    .\Deploy-DefenderOnboarding.ps1
    
.EXAMPLE
    .\Deploy-DefenderOnboarding.ps1 -ManagementGroupId "mg-contoso" -Location "eastus"

.EXAMPLE
    .\Deploy-DefenderOnboarding.ps1 -ParameterFile ".\parameters\custom.parameters.json"

.NOTES
    Author: Bicep Deployment Script
    Requires: Azure PowerShell module (Az)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManagementGroupId,

    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = ".\parameters\main.parameters.json",

    [Parameter(Mandatory = $false)]
    [string]$Location = "westus2",

    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation
)

#Requires -Modules Az.Accounts, Az.Resources

# Set strict mode and error action preference
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Script variables
$TemplateFile = ".\main.bicep"
$DeploymentName = "defender-onboarding-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Defender Onboarding Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Az module is installed
Write-Host "Checking Azure PowerShell module..." -ForegroundColor Yellow
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Write-Error "Azure PowerShell module not found. Please install it using: Install-Module -Name Az -AllowClobber -Scope CurrentUser"
    exit 1
}

# Check if connected to Azure
Write-Host "Checking Azure connection..." -ForegroundColor Yellow
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not connected to Azure. Initiating login..." -ForegroundColor Yellow
    Connect-AzAccount
    $context = Get-AzContext
}

Write-Host "Connected to Azure:" -ForegroundColor Green
Write-Host "  Account: $($context.Account.Id)" -ForegroundColor Gray
Write-Host "  Tenant:  $($context.Tenant.Id)" -ForegroundColor Gray
Write-Host ""

# Verify files exist
Write-Host "Verifying template and parameter files..." -ForegroundColor Yellow
if (-not (Test-Path $TemplateFile)) {
    Write-Error "Template file not found: $TemplateFile"
    exit 1
}

if (-not (Test-Path $ParameterFile)) {
    Write-Error "Parameter file not found: $ParameterFile"
    exit 1
}

Write-Host "  Template file: $TemplateFile" -ForegroundColor Green
Write-Host "  Parameter file: $ParameterFile" -ForegroundColor Green
Write-Host ""

# Read parameter file to get management group ID if not provided
if (-not $ManagementGroupId) {
    Write-Host "Reading management group ID from parameter file..." -ForegroundColor Yellow
    $paramContent = Get-Content $ParameterFile -Raw | ConvertFrom-Json
    $ManagementGroupId = $paramContent.parameters.managementGroupId.value
    
    if ($ManagementGroupId -eq "YOUR_MANAGEMENT_GROUP_ID") {
        Write-Error "Management group ID not set in parameter file. Please update the parameter file or use -ManagementGroupId parameter."
        exit 1
    }
}

Write-Host "Deployment Configuration:" -ForegroundColor Cyan
Write-Host "  Management Group: $ManagementGroupId" -ForegroundColor Gray
Write-Host "  Location:         $Location" -ForegroundColor Gray
Write-Host "  Deployment Name:  $DeploymentName" -ForegroundColor Gray
Write-Host ""

# Validate template
if (-not $SkipValidation) {
    Write-Host "Validating Bicep template..." -ForegroundColor Yellow
    try {
        $validationResult = Test-AzManagementGroupDeployment `
            -ManagementGroupId $ManagementGroupId `
            -Location $Location `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $ParameterFile
        
        if ($validationResult) {
            Write-Host "Validation completed with warnings/errors:" -ForegroundColor Red
            $validationResult | Format-List
            
            $continue = Read-Host "Do you want to continue with deployment? (Y/N)"
            if ($continue -ne 'Y' -and $continue -ne 'y') {
                Write-Host "Deployment cancelled by user." -ForegroundColor Yellow
                exit 0
            }
        } else {
            Write-Host "Template validation successful!" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Template validation failed: $_"
        exit 1
    }
    Write-Host ""
}

# Deploy
Write-Host "Starting deployment..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes..." -ForegroundColor Gray
Write-Host ""

try {
    $deployment = New-AzManagementGroupDeployment `
        -ManagementGroupId $ManagementGroupId `
        -Location $Location `
        -Name $DeploymentName `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $ParameterFile `
        -Verbose
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Deployment Successful!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # Display outputs
    if ($deployment.Outputs) {
        Write-Host "Deployment Outputs:" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "User-Assigned Managed Identity:" -ForegroundColor Yellow
        Write-Host "  Name:        $($deployment.Outputs.uamiName.Value)" -ForegroundColor Gray
        Write-Host "  Client ID:   $($deployment.Outputs.uamiClientId.Value)" -ForegroundColor Gray
        Write-Host "  Resource ID: $($deployment.Outputs.uamiResourceId.Value)" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "Policy Definitions:" -ForegroundColor Yellow
        Write-Host "  UAMI Policy: $($deployment.Outputs.uamiPolicyDefinitionId.Value)" -ForegroundColor Gray
        Write-Host "  CSE Policy:  $($deployment.Outputs.csePolicyDefinitionId.Value)" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "Policy Initiative:" -ForegroundColor Yellow
        Write-Host "  ID: $($deployment.Outputs.initiativeId.Value)" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Assign the policy initiative to your desired scope" -ForegroundColor White
    Write-Host "  2. Configure assignment parameters (UAMI Client ID, Script URI)" -ForegroundColor White
    Write-Host "  3. Grant UAMI permissions to access blob storage" -ForegroundColor White
    Write-Host ""
    Write-Host "For more information, see README.md" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Deployment Failed!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Error $_.Exception.Message
    
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  - Verify you have the required permissions" -ForegroundColor Gray
    Write-Host "  - Check that the parameter file values are correct" -ForegroundColor Gray
    Write-Host "  - Review the error message above for details" -ForegroundColor Gray
    Write-Host ""
    
    exit 1
}