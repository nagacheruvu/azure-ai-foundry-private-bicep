<#
.SYNOPSIS
    Pre-requisites check for AI Foundry Private Deployment (Hub-Spoke Model)
.DESCRIPTION
    Validates that all required resources exist and are properly configured
    in the central networking subscription before deploying AI Foundry.
.PARAMETER PeSubnetId
    Resource ID of the private endpoints subnet
.PARAMETER DnsSubscriptionId
    Subscription ID where Private DNS Zones live
.PARAMETER DnsResourceGroup
    Resource group name containing Private DNS Zones
.PARAMETER TargetSubscriptionId
    Subscription ID where AI Foundry will be deployed
.PARAMETER TargetResourceGroup
    Resource group for AI Foundry deployment
.PARAMETER Location
    Azure region for deployment
.EXAMPLE
    .\prereqs-check.ps1 -PeSubnetId "/subscriptions/.../subnets/snet-pe" -DnsSubscriptionId "abc-123" -DnsResourceGroup "rg-dns-central" -TargetSubscriptionId "def-456" -TargetResourceGroup "rg-aifoundry-prod"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PeSubnetId,

    [Parameter(Mandatory=$true)]
    [string]$DnsSubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$DnsResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$TargetSubscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$TargetResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2",

    [Parameter(Mandatory=$false)]
    [string]$ComputeSubnetId = "",

    [Parameter(Mandatory=$false)]
    [string]$ExistingKeyVaultName = "",

    [Parameter(Mandatory=$false)]
    [string]$ExistingStorageAccountName = "",

    [Parameter(Mandatory=$false)]
    [string]$ExistingAcrName = ""
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
$script:passed = 0
$script:failed = 0
$script:warnings = 0

function Write-Check {
    param([string]$Name, [string]$Status, [string]$Detail = "")
    switch ($Status) {
        "PASS" { 
            Write-Host "  [PASS] " -ForegroundColor Green -NoNewline
            $script:passed++
        }
        "FAIL" { 
            Write-Host "  [FAIL] " -ForegroundColor Red -NoNewline
            $script:failed++
        }
        "WARN" { 
            Write-Host "  [WARN] " -ForegroundColor Yellow -NoNewline
            $script:warnings++
        }
    }
    Write-Host "$Name" -NoNewline
    if ($Detail) { Write-Host " - $Detail" -ForegroundColor DarkGray } else { Write-Host "" }
}

