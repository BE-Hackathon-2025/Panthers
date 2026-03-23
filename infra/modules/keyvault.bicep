// ── Key Vault ─────────────────────────────────────────────────────────────────
param location string
param environment string

var kvName = 'kv-swap-dev'

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    // Soft-delete and purge protection enabled for production safety
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    // RBAC authorization model (not vault access policies)
    enableRbacAuthorization: true
  }
  tags: {
    environment: environment
    project: 'swap'
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output keyVaultId string = keyVault.id