function Get-ResourceFromId {
    param([string]$ResourceId)
    $parts = $ResourceId -split '/'
    return @{
        SubscriptionId = $parts[2]
        ResourceGroup = $parts[4]
        Provider = $parts[6]
        ResourceType = $parts[7]
        Name = $parts[8]
    }
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " AI Foundry Private Deployment - Prerequisites Check" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Azure CLI & Authentication
# ---------------------------------------------------------------------------
Write-Host "[1/7] Azure CLI & Authentication" -ForegroundColor White
Write-Host "------------------------------------------------------------"

try {
    $azVersionJson = az version 2>$null | ConvertFrom-Json
    $azVersion = $azVersionJson.'azure-cli'
}
catch { $azVersion = $null }
if ($azVersion) {
    Write-Check "Azure CLI installed" "PASS" "v$azVersion"
} else {
    Write-Check "Azure CLI installed" "FAIL" "az CLI not found in PATH"
    Write-Host "`n  Cannot continue without Azure CLI. Install from https://aka.ms/installazurecli" -ForegroundColor Red
    exit 1
}

$account = az account show --query "{id:id, name:name, tenantId:tenantId}" -o json 2>$null | ConvertFrom-Json
if ($account) {
    Write-Check "Authenticated to Azure" "PASS" "$($account.name) ($($account.id))"
} else {
    Write-Check "Authenticated to Azure" "FAIL" "Run 'az login' first"
    exit 1
}

# Check bicep
$bicepVersion = az bicep version 2>$null
if ($bicepVersion -match 'Bicep CLI version (\S+)') {
    Write-Check "Bicep CLI available" "PASS" "$($Matches[1])"
} else {
    Write-Check "Bicep CLI available" "WARN" "Will attempt install via 'az bicep install'"
}

Write-Host ""

# ---------------------------------------------------------------------------
# 2. Subscription Access
# ---------------------------------------------------------------------------
Write-Host "[2/7] Subscription Access" -ForegroundColor White
Write-Host "------------------------------------------------------------"

# Check target subscription access
$targetSub = az account show --subscription $TargetSubscriptionId --query "name" -o tsv 2>$null
if ($targetSub) {
    Write-Check "Target subscription accessible" "PASS" "$targetSub ($TargetSubscriptionId)"
} else {
    Write-Check "Target subscription accessible" "FAIL" "Cannot access subscription $TargetSubscriptionId"
}

# Check DNS/networking subscription access
$dnsSub = az account show --subscription $DnsSubscriptionId --query "name" -o tsv 2>$null
if ($dnsSub) {
    Write-Check "DNS/Network subscription accessible" "PASS" "$dnsSub ($DnsSubscriptionId)"
} else {
    Write-Check "DNS/Network subscription accessible" "FAIL" "Cannot access subscription $DnsSubscriptionId"
}

Write-Host ""

# ---------------------------------------------------------------------------
# 3. Resource Provider Registration
# ---------------------------------------------------------------------------
Write-Host "[3/7] Resource Provider Registration (target subscription)" -ForegroundColor White
Write-Host "------------------------------------------------------------"

$requiredProviders = @(
    'Microsoft.MachineLearningServices',
    'Microsoft.Network',
    'Microsoft.Storage',
    'Microsoft.KeyVault',
    'Microsoft.ContainerRegistry',
    'Microsoft.Insights',
    'Microsoft.OperationalInsights'
)

foreach ($provider in $requiredProviders) {
    $state = az provider show --namespace $provider --subscription $TargetSubscriptionId --query "registrationState" -o tsv 2>$null
    if ($state -eq "Registered") {
        Write-Check "$provider" "PASS" "Registered"
    } else {
        Write-Check "$provider" "FAIL" "State: $state - Run: az provider register --namespace $provider --subscription $TargetSubscriptionId"
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# 4. VNet & Subnet Validation
# ---------------------------------------------------------------------------
Write-Host "[4/7] VNet & Subnet Validation" -ForegroundColor White
Write-Host "------------------------------------------------------------"

$subnetParts = Get-ResourceFromId $PeSubnetId
$vnetSubId = $subnetParts.SubscriptionId

# Check subnet exists
$subnet = az network vnet subnet show --ids $PeSubnetId --query "{name:name, addressPrefix:addressPrefix, privateEndpointNetworkPolicies:privateEndpointNetworkPolicies}" -o json 2>$null | ConvertFrom-Json
if ($subnet) {
    Write-Check "PE subnet exists" "PASS" "$($subnet.name) ($($subnet.addressPrefix))"
    
    # Check PE network policies are disabled
    if ($subnet.privateEndpointNetworkPolicies -eq "Disabled") {
        Write-Check "PE network policies disabled" "PASS"
    } else {
        Write-Check "PE network policies disabled" "FAIL" "privateEndpointNetworkPolicies must be 'Disabled'. Run: az network vnet subnet update --ids $PeSubnetId --private-endpoint-network-policies Disabled"
    }

    # Check available IPs
    $prefixSize = [int]($subnet.addressPrefix -split '/')[1]
    $availableIps = [math]::Pow(2, 32 - $prefixSize) - 5  # Azure reserves 5
    $minRequired = 15  # Hub PE + Storage (blob, file) + KV + ACR + buffer
    if ($availableIps -ge $minRequired) {
        Write-Check "Subnet IP capacity" "PASS" "~$([int]$availableIps) usable IPs (need $minRequired minimum)"
    } else {
        Write-Check "Subnet IP capacity" "WARN" "Only ~$([int]$availableIps) IPs available; may need larger subnet"
    }
} else {
    Write-Check "PE subnet exists" "FAIL" "Cannot find subnet: $PeSubnetId"
}

# Check compute subnet if provided
if ($ComputeSubnetId) {
    $computeSubnet = az network vnet subnet show --ids $ComputeSubnetId --query "{name:name, addressPrefix:addressPrefix}" -o json 2>$null | ConvertFrom-Json
    if ($computeSubnet) {
        Write-Check "Compute subnet exists" "PASS" "$($computeSubnet.name) ($($computeSubnet.addressPrefix))"
    } else {
        Write-Check "Compute subnet exists" "FAIL" "Cannot find subnet: $ComputeSubnetId"
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# 5. Private DNS Zones
# ---------------------------------------------------------------------------
Write-Host "[5/7] Private DNS Zones (central subscription)" -ForegroundColor White
Write-Host "------------------------------------------------------------"

$requiredZones = @(
    'privatelink.api.azureml.ms',
    'privatelink.notebooks.azure.net',
    'privatelink.blob.core.windows.net',
    'privatelink.file.core.windows.net',
    'privatelink.vaultcore.azure.net',
    'privatelink.azurecr.io',
    'privatelink.openai.azure.com',
    'privatelink.cognitiveservices.azure.com'
)

$dnsZonesFound = @{}
$dnsZonesList = az network private-dns zone list --subscription $DnsSubscriptionId --resource-group $DnsResourceGroup --query "[].name" -o json 2>$null | ConvertFrom-Json

foreach ($zone in $requiredZones) {
    if ($dnsZonesList -contains $zone) {
        Write-Check "$zone" "PASS"
        $dnsZonesFound[$zone] = $true
        
        # Check VNet link exists
        $vnetId = ($PeSubnetId -split '/subnets/')[0]
        $links = az network private-dns link vnet list --zone-name $zone --resource-group $DnsResourceGroup --subscription $DnsSubscriptionId --query "[?virtualNetwork.id=='$vnetId'].name" -o json 2>$null | ConvertFrom-Json
        if ($links -and $links.Count -gt 0) {
            Write-Check "  VNet link for $zone" "PASS" "Linked to VNet"
        } else {
            Write-Check "  VNet link for $zone" "WARN" "No VNet link found - PE DNS resolution may fail"
        }
    } else {
        Write-Check "$zone" "FAIL" "Not found in $DnsResourceGroup"
    }
}

Write-Host ""

# ---------------------------------------------------------------------------
# 6. Existing Resources Validation (if specified)
# ---------------------------------------------------------------------------
Write-Host "[6/7] Existing Resources Validation" -ForegroundColor White
Write-Host "------------------------------------------------------------"

if ($ExistingKeyVaultName) {
    $kv = az keyvault show --name $ExistingKeyVaultName --query "{name:name, sku:properties.sku.name, rbac:properties.enableRbacAuthorization, publicAccess:properties.publicNetworkAccess}" -o json 2>$null | ConvertFrom-Json
    if ($kv) {
        Write-Check "Key Vault '$ExistingKeyVaultName' exists" "PASS"
        if ($kv.rbac -eq $true) {
            Write-Check "  RBAC authorization enabled" "PASS"
        } else {
            Write-Check "  RBAC authorization enabled" "WARN" "AI Foundry works best with RBAC-enabled Key Vault"
        }
    } else {
        Write-Check "Key Vault '$ExistingKeyVaultName' exists" "FAIL"
    }
} else {
    Write-Check "Key Vault" "PASS" "Will create new"
}

if ($ExistingStorageAccountName) {
    $st = az storage account show --name $ExistingStorageAccountName --query "{name:name, kind:kind, sku:sku.name, hns:isHnsEnabled}" -o json 2>$null | ConvertFrom-Json
    if ($st) {
        Write-Check "Storage Account '$ExistingStorageAccountName' exists" "PASS" "$($st.kind) / $($st.sku)"
        if ($st.hns -eq $true) {
            Write-Check "  HNS (Data Lake)" "WARN" "AI Foundry prefers non-HNS StorageV2 accounts"
        }
    } else {
        Write-Check "Storage Account '$ExistingStorageAccountName' exists" "FAIL"
    }
} else {
    Write-Check "Storage Account" "PASS" "Will create new"
}

if ($ExistingAcrName) {
    $acr = az acr show --name $ExistingAcrName --query "{name:name, sku:sku.name, publicAccess:publicNetworkAccess}" -o json 2>$null | ConvertFrom-Json
    if ($acr) {
        Write-Check "Container Registry '$ExistingAcrName' exists" "PASS" "SKU: $($acr.sku)"
        if ($acr.sku -ne "Premium") {
            Write-Check "  ACR SKU is Premium" "FAIL" "Private endpoints require Premium SKU"
        } else {
            Write-Check "  ACR SKU is Premium" "PASS"
        }
    } else {
        Write-Check "Container Registry '$ExistingAcrName' exists" "FAIL"
    }
} else {
    Write-Check "Container Registry" "PASS" "Will create new (Premium SKU)"
}

Write-Host ""

# ---------------------------------------------------------------------------
# 7. RBAC & Permissions
# ---------------------------------------------------------------------------
Write-Host "[7/7] RBAC & Permissions" -ForegroundColor White
Write-Host "------------------------------------------------------------"

$currentUser = az ad signed-in-user show --query "{objectId:id, upn:userPrincipalName}" -o json 2>$null | ConvertFrom-Json
if ($currentUser) {
    Write-Check "Current user identity" "PASS" "$($currentUser.upn)"
} else {
    Write-Check "Current user identity" "WARN" "Could not resolve signed-in user (service principal?)"
}

# Check if user has Contributor on target subscription
$roleAssignments = az role assignment list --assignee $currentUser.objectId --subscription $TargetSubscriptionId --query "[?roleDefinitionName=='Contributor' || roleDefinitionName=='Owner'].roleDefinitionName" -o json 2>$null | ConvertFrom-Json
if ($roleAssignments -and $roleAssignments.Count -gt 0) {
    Write-Check "Contributor/Owner on target sub" "PASS" "$($roleAssignments[0])"
} else {
    Write-Check "Contributor/Owner on target sub" "WARN" "May lack permissions - check role assignments"
}

# Check Network Contributor on network sub (needed for PE creation in cross-sub VNet)
if ($vnetSubId -ne $TargetSubscriptionId) {
    $netRoles = az role assignment list --assignee $currentUser.objectId --subscription $vnetSubId --query "[?roleDefinitionName=='Network Contributor' || roleDefinitionName=='Contributor' || roleDefinitionName=='Owner'].roleDefinitionName" -o json 2>$null | ConvertFrom-Json
    if ($netRoles -and $netRoles.Count -gt 0) {
        Write-Check "Network Contributor on network sub" "PASS" "$($netRoles[0])"
    } else {
        Write-Check "Network Contributor on network sub" "FAIL" "Need 'Network Contributor' on networking subscription for cross-sub PE creation"
    }
}

# Check Private DNS Zone Contributor
$dnsRoles = az role assignment list --assignee $currentUser.objectId --subscription $DnsSubscriptionId --resource-group $DnsResourceGroup --query "[?contains(roleDefinitionName, 'DNS') || roleDefinitionName=='Contributor' || roleDefinitionName=='Owner'].roleDefinitionName" -o json 2>$null | ConvertFrom-Json
if ($dnsRoles -and $dnsRoles.Count -gt 0) {
    Write-Check "DNS Zone Contributor on DNS RG" "PASS" "$($dnsRoles[0])"
} else {
    Write-Check "DNS Zone Contributor on DNS RG" "WARN" "May need 'Private DNS Zone Contributor' for A-record auto-registration"
}

Write-Host ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Passed:   $script:passed" -ForegroundColor Green
Write-Host "  Warnings: $script:warnings" -ForegroundColor Yellow
Write-Host "  Failed:   $script:failed" -ForegroundColor Red
Write-Host ""

if ($script:failed -gt 0) {
    Write-Host "  RESULT: NOT READY - Fix the failures above before deploying." -ForegroundColor Red
    Write-Host ""
    exit 1
} elseif ($script:warnings -gt 0) {
    Write-Host "  RESULT: READY WITH WARNINGS - Review warnings above." -ForegroundColor Yellow
    Write-Host ""
    exit 0
} else {
    Write-Host "  RESULT: ALL CLEAR - Ready to deploy!" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# ---------------------------------------------------------------------------
# Output DNS Zone IDs for deployment parameters
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "------------------------------------------------------------"
Write-Host " DNS Zone Resource IDs (for bicepparam file)" -ForegroundColor Cyan
Write-Host "------------------------------------------------------------"

if ($dnsZonesList) {
    foreach ($zone in $requiredZones) {
        if ($dnsZonesFound[$zone]) {
            $zoneId = "/subscriptions/$DnsSubscriptionId/resourceGroups/$DnsResourceGroup/providers/Microsoft.Network/privateDnsZones/$zone"
            Write-Host "  $zone" -ForegroundColor DarkGray
            Write-Host "    $zoneId"
        }
    }
}
Write-Host ""
